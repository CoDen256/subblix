{ lib, settings, ... }:
let
  iface = if settings.interface == "" then null else settings.interface;

  # A static address is only possible if we know which device to put it on.
  useStatic = !settings.useDHCP && iface != null;
in
{
  networking.hostName = settings.hostname;

  # FAIL-SAFE: unless a static address is fully specified, fall back to DHCP.
  #
  # Previously this was `useDHCP = settings.useDHCP`, so setting useDHCP=false
  # while leaving `interface` empty produced a machine with NO ADDRESS AT ALL --
  # it neither asked for DHCP nor applied the static IP. On a headless box that
  # means no way in short of attaching a monitor. Always getting *an* address is
  # worth more than always getting the *intended* one.
  networking.useDHCP = !useStatic;

  networking.interfaces = lib.mkIf useStatic {
    ${iface} = {
      useDHCP = false;
      ipv4.addresses = [{
        address = settings.staticIp;
        prefixLength = settings.prefixLength;
      }];
    };
  };
  networking.defaultGateway = lib.mkIf useStatic settings.gateway;
  networking.nameservers = lib.mkIf useStatic settings.nameservers;

  # Loud at build time rather than silent at boot time.
  warnings = lib.optional (!settings.useDHCP && iface == null) ''
    settings.nix sets useDHCP = false but leaves `interface` empty, so no static
    address can be applied. Falling back to DHCP on all interfaces so the machine
    stays reachable. To get the static IP you asked for, set `interface` to the
    wired device name (find it with `ip link` on the server, e.g. "enp3s0").
  '';

  # Lets other machines reach the server as "<hostname>.local".
  # Android is unreliable about this, so don't depend on it.
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
