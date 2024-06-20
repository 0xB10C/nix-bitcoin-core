{ pkgs ? import <nixpkgs> {} }:

#pkgs.clangStdenv.mkDerivation {
#  name = "libcxxStdenv";
# clang_13
let
  inherit (pkgs.lib) strings;
  jobs = if (strings.hasSuffix "linux" builtins.currentSystem) then "$(($(nproc)))" else "6";
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
      db48 # Berkeley DB 4.8
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
    ];

    # needed in 'autogen.sh'
    LIBTOOLIZE = "libtoolize";

    # needed for 'configure' to find boost
    # Run ./configure with the argument '--with-boost-libdir=\$NIX_BOOST_LIB_DIR'"
    NIX_BOOST_LIB_DIR = "${pkgs.boost}/lib";

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
      alias c="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR"
      alias c_no-wallet="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR --disable-wallet"
      alias c_fast="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR --disable-wallet --disable-tests --disable-fuzz --disable-bench -disable-fuzz-binary"
      alias c_fast_wallet="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR --disable-tests --disable-bench"

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

      echo "adding \$PWD/src to \$PATH to make running built binaries more natural"
      export PATH=$PATH:$PWD/src;

      alias a c m c_fast cm acm acm_nw acm_fast ut ft t
    '';
}