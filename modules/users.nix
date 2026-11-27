{ pkgs, lib, settings, ... }:
{
  # mutableUsers = true so `passwd` works at the console and the password set
  # during `nixos-install` persists.
  #
  # This was false, with no password declared anywhere and root locked -- which
  # produced a machine reachable ONLY by SSH key. The moment the network didn't
  # come up there was no way in at all, not even with a monitor attached. A
  # console password you can actually use is worth more than a fully declarative
  # user list on a single-user home server.
  #
  # SSH stays key-only (see ssh.nix), so this does not weaken remote access.
  users.mutableUsers = true;

  # A shared group for everything that touches media files, so Jellyfin,
  # Samba, File Browser and the subtitle timers can all read/write them.
  users.groups.media = { };

  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.fullName;
    extraGroups = [ "wheel" "media" ];
    openssh.authorizedKeys.keys = [ settings.sshPublicKey ];
    shell = pkgs.bash;

    # Optional declarative console password without putting a hash in this
    # public repo: create the file on the server with
    #   mkpasswd -m sha-512 | sudo tee /var/lib/secrets/user-password-hash
    # If absent, set the password imperatively with `passwd` instead.
    hashedPasswordFile = lib.mkIf (settings.userPasswordHashFile != null)
      settings.userPasswordHashFile;
  };

  security.sudo.wheelNeedsPassword = false;
}
