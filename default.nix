{ lib, nix-gitignore, installShellFiles, buildDunePackage, async
, async_interactive, async_ssl, caqti-async, caqti-driver-sqlite3, cohttp-async
, core, cryptokit, directories, ppx_log, shexp, uri, webbrowser, yojson }:

buildDunePackage rec {
  pname = "watch-later";
  version = "0.1.0";
  useDune2 = true;
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
    ppx_log
    uri
    webbrowser
    yojson
  ];
  passthru.checkInputs = checkInputs;

  nativeBuildInputs = [ installShellFiles ];
  postInstall = ''
    installShellCompletion share/completions/watch-later.bash
  '';

  meta = { homepage = "https://github.com/bcc32/watch-later"; };
}
