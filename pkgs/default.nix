{ pkgs }:
{
  nerd-fonts = pkgs.callPackage ./nerd-fonts { };
  xpwgen = pkgs.callPackage ./xpwgen { };

  default = pkgs.callPackage ./nerd-fonts { };
}
