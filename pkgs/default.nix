{ pkgs }:
{
  boox2readwise = pkgs.callPackage ./boox2readwise { };
  nerd-fonts = pkgs.callPackage ./nerd-fonts { };
  xpwgen = pkgs.callPackage ./xpwgen { };

  default = pkgs.callPackage ./nerd-fonts { };
}
