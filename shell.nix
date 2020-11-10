{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  buildInputs = with pkgs; [ gmp m4 libffi openssl pkgconfig sqlite zlib ];
}
