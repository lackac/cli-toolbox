{ pkgs }:
{
  acsm2epub = pkgs.callPackage ./acsm2epub { };
  boox2readwise = pkgs.callPackage ./boox2readwise { };
  nerd-fonts = pkgs.callPackage ./nerd-fonts { };
  xpwgen = pkgs.callPackage ./xpwgen { };
}
