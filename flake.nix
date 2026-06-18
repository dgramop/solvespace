{
  description = "SolveSpace - parametric 3D CAD";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    libdxfrw = {
      url = "github:solvespace/libdxfrw/8359399ff3eb96aec14fb160c9a5bc4796b60717";
      flake = false;
    };
    mimalloc = {
      url = "github:microsoft/mimalloc/f81bf1b31af819a31195e08f9546dc80f8931587";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, libdxfrw, mimalloc }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux" "aarch64-linux"
        "x86_64-darwin" "aarch64-darwin"
      ];
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
        in {
          default = pkgs.stdenv.mkDerivation {
            pname = "solvespace";
            version = "3.2-dev";

            src = self;

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
            ] ++ pkgs.lib.optionals isDarwin [
              ibtool
            ] ++ pkgs.lib.optionals (!isDarwin) [
              wrapGAppsHook3
            ];

            buildInputs = with pkgs; [
              eigen
              libpng
              freetype
              zlib
              cairo
            ] ++ pkgs.lib.optionals (!isDarwin) [
              gtkmm3
              pangomm
              fontconfig
              json_c
              libGLU
              glew
              libepoxy
            ];

            darwinFrameworks = [ "AppKit" "OpenGL" ];

            # iconutil is a macOS system binary needed to build .icns
            __impureHostDeps = pkgs.lib.optionals isDarwin [ "/usr/bin/iconutil" ];

            cmakeFlags = [
              "-DFORCE_VENDORED_Eigen3=OFF"
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            ] ++ pkgs.lib.optionals isDarwin [
              "-DENABLE_CLI=OFF"
              "-DENABLE_TESTS=OFF"
            ];

            postPatch = ''
              # git isn't available in the sandbox, provide hash directly
              sed -i 's/include(GetGitCommitHash)/set(GIT_COMMIT_HASH "${self.shortRev or self.dirtyShortRev or "unknown"}")/' CMakeLists.txt

              # Use system libraries on all platforms (not just Linux)
              # Nix provides these, so we don't need vendored copies
              substituteInPlace CMakeLists.txt \
                --replace-fail 'if(WIN32 OR APPLE OR EMSCRIPTEN)' 'if(WIN32 OR EMSCRIPTEN)'

              # Benchmark links solvespace-headless which requires ENABLE_CLI
              substituteInPlace CMakeLists.txt \
                --replace-fail '(ENABLE_CLI OR ENABLE_GUI) AND (CMAKE_BUILD_TYPE' 'ENABLE_CLI AND (CMAKE_BUILD_TYPE'

              # Populate vendored-only deps from nix inputs
              rmdir extlib/libdxfrw || true
              rmdir extlib/mimalloc || true
              cp -r --no-preserve=mode ${libdxfrw} extlib/libdxfrw
              cp -r --no-preserve=mode ${mimalloc} extlib/mimalloc
            '';

            preBuild = pkgs.lib.optionalString isDarwin ''
              export PATH="/usr/bin:$PATH"
            '';

            postInstall = pkgs.lib.optionalString isDarwin ''
              mkdir -p $out/Applications
              cp -r bin/SolveSpace.app $out/Applications/
            '';

            meta = with pkgs.lib; {
              description = "Parametric 3D CAD program";
              homepage = "https://solvespace.com";
              license = licenses.gpl3Plus;
              platforms = platforms.unix;
            };
          };
        });
    };
}
