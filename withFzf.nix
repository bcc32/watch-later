{ buildFHSUserEnvBubblewrap, wl }:

buildFHSUserEnvBubblewrap {
  name = "wl";
  runScript = "${wl}/bin/wl";

  # FIXME: This is a workaround for the fact that the Fzf library hardcodes the
  # path [/usr/bin/fzf].  This file can be removed (and fzf added as a build
  # input) when this is fixed upstream.
  targetPkgs = pkgs: with pkgs; [ fzf ];

  inherit (wl) passthru;
}
