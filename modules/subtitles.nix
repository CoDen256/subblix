{ pkgs, lib, settings, ... }:
let
  stateDir = "/var/lib/subtitle-extract";

  # Built as derivations, not referenced as bare .sh paths. A systemd unit has
  # no PATH beyond what we give it, so `#!/usr/bin/env bash` cannot find an
  # interpreter and the unit fails with status 127. writeShellApplication bakes
  # an absolute bash into the shebang, puts runtimeInputs on PATH, and runs
  # shellcheck at build time.
  mkScript = name: runtimeInputs: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    text = builtins.readFile (../scripts + "/${name}.sh");
  };

  extractScript = mkScript "extract-subtitles" (with pkgs; [ ffmpeg-full coreutils gnugrep gnused ]);
  fetchScript   = mkScript "fetch-subtitles"   (with pkgs; [ python3Packages.subliminal coreutils gnugrep ]);
  refreshScript = mkScript "refresh-library"   (with pkgs; [ curl coreutils ]);

  commonEnv = {
    MOVIES_DIR = settings.moviesDir;
    STATE_DIR = stateDir;
    JELLYFIN_PORT = toString settings.jellyfinPort;
  };

  mkTimer = { unit, onCalendar, description }: {
    inherit description;
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = onCalendar;
      Persistent = true;        # catch up if the box was off
      RandomizedDelaySec = "2m";
      Unit = "${unit}.service";
    };
  };
in
{
  systemd.tmpfiles.rules = [ "d ${stateDir} 0775 root media - -" ];

  # --- Extract embedded text subtitles into .srt sidecars --------------------
  # This is what makes .ass films readable by the browser extension.
  systemd.services.subtitle-extract = {
    description = "Extract embedded text subtitles into .srt sidecars";
    environment = commonEnv;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${extractScript}/bin/extract-subtitles";
      User = "root";
      Group = "media";
      UMask = "0002";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.subtitle-extract = mkTimer {
    unit = "subtitle-extract";
    onCalendar = "*:0/15";       # every 15 minutes
    description = "Periodically extract subtitles from new media";
  };

  # --- Download subtitles for films that have none --------------------------
  systemd.services.subtitle-fetch = {
    description = "Download missing subtitles (${lib.concatStringsSep ", " settings.subtitleLanguagesShort})";
    environment = commonEnv // {
      SUBTITLE_LANGS = lib.concatStringsSep " " settings.subtitleLanguagesShort;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fetchScript}/bin/fetch-subtitles";
      User = "root";
      Group = "media";
      UMask = "0002";
      Nice = 10;
    };
  };
  systemd.timers.subtitle-fetch = mkTimer {
    unit = "subtitle-fetch";
    onCalendar = "hourly";
    description = "Periodically look for missing subtitles";
  };

  # --- Tell Jellyfin to rescan, but only when something changed -------------
  systemd.services.library-refresh = {
    description = "Refresh the Jellyfin library after subtitle changes";
    environment = commonEnv;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${refreshScript}/bin/refresh-library";
    };
  };
  systemd.timers.library-refresh = mkTimer {
    unit = "library-refresh";
    onCalendar = "*:5/15";       # shortly after each extraction run
    description = "Refresh the library when subtitles were added";
  };
}
