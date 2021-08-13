{ pkgs ? import <nixpkgs> { } }:

with pkgs;
let pkg = import ./release.nix { };
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
