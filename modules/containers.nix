{ config, pkgs, ... }:

{
  # enable docker
  virtualisation.docker = {
    enable = true;
  };

  # enable podman
  virtualisation.podman = {
    enable = true;
    # Create the default bridge network for podman
    defaultNetwork.settings.dns_enabled = true;
  };

  # install distrobox
  environment.systemPackages = with pkgs; [
    distrobox
  ];

  # add my user to docker group
  users.users.noel.extraGroups = [ "docker" ];
}
