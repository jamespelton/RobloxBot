"""Split a binary file into base64 chunks, each wrapped in a JS append snippet.

Output files are sized so each fits within the Read tool's ~25K token cap
(~18KB raw is safe for base64 — 1 token / ~3 chars).
"""

import base64
import sys
from pathlib import Path

PNG_FILE = sys.argv[1]
KEY = sys.argv[2]  # e.g., 'icon', 'thumb_01'
OUT_DIR = Path("/tmp/rex_chunks")
OUT_DIR.mkdir(exist_ok=True)

# Clear any prior chunks for this KEY
for f in OUT_DIR.glob(f"{KEY}_*.js"):
    f.unlink()

data = Path(PNG_FILE).read_bytes()
b64 = base64.b64encode(data).decode()
CHUNK_SIZE = 18000  # chars of base64 per chunk
chunks = [b64[i:i + CHUNK_SIZE] for i in range(0, len(b64), CHUNK_SIZE)]

for idx, chunk in enumerate(chunks, 1):
    js = f'window.__rex_b64=(window.__rex_b64||"")+"{chunk}";1'
    (OUT_DIR / f"{KEY}_{idx:03d}.js").write_text(js)

print(f"file={PNG_FILE}")
print(f"bytes={len(data)}")
print(f"b64_chars={len(b64)}")
print(f"chunks={len(chunks)}")
print(f"chunk_size={CHUNK_SIZE}")
print(f"output_dir={OUT_DIR}")
print(f"key={KEY}")
