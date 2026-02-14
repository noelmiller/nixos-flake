{ config, pkgs, ... }:

{
  # Install DaVinci Resolve Studio
  environment.systemPackages = with pkgs; [
    davinci-resolve-studio
  ];

  # Enable OpenGL hardware acceleration (required for DaVinci Resolve)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enable ROCm OpenCL support for AMD GPUs (better performance)
  hardware.amdgpu.opencl.enable = true;

  # Optionally add ROCm packages for advanced GPU compute
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];
}
