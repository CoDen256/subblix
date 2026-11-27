{ pkgs, settings, ... }:
{
  users.mutableUsers = false;

  # A shared group for everything that touches media files, so Jellyfin,
  # Samba, File Browser and the subtitle timers can all read/write them.
  users.groups.media = { };

  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.fullName;
    extraGroups = [ "wheel" "media" ];
    openssh.authorizedKeys.keys = [ settings.sshPublicKey ];
    shell = pkgs.bash;
  };

  # Root has no password; you get in via your key as the normal user, then sudo.
  users.users.root.hashedPassword = "!";

  security.sudo.wheelNeedsPassword = false;
}
