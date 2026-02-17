{ config, pkgs, ... }:

{
  # Install DaVinci Resolve Studio and scrcpy for DroidCam
  environment.systemPackages = with pkgs; [
    davinci-resolve-studio
    scrcpy
  ];

  # Enable OpenGL hardware acceleration (required for DaVinci Resolve)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd  # The OpenCL runtime Resolve is looking for
    ];
  };

  # Enable ROCm OpenCL support for AMD GPUs (better performance)
  hardware.amdgpu.opencl.enable = true;

  # Enable kernel driver early
  boot.initrd.kernelModules = [ "amdgpu" ];
}
