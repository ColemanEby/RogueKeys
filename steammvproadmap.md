# RogueKeys — Steam MVP Roadmap

*Prepared 2026-08-02 · Based on a full read of the `master` branch (all 18 Lua files, README, data, resources)*

**Decisions locked in:** Pixel art with chunky readable keycaps (32px+ per key, not the current 16×16) · Free assets only (CC0/CC-BY) · Deepen the roguelite, don't just polish.

---

## 1. Where the project stands today

**What works:** The core loop is real and runs — menu → typing round (trainer module handles input, scoring, WPM/APM/accuracy, streaks) → score converts to money (`floor(score × 0.5)`) → shop sells per-key bonuses (5 random offers, 20–70 coins, +0.05–0.30 per keystroke) → next round needs `floor(20 × round^1.2)` score. QWERTY + Dvorak layouts, ~11k-word corpus, config/save persistence, and a genuinely unusual amount of stat plumbing (lifetime aggregates, bests, match history) already exist.

**What's broken (README-confirmed, causes located in code):**

| Bug | Root cause found |
|---|---|
| Match history not retrievable / bar graph broken | `playerModel.lua` loads history with `pairs()` instead of `ipairs()` (ordering lost) and the hand-rolled serializer mishandles numeric array keys (~line 306) |
| Stats bar graph ordering wrong even with data | `statsState.lua` reverses position but not `matchIndex` |
| "S" to shop from post-round screen broken | roundState/shopState key handling + shop can only ever exit into `roundState`, never back |
| Round & shop can desync money | Each state caches its own `PlayerModel.load()` instance — two divergent copies of the player |

**Structural gaps:** no pause, no settings screen, no game-over/run-summary screen, no results screen between rounds, shop exit force-starts a round, state transitions are stubbed (fade never animates), `menuState` allocates two fonts *every frame*, DEBUG_MODE is split-brained (`local = true` vs `_G = false`), ConfigManager's serializer can corrupt saves containing quotes, ResourceManager's `getFont` on-demand sizing is broken (`__fontPath` doesn't exist on LÖVE fonts).

**Visual state: it's a debug skin, not a game.** Every screen is a flat navy clear color + default LÖVE font + hardcoded RGBA literals. Zero images in any state file, zero audio anywhere, no custom fonts shipped. The only art asset in the repo is one 128×224 keycap sheet (16×16 keys) that most players will never see (sprite path is optional with rectangle fallback). The good news: because everything delegates to `trainer`, `MenuBuilder`, and `KeyboardView`, a reskin doesn't fight the architecture.

**Design gap for a paid product:** the "keycap shop" fantasy — the hook of the whole game — is currently a flat numeric bonus lottery. No rarities, no switch types, no visual change when you upgrade a key, no build identity. This is the #1 thing Steam reviews would punish.

---

## 2. The plan at a glance

Six phases, roughly sequential, each independently shippable to playtesters. Estimated total: **10–16 weeks of part-time work** to a launchable MVP.

| Phase | Theme | Outcome |
|---|---|---|
| 0 | Stabilize | All known bugs fixed, one source of truth for player state, saves trustworthy |
| 1 | Visual foundation | Resolution-independent pixel canvas, theme system, fonts, UI kit — game *looks designed* |
| 2 | The keyboard is the star | 32px+ keycap rendering with visible caps/switches, rarity colors, juice |
| 3 | Roguelite depth | Rarity tiers, switch effects, run structure, results & game-over screens, real shop |
| 4 | Audio + missing screens | SFX, music, pause, settings, credits |
| 5 | Steam | Packaging, achievements, store page, launch |

---

## 3. Phase 0 — Stabilize the foundation (1–2 weeks)

Do this before touching visuals; everything after builds on it.

1. **Single PlayerModel instance.** Create one authoritative instance (e.g. a `Game` context table or make `PlayerModel.load()` a memoized singleton) shared by roundState/shopState/statsState. This kills the money-desync class of bugs. — **DONE:** see `modules/game/context.lua` (`Context.player()` memoized singleton), `modules/player/playerModel.lua`, `states/roundState.lua`, `states/shopState.lua`, `states/statsState.lua`, and `tests/test_player_save.lua`.
2. **Replace the hand-rolled serializers.** Both `playerModel.serializeTable` and `configManager.serializeTable` have array-key and string-escaping bugs. Swap both for one battle-tested library — `serpent` or `bitser`/`binser` (all MIT, single-file, LÖVE-standard). Write a one-time migration that reads old saves with the legacy loader and re-saves in the new format. This alone likely fixes match history persistence. — **DONE:** see `modules/util/serialize.lua` (`lib/serpent.lua` backend), `engine/configManager.lua`, `modules/player/playerModel.lua` (legacy-load fallback at `PlayerModel.load()`), `tests/test_player_save.lua`, and `tests/test_config.lua`.
3. **Fix match history retrieval:** `ipairs()` + fix the reversed-index logic in statsState's bar graph. Add `or 0` guards on all stat reads (old-save crash risk in economy tab). — **DONE:** see `states/statsState.lua` (`barMatchIndex()`, `matchSeries()`, guarded accessors), `modules/player/playerModel.lua` (`MAX_MATCH_HISTORY = 100`, `loadMatchHistory()`), and `tests/test_stats_graph.lua`.
4. **Fix state flow:** shop remembers where you came from (menu ⇄ shop, round → shop → next round); fix the "S" shortcut; make Escape mid-round pause (Phase 4 adds the real pause screen — for now, just don't pay out on Escape). — **DONE:** see `states/shopState.lua` (`returnTo` param + `resolveReturnTo()`), `states/menuState.lua` (`returnTo = "menuState"`), `states/resultsState.lua` (`[S] Shop` button), `states/roundState.lua` (Escape pushes `pauseState` or falls back to menu without payout), `states/pauseState.lua`, and `tests/test_round_flow.lua` + `tests/test_shop.lua`.
5. **Kill the DEBUG_MODE split-brain** (one `_G.DEBUG_MODE`, F-key toggled), move font creation out of `menuState.draw()`, fix or delete ResourceManager's `__fontPath` on-demand font sizing (preload the sizes you need instead). — **DONE:** see `main.lua` (single `_G.DEBUG_MODE`, F5 toggle), `modules/util/debugHelper.lua` (leveled logging gated on it), `states/menuState.lua` (uses `Theme.font()`), `engine/resourceManager.lua` (preloads `Theme.fontSizes`; `fontPaths` replaces broken `__fontPath` sizing), and `tests/test_logging.lua`.
6. **Delete `setup.lua`** (redundant — main.lua already creates directories; it's also Unix-only) or rewrite as a dev-only script. Add `conf.lua` (LÖVE convention: window settings, `t.identity = "RogueKeys"` — also required for clean Steam Auto-Cloud later). — **DONE:** `setup.lua` no longer exists; `main.lua` creates save directories and `conf.lua` supplies `t.identity = "RogueKeys"`, window settings, and the `--test` headless flag.
7. **Add a test harness** while you're in here: `busted` or a tiny custom runner for the pure-logic modules (scoring, economy, serialization round-trips). The stat pipeline has burned you before; lock it down. — **DONE:** see `tests/run.lua` (custom runner), `tests/helpers.lua`, `conf.lua` (`_G.HEADLESS` detection), and `main.lua` (`love . --test` entry point). Currently 278 cases; verify with `love . --test`.

**Exit criteria:** play 10 rounds, buy upgrades, quit, relaunch — money, round, history, and stats all correct. Stats screen shows a real bar graph.

---

## 4. Phase 1 — Visual foundation (2–3 weeks)

The goal of this phase is that *every* screen goes through one theme and one layout system, so polish applied once applies everywhere.

1. **Virtual pixel canvas.** Render the game to a fixed logical canvas — recommend **640×360** (16:9, scales integer-perfect to 720p ×2, 1080p ×3, 1440p ×4, 4K ×6) — drawn with `love.graphics.setDefaultFilter("nearest")` and integer scaling with letterboxing. Use the `push` library (MIT) or ~60 lines by hand. This replaces the current 800×600 window and all the hardcoded-pixel layout pain, and makes pixel art crisp at every resolution. All coordinates become logical; delete per-state `getWidth()` math. — **DONE:** see `modules/ui/screen.lua`; all 10 opt-in states are converted.
2. **Theme module (`modules/ui/theme.lua`).** One table holding the palette, fonts, spacing, and 9-patch styles. Sweep all ~20 hardcoded color literals in states/modules into it. Pick a dark palette with an accent (the existing navy-and-yellow instinct is fine — formalize it, e.g. base #14141f, panel #1e1e2a, accent gold, success green, error red, rarity colors reserved). — **DONE:** see `modules/ui/theme.lua` and `tests/test_theme.lua`.
3. **Fonts (free, verified licenses):**
   - **monogram** (datagoblin, CC0) — monospace bitmap font for the *typing line* and stat tables. Monospace makes caret/error math trivial: `x = n × advance`.
   - **m6x11** (Daniel Linssen, free w/ attribution — the Balatro font) — titles, scores, prices. Instantly reads "polished roguelite."
   - Ship OFL/license files alongside. Load at integer multiples only.
4. **UI kit integration.** Adopt **Mounir Tohami's Pixel Art GUI Elements** (CC0) as the base 9-patch panel/button/bar set, with **Kenney UI Pack: Pixel Adventure** and **Kenney Fantasy UI Borders** (both CC0) filling gaps (sliders, tabs, ornate shop frames). Rebuild `MenuBuilder` to draw 9-patch panels + themed fonts instead of flat rectangles — every menu in the game upgrades at once.
5. **Real state transitions.** Finish the stubbed fade in `stateManager` (it's 80% written); add a 0.2s fade or slide. Add hover/press states to buttons. — **DONE:** see `engine/stateManager.lua` and `tests/test_state_manager.lua`.
6. **Background.** Generate a near-black seamless starfield with **Deep-Fold's Pixel Space Background Generator** (free for commercial use, palette-controllable) or use a flat theme color + `moonshine` vignette/filmgrain. Subtle — the keyboard is the star.
7. **Screens to restyle in this phase:** menu, stats (its card grid + bar chart + pie chart already have decent bones — theme them), shop shell, round HUD frame.

**Exit criteria:** screenshot of any screen looks like a real game; window resize is crisp at every size.

---

## 5. Phase 2 — The keyboard is the star (2–3 weeks)

This is the phase that answers your requirement: *"enough pixels for the keyboard to look cool when they get new key switches/key caps."*

1. **New key size: 32×32 art, rendered at ×2 (64px logical on the 640×360 canvas keyboard view — roughly half the screen width for the full board; scale 0.75 where it needs to be compact).** The current 16×16 sheet becomes a legacy asset. Base pack: **Caz's Pixel Keyboard Buttons** (CC BY 4.0, 215 icons at 32×32 **with pressed states**, modification explicitly allowed) — the only verified free 32px pack with press animation frames.
2. **Layered keycap rendering instead of single sprites.** Draw each key as a stack: `switch/housing base → keycap body (palette-swapped by rarity/material) → legend (glyph) → effect overlay (shine, glow, particles)`. This is what makes upgrades *visible*: a new switch changes the base layer, a new cap changes the body layer. Build cap-body variants by palette-swapping Caz's caps in Aseprite or at runtime with a ~15-line LÖVE palette shader (CC BY allows modification). One pack → unlimited rarity colors/materials. — **DONE:** see `modules/keyboard/capRenderer.lua` and `modules/keyboard/keyboardView.lua`.
3. **Keycap visual vocabulary** (ties into Phase 3 design): rarity = cap color/material (common gray → uncommon green → rare blue → epic purple → legendary gold/animated); switch type = visible stem color peeking under the cap + distinct press animation/sound (linear red, tactile brown, clicky blue — leaning into real mechanical-keyboard culture is free flavor).
4. **Juice pass on typing** (this is the moment-to-moment feel of the entire game):
   - Key press: cap depresses 2px (Caz's pressed frames), brief glow on correct, shake + red flash on error (trainer already has a shake system — wire it up).
   - Per-keystroke floating score numbers (bigger/gold when an upgraded key procs).
   - Streak meter with escalating glow; combo milestones fire a particle burst (**Kenney Particle Pack** CC0, or **pimen's hit sparks** — 48×48 pixel-native, free commercial, no credit required).
   - **moonshine** (MIT, LÖVE post-processing lib: crt, scanlines, glow, chromasep, vignette) — subtle glow + vignette baseline; optional CRT toggle in settings as a style flourish.
5. **Typing line redesign:** monogram font at generous size, smooth caret, typed/pending/error color states, upcoming-word ghost. Look at Monkeytype for feel references.
6. **Icons for the shop/economy:** **Kyrise's Free RPG Icon Pack** (CC BY, ships at 16/32/48px — coins, colored gems ready-made as rarity indicators) + **Shikashi's Fantasy Icons** (CC BY, 32×32, buff/debuff icons for switch effects).

**Exit criteria:** a 10-second GIF of typing with an upgraded board looks *shareable*. This GIF is also your store-page trailer seed.

---

## 6. Phase 3 — Deepen the roguelite (3–4 weeks)

Design goal: turn "flat bonus lottery" into "build a keyboard, chase a run."

1. **Keycap items with identity.** Replace raw `{key, bonus, cost}` offers with item definitions: name, rarity, cap art variant, switch type, and an effect. Effect archetypes that stay cheap to implement but create builds:
   - *Flat*: +X points on this key (current behavior, commons).
   - *Scalers*: +X per current streak; ×2 if previous key was adjacent; vowels echo 10% to all vowels.
   - *Economy*: this key drops +1 coin per press; interest cap raiser.
   - *Utility/switches*: tactile = grace window on this key (first error per round forgiven); clicky = +crit chance (crit = double points, big juice moment); linear = +streak protection.
   - *Legendary set pieces*: home-row set bonus, "Space cadet" (spacebar procs based on words-per-life), etc.
2. **Run structure.** Define a run: rounds 1–N (suggest 8–10) with escalating score gates (current `20 × round^1.2` curve is a fine start), boss rounds every 3rd (mutators: no-backspace, decaying text, timed burst), then **victory screen → endless mode / next difficulty tier**. Failing a gate = run over. This gives the game a session shape, a win state, and difficulty knobs — all currently missing.
3. **Between-round results screen** (new state): WPM/accuracy/streak/score breakdown, money earned counting up, then explicit choice: **Shop / Next round / Abandon run**. Fixes the broken S-shortcut problem *structurally* instead of patching a keybind.
4. **Game-over/run-summary screen** (new state): run stats, best-key MVP, money → meta note, "New best!" callouts. Currently a failed run silently dumps to menu — worst moment in the game to be anticlimactic.
5. **Shop redesign** on the Phase 1 UI kit: 3–5 keycap item cards (art + name + rarity color + effect text + price), reroll button (costs escalate), lock/skip, money always visible, and the keyboard preview showing the hovered item *installed* live. Don't reroll all offers on every purchase (current behavior) — that's a slot machine, not a draft.
6. **Persistent meta layer (light touch for MVP):** lifetime stats already exist — surface them. Unlockable cosmetic board themes/layouts (Dvorak as an *unlock* is cute) rather than power creep. Stats screen gets the WPM-over-time graph (the flagship feature the README promises — history cap raised from 10 to 100+ sessions).
7. **Balance pass** with real numbers: current payout (`0.5 × score`) vs gate curve vs 20–70 coin costs — model it in a spreadsheet, target "afford 1–2 items per shop visit, meaningful choice each time."

**Exit criteria:** a full run (win or lose) feels like a story; two runs in a row produce visibly different keyboards.

---

## 7. Phase 4 — Audio + missing screens (1–2 weeks)

1. **SFX (all free/verified):** mechanical key thock per press — slice from CC0 freesound recordings (filter License: CC0; e.g. GeorgeHopkins' mech keyboard recording is CC-BY if you prefer, needs one credit line) with pitch variance per press (`source:setPitch(0.95 + rand*0.1)`) so it never machine-guns; distinct sound per switch type. UI/coin/purchase/stinger sounds from **Kenney Interface Sounds / UI Audio / Music Jingles / Digital Audio** (all CC0). Custom blips via **jsfxr** or **ChipTone** (both output CC0). Route through a tiny audio manager honoring the volume settings that already exist in config.
2. **Music:** **"Three Red Hearts — Prepare to Dev"** by Tallbeard/Abstraction — 24 seamless chiptune loops, **explicitly CC0** — menu/gameplay/shop tracks with zero license burden. (Backup: Abstraction's 100-loop bundle, attribution requested; Kevin MacLeod CC-BY.)
3. **Pause state** (Escape mid-round): resume / settings / abandon run. Do NOT pay out on abandon.
4. **Settings state:** volumes (config keys exist already), window mode/scale, CRT toggle, keyboard layout, reset progress (with confirm). ConfigManager already persists all of this — it just has no UI.
5. **Credits screen:** the CC-BY attribution ledger lives here (Caz, Kyrise, Shikashi/game-icons.net, Daniel Linssen m6x11, plus any freesound CC-BY credits). Keep `CREDITS.txt` in-repo as the source of truth, render it in-game.

---

## 8. Phase 5 — Steam (2–3 weeks calendar time, much of it waiting)

**Precedent: LÖVE is Steam-proven** — Balatro (fused LÖVE exe, 96%+ rating), Moonring, SNKRX, Gravity Circuit. No engine change needed, ever.

1. **Steamworks account + fee:** $100 per app (recouped after $1,000 adjusted gross revenue). Identity verification 2–7 business days. **30-day mandatory wait between paying the fee and releasing** — pay it a month before you think you're done. Store page must be live as "Coming Soon" ≥2 weeks pre-launch. Store review ~3–5 business days; build review ~3–5 business days.
2. **Packaging** (per LÖVE wiki): zip game → `.love` → Windows: `copy /b love.exe+RogueKeys.love RogueKeys.exe` + ship LÖVE's DLLs + license.txt. Linux depot optional but cheap (Proton runs LÖVE fine on Deck regardless; native Linux is a nice-to-have). Set `t.identity` in conf.lua now — it's the path Steam Auto-Cloud will sync.
3. **Steam integration (optional but worth it):** **luasteam** v5 (actively maintained, v5.0.0 March 2026) — achievements are ~10 lines (`Steam.UserStats.SetAchievement` + `StoreStats`). Ship 15–25 achievements (first run won, 100 WPM round, all-legendary board, perfect round, etc.). **Cloud saves via zero-code Auto-Cloud** pointed at the save dir. Overlay works automatically with LÖVE — no code.
4. **Store assets** (current required sizes): header 920×430, small 462×174, main 1232×706, vertical 748×896; library capsule 600×900, hero 3840×1240, logo PNG; icons 256×256 + 184×184; **5+ screenshots at 1920×1080** (real gameplay). Trailer not strictly required but pages without one underperform — a 30–45s gameplay capture with the Phase 2 juice is enough. Capsule art is the one place "free assets only" bites: budget real time to composite something strong from your own game art at ×3 scale (big glowing keycaps spelling the title is an obvious, good capsule concept).
5. **Deck note:** a typing game will rate "Playable"/"Unsupported" on Deck Verified — that's fine and doesn't gate release; be honest on the page.
6. **Pre-launch:** 2 weeks of the Coming Soon page + a free itch.io demo build for playtesting/wishlists. Playtest with strangers (typing games surface layout/locale bugs fast — non-QWERTY, non-US keyboards).

---

## 9. Free-asset shopping list (all licenses verified on-page, Aug 2026)

| Category | Pick | License | Note |
|---|---|---|---|
| Keycaps 32×32 | [Caz — Pixel Keyboard Buttons](https://cazwolf.itch.io/caz-pixel-keyboard) | CC BY 4.0 | 215 icons incl. pressed states; palette-swap for rarities |
| Key glyph fallback | [Kenney — Input Prompts Pixel 16×](https://kenney.nl/assets/input-prompts-pixel) | CC0 | supplement only |
| UI 9-patch kit | [Mounir Tohami — Pixel Art GUI](https://mounirtohami.itch.io/pixel-art-gui-elements) | CC0 | panels, buttons, bars |
| UI extras | [Kenney — UI Pack Pixel Adventure](https://kenney.nl/assets/ui-pack-pixel-adventure) · [Fantasy UI Borders](https://kenney-assets.itch.io/fantasy-ui-borders) | CC0 | sliders/tabs · ornate shop frames |
| Typing font (mono) | [monogram](https://datagoblin.itch.io/monogram) | CC0 | bitmap monospace |
| Display font | [m6x11](https://managore.itch.io/m6x11) | Free w/ attribution | the Balatro font |
| Icons/gems/coins | [Kyrise — RPG Icon Pack](https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack) | CC BY 4.0 | ships 16/32/48px |
| Effect icons | [Shikashi — Fantasy Icons](https://shikashipx.itch.io/shikashis-fantasy-icons-pack) | CC BY 4.0 | buffs/debuffs for switches |
| Shaders | [moonshine](https://github.com/vrld/moonshine) | MIT | crt, glow, vignette, chromasep |
| Particles | [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) · [pimen hit sparks](https://pimen.itch.io/battle-vfx-hit-spark) | CC0 · free commercial | bursts · pixel-native impacts |
| Background | [Deep-Fold space generator](https://deep-fold.itch.io/space-background-generator) | free commercial | palette-matched, seamless |
| SFX | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) + [UI Audio](https://kenney.nl/assets/ui-audio) + [Music Jingles](https://kenney.nl/assets/music-jingles) · [jsfxr](https://sfxr.me/) / [ChipTone](https://sfbgames.itch.io/chiptone) | CC0 | plus CC0-filtered freesound key thocks |
| Music | [Three Red Hearts — Prepare to Dev](https://tallbeard.itch.io/three-red-hearts-prepare-to-dev) | CC0 | 24 seamless chiptune loops |
| Serialization | serpent or bitser | MIT | replaces hand-rolled serializers |
| Resolution | push (or hand-rolled) | MIT | virtual 640×360 canvas |
| Steamworks | [luasteam v5](https://github.com/uspgamedev/luasteam) | MIT | achievements, cloud |

**Attribution required (credits screen + CREDITS.txt):** Caz · Kyrise · Shikashi (Matt Firth) + game-icons.net · Daniel Linssen (m6x11) · any CC-BY freesound clips. Everything else is CC0/MIT (keep license files in repo).

**Avoid:** BDragon1727 packs (non-commercial without donation), xfez keyboard pack (unclear license), Veyroa UI (provenance concerns).

---

## 10. Risks & honest notes

- **Biggest risk is design, not code:** the keycap-effect system (Phase 3) is where the game becomes worth $5–8 or doesn't. Prototype 5–6 effects early — during Phase 2 — and playtest before building all the art around them.
- **Capsule art on a $0 budget** is the weakest link for store conversion. Composite from in-game art at high scale; if any money ever gets spent, spend it here first.
- **Match-history data model** should be settled in Phase 0 (per-run + per-session records, unbounded or 100+ cap) because the stats screens in Phase 3 depend on it — don't rebuild it twice.
- **Scope guard:** QWERTY-only effects for MVP is fine; make Dvorak an unlock. Don't add more layouts, modes, or a second currency until after launch.
- A demo on itch.io before Steam costs nothing and de-risks everything.
