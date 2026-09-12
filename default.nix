{ pkgs ? import <nixpkgs> {}, src ? ./. }:

let
  inherit (pkgs) lib stdenv;
  isDarwin = stdenv.isDarwin;
in
stdenv.mkDerivation {
  pname = "solvespace-themed";
  version = "3.2-themed";

  inherit src;

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
  ] ++ lib.optionals (!isDarwin) [
    wrapGAppsHook3
  ];

  buildInputs = with pkgs; [
    eigen
    freetype
    fontconfig
    libpng
    opencascade-occt
    zlib
  ] ++ lib.optionals isDarwin [
    llvmPackages.openmp
  ] ++ lib.optionals (!isDarwin) [
    at-spi2-core
    cairo
    dbus
    glew
    gtkmm3
    json_c
    libdatrie
    libdeflate
    libepoxy
    libGLU
    libselinux
    libsepol
    libspnav
    libthai
    libtiff
    libxkbcommon
    lerc
    pangomm
    pcre
    pcre2
    util-linuxMinimal
    xorg.libpthreadstubs
    xorg.libXdmcp
    xorg.libXtst
    libsysprof-capture
  ];

  postPatch = ''
    # Patch out git hash requirement since we're building from local source
    substituteInPlace CMakeLists.txt \
      --replace "include(GetGitCommitHash)" "# include(GetGitCommitHash)" \
      --replace "# set(GIT_COMMIT_HASH 0000000000000000000000000000000000000000)" "set(GIT_COMMIT_HASH themed-fork)"
  '' + lib.optionalString isDarwin ''
    # OpenMP_CXX_INCLUDE_DIRS is empty when clang's -fopenmp=libomp discovers
    # libomp implicitly, so LIBOMP_LIB_PATH resolves to /../lib/libomp.dylib.
    # Point it at the actual dylib from llvmPackages.openmp.
    substituteInPlace src/CMakeLists.txt \
      --replace '${"\${OpenMP_CXX_INCLUDE_DIRS}"}/../lib/libomp.dylib' '${pkgs.llvmPackages.openmp}/lib/libomp.dylib'
  '';

  # macOS needs iconutil (icon bundle) and ibtool (nib compiler) from Xcode.
  # /usr/bin/ibtool is a shim that dispatches through DEVELOPER_DIR, so we set
  # both. Only reachable because Determinate Nix runs with sandbox disabled.
  preBuild = lib.optionalString isDarwin ''
    export PATH="$PATH:/usr/bin:/Applications/Xcode.app/Contents/Developer/usr/bin"
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  '';

  cmakeFlags = [
    "-DENABLE_OPENMP=ON"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  # CMake has no install() rule for the macOS .app; copy it out of the build tree.
  postInstall = lib.optionalString isDarwin ''
    mkdir -p $out/Applications
    cp -R bin/SolveSpace.app $out/Applications/
    mkdir -p $out/bin
    ln -s $out/Applications/SolveSpace.app/Contents/MacOS/SolveSpace $out/bin/SolveSpace
  '';

  meta = with lib; {
    description = "Parametric 3D CAD program with themeable text window";
    license = licenses.gpl3Plus;
    platforms = platforms.linux ++ platforms.darwin;
    homepage = "https://solvespace.com";
  };
}
