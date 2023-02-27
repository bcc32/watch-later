{ pkgs ? import <nixpkgs> { } }:

pkgs.ocamlPackages.callPackage ./. { inherit (pkgs) fzf; }
