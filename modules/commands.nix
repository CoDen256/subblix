{ pkgs, settings, ... }:
let
  flakeTarget = "${settings.repoUrl}#media";

  # Real commands rather than shell aliases, so they also work non-interactively:
  #   ssh media media-update
  # Aliases only exist inside an interactive shell and would silently do nothing
  # there.
  mkCmd = name: text: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ nixos-rebuild systemd coreutils ];
    inherit text;
  };

  update = mkCmd "media-update" ''
    # Re-exec as root if needed; wheel is passwordless on this box.
    if [ "$(id -u)" -ne 0 ]; then exec sudo -- "$0" "$@"; fi

    echo "Pulling ${flakeTarget} and rebuilding..."
    nixos-rebuild switch --flake "${flakeTarget}" --refresh "$@"
    echo
    echo "Now on: $(readlink -f /run/current-system)"
    echo "If something broke:  media-rollback"
  '';

  rollback = mkCmd "media-rollback" ''
    if [ "$(id -u)" -ne 0 ]; then exec sudo -- "$0" "$@"; fi

    echo "Current:  $(readlink -f /run/current-system)"
    nixos-rebuild switch --rollback
    echo "Now on:   $(readlink -f /run/current-system)"
  '';

  status = mkCmd "media-status" ''
    echo "=== services ==="
    systemctl --no-pager --plain list-units \
      'jellyfin*' 'subtitle-*' 'library-refresh*' 'samba*' 'filebrowser*' \
      --type=service --all 2>/dev/null || true
    echo
    echo "=== timers ==="
    systemctl --no-pager --plain list-timers 'subtitle-*' 'library-*' 2>/dev/null || true
    echo
    echo "=== disk ==="
    df -h / | tail -1
    echo
    echo "=== address ==="
    ip -br addr show scope global 2>/dev/null || true
  '';
in
{
  environment.systemPackages = [ update rollback status ];

  # Short forms for when you're typing at a prompt.
  environment.shellAliases = {
    update = "media-update";
    rollback = "media-rollback";
  };
}
