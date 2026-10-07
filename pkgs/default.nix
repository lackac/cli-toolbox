{
  pkgs,
  pyproject-nix,
  uv2nix,
}:
{
  acsm2epub = pkgs.callPackage ./acsm2epub { };
  boox2readwise = pkgs.callPackage ./boox2readwise { };
  nerd-fonts = pkgs.callPackage ./nerd-fonts { };
  xpwgen = pkgs.callPackage ./xpwgen { };
}
// pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") {
  kokoro-narrate = pkgs.callPackage ./kokoro-narrate { inherit pyproject-nix uv2nix; };
}
