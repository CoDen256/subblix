{
  description = "Headless NixOS media server: Jellyfin with DOM-readable subtitles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      system = "x86_64-linux";
      settings = import ./settings.nix;
    in
    {
      # Always keyed "media" so the install/rebuild commands in INSTALL.md
      # keep working no matter what you set `hostname` to in settings.nix
      # (the actual hostname comes from settings.nix via modules/network.nix).
      nixosConfigurations.media = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit settings; };
        modules = [
          disko.nixosModules.disko
          ./hosts/media/disko.nix
          ./hosts/media/hardware.nix
          ./modules/base.nix
          ./modules/users.nix
          ./modules/ssh.nix
          ./modules/network.nix
          ./modules/maintenance.nix
          ./modules/jellyfin.nix
          ./modules/jellyfin-provision.nix
          ./modules/subtitles.nix
          ./modules/ingest.nix
          { nixpkgs.overlays = [ (import ./overlays/jellyfin-web.nix) ]; }
        ];
      };

      # The patched web client on its own, for testing:
      #   nix build .#jellyfin-web-patched
      packages.${system}.jellyfin-web-patched =
        (import nixpkgs {
          inherit system;
          overlays = [ (import ./overlays/jellyfin-web.nix) ];
        }).jellyfin-web;
    };
}
