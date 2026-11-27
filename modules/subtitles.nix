{ pkgs, lib, settings, ... }:
let
  stateDir = "/var/lib/subtitle-extract";
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
    path = with pkgs; [ ffmpeg-full coreutils gnugrep gnused ];
    environment = commonEnv;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${../scripts/extract-subtitles.sh}";
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
    path = with pkgs; [ python3Packages.subliminal coreutils gnugrep ];
    environment = commonEnv // {
      SUBTITLE_LANGS = lib.concatStringsSep " " settings.subtitleLanguagesShort;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${../scripts/fetch-subtitles.sh}";
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
    path = with pkgs; [ curl coreutils ];
    environment = commonEnv;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${../scripts/refresh-library.sh}";
    };
  };
  systemd.timers.library-refresh = mkTimer {
    unit = "library-refresh";
    onCalendar = "*:5/15";       # shortly after each extraction run
    description = "Refresh the library when subtitles were added";
  };
}
