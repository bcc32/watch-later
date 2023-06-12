{ lib, buildDunePackage, nix-gitignore, installShellFiles, async
, async_interactive, async_ssl, bash, caqti-async, caqti-driver-sqlite3
, cohttp-async, core, cryptokit, directories, jsonaf, ocamlPackages, ppx_log
, ppx_jsonaf_conv, shexp, uri, webbrowser }:

buildDunePackage rec {
  pname = "watch-later";
  version = "0.1.0";
  duneVersion = "3";
  src = nix-gitignore.gitignoreFilterSource lib.cleanSourceFilter [ ] ./.;
  checkInputs = [ shexp ];
  propagatedBuildInputs = [
    async
    async_interactive
    async_ssl
    caqti-async
    caqti-driver-sqlite3
    cohttp-async
    core
    cryptokit
    directories
    ocamlPackages.fzf
    jsonaf
    ppx_jsonaf_conv
    ppx_log
    uri
    webbrowser
  ];
  passthru.checkInputs = checkInputs;

  nativeBuildInputs = [ installShellFiles ];
  postInstall = ''
    installShellCompletion share/completions/wl.bash
  '';

  meta = { homepage = "https://github.com/bcc32/watch-later"; };
}
