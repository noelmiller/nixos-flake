#!/usr/bin/env python3
"""Check NixOS package build status against Hydra and cache.nixos.org."""

import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from threading import Lock
from typing import TypedDict, cast

ARCH = "x86_64-linux"
OFFICIAL_HYDRA = "https://hydra.nixos.org"
MAX_PAGES = 5
SLOW_THRESHOLD = 500 * 1024 * 1024  # 500MB

# ── Types ──────────────────────────────────────────────────────────────────────


class NixpkgsInput(TypedDict):
    revision: str


class JobsetEvalInputs(TypedDict):
    nixpkgs: NixpkgsInput


class HydraEval(TypedDict):
    id: int
    jobsetevalinputs: JobsetEvalInputs


class HydraEvalsPage(TypedDict):
    evals: list[HydraEval]


class HydraBuildJob(TypedDict, total=False):
    buildstatus: int | None


class NixPackage(TypedDict):
    name: str
    free: bool


class LockedInput(TypedDict, total=False):
    owner: str
    repo: str
    rev: str


class FlakeLockNode(TypedDict, total=False):
    locked: LockedInput


class FlakeLock(TypedDict):
    nodes: dict[str, FlakeLockNode]


class LatestEvalCache(TypedDict):
    eval_id: str
    revision: str
    fetched_at: float


EVAL_CACHE_TTL = 3600  # seconds — Hydra unstable evals change every few hours

# ── Setup ──────────────────────────────────────────────────────────────────────

script_dir = Path(__file__).resolve().parent
flake_path = subprocess.check_output(
    ["git", "-C", str(script_dir), "rev-parse", "--show-toplevel"],
    text=True,
).strip()

host = os.environ.get("HOST") or subprocess.check_output(["hostname"], text=True).strip()

cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "nixos-check-packages"
cache_file = cache_dir / "hydra-evals.json"
eval_cache_file = cache_dir / "latest-eval.json"
cache_dir.mkdir(parents=True, exist_ok=True)
if not cache_file.exists():
    _ = cache_file.write_text("{}")

# In-memory cache loaded once; writes flushed to disk under lock
_cache_lock = Lock()
_cache: dict[str, dict[str, str]] = cast(dict[str, dict[str, str]], json.loads(cache_file.read_text()))


def cache_get(eval_id: str, pkg: str) -> str | None:
    return _cache.get(eval_id, {}).get(pkg)


def cache_set(eval_id: str, pkg: str, status: str) -> None:
    with _cache_lock:
        _cache.setdefault(eval_id, {})[pkg] = status
        _ = cache_file.write_text(json.dumps(_cache))


# ── HTTP helpers ───────────────────────────────────────────────────────────────

def _fetch_raw(url: str, headers: dict[str, str] | None = None) -> bytes:
    req = urllib.request.Request(url, headers=headers or {})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:  # pyright: ignore[reportAny]
                raw: bytes = resp.read()  # pyright: ignore[reportAny]
            return raw
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            retry_after = int(e.headers.get("Retry-After", 0))  # pyright: ignore[reportAny]
            delay = retry_after if retry_after > 0 else (2 ** attempt * 5)
            print(f"  429 rate limited — retrying in {delay}s (attempt {attempt + 1}/5)", file=sys.stderr)
            time.sleep(delay)
    raise RuntimeError(f"Hydra rate limit exceeded after 5 retries: {url}")


def fetch_json_evals(url: str) -> HydraEvalsPage:
    raw = _fetch_raw(url, {"Accept": "application/json"})
    return cast(HydraEvalsPage, json.loads(raw))


def fetch_json_build(url: str) -> HydraBuildJob:
    raw = _fetch_raw(url, {"Accept": "application/json"})
    return cast(HydraBuildJob, json.loads(raw))


def fetch_text(url: str) -> str:
    try:
        return _fetch_raw(url).decode()
    except urllib.error.HTTPError:
        return ""


# ── Read pinned packages from flake.lock ───────────────────────────────────────

print("Reading pinned packages from flake.lock...")
with open(f"{flake_path}/flake.lock") as f:
    lock_data = cast(FlakeLock, json.load(f))

pinned_packages: dict[str, str] = {}
for key, node in lock_data["nodes"].items():
    locked = node.get("locked")
    if (
        locked is not None
        and key.startswith("nixpkgs-")
        and key != "nixpkgs-stable"
        and locked.get("owner") == "NixOS"
        and locked.get("repo") == "nixpkgs"
    ):
        attr = key.removeprefix("nixpkgs-")
        rev = locked.get("rev", "")
        pinned_packages[attr] = rev
        print(f"  Pinned: {attr} @ {rev[:7]}")

# ── Fetch latest Hydra eval ────────────────────────────────────────────────────

print()
print("Fetching latest official Hydra eval (nixos/unstable)...")

official_eval_id: str
revision: str
page1_data: HydraEvalsPage | None = None

_eval_cached: LatestEvalCache | None = None
if eval_cache_file.exists():
    try:
        _eval_cached = cast(LatestEvalCache, json.loads(eval_cache_file.read_text()))
    except (json.JSONDecodeError, KeyError):
        _eval_cached = None

if (
    _eval_cached is not None
    and time.time() - _eval_cached["fetched_at"] < EVAL_CACHE_TTL
):
    official_eval_id = _eval_cached["eval_id"]
    revision = _eval_cached["revision"]
    print(f"Official eval: {official_eval_id} @ {revision} (cached)")
else:
    page1_data = fetch_json_evals(f"{OFFICIAL_HYDRA}/jobset/nixos/unstable/evals")
    official_eval_id = str(page1_data["evals"][0]["id"])
    revision = page1_data["evals"][0]["jobsetevalinputs"]["nixpkgs"]["revision"]
    _to_cache: LatestEvalCache = {
        "eval_id": official_eval_id,
        "revision": revision,
        "fetched_at": time.time(),
    }
    _ = eval_cache_file.write_text(json.dumps(_to_cache))
    print(f"Official eval: {official_eval_id} @ {revision}")

# ── Fetch package lists (two nix evals in parallel) ───────────────────────────

print()
print(f"Evaluating explicit package list from flake ({flake_path}#{host})...")

NIX_APPLY = """pkgs: map (p: {
    name = p.pname or p.name or "unknown";
    free = p.meta.license.free or (
      if builtins.isList (p.meta.license or [])
      then builtins.all (l: l.free or true) (p.meta.license or [])
      else true
    );
  }) pkgs"""

HM_SKIP = re.compile(r"^(dummy-|hm-session-vars|home-configuration-reference|shared-mime-info)")


def nix_eval_packages(attr: str) -> list[NixPackage]:
    result = subprocess.run(
        ["nix", "eval", "--json", attr, "--apply", NIX_APPLY],
        capture_output=True,
        text=True,
    )
    return cast(list[NixPackage], json.loads(result.stdout)) if result.stdout.strip() else []


def fetch_home_packages() -> list[NixPackage]:
    pkgs = nix_eval_packages(
        f"{flake_path}#nixosConfigurations.{host}.config.home-manager.users.noel.home.packages"
    )
    return [p for p in pkgs if not HM_SKIP.match(p["name"])]


with ThreadPoolExecutor(max_workers=2) as ex:
    fut_sys = ex.submit(
        nix_eval_packages,
        f"{flake_path}#nixosConfigurations.{host}.config.my.explicitPackages",
    )
    fut_home = ex.submit(fetch_home_packages)
    sys_pkgs = fut_sys.result()
    home_pkgs = fut_home.result()

# Merge, deduplicate by name, sort
seen: dict[str, bool] = {}
for p in sys_pkgs + home_pkgs:
    seen[p["name"]] = p["free"]

all_with_license: list[tuple[str, bool]] = sorted(seen.items(), key=lambda x: x[0])
free_packages = [name for name, free in all_with_license if free]
unfree_packages = [name for name, free in all_with_license if not free]

print(f"Found {len(all_with_license)} packages ({len(unfree_packages)} unfree).")

# ── Hydra helpers ──────────────────────────────────────────────────────────────

_page_cache: dict[int, list[tuple[str, str]]] = (
    {
        1: [
            (str(e["id"]), e["jobsetevalinputs"]["nixpkgs"]["revision"])
            for e in page1_data["evals"]
        ]
    }
    if page1_data is not None
    else {}
)
_page_lock = Lock()


def get_hydra_page(page: int) -> list[tuple[str, str]]:
    with _page_lock:
        if page in _page_cache:
            return _page_cache[page]
        print(f"  (fetching eval page {page}...)", file=sys.stderr)
        data = fetch_json_evals(f"{OFFICIAL_HYDRA}/jobset/nixos/unstable/evals?page={page}")
        result = [
            (str(e["id"]), e["jobsetevalinputs"]["nixpkgs"]["revision"])
            for e in data["evals"]
        ]
        _page_cache[page] = result
        return result


def check_hydra_eval(pkg: str, eval_id: str) -> str:
    cached = cache_get(eval_id, pkg)
    if cached is not None:
        return cached
    try:
        data = fetch_json_build(f"{OFFICIAL_HYDRA}/eval/{eval_id}/job/nixpkgs.{pkg}.{ARCH}")
        bs = data.get("buildstatus")
        status = str(bs) if bs is not None else "missing"
    except urllib.error.HTTPError as e:
        status = "missing" if e.code == 404 else "error"
        if status == "error":
            print(f"  ! {pkg}: HTTP {e.code}", file=sys.stderr)
    except Exception as e:
        print(f"  ! {pkg}: {e}", file=sys.stderr)
        status = "missing"
    if status != "missing":
        cache_set(eval_id, pkg, status)
    return status


def find_last_good(pkg: str) -> str:
    """Walk evals page by page, checking each page in parallel, stop at first success."""
    for page in range(1, MAX_PAGES + 1):
        candidates = [
            (eid, rev)
            for eid, rev in get_hydra_page(page)
            if eid != official_eval_id
        ]
        if not candidates:
            continue
        eids = [eid for eid, _ in candidates]

        def _check(eid: str) -> str:
            return check_hydra_eval(pkg, eid)

        with ThreadPoolExecutor(max_workers=min(len(eids), 8)) as ex:
            statuses = list(ex.map(_check, eids))
        for (_, rev), status in zip(candidates, statuses):
            if status == "0":
                return rev
    return ""


# ── Unfree cache check ─────────────────────────────────────────────────────────

def check_cache(pkg: str) -> tuple[str, str, str]:
    """Returns (pkg, category, message). category: cached | slow | quick | unknown"""
    result = subprocess.run(
        ["nix", "eval", "--impure", "--raw", f"github:NixOS/nixpkgs/{revision}#{pkg}.outPath"],
        capture_output=True,
        text=True,
        env={**os.environ, "NIXPKGS_ALLOW_UNFREE": "1"},
    )
    store_path = result.stdout.strip()
    if not store_path:
        return pkg, "unknown", f"  ? {pkg} (could not evaluate — attr path may differ)"

    hash_part = Path(store_path).name.split("-")[0]
    narinfo = fetch_text(f"https://cache.nixos.org/{hash_part}.narinfo")
    if "StorePath:" in narinfo:
        return pkg, "cached", f"  ✓ {pkg} (unfree — cached)"

    size_result = subprocess.run(
        ["nix", "eval", "--impure", f"github:NixOS/nixpkgs/{revision}#{pkg}.size"],
        capture_output=True,
        text=True,
        env={**os.environ, "NIXPKGS_ALLOW_UNFREE": "1"},
    )
    try:
        nar_size = int(size_result.stdout.strip())
    except (ValueError, TypeError):
        nar_size = 0

    if nar_size > SLOW_THRESHOLD:
        return pkg, "slow", f"  ~ {pkg} (unfree — not cached, will build locally — SLOW)"
    return pkg, "quick", f"  ~ {pkg} (unfree — not cached, will build locally — usually quick)"


# ── Tier 1: Free packages (all Hydra checks in parallel) ──────────────────────

print()
print("── Tier 1: Free packages (Hydra) ────────────────────────────────────────")

failed: list[str] = []
pkgs_to_check = [
    p for p in free_packages if p and p != "unknown" and p not in pinned_packages
]


def check_free_pkg(pkg: str) -> tuple[str, str, str]:
    status = check_hydra_eval(pkg, official_eval_id)
    if status == "0":
        return pkg, "ok", f"  ✓ {pkg}"
    if status == "missing":
        return pkg, "missing", f"  ? {pkg} (not found in Hydra — may need attr path adjustment)"
    last_good = find_last_good(pkg)
    if last_good:
        line = f"  ✗ {pkg} (status: {status}) — pin to {last_good[:7]}\n      github:NixOS/nixpkgs/{last_good}"
    else:
        line = f"  ✗ {pkg} (status: {status}) — none found in last {MAX_PAGES} pages"
    return pkg, "failed", line


with ThreadPoolExecutor(max_workers=8) as ex:
    futures = {ex.submit(check_free_pkg, pkg): pkg for pkg in pkgs_to_check}
    free_results: dict[str, tuple[str, str, str]] = {}
    for fut in as_completed(futures):
        r = fut.result()
        free_results[r[0]] = r

for pkg in pkgs_to_check:
    _, status_code, line = free_results[pkg]
    print(line)
    if status_code == "failed":
        failed.append(pkg)

# ── Tier 2: Unfree packages (all cache checks in parallel) ────────────────────

print()
print("── Tier 2: Unfree packages (cache check) ────────────────────────────────")
print("   (not cached = will build locally — not necessarily broken)")

local_build: list[str] = []
local_build_slow: list[str] = []
unfree_to_check = [p for p in unfree_packages if p]

with ThreadPoolExecutor(max_workers=8) as ex:
    futures_u = {ex.submit(check_cache, pkg): pkg for pkg in unfree_to_check}
    unfree_results: dict[str, tuple[str, str, str]] = {}
    for fut in as_completed(futures_u):
        r = fut.result()
        unfree_results[r[0]] = r

for pkg in unfree_to_check:
    _, category, line = unfree_results[pkg]
    print(line)
    if category == "slow":
        local_build_slow.append(pkg)
    elif category == "quick":
        local_build.append(pkg)

# ── Pinned packages (all checks in parallel) ───────────────────────────────────

print()
print("── Pinned packages (checking if safe to unpin) ──────────────────────────")

safe_to_unpin: list[str] = []


def check_pinned(attr: str) -> tuple[str, str, str]:
    pinned_rev = pinned_packages[attr]
    short_pin = pinned_rev[:7]
    if pinned_rev == revision:
        return attr, "current", f"  ✓ {attr} (pinned rev matches latest — already up to date)"
    status = check_hydra_eval(attr, official_eval_id)
    if status == "0":
        return attr, "safe", f"  ✓ {attr} (pinned @ {short_pin} — SAFE TO UNPIN, builds OK in latest eval)"
    if status == "missing":
        return attr, "missing", f"  ? {attr} (pinned @ {short_pin} — not found in latest Hydra eval)"
    return attr, "broken", f"  ✗ {attr} (pinned @ {short_pin} — still broken in latest eval, keep pinned)"


with ThreadPoolExecutor(max_workers=8) as ex:
    futures_p = {ex.submit(check_pinned, attr): attr for attr in pinned_packages}
    pinned_results: dict[str, tuple[str, str, str]] = {}
    for fut in as_completed(futures_p):
        r = fut.result()
        pinned_results[r[0]] = r

for attr in pinned_packages:
    _, category, line = pinned_results[attr]
    print(line)
    if category == "safe":
        safe_to_unpin.append(attr)

# ── Summary ────────────────────────────────────────────────────────────────────

print()
print("═════════════════════════════════════════════════════════════════════════")
print(f"  Host:             {host}")
print(f"  Nixpkgs revision: {revision}")
print(f"  Eval cache:       {cache_file}")

if not failed:
    print("  ✓ No free packages are broken — safe to upgrade")
else:
    print(f"  ✗ Failed packages (pin to suggested commits above): {' '.join(failed)}")

if safe_to_unpin:
    print(f"  ✓ Safe to unpin: {' '.join(safe_to_unpin)}")

if local_build_slow:
    print(f"  ⚠ Slow local builds expected: {' '.join(local_build_slow)}")

if local_build:
    print(f"  ~ Quick local builds expected: {' '.join(local_build)}")

print("═════════════════════════════════════════════════════════════════════════")
