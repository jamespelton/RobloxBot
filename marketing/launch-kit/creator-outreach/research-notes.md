# Crystal Siege Creator Outreach — Research Notes

**Date:** 2026-05-12
**Time budget:** 15 minutes
**Researcher:** Rex (Roblox bot)

## Summary

Built a 30-row target list at `targets.csv`. Of those, **18 rows have verified channel data** (handle + sub count + niche). **12 rows are named leads from TDS community lists where the channel handle could not be verified in the time budget** — flagged with `UNKNOWN` and queued for manual lookup before send.

Quality > quantity. The 18 verified rows are the priority queue.

## Total candidates evaluated

~40 channel names surfaced across search results. Filtered down to 30 in CSV based on:
- Niche fit (TD > Co-op/Survival > Variety > Stretch)
- Sub range (10K–100K target; flagged 8 outside range with notes)
- Public contact path (email > YouTube DM > unknown)

## Methodology

1. WebSearch broad: "small roblox youtubers tower defense", "best roblox tower defense creators"
2. WebSearch named-entity drill: Once a name surfaced (e.g. JustADuckie, Photon, iamEvan), searched for "{name} subscribers email business"
3. WebFetch to vidIQ youtube-stats pages — **this was the breakthrough source**. vidIQ pages render verified subscriber counts, video counts, country, and last-upload signals server-side. socialblade and youtube.com /about pages both 403'd or returned empty HTML.
4. WebFetch to iqfluence.io's "Top 16 Small Roblox YouTubers" — returned 15 channels with sub counts and engagement rates, but URLs/contacts paywalled.

## Search terms that worked best

- `"{creator name}" Roblox YouTube subscribers email` — drilled into individual channel data
- `"Tower Defense Simulator" YouTubers list {names}` — surfaced community-known TDS creators (Photon, JustHarrison, Sambeans, Pighead, Cypher, MenacingX1, Puri)
- `Roblox tower defense YouTuber "business inquiries"` — directly surfaced public business emails (Photon: odinarymailofkyle@gmail.com, iamEvan: iamevanrb@gmail.com, JoJewyd: jojewyd@gmail.com)

## Search terms that wasted time

- Generic queries like `"small Roblox YouTubers"` returned listicles dominated by 1M+ subscriber channels (KreekCraft, Flamingo, Thinknoodles) — useless for our tier.
- Game-name queries (`"Anime Defenders" review`) returned videos but not creator names extracted.
- TierMaker and feedspot links are paywalled or contain mostly mega-tier creators.

## Patterns noticed

1. **Tower Defense YouTubers cluster at 100K-250K**, not 10K-100K. The genre attracts long-tenured channels (JustHarrison 139K/7yrs, Photon 234K, iamEvan 140K, Roblox Minigunner 133K/10yrs). Pure-TD channels below 100K are rare — JustADuckie at 34K is the standout.
2. **The 10K-50K Roblox tier is dominated by VARIETY creators**, not TD specialists. iQfluence's small-channel list confirms this: 15 channels in 4K–32K range, all variety/kid-friendly (Junidrawz, AmberRains, KoKo Panda, NutMeg, etc.).
3. **Public business emails are rare** — only ~3 of 30 had visible email. Most outreach will be YouTube DM or hunting About-tab manually.
4. **Engagement rate matters more than sub count at this size.** NutMeg at 15K has 18.91% engagement; that beats a 100K channel at 2%. The high-engagement small channels in iQfluence's list (NutMeg 18.91%, KoKo Panda 18.1%, Morri7_ 12.13%, AmberRains 12.9%) are the best ROI per 500 Robux.
5. **Estimated monthly earnings $50-$200/mo** on most mid-tier TD channels (per vidIQ). 500 Robux ≈ $5-7 cash equivalent — this is meaningful to a $59/mo creator but laughable to a $5K/mo creator. Confirms target tier is correct.
6. **Brand-safety flag:** Some "Ducky"-named channels overlap with Roblox drama/commentary culture (e.g., directedbyducky). Filter on actual gameplay content vs. drama before sending.
7. **Elite (@EliteElite) explicitly states "not accepting sponsorships"** in About — saves a wasted email. Worth checking each target's About statement before pitch.

## Recommended outreach strategy

1. **Tier 1 (send first):** JustADuckie, iamEvan, Photon — verified channels, public emails or DM-reachable, perfect niche fit. 3 sends.
2. **Tier 2 (send next):** JustHarrison, JuniDrawz, AmberRains, KoKo Panda, NutMeg, RetroDan — verified handles in 15K-140K range, strong engagement. 6 sends.
3. **Tier 3 (manual lookup needed):** Sambeans, Pighead, Cypher, MenacingX1, Puri, Sister Guard, Mikon Cur-Desu, Engraved Gaming — TDS community names with no verifiable channel handle from public search. Need 15 min of manual YouTube search to confirm channels + sub counts before pitch.

**Pitch positioning:** Lead with "I'm a 12yo + dad indie dev team launching a TD/co-op on Roblox — 500 Robux + custom in-game tag + personalized promo code if you cover it." The dad/kid angle + custom in-game tag is a stronger hook for small creators than the Robux alone.

## Files produced

- `/Users/jamespelton/Apps/React/RobloxBot/marketing/launch-kit/creator-outreach/targets.csv` — 30 rows, 18 verified
- `/Users/jamespelton/Apps/React/RobloxBot/marketing/launch-kit/creator-outreach/research-notes.md` — this file
