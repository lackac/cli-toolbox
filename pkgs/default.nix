{ pkgs }:
{
  nerd-fonts = pkgs.callPackage ./nerd-fonts { };

  default = pkgs.callPackage ./nerd-fonts { };
}
