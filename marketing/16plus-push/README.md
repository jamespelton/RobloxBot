# Crystal Siege: getting it open to players under 16 (free route)

Built by Rex, 2026-10-07. Nothing in this folder has been posted or sent.
Every post and email here gets shown to James one at a time, and only goes out on his yes.

## Why the game is 16+ right now

Roblox's public listing says **"Maturity: Minimal • Ages 16+"**. The content is fine. Since June 2026,
every game starts out shown only to age-checked players 16 and older, and opens to Roblox Kids
(5-8) and Roblox Select (9-15) only after it passes evaluation.

Checked 2026-10-07 against `apis.roblox.com/experience-guidelines-api` (universe 9826868953):
Minimal, no content descriptors, minimum age 16.

## The bar we have to clear

| | Now | From November 2026 |
|---|---|---|
| Highly engaged players needed | 250 | **100** (announced at RDC26) |
| Window | rolling 60 days | rolling 60 days |

A **highly engaged player** is an age-checked 16+ account with some account tenure, real playtime
in Crystal Siege, and **a purchase anywhere on Roblox in the last 60 days**. They do not need to buy
anything in our game. Roblox doesn't publish the exact minimums.

**Because the window rolls, a slow trickle never adds up.** Players who come in today drop out of
the count 60 days later. The push has to land in one tight stretch, ideally November through
December, so 100 qualifying players overlap inside the same 60 days.

**The binding constraint is traffic, not content.** Lifetime visits are 498, with 0 playing right now.
One real data point from the DevForum (Oct 2026): a dev spent $100 on Roblox ads at a 5% CTR and
got 135 highly engaged players. Free channels are slower and less predictable than that.

## James's list, in order

1. **Verify ID + turn on 2-Step Verification on JimmyP722.** Do this first. I could not see
   the Audience Reach page (Chrome isn't logged in to Roblox), so I don't know whether plays count
   before the account requirements are met. If they don't, any traffic we drive first is wasted.
   Check: create.roblox.com/settings/eligibility/publishing-permissions
2. **Play one full round yourself.** The last game update was June 10 and nobody has played since.
   A broken first five minutes kills playtime, and playtime is part of what makes a player count.
3. **Fix the live game description** (`game-description.txt`). The live one has claims the game
   can't back up. See "Fixed claims" below.
4. Then the posts and emails, one at a time: DevForum first, then creators, then Reddit.

The 1,000 Robux refundable fee (or Plus) can wait until Roblox says the game qualifies.

## Channels, ranked by how likely they are to produce players who count

1. **Roblox DevForum, Creations Feedback** (`devforum-post.md`). Developers are adults, mostly age-checked,
   and spend on Roblox. Posts asking for honest feedback get played. Needs a DevForum account.
2. **Tower defense YouTubers** (`creator-outreach.md`). TD audiences skew older than variety channels.
   One video is worth more than every other channel combined. Kid-variety channels are cut from this pass.
3. **Reddit** (`reddit-posts.md`). I could not check subreddit rules (Reddit blocks automated reads).
   Read each sub's rules tab before posting, or the post gets removed.
4. **TikTok kit** (`../launch-kit/tiktok/`). Last. It skews young and the captions were written for kids.

## Fixed claims

The live description and the old outreach template say things the game doesn't back up.
Everything in this folder uses only the feature list in `CLAUDE.md`.

| Old claim | What's true |
|---|---|
| "30+ buildings" | 9 building types, each with 3 upgrade tiers |
| "Boss battles every 5 waves" | Bosses at wave 5 and wave 10, then every 50 waves in endless |
| "Co-op for up to 4 players" | Co-op; server max is 50, no verified 4-player cap |

The same claims are now fixed across `../launch-kit/` too (copy, outreach template, ad copy,
TikTok scripts). The old outreach template still offers a custom chat tag and personal promo codes
that don't exist in the game, so use `creator-outreach.md` here instead.

**Also worth knowing:** the game-page thumbnails are AI-generated. DevForum readers spot that
fast ("everything looks AI" was the first reply on a similar post this week). Real gameplay
screenshots will do better there.

## Items marked [CONFIRM]

The drafts say James built the game with his son Hayden, which the old kit also said. Only James
can vouch for that, so those lines are marked [CONFIRM] and get cut if they aren't right.

## Tracking

`tracker.csv`: one row per post or email. The real number is the Highly Engaged Player count on the
Audience Reach tab in Creator Hub. It updates daily.
