{
  coreutils,
  curl,
  fzf,
  jq,
  writeShellApplication,
}:
writeShellApplication {
  name = "nerd-fonts";

  runtimeInputs = [
    coreutils
    curl
    fzf
    jq
  ];

  text = builtins.readFile ./src/nerd-fonts;
}
