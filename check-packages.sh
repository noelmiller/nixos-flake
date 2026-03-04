#!/usr/bin/env bash
set -euo pipefail

ARCH="x86_64-linux"
OFFICIAL_HYDRA="https://hydra.nixos.org"
FLAKE_PATH="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
HOST="${HOST:-$(hostname)}"
MAX_PAGES=5
SLOW_THRESHOLD=$((500 * 1024 * 1024)) # 500MB

# ── Cache setup ───────────────────────────────────────────────────────────────
# Stores Hydra eval results as { "eval_id": { "pkg": buildstatus } }
# Results are immutable so cached entries never need to be invalidated.

CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/nixos-check-packages"
CACHE_FILE="${CACHE_DIR}/hydra-evals.json"
mkdir -p "$CACHE_DIR"
[[ -f "$CACHE_FILE" ]] || echo '{}' > "$CACHE_FILE"

# Look up a build status from cache. Exits 0 and prints status if found, 1 if not.
cache_get() {
  local eval_id=$1 pkg=$2
  local result
  result=$(jq -r --arg e "$eval_id" --arg p "$pkg" \
    '.[$e][$p] // empty' "$CACHE_FILE")
  if [[ -n "$result" ]]; then
    echo "$result"
    return 0
  fi
  return 1
}

# Write a build status to cache.
cache_set() {
  local eval_id=$1 pkg=$2 status=$3
  local tmp
  tmp=$(mktemp)
  jq --arg e "$eval_id" --arg p "$pkg" --arg s "$status" \
    '.[$e] //= {} | .[$e][$p] = $s' "$CACHE_FILE" > "$tmp"
  mv "$tmp" "$CACHE_FILE"
}

# ── Derive pinned packages from flake.lock ────────────────────────────────────

echo "Reading pinned packages from flake.lock..."
declare -A PINNED_PACKAGES

while IFS=: read -r key rev; do
  attr="${key#nixpkgs-}"
  PINNED_PACKAGES["$attr"]="$rev"
  echo "  Pinned: ${attr} @ ${rev:0:7}"
done < <(jq -r '
  .nodes | to_entries[] |
  select(
    (.key | startswith("nixpkgs-")) and
    (.key != "nixpkgs-stable") and
    .value.locked.owner == "NixOS" and
    .value.locked.repo == "nixpkgs"
  ) |
  .key + ":" + .value.locked.rev
' "${FLAKE_PATH}/flake.lock")

# ── Fetch latest Hydra eval (always fresh) ───────────────────────────────────

echo ""
echo "Fetching latest official Hydra eval (nixos/unstable)..."
curl -s "${OFFICIAL_HYDRA}/jobset/nixos/unstable/evals" \
  -H "Accept: application/json" -L -o /tmp/hydra-page-1.json
OFFICIAL_EVAL_ID=$(jq -r '.evals[0].id' /tmp/hydra-page-1.json)
REVISION=$(jq -r '.evals[0].jobsetevalinputs.nixpkgs.revision' /tmp/hydra-page-1.json)
echo "Official eval: ${OFFICIAL_EVAL_ID} @ ${REVISION}"

# ── Pull explicit package lists ───────────────────────────────────────────────

echo ""
echo "Evaluating explicit package list from flake (${FLAKE_PATH}#${HOST})..."

ALL_WITH_LICENSE=$(nix eval --json \
  "${FLAKE_PATH}#nixosConfigurations.${HOST}.config.my.explicitPackages" \
  --apply 'pkgs: map (p: {
    name = p.pname or p.name or "unknown";
    free = p.meta.license.free or (
      if builtins.isList (p.meta.license or [])
      then builtins.all (l: l.free or true) (p.meta.license or [])
      else true
    );
  }) pkgs' \
  2>/dev/null)

HOME_WITH_LICENSE=$(nix eval --json \
  "${FLAKE_PATH}#nixosConfigurations.${HOST}.config.home-manager.users.noel.home.packages" \
  --apply 'pkgs: map (p: {
    name = p.pname or p.name or "unknown";
    free = p.meta.license.free or (
      if builtins.isList (p.meta.license or [])
      then builtins.all (l: l.free or true) (p.meta.license or [])
      else true
    );
  }) pkgs' \
  2>/dev/null \
  | jq '[.[] | select(.name | test("^(dummy-|hm-session-vars|home-configuration-reference|shared-mime-info)") | not)]')

ALL_WITH_LICENSE=$(echo "${ALL_WITH_LICENSE} ${HOME_WITH_LICENSE}" \
  | jq -s 'add | unique_by(.name) | sort_by(.name)')

FREE_PACKAGES=$(echo "$ALL_WITH_LICENSE"   | jq -r '[.[] | select(.free == true)  | .name] | .[]')
UNFREE_PACKAGES=$(echo "$ALL_WITH_LICENSE" | jq -r '[.[] | select(.free == false) | .name] | .[]')

echo "Found $(echo "$ALL_WITH_LICENSE" | jq 'length') packages \
($(echo "$ALL_WITH_LICENSE" | jq '[.[] | select(.free==false)] | length') unfree)."

# ── Helpers ───────────────────────────────────────────────────────────────────

is_pinned() {
  local pkg=$1
  [[ -n "${PINNED_PACKAGES[$pkg]+x}" ]]
}

FAILED=()
LOCAL_BUILD=()
LOCAL_BUILD_SLOW=()
SAFE_TO_UNPIN=()

# Check a package in a specific eval, using cache where possible
check_hydra_eval() {
  local pkg=$1 eval_id=$2
  local status

  # Return cached result if available
  if status=$(cache_get "$eval_id" "$pkg"); then
    echo "$status"
    return
  fi

  # Fetch from Hydra and cache the result
  status=$(curl -s "${OFFICIAL_HYDRA}/eval/${eval_id}/job/nixpkgs.${pkg}.${ARCH}" \
    -H "Accept: application/json" -L \
    | jq -r '.buildstatus // "missing"')

  # Only cache definitive results — not "missing" since the eval may still be running
  if [[ "$status" != "missing" ]]; then
    cache_set "$eval_id" "$pkg" "$status"
  fi

  echo "$status"
}

# Walk evals one at a time, fetching pages only as needed, stopping at first success
find_last_good() {
  local pkg=$1
  local page=1
  local page_file eval_id rev status

  while [[ $page -le $MAX_PAGES ]]; do
    page_file="/tmp/hydra-page-${page}.json"

    if [[ ! -f "$page_file" ]]; then
      echo "  (fetching eval page ${page}...)" >&2
      curl -s "${OFFICIAL_HYDRA}/jobset/nixos/unstable/evals?page=${page}" \
        -H "Accept: application/json" -L -o "$page_file"
    fi

    while IFS=$'\t' read -r eval_id rev; do
      [[ "$eval_id" == "$OFFICIAL_EVAL_ID" ]] && continue

      status=$(check_hydra_eval "$pkg" "$eval_id")
      if [[ "$status" == "0" ]]; then
        echo "${rev}"
        return 0
      fi
    done < <(jq -r '.evals[] | [.id, .jobsetevalinputs.nixpkgs.revision] | @tsv' "$page_file")

    page=$(( page + 1 ))
  done

  echo ""
  return 1
}

check_cache() {
  local pkg=$1
  local store_path hash narinfo nar_size

  store_path=$(NIXPKGS_ALLOW_UNFREE=1 nix eval --impure --raw \
    "github:NixOS/nixpkgs/${REVISION}#${pkg}.outPath" 2>/dev/null || echo "")

  if [[ -z "$store_path" ]]; then
    echo "  ? ${pkg} (could not evaluate — attr path may differ)"
    return
  fi

  hash=$(basename "$store_path" | cut -d- -f1)
  narinfo=$(curl -s "https://cache.nixos.org/${hash}.narinfo")

  if echo "$narinfo" | grep -q "^StorePath:"; then
    echo "  ✓ ${pkg} (unfree — cached)"
  else
    nar_size=$(NIXPKGS_ALLOW_UNFREE=1 nix eval --impure \
      "github:NixOS/nixpkgs/${REVISION}#${pkg}.size" 2>/dev/null || echo "0")
    if [[ "${nar_size:-0}" -gt "$SLOW_THRESHOLD" ]]; then
      echo "  ~ ${pkg} (unfree — not cached, will build locally — SLOW)"
      LOCAL_BUILD_SLOW+=("${pkg}")
    else
      echo "  ~ ${pkg} (unfree — not cached, will build locally — usually quick)"
      LOCAL_BUILD+=("${pkg}")
    fi
  fi
}

# ── Run checks ────────────────────────────────────────────────────────────────

echo ""
echo "── Tier 1: Free packages (Hydra) ────────────────────────────────────────"
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == "unknown" ]] && continue
  is_pinned "$pkg" && continue

  status=$(check_hydra_eval "$pkg" "$OFFICIAL_EVAL_ID")
  case "$status" in
    0)
      echo "  ✓ ${pkg}"
      ;;
    missing)
      echo "  ? ${pkg} (not found in Hydra — may need attr path adjustment)"
      ;;
    *)
      echo -n "  ✗ ${pkg} (status: ${status}) — searching for last good commit..."
      last_good=$(find_last_good "$pkg")
      if [[ -n "$last_good" ]]; then
        echo " pin to ${last_good:0:7}"
        echo "      github:NixOS/nixpkgs/${last_good}"
      else
        echo " none found in last ${MAX_PAGES} pages"
      fi
      FAILED+=("${pkg}")
      ;;
  esac
done <<< "$FREE_PACKAGES"

echo ""
echo "── Tier 2: Unfree packages (cache check) ────────────────────────────────"
echo "   (not cached = will build locally — not necessarily broken)"
while IFS= read -r pkg; do
  [[ -z "$pkg" ]] && continue
  check_cache "$pkg"
done <<< "$UNFREE_PACKAGES"

echo ""
echo "── Pinned packages (checking if safe to unpin) ──────────────────────────"
for attr in "${!PINNED_PACKAGES[@]}"; do
  pinned_rev="${PINNED_PACKAGES[$attr]}"
  short_pin="${pinned_rev:0:7}"

  if [[ "$pinned_rev" == "$REVISION" ]]; then
    echo "  ✓ ${attr} (pinned rev matches latest — already up to date)"
    continue
  fi

  status=$(check_hydra_eval "$attr" "$OFFICIAL_EVAL_ID")
  case "$status" in
    0)
      echo "  ✓ ${attr} (pinned @ ${short_pin} — SAFE TO UNPIN, builds OK in latest eval)"
      SAFE_TO_UNPIN+=("${attr}")
      ;;
    missing)
      echo "  ? ${attr} (pinned @ ${short_pin} — not found in latest Hydra eval)"
      ;;
    *)
      echo "  ✗ ${attr} (pinned @ ${short_pin} — still broken in latest eval, keep pinned)"
      ;;
  esac
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "═════════════════════════════════════════════════════════════════════════"
echo "  Host:             ${HOST}"
echo "  Nixpkgs revision: ${REVISION}"
echo "  Eval cache:       ${CACHE_FILE}"

if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "  ✓ No free packages are broken — safe to upgrade"
else
  echo "  ✗ Failed packages (pin to suggested commits above): ${FAILED[*]}"
fi

if [[ ${#SAFE_TO_UNPIN[@]} -gt 0 ]]; then
  echo "  ✓ Safe to unpin: ${SAFE_TO_UNPIN[*]}"
fi

if [[ ${#LOCAL_BUILD_SLOW[@]} -gt 0 ]]; then
  echo "  ⚠ Slow local builds expected: ${LOCAL_BUILD_SLOW[*]}"
fi

if [[ ${#LOCAL_BUILD[@]} -gt 0 ]]; then
  echo "  ~ Quick local builds expected: ${LOCAL_BUILD[*]}"
fi
echo "═════════════════════════════════════════════════════════════════════════"
