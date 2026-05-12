"""Roblox icon/asset generator — Gemini image API (Nano Banana Pro).

Generates SQUARE Roblox-style icon variants from a text prompt + reference avatar.
Outputs both 1024x1024 (full quality) and 512x512 (Roblox icon target size).

Usage:
    python3 roblox_icon_generator.py \\
        --prompt-file /tmp/icon_prompt.txt \\
        --face marketing/icon-references/hayden-avatar.png \\
        --output marketing/icon-variants/crystal-siege-icon \\
        --variants 3 \\
        --open
"""

import argparse
import io
import os
import subprocess
import sys
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image

DEFAULT_MODEL = "gemini-3-pro-image-preview"
GEMINI_KEY_ENV = "GEMINI_API_KEY"


def generate_variant(client, model: str, prompt: str, face_path: str | None, out_stem: str) -> bool:
    contents: list = []
    if face_path:
        with open(face_path, "rb") as f:
            face_bytes = f.read()
        mime = "image/jpeg" if face_path.lower().endswith((".jpg", ".jpeg")) else "image/png"
        contents.append(types.Part.from_bytes(data=face_bytes, mime_type=mime))
    contents.append(prompt)

    response = client.models.generate_content(
        model=model,
        contents=contents,
        config=types.GenerateContentConfig(response_modalities=["IMAGE", "TEXT"]),
    )
    for part in response.candidates[0].content.parts:
        inline = getattr(part, "inline_data", None)
        if inline and inline.mime_type and inline.mime_type.startswith("image/"):
            img = Image.open(io.BytesIO(inline.data))
            # Center-crop to square if needed, then save both sizes.
            w, h = img.size
            side = min(w, h)
            left = (w - side) // 2
            top = (h - side) // 2
            img_sq = img.crop((left, top, left + side, top + side))
            img_sq.resize((1024, 1024), Image.LANCZOS).save(f"{out_stem}_1024.png", quality=95)
            img_sq.resize((512, 512), Image.LANCZOS).save(f"{out_stem}_512.png", quality=95)
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Roblox icons via Gemini image API.")
    prompt_src = parser.add_mutually_exclusive_group(required=True)
    prompt_src.add_argument("--prompt", help="Prompt text (quoted).")
    prompt_src.add_argument("--prompt-file", help="Path to text file containing the prompt.")
    parser.add_argument("--output", required=True, help="Output stem (no extension).")
    parser.add_argument("--variants", type=int, default=3, help="Number of variants (default 3).")
    parser.add_argument("--face", help="Reference avatar image path (optional).")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Gemini image model ID.")
    parser.add_argument("--open", action="store_true", help="Open generated icons in Preview.")
    args = parser.parse_args()

    prompt = Path(args.prompt_file).read_text() if args.prompt_file else args.prompt

    api_key = os.environ.get(GEMINI_KEY_ENV)
    if not api_key:
        print(f"ERROR: Set {GEMINI_KEY_ENV} environment variable.")
        return 1
    client = genai.Client(api_key=api_key)

    output_stem = Path(args.output).expanduser().resolve()
    output_stem.parent.mkdir(parents=True, exist_ok=True)

    generated = []
    for i in range(1, args.variants + 1):
        stem = f"{output_stem}_v{i}"
        print(f"[{i}/{args.variants}] → {stem}_512.png")
        try:
            if generate_variant(client, args.model, prompt, args.face, stem):
                print(f"  OK: {stem}_512.png + {stem}_1024.png")
                generated.append(f"{stem}_512.png")
            else:
                print(f"  SKIP: no image returned")
        except Exception as exc:  # noqa: BLE001
            print(f"  ERROR: {exc}")

    if not generated:
        print("No icons generated.")
        return 1

    print(f"\nGenerated {len(generated)} icon(s):")
    for path in generated:
        print(f"  {path}")

    if args.open:
        subprocess.run(["open", *generated], check=False)

    return 0


if __name__ == "__main__":
    sys.exit(main())
