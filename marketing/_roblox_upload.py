"""One-shot Roblox icon + thumbnail uploader.

Reads ROBLOSECURITY cookie from ~/.roblox-cookie, uploads:
  1. Game icon (replaces accidental pink-gradient with the real Variant A)
  2. All 8 game-page thumbnails in the correct order
Deletes the cookie file at the end.

Run: python3 marketing/_roblox_upload.py
"""

import os
import sys
from pathlib import Path

import requests

UNIVERSE_ID = 9826868953

COOKIE_PATH = Path.home() / ".roblox-cookie"
ROOT = Path("/Users/jamespelton/Apps/React/RobloxBot")
ICON_PATH = ROOT / "marketing/crystal-siege-icon-512.png"
THUMB_DIR = ROOT / "marketing/launch-kit/thumbnails"

# Per ads/creative-spec.md: 01 hero, then 02, 06, 03, 05, 04, 07, 08
THUMB_ORDER = [
    "01-boss-fight.png",
    "02-all-classes.png",
    "06-coop-group.png",
    "03-building-system.png",
    "05-crystal-upgrade.png",
    "04-loot-chest.png",
    "07-weather-effects.png",
    "08-promo-code.png",
]


def get_csrf(cookie: str) -> str:
    """Send a no-op authenticated request to harvest the X-CSRF-TOKEN."""
    r = requests.post(
        "https://auth.roblox.com/v2/logout",
        cookies={".ROBLOSECURITY": cookie},
        allow_redirects=False,
    )
    if "x-csrf-token" not in r.headers:
        raise RuntimeError(f"No CSRF token in response. Status={r.status_code}, headers={dict(r.headers)}")
    return r.headers["x-csrf-token"]


def upload_icon(cookie: str, csrf: str, png_path: Path) -> dict:
    url = f"https://publish.roblox.com/v1/games/{UNIVERSE_ID}/icon"
    with open(png_path, "rb") as f:
        files = {"request.files": (png_path.name, f, "image/png")}
        r = requests.post(
            url,
            params={"name": "icon", "description": ""},
            cookies={".ROBLOSECURITY": cookie},
            headers={"X-CSRF-TOKEN": csrf},
            files=files,
        )
    return {"status": r.status_code, "body": r.text[:500]}


def upload_thumbnail(cookie: str, csrf: str, png_path: Path) -> dict:
    url = f"https://publish.roblox.com/v1/games/{UNIVERSE_ID}/thumbnail/image"
    with open(png_path, "rb") as f:
        files = {"request.files": (png_path.name, f, "image/png")}
        r = requests.post(
            url,
            cookies={".ROBLOSECURITY": cookie},
            headers={"X-CSRF-TOKEN": csrf},
            files=files,
        )
    return {"status": r.status_code, "body": r.text[:500]}


def main() -> int:
    if not COOKIE_PATH.exists():
        print(f"ERROR: Cookie file not found at {COOKIE_PATH}")
        print("Save the ROBLOSECURITY value first:")
        print("  echo 'YOUR_COOKIE_VALUE' > ~/.roblox-cookie && chmod 600 ~/.roblox-cookie")
        return 1

    cookie = COOKIE_PATH.read_text().strip()
    if not cookie:
        print(f"ERROR: Cookie file at {COOKIE_PATH} is empty.")
        return 1

    # Verify auth first.
    me = requests.get(
        "https://users.roblox.com/v1/users/authenticated",
        cookies={".ROBLOSECURITY": cookie},
    )
    if me.status_code != 200:
        print(f"ERROR: Cookie auth failed. Status={me.status_code}. Cookie may be invalid/expired.")
        return 1
    user = me.json()
    print(f"Authenticated as {user['name']} (id={user['id']})")
    if user["id"] != 7923191564:
        print(f"WARNING: Logged in as {user['name']} but Crystal Siege is owned by JimmyP722 (id=7923191564).")
        print("Upload will fail with 403. Aborting.")
        return 1

    # Get CSRF token.
    csrf = get_csrf(cookie)
    print(f"CSRF token acquired ({len(csrf)} chars)")

    # Upload icon.
    print(f"\n--- Uploading icon: {ICON_PATH.name} ({ICON_PATH.stat().st_size} bytes) ---")
    icon_result = upload_icon(cookie, csrf, ICON_PATH)
    print(f"  Status: {icon_result['status']}")
    print(f"  Body: {icon_result['body']}")
    if icon_result["status"] != 200:
        print("  Icon upload FAILED — investigate before continuing thumbnails.")
        return 1

    # Upload thumbnails.
    print(f"\n--- Uploading {len(THUMB_ORDER)} thumbnails ---")
    thumb_results = []
    for thumb_name in THUMB_ORDER:
        png = THUMB_DIR / thumb_name
        if not png.exists():
            print(f"  SKIP (not found): {thumb_name}")
            thumb_results.append((thumb_name, "MISSING"))
            continue
        r = upload_thumbnail(cookie, csrf, png)
        marker = "OK" if r["status"] == 200 else f"FAIL({r['status']})"
        print(f"  {thumb_name}: {marker}")
        if r["status"] != 200:
            print(f"    Body: {r['body']}")
        thumb_results.append((thumb_name, marker))

    # Cleanup.
    print("\n--- Cleanup ---")
    try:
        COOKIE_PATH.unlink()
        print(f"  Deleted {COOKIE_PATH}")
    except Exception as exc:  # noqa: BLE001
        print(f"  Failed to delete cookie file: {exc}")

    # Summary.
    print("\n=== SUMMARY ===")
    print(f"Icon: status {icon_result['status']}")
    for name, marker in thumb_results:
        print(f"Thumb {name}: {marker}")
    successes = sum(1 for _, m in thumb_results if m == "OK")
    print(f"\n{successes}/{len(THUMB_ORDER)} thumbnails uploaded successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
