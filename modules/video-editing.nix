{ config, pkgs, ... }:

let
  # Define the accelerated scrcpy here (this fixes ghost window for scrcpy)
  scrcpy-hw = pkgs.scrcpy.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/scrcpy --add-flags "--render-driver=opengl"
    '';
  });
in
{
  # Install DaVinci Resolve Studio and our custom scrcpy
  environment.systemPackages = with pkgs; [
    davinci-resolve-studio
    scrcpy-hw # Use the hardware-accelerated version we defined above
    v4l-utils  # Added this: helpful for debugging your /dev/video10 status
  ];

  # AMD-specific extras for DaVinci Resolve
  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd  # AMD OpenCL
  ];

  # Enable ROCm OpenCL support for AMD GPUs (better performance)
  hardware.amdgpu.opencl.enable = true;

  # Enable kernel driver early
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Enable v4l2loopback kernel module for virtual camera
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  # Configure v4l2loopback with specific parameters
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="Virtual Camera" exclusive_caps=1
  '';
}
