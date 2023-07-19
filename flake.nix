{
  description = "Utility for managing a queue of YouTube content";

  inputs = { flake-utils.url = "github:numtide/flake-utils"; };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in with pkgs; rec {
        devShells.default = mkShell {
          inputsFrom = [ packages.default ];
          buildInputs = packages.default.checkInputs ++ [
            inotify-tools
            ocamlPackages.merlin
            ocamlformat
            ocamlPackages.ocp-indent
            ocamlPackages.utop
          ];
        };

        packages.default = ocamlPackages.buildDunePackage rec {
          pname = "watch-later";
          version = "0.1.0";
          duneVersion = "3";
          src = ./.;
          checkInputs = with ocamlPackages; [ shexp ];
          propagatedBuildInputs = with ocamlPackages; [
            async
            async_interactive
            async_ssl
            caqti-async
            caqti-driver-sqlite3
            cohttp-async
            core
            cryptokit
            directories
            fzf
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
        };
      });
}
