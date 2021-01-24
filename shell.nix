{ pkgs ? import <nixpkgs> { } }:
let inherit (pkgs) mkShell m4 libffi opam openssl pkgconfig sqlite zlib;
in mkShell {
  buildInputs = [ m4 libffi opam openssl pkgconfig sqlite zlib ];
}
