"""Generate English narration with the packaged Kokoro model."""

import argparse
import math
import os
import sys
import wave
from datetime import datetime
from pathlib import Path


def positive_speed(value):
    speed = float(value)
    if not math.isfinite(speed) or speed <= 0:
        raise argparse.ArgumentTypeError("speed must be a finite number greater than zero")
    return speed


def main():
    parser = argparse.ArgumentParser(prog="kokoro-narrate", description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--text", help="text to narrate; otherwise read standard input")
    source.add_argument("-f", "--input", type=Path, help="UTF-8 text file to narrate")
    parser.add_argument("-o", "--output", type=Path, help="new WAV file to create")
    parser.add_argument(
        "--voice", default="bf_emma", help="voice name or comma-separated equal blend"
    )
    parser.add_argument("--speed", type=positive_speed, default=1.0)
    parser.add_argument(
        "--lang-code",
        choices=["a", "b"],
        help="American or British pronunciation; defaults to the first voice's accent",
    )
    parser.add_argument("--list-voices", action="store_true")
    args = parser.parse_args()

    model_dir = Path(os.environ["KOKORO_MODEL_DIR"])
    voices = {
        path.stem: path
        for path in (model_dir / "voices").glob("[ab][fm]_*.safetensors")
    }
    if args.list_voices:
        print("\n".join(sorted(voices)))
        return

    selected = [name.strip() for name in args.voice.split(",")]
    for name in selected:
        if name not in voices:
            parser.error(f"unknown English voice {name!r}; use --list-voices")

    if args.input is not None:
        text = args.input.read_text(encoding="utf-8")
    elif args.text is not None:
        text = args.text
    else:
        if sys.stdin.isatty():
            parser.error("provide --text, --input, or text on standard input")
        text = sys.stdin.read()
    if not text.strip():
        parser.error("narration text is empty")

    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    output = args.output or Path(f"narration-{timestamp}.wav")
    if output.suffix.lower() != ".wav":
        parser.error("output must have a .wav extension")
    if output.exists():
        parser.error(f"output already exists: {output}")
    if not output.parent.is_dir():
        parser.error(f"output directory does not exist: {output.parent}")

    import mlx.core as mx
    import numpy as np
    from mlx_audio.tts.utils import load_model

    if not mx.metal.is_available():
        raise RuntimeError("Metal GPU acceleration is unavailable")
    model = load_model(model_dir, model_type="kokoro")
    chunks = [
        np.asarray(result.audio)
        for result in model.generate(
            text.strip(),
            voice=",".join(str(voices[name]) for name in selected),
            lang_code=args.lang_code or selected[0][0],
            speed=args.speed,
        )
    ]
    if not chunks or any(chunk.ndim != 1 for chunk in chunks):
        raise RuntimeError("the model returned no audio or an unexpected audio shape")
    audio = np.concatenate(chunks)
    if not audio.size or not np.isfinite(audio).all() or not np.any(audio):
        raise RuntimeError("the model returned invalid or silent audio")

    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
    with output.open("xb") as handle, wave.open(handle, "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(model.sample_rate)
        stream.writeframes(pcm.tobytes())
    print(f"{output}: {len(audio) / model.sample_rate:.2f}s, {args.voice}, {args.speed:g}x")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        print(f"kokoro-narrate: {error}", file=sys.stderr)
        sys.exit(1)
