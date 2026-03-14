{ ruby, writeShellApplication }:
writeShellApplication {
  name = "xpwgen";

  runtimeInputs = [ ruby ];

  text = ''
    exec ruby ${./src/xpwgen.rb} "$@"
  '';
}
