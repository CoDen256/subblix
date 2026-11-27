{ pkgs, settings, ... }:
{
  # --- Samba: drag films in from any computer on the LAN --------------------
  services.samba = {
    enable = true;
    openFirewall = false;   # ports opened explicitly in network.nix
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = settings.hostname;
        "netbios name" = settings.hostname;
        "security" = "user";
        # LAN only. Adjust if your network isn't 192.168.0.0/16.
        "hosts allow" = "192.168.0.0/16 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      media = {
        "path" = settings.mediaRoot;
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = settings.username;
        "create mask" = "0664";
        "directory mask" = "0775";
        "force group" = "media";
      };
    };
  };
  # Makes the share show up in Windows/macOS network browsers.
  services.samba-wsdd = {
    enable = true;
    openFirewall = false;
  };

  # --- File Browser: upload from a phone or any browser ---------------------
  services.filebrowser = {
    enable = true;
    user = settings.username;
    group = "media";
    settings = {
      address = "0.0.0.0";
      port = settings.fileBrowserPort;
      root = settings.mediaRoot;
    };
  };
}
