{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    policies = {
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      DisableFirefoxStudies = true;
      DisableFormHistory = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "always";
      FirefoxHome = {
        Search = true;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        Stories = false;
        SponsoredPocket = false;
        SponsoredStories = false;
        Snippets = false;
      };
      GenerativeAI = false;
      HardwareAcceleration = true;
      OfferToSaveLogins = false;
      OverrideFirstRunPage = "";
      PasswordManagerEnabled = false;
      SearchEngines = {
        Default = "Brave Search";
        Add = [
          {
            Name = "Brave Search";
            URLTemplate = "https://search.brave.com/search?q={searchTerms}&amp";
            IconURL = "https://cdn.search.brave.com/serp/v1/static/brand/eebf5f2ce06b0b0ee6bbd72d7e18621d4618b9663471d42463c692d019068072-brave-lion-favicon.png";
            Alias = "brave";
          }
        ];
      };
      ExtensionSettings = builtins.listToAttrs (
      builtins.map (id: {
        name = id;
        value = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${id}/latest.xpi";
          installation_mode = "force_installed";
          default_area = "navbar";
        };
      }) [
        "uBlock0@raymondhill.net"                # uBlock Origin
        "{d7742d87-e61d-4b78-b8a1-b469842139fa}" # Vimium
        "addon@darkreader.org"                   # Dark Reader
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" # 1Password
        "{019b606a-6f61-4d01-af2a-cea528f606da}" # XBrowserSync
      ]
    );
    };
  };
}
