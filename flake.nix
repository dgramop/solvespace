{
  description = "SolveSpace with themeable text window";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems
          (system: f system nixpkgs.legacyPackages.${system});
    in {
      packages = forAllSystems (system: pkgs:
        let
          solvespace-themed = pkgs.callPackage ./default.nix { src = self; };
        in {
          default = solvespace-themed;
          solvespace-themed = solvespace-themed;
        });

      devShells = forAllSystems (system: pkgs:
        let
          inherit (nixpkgs) lib;
          solvespace-themed = self.packages.${system}.solvespace-themed;
        in {
          default = pkgs.mkShell ({
            inputsFrom = [ solvespace-themed ];

            packages = with pkgs; [
              clang-tools
              qt6.qtbase
              qt6.wrapQtAppsHook
              opencascade-occt
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              gdb
              gsettings-desktop-schemas
              dconf
            ];
          } // lib.optionalAttrs pkgs.stdenv.isLinux {
            # GSettings environment for running unwrapped binaries during development
            GIO_EXTRA_MODULES = "${pkgs.dconf.lib}/lib/gio/modules";
            XDG_DATA_DIRS = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}";
          });
        });
    };
}
