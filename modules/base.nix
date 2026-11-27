{ pkgs, settings, ... }:
{
  system.stateVersion = "26.05";

  time.timeZone = settings.timezone;
  i18n.defaultLocale = settings.locale;
  console.keyMap = "us";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Handy things to have when you're SSH'd in at 1am.
  environment.systemPackages = with pkgs; [
    git vim htop tmux ffmpeg-full mediainfo rsync tree curl jq ncdu
  ];

  # Headless box: never suspend when "idle".
  services.logind.settings.Login.HandleLidSwitch = "ignore";
  powerManagement.enable = false;

  documentation.nixos.enable = false;
}
