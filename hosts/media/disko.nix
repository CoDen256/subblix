# Declarative disk layout. Running disko against this ERASES the whole disk.
# Simple on purpose: one EFI boot partition, everything else one ext4 root.
# Movies live on the same filesystem under /srv/media.
{ settings, ... }:
{
  disko.devices.disk.main = {
    device = settings.diskDevice;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        swap = {
          size = "8G";
          content = {
            type = "swap";
            randomEncryption = false;
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
