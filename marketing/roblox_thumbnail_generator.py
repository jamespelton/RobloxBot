"""Roblox game-page thumbnail generator (16:9, 1280x720).

Loops through a list of (prompt_file, output_path) tuples and generates
each thumbnail via Gemini Nano Banana Pro. Used for the 8 thumbnail
variants on the Roblox game store page.

Usage: edit the JOBS list below and run.
"""

import io
import os
import sys
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image

MODEL = "gemini-3-pro-image-preview"
ROOT = Path("/Users/jamespelton/Apps/React/RobloxBot")
HAYDEN_AVATAR = ROOT / "marketing/icon-references/hayden-avatar.png"
PROMPTS_DIR = ROOT / "marketing/launch-kit/_thumbnail-prompts"
OUTPUT_DIR = ROOT / "marketing/launch-kit/thumbnails"

# (prompt_filename, output_filename, use_hayden_reference)
JOBS = [
    ("01-boss-fight.txt", "01-boss-fight.png", False),
    ("02-all-classes.txt", "02-all-classes.png", True),
    ("03-building-system.txt", "03-building-system.png", False),
    ("04-loot-chest.txt", "04-loot-chest.png", False),
    ("05-crystal-upgrade.txt", "05-crystal-upgrade.png", False),
    ("06-coop-group.txt", "06-coop-group.png", True),
    ("07-weather-effects.txt", "07-weather-effects.png", False),
    ("08-promo-code.txt", "08-promo-code.png", False),
]


def generate(client, prompt: str, face_path: Path | None, out_path: Path) -> bool:
    contents: list = []
    if face_path and face_path.exists():
        with open(face_path, "rb") as f:
            face_bytes = f.read()
        mime = "image/png"
        contents.append(types.Part.from_bytes(data=face_bytes, mime_type=mime))
    contents.append(prompt)

    response = client.models.generate_content(
        model=MODEL,
        contents=contents,
        config=types.GenerateContentConfig(response_modalities=["IMAGE", "TEXT"]),
    )
    for part in response.candidates[0].content.parts:
        inline = getattr(part, "inline_data", None)
        if inline and inline.mime_type and inline.mime_type.startswith("image/"):
            img = Image.open(io.BytesIO(inline.data))
            # Force 16:9 — center-crop to 16:9 ratio if needed, then resize to 1280x720.
            w, h = img.size
            target_ratio = 16 / 9
            current_ratio = w / h
            if current_ratio > target_ratio:
                # Too wide — crop sides.
                new_w = int(h * target_ratio)
                left = (w - new_w) // 2
                img = img.crop((left, 0, left + new_w, h))
            elif current_ratio < target_ratio:
                # Too tall — crop top/bottom.
                new_h = int(w / target_ratio)
                top = (h - new_h) // 2
                img = img.crop((0, top, w, top + new_h))
            img.resize((1280, 720), Image.LANCZOS).save(out_path, quality=95)
            return True
    return False


def main() -> int:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: Set GEMINI_API_KEY environment variable.")
        return 1
    client = genai.Client(api_key=api_key)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    generated = 0
    failed = []
    for prompt_file, out_file, use_hayden in JOBS:
        prompt_path = PROMPTS_DIR / prompt_file
        out_path = OUTPUT_DIR / out_file
        if not prompt_path.exists():
            print(f"SKIP: prompt not found: {prompt_path}")
            failed.append(prompt_file)
            continue
        prompt = prompt_path.read_text()
        face = HAYDEN_AVATAR if use_hayden else None
        print(f"Generating {out_file}...")
        try:
            if generate(client, prompt, face, out_path):
                print(f"  OK: {out_path}")
                generated += 1
            else:
                print(f"  SKIP: no image returned for {prompt_file}")
                failed.append(prompt_file)
        except Exception as exc:  # noqa: BLE001
            print(f"  ERROR ({prompt_file}): {exc}")
            failed.append(prompt_file)

    print(f"\nDone: {generated}/{len(JOBS)} thumbnails generated.")
    if failed:
        print(f"Failed: {failed}")
    return 0 if generated == len(JOBS) else 1


if __name__ == "__main__":
    sys.exit(main())
