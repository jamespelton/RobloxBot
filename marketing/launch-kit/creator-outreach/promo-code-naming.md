# Promo Code Naming Convention

Each creator gets a personalized code. Naming rules to keep them clean, easy to type, and trackable.

---

## Format

`<CREATOR_NAME_SHORT>` — all caps, no spaces, no special chars, 4-12 characters max.

## Examples

| Creator | Code |
|---------|------|
| JustADuckie | `DUCKIE` |
| JustHarrison | `HARRISON` |
| iamEvan | `EVAN` |
| Photon | `PHOTON` |
| Elitelupus | `ELITE` |
| RetroDan | `RETRODAN` |
| NutMeg | `NUTMEG` |
| KoKo Panda | `KOKO` |
| AmberRains | `AMBER` |
| JuniDrawz | `JUNI` |

## Rules

1. **All caps** — easier to type on mobile, more visible in chat
2. **No spaces or special chars** — Roblox code redemption fields strip these inconsistently
3. **4-12 chars** — long enough to feel personal, short enough to type fast
4. **Drop "Just", "Mr", "Mrs"** prefixes — `DUCKIE` not `JUSTADUCKIE`
5. **Drop numbers** unless they're part of the brand — `KEIRA` not `KEIRAPLAYZ` unless they go by the full name
6. **Check uniqueness** — no two creators get the same code. Append a number if needed (`DUCKIE2`).
7. **Spell it out for them** — when you send the code, spell each letter so they don't typo it on stream

## Reward Tier

All creator codes give the same reward to viewers:

- **200 free gems** (one-time use per Roblox account)
- **Active for 60 days** from issue date — after that, kill it (gem inflation risk)
- **Tracked separately** in CodeManager so you can see which creator drove which redemptions

## Expiring Codes

After 60 days:
1. Disable the code in CodeManager (so no new redemptions)
2. Email the creator: "Heads-up, code expires today. Want a new one for your next video?"
3. Either reissue with a v2 suffix (`DUCKIE2`, `HARRISON2`) or sunset it.

## Public-Code Bonus

A creator's code can be promoted PUBLICLY (their viewers can share it on Discord, etc.) — that's part of the deal. But if you see a creator's code getting redeemed 1000+ times in a day, check that they haven't posted it on a coupon-aggregator site (those drain gem economy fast).

---

## Tracking Spreadsheet

Keep at `marketing/creator-codes-tracking.csv`:

```
creator,code,issued_date,expires_date,redemptions,videos_referenced,status
JustADuckie,DUCKIE,2026-05-12,2026-07-11,0,,active
NutMeg,NUTMEG,2026-05-13,2026-07-12,0,,active
```

Update weekly. Codes that get <10 redemptions in 30 days → kill and reissue a different message.
