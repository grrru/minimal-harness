# Upstream Sources

Plain-clone optional upstream repos here. These directories are local inputs for
install scripts and are not committed.

```sh
./codex/install.sh --fetch-ecc --list-ecc
```

Use the Codex installer with an explicit source path when selecting ECC material:

```sh
./codex/install.sh --fetch-ecc --ecc-source upstream/ECC --with-ecc-skill search-first
```
