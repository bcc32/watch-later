{ pkgs ? import <nixpkgs> { } }:
let inherit (pkgs) mkShell gmp m4 libffi opam openssl pkgconfig sqlite zlib;
in mkShell {
  buildInputs = [ gmp m4 libffi opam openssl pkgconfig sqlite zlib ];
}
