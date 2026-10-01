# Breachpoint (fps.cpp) — "More CS2 + Cool Graphics" Plan

Goal: two batches, each ending in **zero-warning build → hidden selftest ×2 = SELFTEST OK → release build (`build_fps.bat`) → artifact cleanup → code explanation for study** (per standing session rules: never launch the game visibly; read exact file text before every edit).

---

## Batch 1 — CS2 gameplay depth

### 1.1 Movement overhaul: real velocity + counter-strafing
- Replace the instantaneous movement in `updatePlayer` (~2351–2479) with a velocity model: acceleration (~48/s²), friction (~9/s² when no input), per-weapon max speed, **air control limited to ~25%**.
- Spread in `fireShot` (~1880) driven by actual `|velocity|` instead of only `moveAmt` → tapping opposite direction stops you fast and accuracy recovers (counter-strafe), staying still = tight cone.
- Keep `moveAmt` for view-bob only. Risk: footstep/crouch/jump selftests hold keys — velocity model must still move the player while keys held (verified by running selftest).

### 1.2 Wallbang (bullet penetration)
- In `fireShot` (~1888–1927): after the wall hit at `wallD`, cast one continuation segment past the wall (range − wallD); first enemy behind the wall takes **35% damage**, spark FX instead of a bullet hole, tracer continues.
- Counter `g_penCount` for the selftest (deterministic rigged scenario: teleport bot behind a known 1-cell wall, aim, fire, assert hp drop + counter).

### 1.3 Six new weapons (CS2 buy-menu tiers)
| Weapon | Key | Team | Price | Notes |
|---|---|---|---|---|
| P250 | P | both | 300 | pistol |
| Tec-9 | X | T only | 500 | pistol, auto |
| Galil AR | J | T only | 1800 | rifle tier |
| FAMAS | L | CT only | 2050 | rifle tier, 3-round burst feel via tight spread |
| SSG 08 | N | both | 1700 | scoped (`scoped=1` reuses AWP zoom path) |
| XM1014 | C | both | 2000 | **shotgun: `fireShot` loops 8 pellets** (restructure), biggest code change |

- Add `WDEFS` rows (~771), extend buy dispatch (3758 filter + `buyItem` switch + `BUY_ITEMS` table ~3319), team-restriction messages like molotov.
- Viewmodel/sounds/spray auto-reuse by slot (verified: `drawViewmodel` branches on `WDEFS[].slot`).
- Append-only key usage → existing selftest buy keys untouched.

### 1.4 Bots throw grenades (biggest AI gap)
- `Nade` struct gains `team`/`owner`; **`explodeNade` (~1929) gets team filtering (no friendly fire)** — required, currently damages ALL bots.
- Bot rules (in `updateBots` ~1985–2252): enemy visible at 7–20 tiles + HE + 10s cooldown → throw HE at target; flash before first contact; smoke self-cover when `hp < 40`.
- Selftest: deterministic forced throw (set cooldown/has-nade, call throw helper, assert `g_nades` grew + counter).
- Risk: existing "st HE" test — verify player-HE assertions still pass after team filter lands.

### 1.5 Economy + round damage report
- +$300 plant (player), +$300 defuse (existing plant/defuse paths in `updatePlayer` ~2452/2462).
- `g_dmgDealt` reset per round (`startRound` ~1114), accumulated in `damageBot` when attacker is player; shown as **DMG column in scoreboard** (`drawBoardCol` ~3260) + feed line at round end.

### 1.6 Selftest additions
- Counter-strafe: hold D → release → assert velocity < 0.3 after 0.35s.
- Wallbang rigged scenario (above).
- Buy P250 (P) + XM1014 (C) → `hasW` asserts.
- Forced bot grenade throw assert; `g_dmgDealt > 0` after the HS kill.
- All new asserts added to `allGood` (~4283).

---

## Batch 2 — Cool graphics

### 2.1 Planted C4 becomes a real world object (biggest visual gap — currently minimap-only)
- Procedural sprite (ammo-crate body, LCD strip, red LED) in `buildSprites` (~626); billboard pushed in `renderSprites` (~1508) at `g_bombX/g_bombY` when planted/loose.
- LED blink synced to the beep timer (`g_lastBeep` ~2496); **radial red glow** via `PathGradientBrush` (first use in file) projected screen-space, pulsing with `g_bombT`.

### 2.2 Dynamic lighting
- Light sources: fire pools (`g_fires`), planted C4, HE/bomb explosion FX.
- (a) **Screen-space radial glows** in GDI+ over the framebuffer (project world→screen with the sprite camera basis, `PathGradientBrush` falloff);
- (b) **Per-column warm additive term in the wall raycast** (~1441): distance from wall world-pos to nearest light × falloff (walls only — keeps full-res floor/ceiling cheap; ~3 lights max, no perf risk).

### 2.3 Blood + corpses
- New red particle sprite + blood puff: spawned in `damageBot` (~1695) on hit; red splatter decal on the wall behind when a bot dies to a bullet.
- **Corpses persist until round end**: `renderSprites` death path (~1513) currently shrinks bodies to nothing at `dieT<=0` — keep last frame, flattened/darkened; cleared naturally by `spawnRoundBots`.

### 2.4 Contact shadows
- Dark alpha ellipse projected at z=0 under every bot, thrown nade, C4, ground gun, corpse (pushed before the sprite in the painter pass, same z-test vs `g_zbuf`) — instant depth read.

### 2.5 Screen effects
- **Low-HP red vignette**: full-screen `PathGradientBrush` (transparent center → red edge), alpha pulses under 35 HP (replaces text-only warning, text stays).
- **Money popups**: "+$300" floats up on any `giveMoney` (CS2 money delta).

### 2.6 Environment detail
- **Wooden-crate texture** (`texWall[3]`, procedural like the other five) + new map char `'4'` cells placed at safe decorative spots near sites: `cellAt` (~258) already returns the digit, `bfsField` already blocks non-`'0'` — must update `validateMap` gate (~341 `'0'..'3'` → `'0'..'4'`), wall texture pick `(cell-1)%3` (~1441), minimap color table (~3004). **Selftest runs `validateMap` (reachability) — natural safety gate.**
- **Bomb-site floor markings**: paint circle + A/B letter onto floor pixels during the floor cast (~1384) when the world position is inside `siteCenter` radius.

### 2.7 Polish
- **FX alpha fade fix**: `RS.dead` is written (~1492/1502) but never read — FX/deaths currently pop out; honor fade so sparks/booms dissolve.
- **Viewmodel sway**: mouse-turn delta lags the gun sideways (CS2 feel); **inspect animation gains rotation** (GDI+ `RotateTransform` around gun pivot instead of slide-only).
- **Tracer occlusion**: skip tracer segments whose midpoint screen-x lies behind `g_zbuf` (currently drawn over walls).

### 2.8 Selftest additions
- `g_c4Drawn` while planted C4 visible; `g_bloodCount > 0` after HS kill; `g_shadowDrawn` during a fight frame; site-paint flag when facing a site. Added to `allGood`.

---

## Order & risks
1. **Batch 1 first** (gameplay, riskier for selftest) → stabilize → **Batch 2** (visuals) → stabilize.
- Highest risks: XM1014 pellet restructure of `fireShot`; bot grenades changing fight pacing (may starve fixed-frame tests — make any failing test phase-driven, never fixed-frame); crate cells breaking bot paths (gated by `validateMap` + bot-plant/defuse tests).
- Freeze-time movement lock (CS2 competitive) is **deliberately skipped** — it would freeze selftest players mid-buy and adds little over the current 9s buy window.
- New selftest assertions keep the "hidden test" contract; every batch ends with `SELFTEST OK` ×2 before release build.

## Deliverables per batch
- `fps.cpp` updated; `fps.exe` rebuilt via `build_fps.bat` (record size); `fps_dbg.exe`/`selftest.log`/`fps_save.dat` deleted.
- Final reply: plain-language walkthrough of every added feature (data flow, formulas, line refs) for study.
