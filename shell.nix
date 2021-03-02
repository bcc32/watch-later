{ pkgs ? import <nixpkgs> { } }:

with pkgs;
mkShell {
  inputsFrom = [ (ocamlPackages.callPackage ./. { }) ];
  buildInputs = [
    ocamlPackages.merlin
    ocamlformat
    ocamlPackages.ocp-indent
    ocamlPackages.utop
  ];
}
