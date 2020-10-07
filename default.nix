with import <nixpkgs> { };

let
  inherit (ocamlPackages)
    buildDunePackage async async_interactive async_ssl cohttp-async core
    ocaml_sqlite3 uri webbrowser yojson;

in buildDunePackage {
  pname = "watch-later";
  version = "0.1.0";
  useDune2 = true;
  src = nix-gitignore.gitignoreFilterSource lib.cleanSourceFilter [ ] ./.;
  propagatedBuildInputs = [
    async
    async_interactive
    async_ssl
    cohttp-async
    core
    ocaml_sqlite3
    uri
    webbrowser
    yojson
  ];
  meta = { homepage = "https://github.com/bcc32/watch-later"; };
}
