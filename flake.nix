{
  description = "Utility for managing a queue of YouTube content";

  inputs = { };

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in with pkgs; rec {
      devShells.x86_64-linux.default = mkShell {
        inputsFrom = [ packages.x86_64-linux.default ];
        buildInputs = packages.x86_64-linux.default.checkInputs ++ [
          inotify-tools
          ocamlPackages.merlin
          ocamlformat
          ocamlPackages.ocp-indent
          ocamlPackages.utop
        ];
      };

      packages.x86_64-linux.default = ocamlPackages.buildDunePackage rec {
        pname = "watch-later";
        version = "0.1.0";
        duneVersion = "3";
        src = nix-gitignore.gitignoreFilterSource lib.cleanSourceFilter [ ] ./.;
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
    };
}
