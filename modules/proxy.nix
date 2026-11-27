{ lib, settings, ... }:
lib.mkIf settings.enableHttpProxy {
  # Puts Jellyfin on plain http://media.local instead of :8096.
  #
  # `default = true` rather than naming a virtual host, because the server is
  # reached by several names — media.local (mDNS), media.lan (router DNS), and
  # its bare IP — and all of them must work. A named vhost would only answer
  # to whichever Host header you happened to pick.
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;   # sets X-Forwarded-* and friends
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts.jellyfin = {
      default = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString settings.jellyfinPort}";
        # Jellyfin uses a websocket for playback state, remote control and
        # SyncPlay. Without this, playback works but the UI stops updating.
        proxyWebsockets = true;
        extraConfig = ''
          # Subtitle uploads and similar POSTs can exceed nginx's 1M default.
          client_max_body_size 100M;
          # Long-lived connections for the websocket and for streaming.
          proxy_read_timeout 1h;
          proxy_send_timeout 1h;
          proxy_buffering off;
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
