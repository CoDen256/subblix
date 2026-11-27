{ pkgs, lib, settings, ... }:
{
  services.jellyfin = {
    enable = true;
    openFirewall = false;   # we open the port explicitly in network.nix
    group = "media";
  };

  # Intel QuickSync / VAAPI for the i5-4570 (Haswell).
  #
  # Haswell can hardware-ENCODE H.264 but CANNOT hardware-decode HEVC, so this
  # is a fallback, not the main path. The design is to direct-play: both your
  # PC browser and the projector's Android TV app decode HEVC themselves.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver      # iHD, modern Intel
      intel-vaapi-driver      # i965, the right one for Haswell
      libvdpau-va-gl
      libva-vdpau-driver
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";

  # Jellyfin needs access to the GPU render node to use VAAPI at all.
  users.users.jellyfin.extraGroups = [ "render" "video" ];

  # Transcoding scratch goes to RAM, not the SSD. Saves write wear on the
  # single shared disk and is faster. Harmless if transcoding never happens.
  systemd.tmpfiles.rules = [
    "d ${settings.mediaRoot} 0775 ${settings.username} media - -"
    "d ${settings.moviesDir} 0775 ${settings.username} media - -"
    "d /var/lib/secrets 0750 root root - -"
  ];

  fileSystems."/var/cache/jellyfin/transcodes" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=${settings.transcodeTmpfsSize}" "mode=0755" "uid=jellyfin" "gid=media" ];
  };

  # New files dropped in by Samba/File Browser must stay group-readable.
  systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
}
