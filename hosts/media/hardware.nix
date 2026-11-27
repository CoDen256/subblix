# Hardware for the headless box: Intel Core i5-4570 (Haswell), 12 GB RAM.
# Filesystems come from disko.nix, so nothing is declared here.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "nvme"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Headless: no graphical target, and don't wait forever for a network device.
  systemd.services.NetworkManager-wait-online.enable = false;
}
