{ buildFHSUserEnvBubblewrap, installShellFiles, wl }:

buildFHSUserEnvBubblewrap {
  name = "wl";
  runScript = "exec -a \"$0\" ${wl}/bin/wl";

  # FIXME: This is a workaround for the fact that the Fzf library hardcodes the
  # path [/usr/bin/fzf].  This file can be removed (and fzf added as a build
  # input) when this is fixed upstream.
  targetPkgs = pkgs: with pkgs; [ fzf ];

  inherit (wl) passthru;

  extraInstallCommands = ''
    source ${installShellFiles}/nix-support/setup-hook
    installShellCompletion ${wl}/share/bash-completion/completions/wl.bash
  '';
}
