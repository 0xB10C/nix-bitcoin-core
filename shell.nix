# Usage example:
# $ nix-shell --arg spareCores 2 --arg withDebug true
{ pkgs ? import <nixpkgs> { }, spareCores ? 0, withDebug ? false, }:
let
  inherit (pkgs.lib) strings;

  pinnedPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/50dc918cfe0dd0419403c957bcf395e881214416.tar.gz";
    sha256 = "sha256:1wiz5n0l4mqjbrnqh2zs14lsfcb668xpv5b5psyzf5fdqq15mdbs";
  }) {};

  # Lief v 0.13.2
  pinnedLief = pinnedPkgs.python310Packages.lief;

  binDirs = [ "$PWD/build/src" "$PWD/build/src/qt" ];
  jobs = if (strings.hasSuffix "linux" builtins.currentSystem) then
    "$(($(nproc)-${toString spareCores}))"
  else if (strings.hasSuffix "darwin" builtins.currentSystem) then
    "$(($(sysctl -n hw.physicalcpu)-${toString spareCores}))"
  else
    "6";

  libmultiprocess = pkgs.stdenv.mkDerivation {
    name = "libmultiprocess";
    src = pkgs.fetchFromGitHub {
      owner = "bitcoin-core";
      repo = "libmultiprocess";
      rev = "f35df6bdc536b068597559d4ab470dab9cff7cfc";
      sha256 = "sha256-1gg6MAql70JUXOdaP0A9Lmny5y6EFw55bJrzUvYRzMQ=";
    };

    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
    buildInputs = [ pkgs.capnproto ];
    cmakeFlags =
      [ "-DCMAKE_INSTALL_LIBDIR=lib" "-DCMAKE_INSTALL_INCLUDEDIR=include" ];

    # Optional test check
    doCheck = true;
    checkPhase = ''
      make check
    '';

    # Make sure pkg-config and cmake files are properly installed
    postInstall = ''
      mkdir -p $out/lib/pkgconfig
    '';

    # Makes sure that the pkg-config and cmake files can find dependencies
    setupHook = pkgs.writeText "setup-hook.sh" ''
      export PKG_CONFIG_PATH="''${PKG_CONFIG_PATH:+$PKG_CONFIG_PATH:}${
        placeholder "out"
      }/lib/pkgconfig"
      export CMAKE_PREFIX_PATH="''${CMAKE_PREFIX_PATH:+$CMAKE_PREFIX_PATH:}${
        placeholder "out"
      }"
    '';

    meta = with pkgs.lib; {
      description = "Multi-process library";
      homepage = "https://github.com/bitcoin-core/libmultiprocess";
      license = licenses.mit;
    };
  };
in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # Essential build tools
    boost
    ccache
    clang-tools_19
    clang_19
    cmake
    gcc14
    libevent
    pkg-config
    sqlite

    # Optional build dependencies
    capnproto
    db4
    libmultiprocess
    qrencode
    zeromq

    # Tests
    hexdump

    # Depends
    byacc

    # Functional tests & linting
    python310
    python310Packages.autopep8
    python310Packages.flake8
    pinnedLief
    python310Packages.mypy
    python310Packages.pyzmq
    python310Packages.requests

    # Benchmarking
    python310Packages.pyperf

    # Debugging
    gdb

    # Tracing
    libsystemtap
    linuxPackages.bcc
    linuxPackages.bpftrace

    # Bitcoin-qt
    qt5.qtbase
    # required for bitcoin-qt for "LRELEASE" etc
    qt5.qttools
  ];

  # Modifies the Nix clang++ wrapper to avoid warning:
  # "_FORTIFY_SOURCE requires compiling with optimization (-O)"
  hardeningDisable = if withDebug then [ "all" ] else [ ];

  # Fixes xcb plugin error when trying to launch bitcoin-qt
  QT_QPA_PLATFORM_PLUGIN_PATH =
    "${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins/platforms";

  shellHook = ''
    echo "Bitcoin Core build nix-shell"
    echo ""

    BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python3.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.${pkgs.python3.sourceVersion.minor}.egg
    if [ -f $BCC_EGG ]; then
      export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
    else
      echo "The bcc egg $BCC_EGG does not exist. Maybe the python or bcc version is different?"
    fi

    # Building
    alias c="cmake -B build"
    alias ca="cmake -B build --preset=dev-mode"
    alias b="cmake --build build -j ${jobs}"
    alias build="c && b"
    alias build-all="ca && b"

    # Cleaning
    alias clean="rm -Rf build"

    # Unit tests
    alias ut="ctest --test-dir build -j ${jobs}"

    # Functional tests
    alias ft="python3 build/test/functional/test_runner.py -j ${jobs}"

    # All tests
    alias t="ut && ft"
    alias test="t"

    # Linting
    alias lint="DOCKER_BUILDKIT=1 docker build -t bitcoin-linter --file "./ci/lint_imagefile" ./ && docker run --rm -v $(pwd):/bitcoin -it bitcoin-linter"

    export PATH=$PATH:${builtins.concatStringsSep ":" binDirs};
    echo "Added ${
      builtins.concatStringsSep ":" binDirs
    } to \$PATH to make running built binaries more natural"
  '';
}
