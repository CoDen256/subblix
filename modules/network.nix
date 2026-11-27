{ lib, settings, ... }:
let
  iface = if settings.interface == "" then null else settings.interface;
in
{
  networking.hostName = settings.hostname;
  networking.useDHCP = lib.mkDefault settings.useDHCP;

  # Static address so the phone and projector always find the server.
  networking.interfaces = lib.mkIf (!settings.useDHCP && iface != null) {
    ${iface} = {
      useDHCP = false;
      ipv4.addresses = [{
        address = settings.staticIp;
        prefixLength = settings.prefixLength;
      }];
    };
  };
  networking.defaultGateway = lib.mkIf (!settings.useDHCP) settings.gateway;
  networking.nameservers = lib.mkIf (!settings.useDHCP) settings.nameservers;

  # Lets other machines reach the server as "media.local".
  # Android is unreliable about this, which is why we also pin a static IP.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22                        # SSH
      settings.jellyfinPort     # Jellyfin web
      settings.fileBrowserPort  # File Browser uploader
      139 445                   # Samba
    ];
    allowedUDPPorts = [
      1900 7359                 # Jellyfin DLNA + client auto-discovery
      137 138                   # Samba NetBIOS
      5353                      # mDNS (.local)
    ];
  };
}
