# kokoro-narrate

`kokoro-narrate` generates English narration locally with Kokoro and MLX Audio on
Apple Silicon with macOS 26 or later. Emma (`bf_emma`) is the default voice, with
British pronunciation and normal speed.

## Usage

Build and run from the CLI toolbox checkout:

```sh
nix run .#kokoro-narrate -- \
  --text "A good explanation makes a difficult idea feel simple." -o narration.wav
```

Once installed:

```sh
kokoro-narrate --input script.txt --output narration.wav
printf '%s\n' "Let's begin." | kokoro-narrate -o introduction.wav
kokoro-narrate --list-voices
kokoro-narrate --voice am_michael --speed 1.1 --input script.txt -o michael.wav
kokoro-narrate --voice af_heart,af_bella --input script.txt -o blend.wav
```

All 28 English preset voices are bundled. Select any of them with `--voice`; no
code change or additional download is needed. Names start with `a` for American
or `b` for British English, followed by `f` or `m` for female or male voices.

Comma-separated voices form an equal blend. Pronunciation follows the first
voice's accent; `--lang-code a` selects American English and `--lang-code b`
selects British English. Speed must be positive: `0.9` is slower, `1.1` faster.

Output is mono, 24 kHz, 16-bit PCM WAV. Without `--output`, the filename is
`narration-YYYY-MM-DD-HHmmss.wav`. Existing files are preserved. For videos,
generate one file per scene and time the animation from the resulting audio.

## Reproducibility

Nix installs Python, locked wheel dependencies, pronunciation data, the spaCy
English model, and Kokoro's weights and voices. Generation runs offline, including
with an empty Hugging Face cache. The build needs network access for uncached
sources. `uv2nix` packages the locked wheels into the Nix store; the official MLX
wheels include the precompiled Metal kernels.

The Python project and `uv.lock` live in `pkgs/kokoro-narrate/`. The lock
matches the auditioned Python 3.12 environment: MLX Audio 0.5.7, MLX/Metal 0.32.3,
and Misaki 0.9.4. Model assets are pinned to
`mlx-community/Kokoro-82M-bf16` revision
`a71e4d38b236d968966a2002c4c895dbd12b1c3c`.

After changing Python dependencies, regenerate the lock in that directory with
`uv lock --python 3.12`, build `.#kokoro-narrate` from the repository root, and verify
Metal acceleration and offline narration. Update both pinned MLX wheel URLs when
changing MLX versions. Model revision changes also require a new fixed-output hash
in `pkgs/kokoro-narrate/default.nix`.
