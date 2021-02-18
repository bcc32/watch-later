{ pkgs ? import <nixpkgs> { } }:

with pkgs;
mkShell {
  buildInputs = [
    # For opam
    m4
    opam
    pkgconfig
    # For this project
    gmp
    libffi
    openssl
    sqlite
    zlib
  ];
}
