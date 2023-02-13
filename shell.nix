{ pkgs ? import <nixpkgs> { } }:

with pkgs;
let
  pkg = ocamlPackages.callPackage ./. {
    inherit fzf;
  };
in mkShell {
  inputsFrom = [ pkg ];
  buildInputs = pkg.checkInputs ++ [
    inotify-tools
    ocamlPackages.merlin
    ocamlformat
    ocamlPackages.ocp-indent
    ocamlPackages.utop
  ];
}
