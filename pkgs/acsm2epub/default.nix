{
  coreutils,
  docker,
  gnused,
  writeShellApplication,
}:
writeShellApplication {
  name = "acsm2epub";

  runtimeInputs = [
    coreutils
    docker
    gnused
  ];

  text = builtins.readFile ./src/acsm2epub;
}
