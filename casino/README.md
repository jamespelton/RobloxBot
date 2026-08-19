# Golden Spire Casino — game scripts

Playable casino built on top of the `Casino` model in Workspace
(backed up at `build-library/modern/golden_spire_casino.json`).

These files are the **only backup of the game logic** — the build JSON stores
geometry only, no scripts. Keep them in sync with Studio.

## Where each file goes

| File | Studio location | Class |
|---|---|---|
| `server/CasinoCore.server.lua` | `ServerScriptService.CasinoCore` | `Script` |
| `server/SlotService.server.lua` | `ServerScriptService.SlotService` | `Script` |
| `server/TableGames.server.lua` | `ServerScriptService.TableGames` | `Script` |
| `client/CasinoClient.client.lua` | `StarterPlayer.StarterPlayerScripts.CasinoClient` | `LocalScript` |

## Required RemoteEvents

`ReplicatedStorage.CasinoEvents` (Folder) containing 13 `RemoteEvent`s:

```
SlotSpin  SlotResult  Notify  ChipsChanged
BJOpen    BJAction    BJState  BJClose
RLOpen    RLBet       RLResult RLClose
CashierClaim
```

## Required world objects

The services find their hooks by name, so these must exist:

- `Workspace.Casino.Slots.*` — models named `SlotMachine`, each containing
  `Ruedas Jackpot` (3 parts carrying a `Decal`), `Lever`, `LEDS`, `_Collider`
- `Workspace.Casino.Tables.*` — models named `BlackjackTable` (each with a
  `Table` child) and `RouletteTable` (with `Top`, `Wheel`, `Pocket`, `Hub`, `Ball`)
- `Workspace.Casino.Venue.Cashier.CounterTop`

Templates for the imported models live in `ServerStorage`:
`BlackjackTableTemplate`, `SlotMachineTemplate`.

## How it plays

- Start with **500 chips**. Bet size is picked from the HUD (10 / 25 / 50 / 100 / 250).
- **Slots** — walk up, press **E**. Reels spin ~1.8s and stop staggered.
- **Blackjack** — press **E** at a table, then Deal / Hit / Stand / Double.
  Dealer stands on all 17. Blackjack pays 3:2.
- **Roulette** — press **E**, bet Red / Black / Odd / Even (2x) or Green (36x).
  The physical wheel spins for 3.2s before the result.
- **Cashier** — press **E** for 250 chips, 2 minute cooldown (waived at 0 chips).

## House edge

Measured over 300k simulated spins / 120k spins per roulette bet type:

| Game | RTP | Notes |
|---|---|---|
| Slots | 91.3% | 26.9% hit rate, 38x+ win about 1 in 328 |
| Roulette | ~97.0% | single zero, 2.7% house edge |
| Blackjack | ~99% | dealer stands on all 17, no splits |

Slot weights and payouts are the `SYMBOLS` table at the top of
`SlotService.server.lua`; changing a `weight` or `three` value shifts the RTP,
so re-run the simulation if you tune it.

## Known gaps

- Persistence is written but **inactive until the place is published** —
  `DataStoreService` cannot be reached from an unsaved place, so chips reset
  each session. Every call is `pcall`-guarded, so it starts working on publish.
- Poker and craps tables are decoration only; no interaction is wired to them.
- Blackjack has no split or insurance.
- Leaving a blackjack table mid-hand forfeits the stake.
