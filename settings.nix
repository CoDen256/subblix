# ─────────────────────────────────────────────────────────────────────────────
#  EVERYTHING YOU ARE LIKELY TO CHANGE LIVES IN THIS FILE.
#  You should rarely need to open anything in modules/.
# ─────────────────────────────────────────────────────────────────────────────
{
  # --- Who you are -----------------------------------------------------------
  username = "coden";
  fullName = "Denys Chernyshov";

  # Your SSH public key. Get it with:  cat ~/.ssh/id_ed25519.pub
  # Without this you cannot log in after install. Replace the placeholder.
  sshPublicKey = "ssh-ed25519 AAAAREPLACE_ME_WITH_YOUR_PUBLIC_KEY you@yourmachine";

  # --- The machine -----------------------------------------------------------
  hostname = "media";
  timezone = "Europe/Oslo";
  locale = "en_GB.UTF-8";

  # The whole disk the server is installed on. THIS DISK GETS ERASED.
  # Find it from the installer with:  lsblk
  # Prefer a stable path, e.g. /dev/disk/by-id/ata-Samsung_SSD_...
  diskDevice = "/dev/sda";

  # --- Network ---------------------------------------------------------------
  # A fixed address so the phone and projector always find the server.
  # Set useDHCP = true instead if you'd rather reserve the address on your router.
  useDHCP = false;
  staticIp = "192.168.1.50";
  prefixLength = 24;
  gateway = "192.168.1.1";
  nameservers = [ "192.168.1.1" "1.1.1.1" ];
  # Leave empty to let NixOS pick the wired interface automatically.
  interface = "";

  # --- Media -----------------------------------------------------------------
  mediaRoot = "/srv/media";
  moviesDir = "/srv/media/movies";

  # Subtitle languages, most preferred first. ISO 639-3 codes.
  subtitleLanguages = [ "nor" "deu" "eng" ];
  # Same languages in the 2-letter form the subtitle downloader wants.
  subtitleLanguagesShort = [ "no" "de" "en" ];

  # --- Ports -----------------------------------------------------------------
  jellyfinPort = 8096;
  fileBrowserPort = 8080;

  # --- Self-update -----------------------------------------------------------
  # The server pulls this repo and rebuilds itself on a schedule.
  repoUrl = "github:dchernyshov/subblix";
  autoUpgrade = true;
  autoUpgradeSchedule = "04:30";
  # Keep false: you don't want the server rebooting mid-film.
  autoUpgradeAllowReboot = false;

  # --- Housekeeping ----------------------------------------------------------
  # Delete system generations older than this (the disk is shared with movies).
  gcOlderThan = "14d";
  bootGenerationLimit = 10;
  # RAM set aside for transcoding scratch space, so the SSD isn't hammered.
  transcodeTmpfsSize = "4G";
}
