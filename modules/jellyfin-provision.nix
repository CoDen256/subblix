{ pkgs, settings, ... }:
let
  # Built as a derivation rather than referenced as a bare file path.
  #
  # The previous version pointed ExecStart straight at the .sh, whose shebang
  # is `#!/usr/bin/env bash`. systemd units get an empty PATH apart from
  # `path`, which listed curl/jq/coreutils but not bash -- so env could not
  # find an interpreter and the unit died with status 127. writeShellApplication
  # bakes an absolute bash path into the shebang, puts runtimeInputs on PATH,
  # and runs shellcheck at build time so this class of thing fails in CI rather
  # than at 9pm on the server.
  provisionScript = pkgs.writeShellApplication {
    name = "provision-jellyfin";
    runtimeInputs = with pkgs; [ curl jq coreutils ];
    text = builtins.readFile ../scripts/provision-jellyfin.sh;
  };
in
{
  systemd.services.jellyfin-provision = {
    description = "Provision Jellyfin on first run (wizard, admin, library, VAAPI)";
    after = [ "jellyfin.service" ];
    wants = [ "jellyfin.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      JELLYFIN_PORT = toString settings.jellyfinPort;
      MOVIES_DIR = settings.moviesDir;
      SHOWS_DIR = settings.showsDir;
      INSTALL_OPENSUBTITLES = if settings.installOpenSubtitlesPlugin then "1" else "0";
      ADMIN_USER = settings.username;
      ADMIN_PASSWORD_FILE = "/var/lib/secrets/jellyfin-admin-password";
      # Provisioning creates this itself so the library-refresh timer works
      # without you having to make an API key by hand in the dashboard.
      JELLYFIN_API_KEY_FILE = "/var/lib/secrets/jellyfin-api-key";
      METADATA_COUNTRY = "NO";
      METADATA_LANGUAGE = "en";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${provisionScript}/bin/provision-jellyfin";
      # Missing admin password file is a "come back later", not a boot failure.
      SuccessExitStatus = [ 0 1 ];
    };
  };
}
