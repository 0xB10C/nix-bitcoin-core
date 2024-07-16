# nix-bitcoin-core

A Nix environment for Bitcoin Core development. Helps install necessary and optional dependencies.

## Installation

One way is to have the **nix-bitcoin-core/** directory alongside your **bitcoin/** directory, then symlink the shell.nix across. (Here it's done from **bitcoin/** assuming a common parent directory).

```console
ln -s ../nix-bitcoin-core/shell.nix .
```

## Usage

Get your terminal into the **bitcoin/** directory and do some variant of this:
```console
nix-shell
```
