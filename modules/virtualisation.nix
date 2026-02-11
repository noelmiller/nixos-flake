{ config, pkgs, ... }:

{
  # enable virtualization
  virtualisation.libvirtd = {
  enable = true;
  qemu = {
    package = pkgs.qemu_kvm;
    runAsRoot = true;
    swtpm.enable = true;
  };
  };

  # install virt-manager
  environment.systemPackages = with pkgs; [
    virt-manager
  ];
}
