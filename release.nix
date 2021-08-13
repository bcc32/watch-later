{ pkgs ? import <nixpkgs> { } }:

pkgs.ocamlPackages.callPackage ./. {
  # TODO: When this gets released into opam stable, add it to nixpkgs

  jsonaf = pkgs.ocamlPackages.buildDunePackage rec {
    useDune2 = true;
    minimumOCamlVersion = "4.04";
    version = "5d669e9c66a13760dea53efb026a53d7b560edae";

    pname = "jsonaf";
    hash = "1h680bfi4kcm5d2db5vq03yhfd94b0mga6rkln5dl6639jx382is";
    src = pkgs.fetchFromGitHub {
      owner = "janestreet";
      repo = pname;
      rev = version;
      sha256 = hash;
    };

    meta = {
      license = pkgs.lib.licenses.asl20;
      homepage = "https://github.com/janestreet/${pname}";
      description =
        "A library for parsing, manipulating, and serializing data structured as JSON.";
    };

    propagatedBuildInputs = with pkgs.ocamlPackages; [ angstrom faraday ppx_jane ];
  };
}
