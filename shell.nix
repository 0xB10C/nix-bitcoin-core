# Usage example:
# $ nix-shell --arg withClang true --arg spareCores 2 --argstr bdbVersion db5
{ pkgs ? import <nixpkgs> {},
  bdbVersion ? "",
  spareCores ? 0,
  withClang ? false,
  withDebug ? false,
  withGui ? false,
}:
let
  inherit (pkgs.lib) optionals strings;
  binDirs =
    [ "\$PWD/src" ]
    ++ optionals withGui [ "\$PWD/src/qt" ];
  configureFlags =
    [ "--with-boost-libdir=$NIX_BOOST_LIB_DIR" ]
    ++ optionals ((builtins.elem bdbVersion ["" "db48" "db5"]) || abort "Unsupported bdbVersion value: ${bdbVersion}") []
    ++ optionals (bdbVersion == "") [ "--without-bdb" ]
    ++ optionals (!(builtins.elem bdbVersion ["" "db48"])) [ "--with-incompatible-bdb" ]
    ++ optionals withClang [ "CXX=clang++" "CC=clang" ]
    ++ optionals withDebug [ "--enable-debug" ]
    ++ optionals withGui [
      "--with-gui=qt5"
      "--with-qt-bindir=${pkgs.qt5.qtbase.dev}/bin:${pkgs.qt5.qttools.dev}/bin"
    ];
  jobs =
    if (strings.hasSuffix "linux" builtins.currentSystem) then "$(($(nproc)-${toString spareCores}))"
    else if (strings.hasSuffix "darwin" builtins.currentSystem) then "$(($(sysctl -n hw.physicalcpu)-${toString spareCores}))"
    else "6";
in pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      autoconf
      automake
      libtool
      pkg-config
      boost
      libevent
      zeromq
      sqlite
      clang_18

      # tests
      hexdump

      # compiler output caching per
      # https://github.com/bitcoin/bitcoin/blob/master/doc/productivity.md#cache-compilations-with-ccache
      ccache

      # generating compile_commands.json for clang-format, clang-tidy, LSPs etc
      # https://github.com/bitcoin/bitcoin/blob/master/doc/developer-notes.md#running-clang-tidy
      # $ a && c && m clean && bear --config src/.bear-tidy-config -- make -j6
      clang-tools_18
      bear

      # for newer cmake building
      cmake

      # depends
      byacc

      # only needed for older versions
      # openssl

      # functional tests & linting
      python3
      python3Packages.flake8
      python3Packages.lief
      python3Packages.autopep8
      python3Packages.mypy
      python3Packages.requests
      python3Packages.pyzmq

      # benchmarking
      python3Packages.pyperf

      # debugging
      gdb

      # tracing
      libsystemtap
      linuxPackages.bpftrace
      linuxPackages.bcc
    ]
    ++ lib.optionals (bdbVersion == "db48") [
      db48
    ]
    ++ lib.optionals (bdbVersion == "db5") [
      db5
    ]
    ++ lib.optionals withGui [
      # bitcoin-qt
      qt5.qtbase
      # required for bitcoin-qt for "LRELEASE" etc
      qt5.qttools
    ];

    # Modifies the Nix clang++ wrapper to avoid warning:
    # "_FORTIFY_SOURCE requires compiling with optimization (-O)"
    hardeningDisable = if withDebug then [ "all" ] else [ ];

    # needed in 'autogen.sh'
    LIBTOOLIZE = "libtoolize";

    # needed for 'configure' to find boost
    # Run ./configure with the argument '--with-boost-libdir=\$NIX_BOOST_LIB_DIR'"
    NIX_BOOST_LIB_DIR = "${pkgs.boost}/lib";

    # Fixes xcb plugin error when trying to launch bitcoin-qt
    QT_QPA_PLATFORM_PLUGIN_PATH = if withGui then "${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins/platforms" else "";

    shellHook = ''
      echo "Bitcoin Core build nix-shell"
      echo ""

      BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python3.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.${pkgs.python3.sourceVersion.minor}.egg

      echo "adding bcc egg to PYTHONPATH: $BCC_EGG"
      if [ -f $BCC_EGG ]; then
        export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
        echo ""
      else
        echo "The bcc egg $BCC_EGG does not exist. Maybe the python or bcc version is different?"
      fi

      # autogen
      alias a="sh autogen.sh"

      # configure
      alias c="./configure ${builtins.concatStringsSep " " configureFlags}"
      alias c_no-wallet="./configure ${builtins.concatStringsSep " " configureFlags} --disable-wallet"
      alias c_fast="./configure ${builtins.concatStringsSep " " configureFlags} --disable-wallet --disable-tests --disable-fuzz --disable-bench -disable-fuzz-binary"
      alias c_fast_wallet="./configure ${builtins.concatStringsSep " " configureFlags} --disable-tests --disable-bench"

      # make
      alias m="make -j${jobs}"

      # configure + make combos
      alias cm="c && m"
      alias cm_fast="c_fast && m"

      # autogen + configure + make combos
      alias acm="a && c && m"
      alias acm_nw="a && c_no-wallet && m"
      alias acm_fast="a && c_fast && m"
      alias acm_fast_wallet="a && c_fast_wallet && m"

      # tests
      alias ut="make check"
      # functional tests
      alias ft="python3 test/functional/test_runner.py"
      # all tests
      alias t="ut && ft"

      echo "adding ${builtins.concatStringsSep ":" binDirs} to \$PATH to make running built binaries more natural"
      export PATH=$PATH:${builtins.concatStringsSep ":" binDirs};

      alias a c m c_fast cm acm acm_nw acm_fast ut ft t
    '';
}
