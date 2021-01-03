{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  buildInputs = with pkgs; [ gmp m4 libffi opam openssl pkgconfig sqlite zlib ];
}
