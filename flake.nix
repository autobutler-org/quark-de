{
  description = "Quark DE: a Wayland desktop session where the Quark app is the desktop";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        quark-de = pkgs.callPackage ./packaging/nix/package.nix { };
        default = quark-de;
      });

      nixosModules = rec {
        quark-de = import ./packaging/nix/module.nix self;
        default = quark-de;
      };

      checks = forAllSystems (pkgs: import ./packaging/nix/checks.nix { inherit self pkgs nixpkgs; });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
