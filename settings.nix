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
  sshPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2ZH4uHNFP/yQWLQP24FdsM7SkSNKHGX5pIrwIydEx9sLNIKqOsZhAP0NmPvhGoWTNal6D6APUyjgYa0iVJeRpW7RWovOdDD6vuhKebWZpRLB5ALCE6lY57ROCyugyEvkPe5paQkMMoHkJXUJ5tyn3TWPP7Bj+G9J7xN49rquauSQXed0gMYdQFxBrt87CQN+b/b3Kr2e2rTltgMlzw1FZP5bcrL6vpR1P0KysRFrddw/CPOVKuN69EdyWJV4ETve5djPwpI1G0oIRfio+HjZtK+MuYeYjLmq8khRdRvnqg0ZgylVkC3ptRGlIXifa/vV8ehy0k48uwQ9Y3u7HvFlrkDDx56uRKCYqqG+onA2Dx+s3Yumf2VJR21wI4/Xu8xgG/BukiFuIrLTtdV8fUNsYIAmnqwN/5UsuP2YBo8FmMad5Y6K28n1NcVlgxSSyXkh5eWPPVWv8uVOzaETXyyeYfO9S0NITjPSoCh3Ymi8NFQ+dpqMlRdZDMESkOtKRrZFdHh104VGpTPmptgZYYUIXcDcJWOO2cOAKi5/wcJrx4M6mKmJ3GVinqI0ruAuACmEWwcpaQJEx9prdoTBtDg7T5yMDWWK0UCTZDsOpXxSVYnQf7gkbR90MZOi8yOj/sibBwtEB3I/Bfwn6TozF2wtW2w+2tnhrbuG63FHN0a8Klw== den.blackshov@gmail.com";

  # --- The machine -----------------------------------------------------------
  hostname = "media";
  timezone = "Europe/Berlin";
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
  # REQUIRED for a static IP: the wired network device name.
  # Find it by running `ip link` on the server (e.g. "enp3s0", "eno1", "eth0").
  # If you leave this empty the static IP CANNOT be applied, and the server
  # falls back to DHCP so that it stays reachable -- look it up on your router.
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
  repoUrl = "github:coden256/subblix";
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
