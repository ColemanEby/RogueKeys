# Achievements Spec

This spec is fully wired: every achievement id in the table has a live
`Steam.unlockAchievement(id)` call site in gameplay code under `modules/` or
`states/`. Keep it as the id, display-name, and trigger-point reference when
configuring achievements in Steamworks or maintaining their gameplay hooks.

`Steam.unlockAchievement` is idempotent per session (repeat calls for an
already-sent id are free), so callers can call it every time the trigger
condition is true — no "have I already granted this" bookkeeping needed on
the caller's side.

## Id convention

Ids are `SCREAMING_SNAKE_CASE`, ASCII, ≤ 128 characters — this is also what
you type into the Steamworks achievement config in the App Admin panel. They
must never change once configured there; display name/description can be
edited freely, the id cannot.

## The list (25)

| Id | Display name | Description | Visibility | Trigger point |
|---|---|---|---|---|
| `FIRST_KEYSTROKE` | Hello, World | Type your first correct character. | Visible | `modules/typing/trainer.lua` — first correct keystroke of the player's first session (check `stats.totalCorrect == 0` before incrementing). |
| `FIRST_ROUND_COMPLETE` | Warm Up | Complete your first typing round. | Visible | `states/roundState.lua` (or `modules/game/run.lua` if round completion is centralized there) — on the round-complete transition, first time `PlayerModel.stats.totalSessions` goes from 0 to 1. |
| `FIRST_RUN_COMPLETE` | Full Send | Complete a full run, win or lose. | Visible | `modules/game/run.lua` — the run-over transition (both the victory path and the gate-failure path count). |
| `VICTORY_RUN` | Keyboard Warrior | Beat the final round of a run. | Visible | `modules/game/run.lua` — the victory branch specifically (reached round N and cleared its score gate), distinct from a run ending in failure. |
| `FIRST_PURCHASE` | New Cap Smell | Buy your first keycap upgrade. | Visible | `states/shopState.lua` (or wherever the purchase confirmation lands, e.g. `modules/items/` if it owns the buy transaction) — on the first successful purchase, `PlayerModel.stats.moneySpent == 0` before the deduction. |
| `PERFECT_ROUND` | Flawless | Finish a round with zero mistakes. | Visible | `modules/player/playerModel.lua` — wherever `stats.perfectRounds` is incremented (currently the block that checks the round's mistake count is 0 before bumping `perfectRounds`). |
| `FIVE_PERFECT_ROUNDS` | Precision Machine | Finish 5 perfect rounds over your lifetime. | Hidden | `modules/player/playerModel.lua` — same site as `PERFECT_ROUND`, fire when `stats.perfectRounds` reaches 5. |
| `WPM_60` | Speed Typer | Hit 60 WPM in a single round. | Visible | `modules/player/playerModel.lua` — where `stats.bestWPM` is updated from a session's WPM, fire when the new value crosses 60. |
| `WPM_100` | Triple Digit | Hit 100 WPM in a single round. | Visible | Same site as `WPM_60`, threshold 100. |
| `WPM_150` | Inhuman | Hit 150 WPM in a single round. | Hidden | Same site as `WPM_60`, threshold 150. |
| `STREAK_50` | In The Zone | Reach a 50-keystroke correct streak. | Visible | `modules/typing/trainer.lua` — where `self.longestStreak` is updated (line ~91 today), fire when it crosses 50. Mirror in `modules/player/playerModel.lua` if `stats.bestStreak` is the canonical source instead. |
| `STREAK_200` | Unbroken | Reach a 200-keystroke correct streak. | Hidden | Same site as `STREAK_50`, threshold 200. |
| `ACCURACY_SURGEON` | Surgeon's Hands | 100% accuracy over 100+ keystrokes in one round. | Hidden | `modules/player/playerModel.lua` — round-end stat commit; check `sessionStats.accuracy == 100 and sessionStats.keystrokes >= 100` before it's folded into lifetime stats. |
| `FIRST_RARE_ITEM` | Ooh Shiny | Install a keycap of rare rarity or better. | Visible | `modules/items/` — the install/equip step (wherever a purchased item is applied to the keyboard), check `item.rarity` against `Theme.rarityOrder` position >= `"rare"`. |
| `FIRST_LEGENDARY` | Grail Cap | Install a legendary keycap. | Visible | `modules/items/` — same install site, `item.rarity == "legendary"`. |
| `FULL_LEGENDARY_BOARD` | All That Glitters | Every installed key is legendary rarity. | Hidden | `modules/items/` or `modules/keyboard/keyboardModel.lua` — after any install, scan all occupied keys; fire only if none are below legendary. |
| `SET_COMPLETE` | Matched Set | Complete a full keycap set bonus (the `"set"` effect kind activates). | Visible | `modules/items/` — wherever `effect.kind == "set"` bonuses are evaluated as active (the set-completion check itself, not just having one set piece). |
| `HOME_ROW_HERO` | Home Row Hero | Install a full home-row set (A S D F G H J K L on QWERTY). | Hidden | `modules/items/` — same install site as `SET_COMPLETE`; check that every home-row key slot is occupied. |
| `BOSS_ROUND_CLEAR` | Boss Key | Clear your first boss round. | Visible | `modules/game/run.lua` — the boss-round-clear branch (every 3rd round per the run structure), on gate success when the round carried a mutator. |
| `NO_BACKSPACE_CLEAR` | No Backsies | Clear a round with the `"no_backspace"` mutator active. | Hidden | `modules/game/run.lua` — round-clear check where `run.currentMutator == "no_backspace"`. |
| `DECAYING_TEXT_CLEAR` | Race The Fade | Clear a round with the `"decaying_text"` mutator active. | Hidden | `modules/game/run.lua` — same site, `run.currentMutator == "decaying_text"`. |
| `TIMED_BURST_CLEAR` | Burst Fire | Clear a round with the `"timed_burst"` mutator active. | Hidden | `modules/game/run.lua` — same site, `run.currentMutator == "timed_burst"`. |
| `CRIT_STREAK` | Critical Hit | Land 10 crits in a single round. | Hidden | `modules/keyboard/keyboardModel.lua` — `computeKeyScore`'s caller accumulates `procs.crit` per keystroke; fire when a per-round crit counter hits 10 (the counter itself belongs wherever the round tallies `procs`, e.g. `modules/typing/trainer.lua`). |
| `MONEY_1000` | Capitalist | Earn 1000 total coins over your lifetime. | Visible | `modules/player/playerModel.lua` — wherever `stats.moneyEarned` accumulates, fire when it crosses 1000. |
| `HUNDRED_SESSIONS` | Dedicated | Play 100 sessions. | Hidden | `modules/player/playerModel.lua` — wherever `stats.totalSessions` increments, fire when it crosses 100. |

## Notes for implementers

- Prefer firing the achievement call at the same statement that already
  updates the underlying stat/threshold — do not add a second read of player
  state elsewhere just to check achievement conditions.
- `Steam.unlockAchievement` takes only an id; it does not need
  `Steam.isAvailable()` checked first, and it does not throw when Steam is
  absent (the normal case for this repo). Call it unconditionally at the
  trigger point.
- Call `Steam.store()` after a batch of unlocks (e.g. once at round-end,
  once at run-end) rather than after every single call — see
  `docs/STEAM_CHECKLIST.md` and `modules/steam/steam.lua` for the queuing
  contract.
- Mutator identifiers (`no_backspace`, `decaying_text`, `timed_burst`) are
  the exact strings defined in the shared batch brief and owned by
  `modules/game/run.lua` (unit 12) — match them verbatim.
- If a listed trigger site doesn't exist yet in the exact form described
  (module layout may differ slightly once other units land), use the nearest
  equivalent and keep the id and condition the same — the id is the contract
  with Steamworks, not the file path.
