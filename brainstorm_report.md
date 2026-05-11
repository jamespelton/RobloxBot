# Crystal Siege — 12-Week Roadmap to $500/Month

## Executive Summary

The fastest path to **$500/month net** for a solo-dev Roblox wave-survival game is **not** more features — it's **icon/thumbnail CTR + Day-1 retention + a focused, well-priced SKU stack**, then feeding the Roblox algorithm via Friday updates, TikTok shorts, and small Sponsored Experiences spend until organic discovery takes over. The single highest-ROI item in the entire roadmap is the icon. The single biggest killer is Day-1 retention below 20%.

### The math (memorize it)

- Roblox DevEx rate: **$0.0038 per earned Robux** (post-Sept-2025).
- Roblox marketplace fee: **30%** of every gamepass / dev-product sale.
- **$500/mo net** ≈ ~131,500 earned Robux ≈ **~188,000 gross Robux/month spent by players** ≈ ~6,300 Robux/day.
- At a healthy ARPDAU of $0.03 you need **~550 DAU** sustained. At $0.05 (well-tuned), ~330 DAU. At $0.02 (typical), ~830 DAU.
- DAU ≈ 3–5× CCU for casual co-op games → target **sustained ~100–250 CCU**.
- Paying-user rate for casual Roblox games is **1.5–4% of DAU**, average ~150–400 Robux/payer/month.

> Plain-English implication: $500/mo is a polished-niche-game number, not a hobby number. Achievable in 12 weeks, but only if D1 retention ≥ 25% and you ship a Friday update every week.

---

## Phase 1 — Pre-Launch Polish (Weeks 1–3)

Retention before acquisition. Roblox's discovery algorithm rewards D1 retention, session length, like ratio, and CCU stability above almost everything else.

### 1.1 Icon (highest-ROI item, period)

A great icon can 3–10× CTR on identical impressions, which directly multiplies algorithm pickup.

- 512×512, single bold focal point, high saturation, **face-forward character**.
- Test 3 variants in Sponsored Experiences ($5/day, 24–48h each):
  1. Hero with sword + glowing crystal behind
  2. Crystal exploding with enemy silhouettes attacking
  3. "DEFEND THE CRYSTAL!" text overlay + character
- Keep the winner. Re-test every 6–8 weeks.

### 1.2 Thumbnails — use all 8 slots

1. Boss fight w/ "WAVE 10 BOSS" overlay
2. All 6 classes lined up with names
3. Building system mid-build (turrets, walls, cannons)
4. Loot chest opening with "RARE LOOT"
5. Crystal upgrade visual progression
6. Co-op group fighting a wave together
7. Weather effects (rainy / snowy)
8. "NEW CODE: CRYSTALSIEGE" promo card

### 1.3 Title & description

- Rename to a keyword-stacked title: **"⚔️ Crystal Siege: Tower Defense Survival ⚔️"** — the algorithm reads titles heavily and "Tower Defense" is a high-volume search term.
- First two lines of the description (shown collapsed) should hit value + CTA: *"Defend your crystal from endless waves! 6 classes, 30+ buildings, boss raids. CODE: CRYSTALSIEGE for free gems!"*
- Include Discord/Group join CTAs in the description.

### 1.4 First-Time User Experience (FTUE)

The first 60 seconds is everything. D1 retention is THE algorithm signal.

- Spawn → forced class pick (auto-pick after 5s if idle) → arrow pointing to portal → wave 1 starts → first kill within 30 seconds.
- Skippable 3-popup tutorial: movement, click to attack, press B to build.
- **First-time gift**: 500 free coins + 1 free Common loot chest at first spawn. Players who feel a "win" in session 1 retain ~2× better.
- **Wave 1 must be winnable solo in <2 minutes.** Audit current scaling.
- Add the "red path showing enemy approach direction" (from wishlist) — builds anticipation and clarity.

### 1.5 Retention hooks (ship before launch)

- **7-day login streak rewards** (extend existing DataManager). Day 7 = a gamepass-tier item (e.g., exclusive cape).
- **Daily quests**: kill 50 enemies, build 5 turrets, complete wave 5 → 100 gems.
- **Group join reward**: 500 coins + exclusive cape for joining the Roblox group (also pumps group size = social proof + push notification audience).
- **"Bring a friend = both get 500 gems"** referral, tracked by joining the same server.
- "Next unlock at wave X" trail-of-breadcrumbs banner on every wave-clear screen — keep a goal always visible.

### 1.6 Polish quick-wins from your existing wishlist

- Replace the "G" gem text with a proper gem icon (matters during purchase moments).
- Buy 5–10 paid Creator Store SFX (~50 Robux each) for: button click, gem purchase, gamepass purchase, level up, boss death. Quality audio = perceived quality = retention.
- Add screen shake + intense lighting on boss spawns.
- Implement the **Leaderboard wall** (BestWave SurfaceGui) — gives endless-mode grinders a reason to come back.
- Add a "Pets" stub (even just one free pet on a daily reward) — Roblox players are conditioned to expect pets; signals depth.

---

## Phase 2 — Monetization Design

Don't build 20 SKUs. Ship a focused stack that covers the four payer archetypes (whale / dolphin / minnow / social-flexer), priced at proven Robux psychological points.

### Permanent gamepasses

| SKU | Robux | Why it converts |
|-----|------:|-----------------|
| **VIP / "Crystal Champion"** | 499 | Trail, chat tag, +25% coins, 1.5× XP, exclusive cape, 2 extra build slots. Bread & butter — typically 50–60% of small-game revenue. |
| **2× Gems (permanent)** | 299 | Doublers convert at the highest rate of any SKU type. Every player who plays >2 sessions feels the pain of "should have bought this." |
| **Auto-Revive** | 199 | Removes friction from a system you already built. Cheap impulse buy. |
| **Premium Class** (Necromancer / Mech-Pilot) | 399 | Identity + flex. Visually distinctive, balanced — never strictly more powerful than free classes. |

### Developer products (consumables — repeatable = whale revenue)

| SKU | Robux |
|-----|------:|
| 80 Gems (entry impulse) | 80 |
| 400 Gems + 50 bonus (best-value sticker) | 400 |
| 1,000 Gems + 200 bonus (whale tier) | 1,000 |
| Mega Loot Chest (guaranteed Legendary) | 250 |
| **Loss-aversion "Emergency Save"** — prompted only when crystal HP <10% on wave ≥15: revive crystal to 50% + stun all enemies | 49 |

The loss-aversion 49-Robux save is one of the highest-ROI SKUs in survival genres — players hate losing a 30-minute run far more than they hate spending 49 Robux. Cap it at one per round to keep it ethical and not pay-to-win.

### Currency / gem design (critical)

Your gem store **must** contain at least three things only buyable with gems that players *feel* they need:

1. Extra building slots
2. Class unlocks
3. Cosmetic skins / trails

If gems only buy convenience, conversion is poor. If gems gate aspirational identity items, conversion is 2–3× higher. Never gate raw combat power behind premium currency.

### Conversion math sanity-check

- Healthy small-game scenario: 400 DAU × 2.5% paying × 250 Robux avg/payer = 2,500 Robux/day gross = ~75,000 Robux/month gross ≈ **~$200/mo net**. Short of $500.
- $500/mo target requires either **DAU ~600+** OR **ARPDAU pushed to $0.05+** via the doubler + loss-aversion + Mega Chest combo.
- Implication: don't just chase DAU — also tune ARPDAU. Both levers compound.

---

## Phase 3 — Distribution & Growth

### 3.1 Roblox algorithm levers (free, highest leverage)

In rough priority order: D1 retention > session length > like ratio > social plays (friends inviting friends) > CCU stability.

- **Like ratio target ≥ 85%.** Below 70% you are buried. Add a "Rate the game!" prompt after wave 5 clear (peak emotional moment).
- **Update cadence: every Friday for 12 weeks straight.** Roblox surfaces "Updated this week" and players check the update log. Pre-build 3 weeks of content drops in weeks 1–2 to give yourself runway against burnout.
- **Badges**: ship 15–20 at launch. Badge-collection communities drive surprising long-tail traffic. Badge for: first kill, wave 5, wave 10, wave 25, wave 50, all classes, fully upgraded base, 100 enemies, etc.
- **Co-op multiplier**: your game is co-op — exploit it with the referral reward (1.4 above).
- **Codes as a viral retention loop**: ship a new code every Friday with the update; post it on Discord, Roblox group wall, and TikTok video descriptions. Codes give gems (not coins) — gem inflation is fine because gems gate cosmetics, not power.

### 3.2 Sponsored Experiences (paid)

Current benchmark CPC ~$0.25 for Sponsored Experiences.

- **Weeks 1–2**: $5/day icon A/B testing. Total ~$70.
- **Weeks 4–8 launch push**: $15–25/day targeting 9–13, US/UK/CA. Total ~$700–1,200.
- **Stop spending** if (CPC × visit→D1-retained ratio) > $1.50 LTV — you're losing money.
- **Hard launch budget cap: $1,500 across the 12 weeks.** If $1,500 doesn't ignite organic momentum, the game needs more retention work, not more ads.

### 3.3 Short-form video (highest-leverage organic channel)

TikTok and YouTube Shorts are now the dominant Roblox discovery channels for kids 9–13.

- Post **1 short/day for 30 days** yourself. Use trending audio. Hooks: epic boss kills, base-build timelapses, "you won't believe what wave 50 looks like," wave-49 clutch saves.
- Crystal Siege's visuals (hot-pink crystal, lightning, weather, boss cinematics) are tailor-made for short-form. Lean into them.
- Always end with a Roblox-game CTA card.

### 3.4 Creator outreach

- Identify 30 small Roblox YouTubers (10k–100k subs) covering Tower Defense / Survival.
- Offer: 500 Robux + custom in-game tag + early access to next update + a personalized promo code (`CODE: [CreatorName]` rewards gems).
- Realistic: ~5–10% reply rate, ~1–2 videos for every 10 reached.

### 3.5 Group + Discord

- Hit 500 Roblox group members fast (group-join reward + group-only code drives this). Group members get push notifications on update day → instant CCU spike → algorithm sees the spike → more discovery.
- Discord: 1,000-member target by week 6. Hold weekly community events (high score nights) to keep CCU lumpy in a way the algorithm rewards.

### 3.6 Cross-promotion

- Partner with 2–3 other small Roblox devs in adjacent genres (TD, survival, co-op) for teleporter swaps in each other's lobbies. Free traffic exchange.

---

## Phase 4 — 12-Week Milestones & KPIs

| Week | Focus | KPI targets | Cumulative ad spend |
|----:|------|-------------|---:|
| **1** | Icon A/B test, FTUE rewrite, 4 gamepasses live, 15 badges, gem icon shipped | D1 ≥ 20%, Like ratio ≥ 75%, CCU 5–15 | $35 |
| **2** | Daily login streak, daily quests, group reward, sound polish | D1 ≥ 25%, Like ratio ≥ 80%, CCU 10–25 | $70 |
| **3** | First Friday update + new code + TikTok daily begins | CCU 30–60, ARPDAU ≥ $0.01 | $175 |
| **4** | Sponsored Experience push begins ($20/day) | CCU 50–100, paying % ≥ 1.5% | $315 |
| **5** | Creator outreach round 1 (15 YouTubers), Mega Loot Chest live | CCU 75–150, D1 ≥ 28% | $455 |
| **6** | Pets stub + Pet Slot gamepass + Premium Class #1 (Necromancer) | CCU 100–200, ARPDAU ≥ $0.02 | $595 |
| **7** | Major content drop: new boss + new map area + leaderboard wall | CCU 150–250, D7 ≥ 8% | $735 |
| **8** | Creator outreach round 2 + cross-promo teleporter | CCU 200–300, paying % ≥ 2% | $875 |
| **9** | Limited-time event (holiday-themed wave + exclusive cosmetic) | CCU 250–400, ARPDAU ≥ $0.03 | $1,015 |
| **10** | Battle pass / season system if data supports it | CCU 300–450, ARPDAU ≥ $0.04 | $1,155 |
| **11** | Reduce ad spend; lean on organic + creator content | CCU 300–500, **revenue ≥ $300/mo run rate** | $1,225 |
| **12** | Polish + retention tuning + plan post-12-week | CCU 350–600, **revenue ≥ $500/mo run rate** | $1,295 |

### KPI definitions

- **D1 retention** — % of new players who return next day. <20% = product problem; fix gameplay before more ads.
- **Like ratio** — visible thumbs-up %. <75% = something is actively annoying players. Read every negative comment daily.
- **ARPDAU** — gross Robux/day ÷ DAU × $0.0038 × 0.7. $0.01 = poor, $0.03 = healthy small game, $0.05+ = well-tuned.
- **Paying %** — paying users / DAU. 1% poor, 2.5% healthy, 4%+ great.
- **CCU stability** — peak CCU shouldn't crash >50% on weekdays. Stability is what the algorithm rewards.

### The math, restated

To hit $500/mo net:

- Need ~188,000 gross Robux/month sold = ~6,300/day.
- At realistic ARPDAU $0.03 (~8 gross Robux/DAU/day) → need **~800 DAU**.
- DAU ≈ 4× CCU → need **sustained ~200 CCU**.
- 200 CCU is achievable for a polished niche game with ~$1,200 well-targeted ad spend + organic discovery — **only if D1 ≥ 25%**. Without that retention, ad spend is wasted.

---

## Phase 5 — Risks & What to Cut

### Top risks (ranked)

1. **D1 retention <20% kills everything.** No ad spend rescues it. If D1 is still <20% at end of week 2, halt all ad spend and rebuild FTUE + waves 1–3 difficulty curve.
2. **Like ratio drops below 70%.** Usually one annoying mechanic (unwinnable wave, broken gamepass, lag spike). Read comments daily; ship a hotfix within 24h.
3. **Algorithm winner-take-all dynamics.** Top games eat ~80% of plays. Mitigation: niche down hard — *"co-op tower defense survival with deep classes"* — don't try to beat Tower Defense Simulator head-on.
4. **Server performance / lag at higher CCU.** 12 server scripts + building system + projectiles can lag at 20+ players. Stress-test with bots before promoting heavily; cap enemy counts in endless mode.
5. **Solo-dev burnout / update-cadence collapse.** Most solo devs miss weeks 6–8. Pre-build 3 weeks of content drops in weeks 1–2.
6. **DataStore corruption.** One viral "this game lost my progress" TikTok kills you. Add daily backup snapshots of top-100 players.
7. **Sound asset risk** (CLAUDE.md notes only 10 working rbxasset sounds). Spend 500 Robux on Creator Store audio in week 1.
8. **Pay-to-win perception.** Never gate raw combat power. Premium classes must be sidegrades, not upgrades. Loss-aversion save must be capped at 1/round.
9. **Economy imbalance.** Too-generous free gems → no one buys; too-stingy → free players quit. Monitor weekly; tune via codes (cheap to change).

### Cut from your wishlist (defer until after $500/mo)

- AI-generated images for enemies/icons/turrets (nice-to-have; doesn't move retention).
- More classes purchasable in lobby beyond the first premium class (you have 6 free; build depth, not breadth).
- Crystal upgrades + crystal shooting at level 5 — hold for the **week 7 content drop**.

### Keep on the critical path

- Loot boxes after boss + fixing loot box visuals (loot loop = retention + monetization).
- Coins / lootboxes from sky after milestones (dopamine hit = D1 retention).
- Gem icon (small but signals polish at the purchase moment).
- Leaderboard wall (week 7).
- Red enemy-approach path.

---

## Creative / unconventional ideas (worth considering, ranked by effort:value)

- **Loss-aversion "Emergency Save" SKU at 49 Robux** — already in the SKU list above. Probably the single highest-conversion SKU you can ship. *(High value, low effort.)*
- **"Spectator Bet" lobby system** — lobby players spend small gems to spawn extra enemies on the active arena, splitting reward if they survive. Drives engagement between active and waiting players. *(Medium value, medium effort. Speculative.)*
- **Content Creator "Raid" mode** — admin command lets a streamer connect chat to spawn enemies named after viewers. Highly viral on Twitch/YouTube. *(High value if a creator picks it up; otherwise zero. Speculative.)*
- **"Pay-what-you-want" tip-jar gamepass** at 50 / 200 / 500 / 1000 Robux, reward = colored name. Surprising % of dedicated fans buy these. Near-zero work to ship. *(Low effort, modest upside. Speculative.)*
- **Hardcore "Ironman" mode gamepass** — one life per round, exclusive leaderboard. Niche but high-conversion among engaged players. *(Medium effort, niche.)*
- **Twitch/YouTube "streamer mode" toggle** — removes friction for creators considering covering you. *(Low effort, helps creator outreach.)*

---

## What to do this week (concrete next 7 days)

1. Ship a new icon variant + run $5/day Sponsored Experience to A/B test it.
2. Rewrite FTUE: forced class pick, arrow to portal, first kill <30s, 500-coin + 1-chest welcome gift.
3. Wire up 4 gamepasses (VIP 499, 2× Gems 299, Auto-Revive 199, Premium Class 399) and the 49-Robux Emergency Save dev product.
4. Ship gem icon + 5 paid Creator Store sound effects.
5. Ship 15 launch badges.
6. Set up TikTok account + post first 3 short-form clips.
7. Open Discord; hit 100 members via in-game CTA + group reward.

If after 14 days D1 retention is below 20% — stop, do not spend on ads, fix retention.
