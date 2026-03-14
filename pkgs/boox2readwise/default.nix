{
  bundlerEnv,
  ruby,
  writeShellApplication,
}:
let
  gems = bundlerEnv {
    name = "boox2readwise-bundle";
    inherit ruby;
    gemdir = ./.;
  };
in
writeShellApplication {
  name = "boox2readwise";

  runtimeInputs = [ gems.wrappedRuby ];

  text = ''
    exec ruby ${./src/boox2readwise.rb} "$@"
  '';
}
