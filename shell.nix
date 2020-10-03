{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  buildInputs = with pkgs; [ m4 libffi openssl pkgconfig sqlite ];
}
