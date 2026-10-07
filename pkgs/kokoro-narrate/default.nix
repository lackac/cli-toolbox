{
  callPackage,
  espeak-ng,
  fetchFromHuggingFace,
  lib,
  pyproject-nix,
  python312,
  uv2nix,
  writeShellApplication,
}:
let
  python = python312;
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ./.;
  };
  pythonSet =
    (callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
          (final: prev: {
            # MLX's extension finds the Metal runtime relative to its own path.
            # This is the same layout fix used by nixpkgs' mlx-bin package.
            mlx = prev.mlx.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                for dir in lib include share; do
                  ln -s "${final.mlx-metal}/${python.sitePackages}/mlx/$dir" \
                    "$out/${python.sitePackages}/mlx/$dir"
                done
              '';
            });

            # The wheel's bundled eSpeak fails with long Nix/venv data paths.
            misaki = prev.misaki.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                substituteInPlace "$out/${python.sitePackages}/misaki/espeak.py" \
                  --replace-fail 'espeakng_loader.get_library_path()' \
                    '"${lib.getLib espeak-ng}/lib/libespeak-ng.dylib"' \
                  --replace-fail 'espeakng_loader.get_data_path()' \
                    '"${lib.getLib espeak-ng}/share/espeak-ng-data"'
              '';
            });
          })
        ]
      );
  environment = pythonSet.mkVirtualEnv "kokoro-env" workspace.deps.default;
  model = fetchFromHuggingFace {
    name = "kokoro-82m-bf16";
    repoId = "mlx-community/Kokoro-82M-bf16";
    rev = "a71e4d38b236d968966a2002c4c895dbd12b1c3c";
    backend = "lfs";
    hash = "sha256-9ChPYrzzdhmAYl6ZqhewiviZEP/RbRVIMDrMEvtX65k=";
  };
in
writeShellApplication {
  name = "kokoro-narrate";
  runtimeEnv = {
    KOKORO_MODEL_DIR = model;
    HF_HUB_OFFLINE = "1";
    HF_HUB_DISABLE_TELEMETRY = "1";
  };
  text = ''
    exec ${environment}/bin/python -I ${./src/kokoro-narrate.py} "$@"
  '';
  passthru = { inherit environment model; };
  meta = {
    description = "Offline English narration with Kokoro and Metal acceleration";
    mainProgram = "kokoro-narrate";
    platforms = [ "aarch64-darwin" ];
  };
}
