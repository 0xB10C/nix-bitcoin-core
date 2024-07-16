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
nix-shell --arg withClang true --arg withGui false
```

### Supported arguments

| Name         | Description                                   | Valid values  |
|--------------|-----------------------------------------------|---------------|
| `spareCores` | How many cores to exclude when running `make` | `<integer>` = less than the number of logical cores |
| `withClang`  | Whether to switch from GCC to Clang for compilation | `<boolean>` |
| `withDebug`  | Whether to pass `--enable-debug` to `./configure` | `<boolean>` |
| `withGui`    | Whether to enable bitcoin-qt                  | `<boolean>` |
