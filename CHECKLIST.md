# Crystal Siege — Wednesday Checklist

**Goal:** Everything polished and working by Wednesday (Hayden visit)

---

## Priority 1: New Classes (Economist + Jester)

### Economist (300 gems)
- [ ] Add to ClassManager class list + CLASS_WEAPON_MAP
- [ ] Add to ClassShopManager (purchasable, 300 gems)
- [ ] Create weapon: Cane (BaseDamage=14, SwingCooldown=0.5, HitRange=8)
- [ ] Implement passive: 20% discount on shop items (GameManager shop)
- [ ] Implement passive: 20% discount on buildings + upgrades (BuildManager)
- [ ] Implement passive: +20% bonus coins from kills (GameManager enemy death)
- [ ] Implement ability (E): "Market Boom" — 8s 2x coin drops, 15-stud radius, 25s cooldown
- [ ] Gear visuals: Top hat, monocle, suit vest, briefcase on back (need Toolbox assets)
- [ ] Add to ClassSelection GUI (client)
- [ ] Add class color + label

### Jester (400 gems)
- [ ] Add to ClassManager class list + CLASS_WEAPON_MAP
- [ ] Add to ClassShopManager (purchasable, 400 gems)
- [ ] Create weapon: Scepter (BaseDamage=18, SwingCooldown=0.45, HitRange=9)
- [ ] Implement ability (E): "Wild Card" — random effect, 5s cooldown
  - [ ] Effect 1: Slam (AoE 20 dmg, 10 studs)
  - [ ] Effect 2: Heal Pulse (20 HP, self + allies, 15 studs)
  - [ ] Effect 3: Lightning Strike (30 dmg to nearest enemy)
  - [ ] Effect 4: Speed Burst (1.5x speed, 5 seconds)
  - [ ] Effect 5: Coin Shower (spawn 3 coin pickups)
  - [ ] Effect 6: Shield (3s ForceField)
- [ ] Gear visuals: Jester hat (multicolored, bells), colorful cape (need Toolbox assets)
- [ ] Add to ClassSelection GUI (client)
- [ ] Add class color + label

---

## Priority 2: Remaining Class Gear (block Parts → mesh models)

### Mage
- [ ] Replace block wizard hat (base + cone + tip) with Toolbox wizard hat
- [ ] Replace block cape with Toolbox cape model
- [ ] Replace block staff (rod + orb) with Toolbox staff model
- [ ] Staff weapon mesh (currently sword mesh?) — verify/replace

### Shooter
- [ ] All gear is block Parts — needs full visual overhaul
- [ ] Crossbow weapon mesh — verify/replace with proper crossbow
- [ ] Design shooter gear: quiver, hood, arm guard? Find Toolbox assets

### Recruiter
- [ ] All gear is block Parts — needs full visual overhaul
- [ ] Club weapon mesh — verify/replace with proper club
- [ ] Design recruiter gear: banner, horn, armor? Find Toolbox assets

### Verify Completed Classes
- [ ] Fighter — Mesh helmet + CTVEST chestplate still working
- [ ] Healer — Doctor hat + dagger + green cross + med bag working
- [ ] Builder — Construction hat + Toolbox vest + hammer working

---

## Priority 3: Sounds

### Audit Current Sounds
- [ ] List all sounds currently in use (SoundManager + inline)
- [ ] Identify which use the 10 working rbxasset:// sounds vs silence

### Needed Sounds (search Creator Store for audio assets)
- [ ] **Combat:** Sword swing, hammer hit, crossbow fire, staff zap
- [ ] **Enemy:** Enemy hit/damage, enemy death, enemy spawn
- [ ] **Boss:** Dramatic entrance, boss death, boss attack
- [ ] **Wave:** Wave start horn/bell, wave cleared fanfare, final wave victory
- [ ] **Crystal:** Crystal taking damage, crystal destroyed, crystal repaired
- [ ] **Building:** Building placed, building destroyed, turret firing, cannon firing
- [ ] **Pickups:** Coin collected, health kit, speed boost, damage boost
- [ ] **Abilities:** Healer heal, Mage lightning, Fighter slam, Economist boom, Jester wild card
- [ ] **UI:** Shop purchase, class selected, upgrade purchased
- [ ] **Ambient:** Lobby background music, combat/wave background music
- [ ] **Revive:** Down state sound, revive progress, revive complete

---

## Priority 4: Enemy & Building Visuals

### Boss Models
- [ ] Berserker (wave 5) — replace block Part buildBossModel with Toolbox template
- [ ] Dark Commander (wave 10) — replace block Part buildBossModel with Toolbox template
- [ ] Endless boss (every 50 waves) — template variant

### Building Models (block Parts → mesh)
- [ ] Walls — stone/castle wall models
- [ ] Reinforced Walls — upgraded wall look
- [ ] Turrets — mesh turret models
- [ ] Cannon Towers — mesh cannon models
- [ ] Spike Traps — mesh spikes
- [ ] Healing Stations — mesh medical station
- [ ] Slowdown Fields — visual upgrade
- [ ] Coin Forges — mesh forge
- [ ] Crystal Collectors — mesh collector

---

## Priority 5: Lobby & UI Polish

- [ ] ReadyPortal BillboardGui — sign hidden behind arch from some angles, move higher
- [ ] FloorEmblem — still a primitive, could upgrade
- [ ] Sign frame/corners — underground pillar bases cleanup
- [ ] Red arena entrance (LobbyWall2) — very plain, needs decoration
- [ ] Gem Store / Class Shop — verify ProximityPrompts reconnect after playtest
- [ ] Gem icon — replace "G" text with proper image label

---

## Priority 6: Full Regression Testing

### Automated
- [ ] Run `GameTests.runAll()` — all 28 checks pass

### Manual Playtest — Each Class
- [ ] Fighter: gear looks good, greatsword works, slam ability works
- [ ] Healer: gear looks good, dagger in hand, heal ability works, HealOnHit works
- [ ] Builder: gear looks good, hammer right-side-up, 30% building discount works
- [ ] Mage: gear looks good, staff works, lightning zap works
- [ ] Shooter: gear looks good, crossbow works, ability works
- [ ] Recruiter: gear looks good, club works, helper soldiers spawn + follow + fight
- [ ] Economist: gear looks good, cane works, discounts apply, coin bonus works, Market Boom works
- [ ] Jester: gear looks good, scepter works, Wild Card triggers random effects correctly

### Manual Playtest — Game Systems
- [ ] Waves 1-5: correct enemy types spawn per wave (Orc→Knight→Skeleton)
- [ ] Wave 5 boss (Berserker): spawns, cinematic plays, fights correctly
- [ ] Waves 6-10: enemy scaling, variety correct
- [ ] Wave 10 boss (Dark Commander): spawns, fights correctly
- [ ] Endless mode (wave 11+): continues scaling, boss every 50
- [ ] Enemy HP bars visible above heads
- [ ] Enemy name labels visible
- [ ] Enemy AI: attacks crystal, aggros players within 20 studs, attacks walls/buildings

### Manual Playtest — Buildings
- [ ] Place each building type — placement, overlap check, build limits
- [ ] Inspect buildings (press E) — range circle, stats, HP bar, upgrade button
- [ ] Upgrade buildings (3 tiers) — cost, visual change, stat improvement
- [ ] Builder 30% discount on buildings + upgrades applies
- [ ] Economist 20% discount on buildings + upgrades applies
- [ ] Turrets auto-fire at enemies
- [ ] Cannons auto-fire at enemies
- [ ] Spike traps damage enemies walking over
- [ ] Healing stations heal nearby players
- [ ] Coin forges generate coins
- [ ] Crystal collectors contribute to crystal

### Manual Playtest — Shop & Economy
- [ ] Between-wave shop opens, items purchasable
- [ ] Economist 20% shop discount applies
- [ ] Economist +20% kill coins works
- [ ] Economist "Market Boom" doubles coin drops
- [ ] Item pickups work (health, speed, damage, coins)
- [ ] Loot chests spawn, roulette reveal works

### Manual Playtest — Other Systems
- [ ] Revive: go down, hold E to revive, timer works
- [ ] Spawn immunity: 3-second ForceField on spawn
- [ ] 5-second respawn timer
- [ ] 20-second break between waves
- [ ] Crystal health bar + wave counter UI
- [ ] Game over screen when crystal destroyed
- [ ] DataStore: save/load works (coins, gems, XP, daily rewards, class unlocks)
- [ ] Class Shop: purchase classes, gems deducted, class available next round
- [ ] Gem Store: gem purchases work
- [ ] Promo codes: test CRYSTALSIEGE and other codes
- [ ] Weather system: cycles Sunny/Rainy/Snowy
- [ ] Admin panel: weather override, announcements

---

## Production Settings (before publish)
- [ ] ReadyUpManager COUNTDOWN_TIME → 10 (currently shortened for testing)
- [ ] Re-enable daily login reward
- [ ] Verify DataStore API access enabled
- [ ] Remove any debug prints

---

*Last updated: 2026-03-09*
