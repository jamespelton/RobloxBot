# Crystal Siege — Discord Server Blueprint

**Target:** 100 members by end of Week 1, 1,000 by Week 6 (per roadmap).

**Setup time:** ~30 minutes one-time, then weekly events for ongoing engagement.

---

## Server Name + Icon

**Server name:** Crystal Siege Official 🔮

**Server icon:** `marketing/crystal-siege-icon-512.png` (or use the dedicated `discord/server-icon.png` once generated)

**Server banner:** `discord/server-banner.png` (generated separately)

**Vanity URL** (once at 100 boosts — far future): `discord.gg/crystalsiege`

**Server description:**
> Official Discord for Crystal Siege — the co-op tower-defense survival game on Roblox. Join 1,000+ defenders, get free gem codes, play with the community, and get early access to updates. New code drop every Friday!

---

## Channel Structure

### 📋 INFO category
- **#📜-rules** — Server rules + Roblox community guidelines. Read-only for members.
- **#📢-announcements** — Update announcements, code drops, event invites. Read-only for members.
- **#🎁-codes** — Active promo codes pinned. Read-only for members.
- **#🔗-game-links** — Direct links to: Roblox game page, Roblox group, TikTok, YouTube, James's Twitter.

### 💬 COMMUNITY category
- **#💬-general** — Open chat about the game.
- **#🎮-looking-for-group** — "anyone want to play wave 50 with me?" channel for matchmaking.
- **#🖼️-base-builds** — Screenshots of bases. Hot-and-spicy reactions only — keep it positive.
- **#📸-clips** — Video clips, funny moments, boss kills. Members can post.
- **#💡-suggestions** — Feature requests + feedback. Members vote with reactions.
- **#🐛-bug-reports** — Bug submissions. Use a thread per bug.

### 🏆 EVENTS category
- **#⚔️-tournaments** — Tournament announcements + brackets.
- **#📊-leaderboards** — Weekly screenshots of top players + records.
- **#🎉-events** — High score nights, community challenges.

### 🛠️ DEV category (visible to all but locked posting)
- **#📰-changelog** — Patch notes per update. Auto-mirror to #announcements via webhook.
- **#❓-faq** — Pinned answers to common questions. Read-only.
- **#📞-support** — Open a ticket here for account/refund/lost-progress issues.

### 🔒 STAFF category (mods only)
- **#mod-chat** — Internal coordination.
- **#mod-logs** — Bot logs, deleted messages, joins/leaves.

---

## Roles

### Color hierarchy (top = highest visual priority)

| Role | Color | Who Gets It | Why |
|------|-------|-------------|-----|
| 👑 **Crystal Lord** (Owner) | Hot Pink (#FF2D95) | James only | Game creator |
| ⚒️ **Dev** | Yellow | Hayden + anyone helping with the game | Co-devs and admins |
| 🛡️ **Moderator** | Cyan | 2-3 trusted community members | Server moderation |
| ⭐ **VIP** | Gold | Anyone with the VIP gamepass (verify via Roblox link) | Gamepass perk |
| 🏆 **Wave 50 Survivor** | Magenta | Beat endless wave 50 (badge-gated) | Skill-based flex |
| 💎 **Crystal Champion** | Purple | Top 10 weekly leaderboard | Competitive perk |
| 🔔 **Update Pings** | (no color) | Self-assigned via reaction role | Opt-in update notifications |
| 🆕 **Newcomer** | (no color, default) | Default for new joiners | Default everyone |

### Reaction Roles

In #📋-rules, add a message:
> React to the bell 🔔 below to get pinged on every Friday update.

Members can opt-in to update pings without forcing notifications on the whole server.

---

## Welcome Bot Configuration

Recommended bot: **MEE6** (free tier is enough) or **Carl-bot** (more features).

**Welcome message** (in #💬-general or dedicated #🎉-welcome):

```
Welcome to Crystal Siege, {user}! 🔮

⚔️ Play the game → https://roblox.com/games/[GAME_ID]
🎁 Use code CRYSTALSIEGE for FREE gems
👥 Join our Roblox group for an exclusive cape → [GROUP LINK]
🔔 React to the bell in #📋-rules to get update pings

We're a small dev team (James + his son Hayden) building this game on weekends. Drop a screenshot in #🖼️-base-builds, share clips in #📸-clips, and let us know what you want next in #💡-suggestions!

Have fun and defend that crystal 💎
```

**Auto-moderation rules** (MEE6 / Carl-bot config):
- Block invite links from other Discord servers (anti-poaching)
- Block bad words (kid-friendly community)
- Slowmode on #💬-general at 5 seconds (prevents spam)
- Block "everyone" and "here" mentions from non-staff
- Auto-warn for caps spam

---

## Server Boost Goals

| Level | Boosts Needed | What You Unlock |
|------:|--------------:|------------------|
| Tier 1 | 2 boosts | 50-emoji slots, audio bitrate up |
| Tier 2 | 7 boosts | 100 emoji slots, server banner |
| Tier 3 | 14 boosts | Vanity URL (discord.gg/crystalsiege) |

Don't push for boosts in week 1. Focus on member growth. Boosts come naturally from invested fans at 500+ members.

---

## Weekly Event Cadence

| Day | Event | Notes |
|-----|-------|-------|
| **Friday** | Update + Code Drop | Every Friday at the same time. Announce in #📢-announcements + ping @Update Pings role. |
| **Saturday** | High Score Night | 2-hour window. Top wave on endless wins 100 in-game gems. Announce in #🏆-events. |
| **Sunday** | NONE | James's rest day. Server runs itself. |
| **Wednesday (mid-week)** | "Build Showcase" | Member picks favorite base from the past week's #🖼️-base-builds. Winner gets a custom in-game chat tag. |

---

## Growth Tactics

### Week 1 (0 → 100 members)
1. **In-game CTA** — Add a Discord invite to the game's main menu (LobbyUI). Reward: 500 coins for joining via the verify bot.
2. **TikTok bio link** — Discord invite in TikTok bio after the game link.
3. **Game description** — Discord invite in the Roblox game description.
4. **Friends + family seed** — Get 10-20 people you know to join first so the server feels lived-in for the first wave of real members.

### Week 2-4 (100 → 500)
1. **Custom emojis** — Add 20-30 Crystal Siege themed custom emojis (boss faces, class icons, gem icons). Drives chat usage + cross-server visibility.
2. **Pin great content** — Pin the best clips and base builds. New members scroll up and see "wow, this place is active."
3. **Highlight bot** — Use a bot like MEE6's leveling system to gamify chat activity.

### Week 5-12 (500 → 1,000)
1. **Cross-promo with similar Roblox game Discords** — Reach out to TD-genre devs for cross-promo channel mentions.
2. **Roblox group → Discord funnel** — Pin the Discord invite in the Roblox group wall.
3. **Stream events** — When James posts on TikTok Live, have a "watch party" channel.

---

## Verification + Roblox Link

Use **Bloxlink** bot to link Discord accounts to Roblox accounts. This enables:
- Auto-assign **VIP** role to anyone who owns the gamepass on Roblox
- Auto-assign **Wave 50 Survivor** role when they earn the badge
- Block alts (one Discord account per Roblox account)

Bloxlink free tier handles this. Setup is 10 minutes.

---

## DO NOT

- **DO NOT post in Discord during James's Sunday rest** — schedule any Sunday announcements for Monday morning.
- **DO NOT use profanity** in any server messages (James's bot policy applies here).
- **DO NOT post personal photos of Hayden** in the Discord. The Roblox avatar version is okay.
- **DO NOT promise updates you haven't shipped.** Under-promise, over-deliver.
- **DO NOT ban without warning** — community runs on trust. 3-strike rule with documentation.

---

## Reference: Successful Roblox Game Discords To Model

- **Tower Defense Simulator** — 200k+ members. Look at their channel structure for inspiration.
- **Doors** — Smaller but highly engaged. Their event cadence is worth copying.
- **Anime Defenders** — Their VIP gamepass-verification flow is best-in-class.

(Don't link to these in your server — Discord algorithm penalizes cross-server promotion.)
