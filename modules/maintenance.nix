{ lib, settings, ... }:
{
  # The OS shares a 500 GB disk with the movies, so old generations must not
  # pile up. Without this, months of autoUpgrade quietly eats tens of GB.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than ${settings.gcOlderThan}";
  };
  nix.optimise.automatic = true;

  boot.loader.systemd-boot.configurationLimit = settings.bootGenerationLimit;

  # The server pulls the repo and rebuilds itself. A bad update is recovered
  # by picking the previous generation at the boot menu, or:
  #   sudo nixos-rebuild switch --rollback
  system.autoUpgrade = lib.mkIf settings.autoUpgrade {
    enable = true;
    flake = "${settings.repoUrl}#media";
    flags = [ "--refresh" "--no-write-lock-file" ];
    dates = settings.autoUpgradeSchedule;
    allowReboot = settings.autoUpgradeAllowReboot;
    randomizedDelaySec = "20min";
  };
}
