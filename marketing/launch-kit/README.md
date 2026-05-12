# Crystal Siege — Marketing Launch Kit

**Built autonomously by Rex on 2026-05-12.** Everything in this folder is ready for you to act on when you have time. Nothing here requires you to write code or design assets.

---

## ⚡ The "I Have 15 Minutes" Checklist

If you only have 15 minutes today, do these three things in this order. Each one is a high-leverage move that compounds.

### 1. Upload the icon (2 minutes)
- Open https://create.roblox.com → Crystal Siege → **Configure → Game Settings → Game Icon**
- Upload `marketing/crystal-siege-icon-512.png`
- Click **Save → Publish**

### 2. Update title + description (5 minutes)
- Same page → **Basic Info**
- Title: copy from `copy/game-title.txt` (line 1 — the ⚔️ Crystal Siege: Tower Defense Survival ⚔️ version)
- Description: copy from `copy/game-description.txt` (the whole formatted block)
- Tags: copy first 6-10 from `copy/tags.txt`
- **Save → Publish**

### 3. Upload all 8 thumbnails (8 minutes)
- Same page → **Thumbnails**
- Upload `thumbnails/01-boss-fight.png` first (it becomes the hero/large thumbnail)
- Then `02-all-classes.png`, `06-coop-group.png`, `03-building-system.png`, `05-crystal-upgrade.png`, `04-loot-chest.png`, `07-weather-effects.png`, `08-promo-code.png` in that order (per `ads/creative-spec.md`)
- **Save → Publish**

✅ Done. Your Roblox game page is now ~10× more polished than it was this morning.

---

## 📂 What's In This Kit

```
launch-kit/
├── README.md                          ← You are here
├── thumbnails/                        ← 8 × 1280×720 PNGs for the game page
├── copy/                              ← Title, description, tags
├── creator-outreach/                  ← 30-YouTuber target list + email template
├── tiktok/                            ← 30-day content calendar + account setup + first-video script
├── discord/                           ← Server blueprint + icon + banner + pinned messages
└── ads/                               ← Sponsored Experience ad copy + targeting + creative spec
```

Plus, sitting one level up:
```
marketing/
├── crystal-siege-icon-512.png         ← The game icon (Variant A — Hayden hero)
├── crystal-siege-icon-1024.png        ← Same icon, higher res
└── icon-variants/                     ← The 3 generated icon variants (A picked, B + C backup)
```

---

## 📋 The "I Have an Hour" Checklist

When you have more than 15 minutes, work through these in order. Each builds on the previous.

### Hour 1: Roblox Game Page (do the 15-min checklist above)

### Hour 2: Discord Server (30 minutes setup, then ongoing)

Per `discord/blueprint.md`:

1. **Create the server** at https://discord.com/channels/@me → "+" button
2. **Server name:** "Crystal Siege Official 🔮"
3. **Upload server icon:** `discord/server-icon.png`
4. **Upload server banner** (after server boost): `discord/server-banner.png`
5. **Create channels** per `discord/blueprint.md` (5 categories, 18 channels)
6. **Create roles** per the role hierarchy in blueprint
7. **Install MEE6 or Carl-bot** for welcome messages + auto-mod
8. **Paste welcome message** from `discord/welcome-bot-message.txt` into the bot config
9. **Pin per-channel messages** from `discord/pinned-messages.md` into each channel
10. **Generate Discord invite link** (set to never expire, no use cap)
11. **Add invite link** to:
    - Roblox game description (replace `[INVITE]` placeholder)
    - TikTok bio
    - Roblox group wall pin

### Hour 3: TikTok Account (~30 minutes setup, then daily posts)

Per `tiktok/account-bio.txt`:

1. **Create account** with username `@crystalsiege` (or alt if taken)
2. **Profile pic:** `marketing/crystal-siege-icon-512.png`
3. **Bio:** copy from `tiktok/account-bio.txt`
4. **Link in bio:** Roblox game URL
5. **Record first video** using the script in `tiktok/pinned-video-script.txt`
6. **Pin that video** to top of profile after posting

Then: follow the 30-day calendar in `tiktok/content-calendar-30day.md`. Pre-record a batch on a Saturday so you're not on the daily content treadmill.

### Hour 4: Creator Outreach (~1 hour for first 5 emails, then ~10 min/day)

Per `creator-outreach/`:

1. **Open `targets.csv`** — review the 30 ranked targets
2. **Start with the top 5** (the ones with verified contact info and 9-10 relevance):
   - JustADuckie (YouTube DM)
   - iamEvan (business email)
   - Photon (business email)
   - JuniDrawz (YouTube DM)
   - AmberRains (YouTube DM)
3. **Use the email template** from `creator-outreach/email-template.txt` — pick the variation that matches each creator type (TD-focused vs Variety)
4. **Personalize each one** — mention a specific recent video from them
5. **Wire up a personalized code** for each YES (see `creator-outreach/promo-code-naming.md`)
6. **Send 5/day max** until you've worked through the list. Don't blast.

### Hour 5+: Sponsored Experience Ads (after icon is live for 48+ hours)

Per `ads/`:

1. Wait 48 hours after publishing the new icon — let organic CTR data come in
2. If organic CTR is below 1%, regenerate the icon before paid ads (waste prevention)
3. Otherwise, open https://create.roblox.com → Crystal Siege → **Promote → Ads**
4. Set targeting per `ads/targeting-recommendation.md`
5. Use copy variants from `ads/ad-copy-variants.md` ($5/day each, rotate)
6. Monitor daily. Kill criteria are in `ads/ad-copy-variants.md`.

---

## 🚫 What's NOT In This Kit (and why)

Things that require Studio code work — deferred until Studio is available:

- **FTUE rewrite** (forced class pick, arrow to portal, first-kill <30s, welcome gift)
- **4 gamepass server code** (VIP perks, 2× Gems, Auto-Revive, Necromancer class)
- **49-Robux Emergency Save dev product** + prompt UI
- **15 launch badges** (server-side BadgeService:AwardBadge wiring)
- **Group reward code** (GroupService check + 500 coins + cape)
- **Gem icon swap** (replace "G" text with image asset)

These are tracked in tasks #2-7. Surface them next time you open Studio.

Things that require your Roblox account auth / Robux balance:

- **Creating 15 badges on Roblox** (100 Robux each = 1,500 Robux)
- **Buying 5 Creator Store sound effects** (~250 Robux)
- **Publishing 4 gamepasses + setting Robux prices** (Creator Hub web flow)
- **Setting up Robux payouts to your DevEx-enabled account** (one-time, web only)

---

## 🎯 Success Metrics for This Kit

| Asset | What "Success" Looks Like |
|-------|----------------------------|
| Icon | Organic CTR (impressions→plays) > 5% after 14 days |
| Title + Description | Game appears in "Tower Defense" search results within 7 days |
| 8 thumbnails | Average game-page bounce rate <40% (per Creator Hub analytics) |
| TikTok 30-day calendar | At least 3 videos cross 10k views in the first 30 days |
| Discord | 100 members by end of Week 1, 500 by Week 6 |
| Creator outreach (5 sends) | 1-2 replies, 0-1 video coverage |
| Creator outreach (30 sends) | 2-5 replies, 1-3 video coverage |
| Sponsored ads ($35) | CTR > 1.5%, CPC < $0.30 |

Track these in a simple spreadsheet. Re-evaluate at end of Week 2 and end of Week 4.

---

## 🔄 Refresh Cadence

This kit is a starting point, not a permanent fixture. Refresh:

- **Icon:** every 6-8 weeks (regenerate if CTR drops). Already have Variants B + C as backups.
- **Thumbnails:** when you add new major features (new boss, new map, new class)
- **Title:** at major version milestones ("⚔️ Crystal Siege: NEW MAP — Tower Defense ⚔️")
- **Description:** every Friday with the update (include the new code)
- **TikTok calendar:** at end of 30 days — rebuild based on what worked
- **Creator outreach list:** every 2 weeks — top creators in this niche rotate fast
- **Ad creative:** weekly check, refresh creative at end of Week 4

---

## 💸 Total Spend To Execute This Kit

| Item | Cost | Notes |
|------|-----:|-------|
| Icon + thumbnails + Discord art (Gemini gen) | ~$0.40 | Already paid — done |
| Creator outreach Robux rewards | 15,000 Robux (~$60) | 5 creators × 500 Robux × 6 batches |
| 15 launch badges | 1,500 Robux (~$6) | One-time upload fee |
| 5 sound effects | 250 Robux (~$1) | One-time purchase |
| Sponsored Experience ads | $35-1,500 | Week 1: $35. Cap: $1,500 across 12 weeks |
| Discord server setup | $0 | Free tier is enough |
| TikTok account setup | $0 | Free |

**Total to start (Week 1):** ~$40 in Robux + $35 in ads = **~$75**.

**Total over 12 weeks:** ~$300 in Robux + $1,500 in ads = **~$1,800**.

Target revenue: $500/month net by Week 12 = **$6,000/year run-rate**.

ROI math: $1,800 spent → $6,000/year → ~3.3× return in year 1, scaling thereafter.

---

## ❓ FAQ

**Q: Can I change the icon to Variant B or C if I don't like A?**
A: Yes. Both backups are at `marketing/icon-variants/`. Update the file path in `ads/creative-spec.md` if you do.

**Q: The thumbnails look generic. Can I make them more game-specific?**
A: Yes — once the FTUE is rewritten and the game has real screenshots, swap the AI-generated thumbnails for actual gameplay captures. Use F12 in Roblox to hide UI for clean shots.

**Q: I don't want to do creator outreach.**
A: Then skip that section. The icon + thumbnails + Discord + TikTok cover ~80% of the leverage. Creator outreach is the long-tail discovery channel.

**Q: Can you run the TikTok account for me?**
A: I can draft the videos + write the captions + suggest the audio. You have to record gameplay + actually post (TikTok requires phone access + 2FA on your account).

**Q: What if a thumbnail violates Roblox content policy?**
A: Replace it with one of the others. The 8 are independent. None should violate policy (no real faces of minors, no scary imagery, no swearing) but Roblox moderation is inconsistent.

**Q: When should I refresh this kit?**
A: First major checkpoint: end of Week 4. If CTR + retention + CCU are on track, keep going. If not, regenerate underperforming assets.

---

## 📞 If You Need Help

- **Code/Studio work:** Open Roblox Studio + ping me. I'll work through tasks #2-7 (FTUE, gamepasses, badges, etc).
- **Marketing strategy questions:** Ask me. I'll reference the doc + your data.
- **Roblox moderation rejection of any asset:** Send me the rejection message + I'll regenerate.
- **Sponsored Experience setup:** I can walk you through the Creator Hub UI step-by-step if you screenshot what you're seeing.

---

🔮 **Now go defend that crystal.**
