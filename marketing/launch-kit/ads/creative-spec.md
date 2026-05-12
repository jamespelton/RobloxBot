# Sponsored Experience — Creative Spec

## Game Icon

Roblox uses your **game icon** as the primary creative for Sponsored Experiences. The icon IS the ad.

**Use:** `marketing/crystal-siege-icon-512.png` (Variant A — Hayden hero with crystal sword)

If you want a separate ad-only icon (Roblox doesn't really support this — they pull the live game icon — but for experimentation), regenerate with the icon-generator script using a slightly modified prompt.

---

## Companion Thumbnails

When users tap the ad → they land on the game page → first thing they see is your icon + thumbnails. **The ad creative chain is:**

1. **Icon** (ad surface) — Hayden hero
2. **Thumbnail #1** (large hero on game page) — `01-boss-fight.png` (most action)
3. **Thumbnails #2-8** (carousel below) — in this order:
   - #2 — `02-all-classes.png` (depth signal)
   - #6 — `06-coop-group.png` (social proof / multiplayer)
   - #3 — `03-building-system.png` (mechanics)
   - #5 — `05-crystal-upgrade.png` (progression)
   - #4 — `04-loot-chest.png` (reward loop)
   - #7 — `07-weather-effects.png` (polish)
   - #8 — `08-promo-code.png` (CTA at the end)

**Why this order:**
- Boss fight = highest action, hooks scroll
- Classes = depth, "this game has stuff"
- Co-op = "I can play with friends"
- Building/upgrade/loot = mechanics intrigue
- Weather = polish signal (this dev cares)
- Code = end-of-page CTA (last thing they see → drives play with intent)

---

## Optional A/B: Swap Variant A icon for Variant C ("DEFEND THE CRYSTAL!" text)

If after 2 weeks of organic + ad data, CTR is below 1%, swap to **Variant C** (the text-overlay version we generated but didn't pick).

Path: `marketing/icon-variants/icon-C-text_v1_512.png`

Re-run ads for another 2 weeks. Compare CTR delta. Whichever wins, that's your permanent icon for the rest of the 12 weeks.

---

## Ad Copy Pairings

Per the 3 ad copy variants in `ad-copy-variants.md`, pair each with the SAME icon (Variant A). Roblox doesn't support custom-creative-per-ad-variant — the icon is shared. So testing copy variants is testing the LINE OF TEXT, not the visual.

If you want to test visual variants, swap the actual game icon between ad campaigns. (Annoying — 5-30min propagation each time.)

---

## What NOT to do

- ❌ Don't use the game icon AND the same image as a thumbnail — feels redundant.
- ❌ Don't make ad-specific creative that's never seen in-game — users tap, expect to see what they were promised, don't see it, churn.
- ❌ Don't change the icon mid-campaign without noting the change date — your CTR data becomes uninterpretable.
- ❌ Don't run a campaign with a SINGLE thumbnail uploaded — Roblox shows the first 1-3 thumbnails on the game page. Empty slots = "this dev didn't care".

---

## File Inventory

Everything needed for the ad creative chain is at:

```
marketing/
├── crystal-siege-icon-512.png        # Live icon (Variant A)
├── icon-variants/
│   ├── icon-A-hero_v1_512.png        # = the above
│   ├── icon-B-crystal_v1_512.png     # backup
│   └── icon-C-text_v1_512.png        # backup / future A/B
└── launch-kit/
    └── thumbnails/
        ├── 01-boss-fight.png         # 1280x720
        ├── 02-all-classes.png
        ├── 03-building-system.png
        ├── 04-loot-chest.png
        ├── 05-crystal-upgrade.png
        ├── 06-coop-group.png
        ├── 07-weather-effects.png
        └── 08-promo-code.png
```

All ready to upload to Roblox Creator Hub.
