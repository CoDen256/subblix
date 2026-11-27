{ pkgs, settings, ... }:
{
  systemd.services.jellyfin-provision = {
    description = "Provision Jellyfin on first run (wizard, admin, library, VAAPI)";
    after = [ "jellyfin.service" ];
    wants = [ "jellyfin.service" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ curl jq coreutils ];

    environment = {
      JELLYFIN_PORT = toString settings.jellyfinPort;
      MOVIES_DIR = settings.moviesDir;
      ADMIN_USER = settings.username;
      ADMIN_PASSWORD_FILE = "/var/lib/secrets/jellyfin-admin-password";
      METADATA_COUNTRY = "NO";
      METADATA_LANGUAGE = "en";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${../scripts/provision-jellyfin.sh}";
      # Don't take the boot down if the admin password file isn't there yet.
      SuccessExitStatus = [ 0 1 ];
    };
  };
}
