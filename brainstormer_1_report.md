# Report: Crystal Siege — 12-Week Roadmap to Players + $500/Month Revenue

## Executive Summary

The fastest path to $500/mo for a single-developer Roblox wave-survival game is **not** more features — it's **icon/thumbnail CTR + D1 retention + a focused 4-SKU monetization stack** (one premium gamepass, one consumable currency bundle, one cosmetic gamepass, one "2x" doubler), then feeding the algorithm via small daily Sponsored Experience spend until organic discovery takes over. Realistically, $500/mo net (~$715 gross before Roblox's 30% marketplace fee, ~204,000 Robux gross sold) requires sustained ~150–300 CCU at an ARPDAU of $0.02–0.05 — achievable but tight, and the single biggest lever is the icon, not the gameplay. ([Roblox marketplace fees](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions), [BLOXG ad benchmarks](https://bloxg.com/statistics/roblox-advertising-benchmarks))

### The Math to $500/mo (memorize this)

- **DevEx rate**: $0.0035 per earned Robux (standard), $0.0038 for post-Sept-2025 Robux, with a +42% bump for verified 18+ US players starting June 2026. ([Roblox DevEx help](https://en.help.roblox.com/hc/en-us/articles/27984458742676-Earned-Robux-Earned-Robux-Wallet-and-DevEx-Rates), [Roblox newsroom](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42))
- **Marketplace fee**: Roblox takes 30% of every gamepass/dev-product sale. So 1,000 Robux gross sold = 700 Robux earned = ~$2.45 net. ([Roblox marketplace fees](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions))
- **$500/mo target** = ~143,000 earned Robux = **~204,000 gross Robux sold/month** = ~6,800 Robux/day.
- At $0.03 ARPDAU, you need **~545 DAU sustained**. At $0.05 ARPDAU (well-tuned), **~330 DAU**. At $0.02 ARPDAU (typical small game), **~820 DAU**. ([Roblox ARPDAU thread](https://devforum.roblox.com/t/is-it-possible-to-get-very-high-arpdaus/2950843))
- DAU ≈ 3–5× CCU for casual games, so target sustained **~100–250 CCU**.

---

## Phase 1: Pre-Launch Polish (Weeks 1–2) — MUST-HAVES

### 1.1 Icon (highest ROI item in the entire roadmap)

A great Roblox icon can 3–10x your CTR on the same impressions, which directly multiplies algorithm pickup. ([BLOXG thumbnails](https://bloxg.com/marketplace/services/thumbnails), [Simplified guide](https://simplified.com/blog/ai-design/proven-techniques-for-roblox-thumbnail-design))

- 512×512, single bold focal point, high saturation, **face-forward character** (Roblox kids respond to face/eyes), large readable shape silhouette at thumbnail size.
- Test 3 variants: (a) hero character holding sword in front of crystal, (b) crystal exploding with enemies silhouetted, (c) "DEFEND THE CRYSTAL!" text + character. Run Sponsored Experiences A/B for 48h each — keep the winner.
- Avoid: small details, dark backgrounds, generic Roblox avatars. Reference top-charting icons in Tower Defense / Survival categories weekly.

### 1.2 Thumbnails (8 slots — use all of them)

1. Action shot of boss fight w/ "WAVE 10 BOSS" overlay
2. All 6 classes lined up with names
3. Building system mid-build (turrets, walls, cannons)
4. Loot chest opening with "RARE LOOT" text
5. Crystal upgrade visual progression
6. Co-op group fighting wave
7. Weather effects (rainy/snowy)
8. "NEW CODE: CRYSTALSIEGE" promo

### 1.3 Title & Description

- Rename to keyword-stack: **"⚔️ Crystal Siege: Tower Defense Survival ⚔️"** (algorithm reads title heavily for discovery, and "Tower Defense" is a high-volume category).
- First two lines of description are gold (shown in collapsed view): "Defend your crystal from endless waves! 6 classes, 30+ buildings, boss raids. CODE: CRYSTALSIEGE for free coins!"
- Include a **Discord/Group join CTA** in description — converts players into a re-engageable audience.

### 1.4 FTUE / Tutorial (D1 retention is THE algorithm signal)

Roblox's discovery system massively rewards D1 retention >25% — this is the #1 thing the algorithm watches. ([BLOXG algo guide](https://bloxg.com/guides/roblox-game-discovery-algorithm))

- **First 60 seconds** must hit: spawn → forced class pick (auto-pick after 5s) → arrow pointing to portal → wave 1 starts → first kill within 30s.
- **Skippable tutorial** (3 popups max): movement, click to attack, press B to build.
- **First-time player gift**: 500 free coins + 1 free common loot chest at first spawn — players who get a "win" feeling in the first session retain 2x better.
- **Wave 1 must be winnable solo in <2 minutes** — your current scaling probably needs to be checked here.

### 1.5 Retention Hooks (ship before launch)

- **Daily login streak rewards** (you have DataManager — extend to 7-day streak with escalating coins/gems, day 7 = 1 free gamepass-tier item).
- **Daily quest** (kill 50 enemies, build 5 turrets, complete wave 5) → 100 gems.
- **Push notifications**: enable Roblox notifications opt-in prompt on the loading screen.
- **Group join reward**: 500 coins + exclusive cape for joining the Roblox group (also boosts your group size = social proof).
- **Trail of breadcrumbs**: every wave cleared shows "Next unlock at wave X" — keep a goal always visible.

### 1.6 Polish quick-wins specific to your build

- Replace "G" gem icon with proper image asset (already on your wishlist — do it now, gem currency UX matters for store conversion).
- Sound polish: your CLAUDE.md notes only 10 working rbxasset sounds. Buy 5–10 paid Creator Store SFX (~50 Robux each) for: button click, gem purchase, gamepass purchase, level up, boss death. Quality audio = perceived quality = retention.
- Add a "Pets" stub system (even if just one free pet on day-1 daily reward) — Roblox players are conditioned to expect pets; signals depth.

---

## Phase 2: Monetization Design — The 4-SKU Stack

Don't build 20 SKUs. Build 4 great ones that cover the four player archetypes (whale/dolphin/minnow/social-flexer), all priced at proven Robux psychological points. ([Tower Defense Sim gamepasses reference](https://tds.fandom.com/wiki/Gamepasses))

### Permanent Gamepasses

| SKU | Robux | Net to you | Why it converts |
|-----|-------|------------|-----------------|
| **VIP / "Crystal Champion"** | 499 | ~$1.22 | Trail, tag, +25% coins, exclusive cape, 2 extra build slots. Bread & butter — 60–70% of revenue for most small Roblox games. |
| **2x Coins (permanent)** | 299 | ~$0.73 | Doublers convert at the highest rate of any SKU type — every player who plays >2 sessions feels the pain of "should have bought this." |
| **Auto-Revive** | 199 | ~$0.49 | Removes a friction point you already built (Revive system). Cheap impulse buy. |
| **Skip Wave** (gamepass that unlocks ability, costs gems per use) | 399 | ~$0.97 | For frustrated players — converts the "I keep dying on wave 7" moment. |

### Developer Products (consumable — repeatable purchases = whale revenue)

| SKU | Robux | Why |
|-----|-------|-----|
| **80 Gems** | 80 | Entry impulse |
| **400 Gems + 50 bonus** | 400 | Best-value sticker |
| **1,000 Gems + 200 bonus** | 1,000 | Whale tier |
| **Mega Loot Chest** (guaranteed legendary) | 250 | Loot box dopamine |

### Currency design (critical)

Your **gem store must contain at least 3 things only buyable with gems** that players *feel* they need: (1) extra building slots, (2) class unlocks, (3) cosmetic skins. If gems only buy convenience, conversion is poor. If gems gate aspirational items, conversion 2–3x higher.

### Realistic conversion math

- **Paying-user rate** for casual Roblox games: 1.5–4% of DAU. ([GameAnalytics 2025 Roblox Report](https://www.gameanalytics.com/reports/2025-roblox-report))
- Average paying player spends ~150–400 Robux/month.
- At 400 DAU × 2.5% paying = 10 paying/day × ~250 Robux avg = 2,500 Robux/day gross = 75,000 Robux/month gross = ~$184/mo. **That's still short of $500.**
- Hitting $500/mo therefore requires either: (a) DAU ~600+, OR (b) ARPDAU pushed to $0.05+ via the "2x Coins" + "Mega Loot Chest" combo.

---

## Phase 3: Distribution & Growth

### 3.1 Roblox algorithm levers (free)

The algorithm cares, in rough order: **D1 retention, session length, like ratio, social plays (friends inviting friends), CCU stability**. ([Roblox discovery docs](https://create.roblox.com/docs/discovery), [BLOXG algo](https://bloxg.com/guides/roblox-game-discovery-algorithm))

- **Like ratio target: >85%**. Below 70% you are buried. Add a "Rate the game!" prompt after wave 5 clear (peak emotional moment).
- **Co-op multiplier**: your game is co-op — exploit it. Add a **"Bring a friend = both get 500 gems"** referral, tracked by joining same server.
- **Update cadence**: ship a visible update every Friday for the first 12 weeks. Roblox boosts "Updated this week" in some surfaces, and players check the update log.
- **Badges**: ship 15–20 badges at launch. Badge-hunters drive a surprising amount of long-tail traffic via badge-collection communities.

### 3.2 Sponsored Experiences (paid)

Current benchmark ~$0.25 CPC for Sponsored Experiences. ([BLOXG ad benchmarks](https://bloxg.com/statistics/roblox-advertising-benchmarks))

- **Week 1–2**: $5/day to test 3 icon variants (24h each, then 48h winner). Total ~$70.
- **Week 3–8 launch push**: $15–25/day Sponsored Experiences targeting 9–13 male, US/UK/CA. Total ~$700–1,200.
- **Stop spending** if CPC × (visit→D1 retained ratio) > $1.50 LTV — you're losing money.
- **Launch budget cap: $1,500 over 12 weeks.** If you can't hit organic momentum on that, the game needs work, not more ads.

### 3.3 Creator outreach

- Identify 30 small Roblox YouTubers (10k–100k subs) who cover Tower Defense / Survival. Offer them: (a) 500 free Robux + (b) custom in-game tag + (c) early access to next update in exchange for a video. Conversion: ~5–10% reply rate, ~1–2 videos for every 10 reached.
- TikTok is now the dominant Roblox discovery channel for kids 9–13. Post 1 short/day for 30 days yourself: epic boss kills, base-build timelapses, "you won't believe what wave 50 looks like." Use trending audio. ([BLOXG launch playbook](https://bloxg.com/guides/roblox-game-launch-strategy))

### 3.4 Codes as a viral/retention loop

You already have CodeManager. Use it weaponized:
- New code every Friday with the update.
- Post code on Discord, Roblox group wall, and TikTok video description — forces players into your owned channels.
- Codes give gems (not coins) — gem inflation is fine because gems gate cosmetics, not power.

### 3.5 Roblox group

- Hit 500 group members ASAP (group-only rewards push this). Group members get push notifications about new updates → instant boost to CCU on update day → algorithm sees spike → more discovery.

---

## Phase 4: 12-Week Milestones & KPIs

| Week | Focus | KPI Targets | Cumulative spend |
|------|-------|-------------|------------------|
| **1** | Icon A/B test, FTUE rewrite, 4 SKUs live, 15 badges | D1 ≥ 20%, Like ratio ≥ 75%, CCU 5–15 | $35 ad |
| **2** | Daily login streak, daily quests, group rewards | D1 ≥ 25%, Like ratio ≥ 80%, CCU 10–25 | $70 ad |
| **3** | First Friday update + new code + TikTok push | CCU 30–60, ARPDAU ≥ $0.01 | $175 |
| **4** | Sponsored Experience push begins ($20/day) | CCU 50–100, paying % ≥ 1.5% | $315 |
| **5** | Creator outreach round 1 (15 YouTubers) | CCU 75–150, D1 ≥ 28% | $455 |
| **6** | Pets system stub + new gamepass (Pet Slot) | CCU 100–200, ARPDAU ≥ $0.02 | $595 |
| **7** | First major content drop (new boss, new map area) | CCU 150–250, D7 retention ≥ 8% | $735 |
| **8** | Creator outreach round 2 + TikTok daily | CCU 200–300, paying % ≥ 2% | $875 |
| **9** | Limited-time event (holiday-themed wave) | CCU 250–400, ARPDAU ≥ $0.03 | $1,015 |
| **10** | Battle pass / season system (if data supports it) | CCU 300–450, ARPDAU ≥ $0.04 | $1,155 |
| **11** | Reduce ad spend, lean on organic | CCU 300–500, **revenue ≥ $300/mo run rate** | $1,225 |
| **12** | Polish + retention tuning | CCU 350–600, **revenue ≥ $500/mo run rate** | $1,295 |

### KPI definitions & gut-checks

- **D1 retention**: % of new players who return next day. <20% = product problem, fix gameplay before spending more on ads.
- **Like ratio**: visible % thumbs-up. <75% = something is actively annoying players (bugs, paywalls, difficulty spike). Read negative comments daily.
- **ARPDAU**: gross Robux/day ÷ DAU × $0.0035. $0.01 = poor, $0.03 = healthy small game, $0.05+ = well-tuned.
- **Paying %**: paying users / DAU. 1% = poor, 2.5% = healthy, 4%+ = great.
- **CCU stability**: peak CCU shouldn't crash >50% on weekdays — stability is what the algo rewards.

### The math, restated explicitly

To hit **$500/mo net**:
- Need ~204,000 gross Robux/month sold = ~6,800/day
- At realistic ARPDAU $0.03 (= ~8.5 Robux gross/DAU/day): **need ~800 DAU**
- DAU ≈ 4× CCU → **need sustained ~200 CCU**
- 200 CCU is achievable for a polished niche game with ~$1,200 of well-targeted ad spend + organic discovery, but **only if D1 ≥ 25%**. Without that retention, ad spend is wasted.

---

## Phase 5: Risks & What to Cut

### Top risks

1. **D1 retention <20% kills everything.** No amount of ad spend rescues it. If after week 2 D1 is still low, halt all ad spend and rebuild FTUE + wave 1–3 difficulty.
2. **Algorithm ignores you regardless.** Roblox surfaces are increasingly winner-take-all — top 1000 games eat ~80% of plays. Mitigation: lean into a narrow niche ("co-op tower defense survival with classes") rather than competing head-on with Tower Defense Simulator.
3. **Like ratio drops below 70%.** Often caused by a single annoying mechanic (unwinnable wave, broken gamepass, lag). Watch comments daily.
4. **Performance / lag at higher CCU.** You have 12 server scripts and a building system — stress-test with 20-bot load before promoting heavily.
5. **Burnout / update-cadence collapse.** Solo devs typically miss week 6–8. Pre-build 3 weeks of content drops in weeks 1–2 to give yourself runway.
6. **Sound asset risk** (your CLAUDE.md flags only 10 working sounds). Spend 500 Robux on Creator Store audio in week 1.
7. **DataStore corruption / lost progress.** Add daily backup snapshot of top-100 players. One viral "this game lost my progress" TikTok kills you.
8. **COPPA / chat moderation.** Don't add chat-based features that could trip moderation.

### What to cut from your wishlist (ruthlessly)

Defer until **after** $500/mo is hit:
- AI-generated images for enemies/icons/turrets (nice-to-have, doesn't move retention)
- More classes purchasable in lobby (you have 6 — that's enough; build depth in existing ones first)
- Red path showing enemy approach (UX nice but low ROI)
- Crystal upgrades + crystal shooting (could be your week 7 content drop, not pre-launch)
- Leaderboard wall (adds vanity but no monetization lift)

Keep on the critical path:
- Loot boxes after boss + fix loot box visuals (loot loop = retention + monetization)
- Coins/lootboxes from sky after milestones (dopamine hit = D1 retention)
- Gem icon (replaces "G" — small but signals polish during purchase)

### Creative / unconventional ideas (worth considering)

- **"Pay-what-you-want" tip jar gamepass at 50/200/500/1000 Robux**, reward = colored name. Surprising % of dedicated fans buy these to support; near-zero work to ship. *(Speculative — works in some games, not others.)*
- **"Ironman" hardcore mode gamepass** (one life per round, exclusive leaderboard). Your existing systems already support it. Niche but high-conversion among engaged players. *(Speculative.)*
- **Twitch/YouTube integration** — a "streamer mode" toggle and !join command for Roblox creators. Removes friction for creators wanting to feature you. *(Speculative.)*
- **Constraint inversion**: don't try to be a TDS killer. Be the **co-op** wave-survival game with **deep classes** — niche down hard in title and description.
- **18+ DevEx arbitrage** (June 2026+): if you can craft an 18+ verified version of Crystal Siege (slightly more violent, no chat filter), you earn 42% more per Robux from 18+ US players. Most kid-game devs ignore this — large untapped pool. ([Roblox 18+ DevEx](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42))
- **"Reverse paywall"**: give away the VIP gamepass free to anyone who plays 10 sessions. Loss-leader to push retention; recoup via consumable Mega Loot Chests. *(Speculative — risky, but Adopt Me used similar generosity.)*

---

## Recommendation

**Do this, in this order, and don't deviate:**

1. **Weeks 1–2**: Polish only. Icon, FTUE, 4-SKU stack, daily streak, 15 badges. No ad spend beyond icon A/B testing.
2. **Week 3**: Soft launch — Discord, friends, small TikTok push. Confirm D1 ≥ 25% before spending real ad money.
3. **Weeks 4–8**: Sponsored Experience at $20/day + weekly Friday content drops + creator outreach. Watch like ratio and D1 daily.
4. **Weeks 9–12**: Lean into whatever is working. If ARPDAU is high, double down on monetization tuning. If retention is high but ARPDAU low, add the battle pass / 2x events. If neither, the product needs more work — don't burn ad money.

**Honest expectation**: $500/mo by week 12 is achievable but **not guaranteed** for a solo-dev Roblox game. ~70% of polished niche games hit $50–200/mo; ~20% hit $500+; ~10% become breakouts. The single biggest predictor between these tiers is **icon CTR + D1 retention**, not gameplay depth — and Crystal Siege already has more depth than most. **Spend the next 2 weeks on the icon and the first 60 seconds of play, not on more features.**

---

## Sources

1. [Roblox Marketplace Fees](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions) — 30% cut on gamepass/dev product sales
2. [Roblox DevEx Help](https://en.help.roblox.com/hc/en-us/articles/27984458742676-Earned-Robux-Earned-Robux-Wallet-and-DevEx-Rates) — current $0.0035 / $0.0038 per earned Robux rates
3. [Roblox 18+ DevEx Bump](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42) — +42% for 18+ verified US players
4. [BLOXG Roblox Advertising Benchmarks 2026](https://bloxg.com/statistics/roblox-advertising-benchmarks) — ~$0.25 CPC Sponsored Experiences
5. [BLOXG Discovery Algorithm Guide](https://bloxg.com/guides/roblox-game-discovery-algorithm) — D1 retention is dominant signal; >25% target
6. [BLOXG Launch Playbook](https://bloxg.com/guides/roblox-game-launch-strategy) — 8-week launch structure
7. [Roblox Discovery Docs](https://create.roblox.com/docs/discovery) — official two-stage retrieval/ranking system
8. [GameAnalytics 2025 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2025-roblox-report) — paying user / ARPDAU benchmarks
9. [Roblox ARPDAU Forum Thread](https://devforum.roblox.com/t/is-it-possible-to-get-very-high-arpdaus/2950843) — real-dev ARPDAU ranges
10. [Tower Defense Simulator Gamepasses](https://tds.fandom.com/wiki/Gamepasses) — reference pricing for the genre
11. [Roblox Icon Best Practices](https://create.roblox.com/docs/production/publishing/experience-icons) — official icon guidelines
12. [Simplified Thumbnail Techniques](https://simplified.com/blog/ai-design/proven-techniques-for-roblox-thumbnail-design) — CTR-driving thumbnail design
13. [Roblox Gamepass Calculator](https://profitable.app/tools/roblox-gamepass-calculator) — net Robux per sale math
