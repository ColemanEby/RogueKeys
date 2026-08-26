# Backlog

Swept by the `quota-sweeper` automation (see
`~/server_awakening/automations/quota-sweeper/`). Format: `- [ ]` open
(top = highest priority), `- [x]` done, `- [!]` blocked. Items must be small,
self-contained, and mechanically verifiable.

Verification gate for every item (headless test suite, 278 tests currently green):
`cd /data/code/RogueKeys && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . --test`
must end with `ALL TESTS PASSED`.

Roadmap context: `steammvproadmap.md`. Phase 0 is essentially complete in code;
open items below start on Phase 1 (visual foundation) where mechanically
verifiable, plus doc sync.

## Open

- [x] Harden the CI LOVE download — `.github/workflows/ci.yml` fetches the (promoted from PROPOSED.md, 2026-08-23) (done 2026-08-24, codex, ledger #524 + fix round #526; copilot cross-review #525 REQUEST_CHANGES — the hash check sat inside the cache-miss guard so a restored cache was never verified, and a cache restore that dropped the mode bit would fail the test step; the fix round caches the AppImage alongside squashfs-root, verifies the SHA-256 on every run, extracts only on a miss and chmods the binary unconditionally; the sweeper computed the pinned hash 65a67340...5e00 itself from a real download of the URL in the workflow, so the value in CI is verified, not asserted; yamllint clean, suite still 298 green)
- [x] Build the procedural starfield background — roadmap Phase 1 item 6 (promoted from PROPOSED.md, 2026-08-23) (done 2026-08-25, codex, ledger #535; commit f06e507; copilot cross-review #536 APPROVE — it traced the seeding and confirmed determinism is real: the module uses a self-contained Park-Miller PRNG and never touches `math.random`, so a same-seed regeneration cannot be perturbed by another module; non-blocking notes left for later — the same-seed test does not disturb the global RNG between the two calls to prove that independence, and the different-seeds test asserts only the first star differs; bounds come from `Screen.getDimensions()`, colors from Theme, `Background.draw(animTime)` runs first in `MenuState.draw()` so it paints behind the menu; suite 298 -> 303 green)
- [x] Add per-offer lock to the shop — the last unbuilt piece of roadmap Phase 3 (promoted from PROPOSED.md, 2026-08-23) (done 2026-08-25, copilot, ledger #540 + fix round #542; codex attempt #539 produced no diff — it stopped at the brainstorming approval gate, so the retry brief pre-approved the design; codex cross-review #541 REQUEST_CHANGES on test honesty — all three findings were real: every lock test drove only the exported pure helpers, so a revert of `performReroll`/`resetState` would have stayed green. The fix round drives the live call sites through `ShopState.enter`/`keypressed` and asserts exact money deduction and 5/8 escalation across a fully locked board. The sweeper mutation-probed it: reverting the merge line fails 2 cases, dropping `clearOfferLocks(offers)` from `resetState` fails 1. Suite 303 -> 311 green)
- [x] Wire the fifth and final achievement batch, closing `docs/ACHIEVEMENTS.md` (promoted from PROPOSED.md, 2026-08-23) (done 2026-08-26, codex, ledger #555; commit 936ea6c. ACHIEVEMENTS.md is now 24/24 wired — a loop over every id in the spec finds each one under modules/ or states/. SET_COMPLETE and HOME_ROW_HERO fire at the real install site in `ShopState.purchaseOffer` through two new `KeyboardModel` predicates: `hasCompleteSet()` reuses the same rule as `Effects.set` (every id in `effect.setMembers` installed) rather than inventing a second one, and `isHomeRowComplete()` checks the nine home-row slots. CRIT_STREAK runs off a per-round `critCount` reset in `TypingTrainer.new` and incremented where `procs.crit` was already handled; HUNDRED_SESSIONS fires on the 99->100 crossing in `endSession`. The sweeper mutation-probed six lines itself: deleting each of the four unlocks fails 1 test each, and weakening either threshold (10 crits -> 9, 100 sessions -> 99) also fails 1 — so the tests pin the thresholds, not just the presence of a call. copilot cross-review #556 REQUEST_CHANGES with one major finding, `hasCompleteSet` dereferencing `item.effect` without a nil guard; judged unreachable and not applied — `installItem` asserts `item.effect.kind` (keyboardModel.lua:296), nothing outside the model writes `installedItems`, and pre-existing line 304 dereferences the same field the same way. Suite 327 -> 331 green.)
- [x] Wire the fourth achievement batch — the boss/mutator round-clear group, (promoted from PROPOSED.md, 2026-08-23) (done 2026-08-26, copilot, ledger #553; commit 21c1c5f; codex cross-review #554 APPROVE, no findings. The spec named a `run.currentMutator` field that does not exist — the brief redirected the implementer to `Run:getMutators(round)`, read against the pre-increment local `round` so the unlock is attributed to the round actually cleared, and gated on the `passed` path only (the adjacent `FIRST_RUN_COMPLETE` block fires on failure too, and these must not). The sweeper mutation-probed all four new lines itself: dropping `BOSS_ROUND_CLEAR` fails 3 tests, each mutator-specific unlock fails 1 — so the tests drive the real `Run.new`/`submitScore` pipeline, not helpers. Suite 322 -> 327 green. First attempt codex #552 produced no diff — it stopped at a design-approval gate — so the retry brief pre-approved the design.)
- [x] Wire the third achievement batch — the item/rarity group: (promoted from PROPOSED.md, 2026-08-22) (done 2026-08-25, codex, ledger #548; copilot cross-review #549 APPROVE, two minor non-blocking notes — `Steam.store()` sits outside the `applied` guard (a harmless no-op flush when nothing was queued, and it matches how playerModel.lua:298 flushes) and `Rarity.index("rare")` is recomputed per purchase. All three unlocks fire at the real install site in `purchaseOffer`, rarity is compared through the existing `Rarity.index` ordering rather than a new hard-coded list, and `KeyboardModel:isFullyLegendary()` returns false on an empty board. The sweeper mutation-probed all four new lines itself: dropping the `FIRST_RARE_ITEM` unlock fails 3 cases, `FIRST_LEGENDARY` 1, `FULL_LEGENDARY_BOARD` 1, and removing the empty-board guard 1 — so the tests drive the live shop pipeline, not helpers. Suite 316 -> 322 green)
- [x] Sync the docs with reality: (a) annotate `steammvproadmap.md` sections (promoted from PROPOSED.md, 2026-08-22) (done 2026-08-26, codex, ledger #557 + fix round #559. Roadmap DONE count 11 -> 21; sections 6-7 went from zero markers to 10. The sweeper checked every cited path exists and spot-checked the claims: 6.7 (balance pass) and 7.2 (music assets) were correctly left unannotated, and 7.1 carries an explicit "sound assets are still unbundled" caveat rather than claiming shipped audio. copilot cross-review #558 REQUEST_CHANGES with three findings; two applied, one rejected. Applied: 6.1's marker trailed a list-introducing colon, and 6.6 blanket-claimed an item whose second half — "unlockable cosmetic board themes/layouts (Dvorak as an unlock)" — is not built, so the marker now scopes itself to the stats half and says plainly the cosmetic unlocks are absent. Rejected: the review called 6.2 an overclaim for citing no endless-mode evidence, but endless mode is real — `Run:nextTier()` at run.lua:169, per-tier gate scaling at run.lua:20, and `continueEndless()` behind a "Continue (Endless)" entry at victoryState.lua:113-135. README's stale "Keyboard Sprites" section now describes the live 32px path (`resources/sprites/keycaps_32.png`, capRenderer.lua:49) instead of the mapper deleted 2026-08-19. Doc-only; suite unchanged at 331 green.)
- [x] Add a packaging job to `.github/workflows/ci.yml` that runs (promoted from PROPOSED.md, 2026-08-22) (done 2026-08-26, codex, ledger #560. A second job `package`, gated `needs: test`, checks out, runs `bash tools/build.sh`, and uploads `dist/RogueKeys.love` via `upload-artifact@v4` with `if-no-files-found: error`. CI artifact only — no publishing, no Steam upload, no secrets or permissions block added. The diff is 19 lines, all additions appended after the test job; the sweeper parsed the YAML and asserted the structure directly rather than trusting a lint (jobs = [test, package], `package.needs` = test, the three steps and all three `with:` keys exact, and the test job still at its original 8 steps) because neither yamllint nor actionlint is installed on this box. `bash tools/build.sh` was run for real: exits 0, prints BUILD OK, and the zip contains both main.lua and conf.lua. copilot cross-review #561 REQUEST_CHANGES with one major — that build.sh could fail on a clean runner because git does not recreate empty directories — checked and rejected: all seven required dirs carry tracked files (`git ls-files` gives engine 3, modules 21, states 11, lib 1, data 1, resources 1, tests 24), so a fresh checkout recreates every one, and the suggested `mkdir -p` fix would have masked build.sh's own "required path is missing" guard. Worth knowing: `resources/` survives a clean clone on the strength of a single tracked file, `resources/sounds/README.md`. Suite unchanged at 331 green.)
- [x] Smoke-test `states/fallbackMenuState.lua` — it is the only one of the 11 (promoted from PROPOSED.md, 2026-08-22) (done 2026-08-26, copilot, ledger #563; commit d1dedf5. `tests/test_fallback_menu.lua` covers construction, `StateManager.createState` wrapping, `enter`, up/down wrap-around, all three confirm keys on both entries, `f1`, and the non-primary-button `mousepressed` no-op, with `StateManager.switch` and `love.event.quit` stubbed in setup/teardown (a real quit would kill the test process). Suite 331 -> 338 green. `draw()` and primary-button `mousepressed()` are deliberately uncovered: headless `Theme.font()` returns nil, so `draw()` calls `love.graphics.setFont(nil)` and crashes LOVE at the C level (exit 139, uncatchable by pcall) — the first attempt, codex #562, covered them and core-dumped the run, which is why it was retried with copilot. The sweeper mutation-probed the state itself: narrowing the confirm keys to `return` only fails 1 case, changing the `up` wrap from `#menuItems` to `1` fails 2 — so the tests drive `keypressed`, not their own stubs. codex cross-review #564 REQUEST_CHANGES; both findings judged real but non-blocking and not applied — the suite leaves `selectedItem`/`showDebugInfo` mutated (no other suite requires this module and every case probes the selection rather than assuming it) and the createState contract case asserts only `update`. Both are reopened as the follow-up item below.)

- [x] Follow-up from the fallback-menu smoke test (codex review #564, 2026-08-26): restore `selectedItem`/`showDebugInfo` in `tests/test_fallback_menu.lua`'s teardown and widen the createState contract case (done 2026-08-26, codex, ledger #565; commit cadd4b4; copilot cross-review #566 APPROVE, no findings. Both locals are private upvalues of the module's `keypressed`, and `showDebugInfo` is unobservable through the public API headless, so teardown finds each by name with `debug.getupvalue` and resets it with `debug.setupvalue` to a pristine value captured at suite-load time rather than hard-coded. A new case mutates both through `keypressed` ("up", "f1"), calls `teardown()` and asserts the reset; it is idempotent under the runner's per-case teardown (run.lua:188-207) and presses no key after the `love.event.quit` stub is removed. The contract case now asserts all eight handlers `createState` supplies (stateManager.lua:59-66) and calls the five wrapper-defaulted ones; `draw` is type-checked but never invoked. The sweeper mutation-probed the crux itself: deleting either restore line from teardown fails exactly 1 test each, so the new case pins the restores rather than its own helpers. Suite 338 -> 339 green. NOT done, deliberately: the companion nil-font guard in `FallbackMenuState.draw()` is production code and stays an operator decision — `draw()` still hard-crashes the process (exit 139) when `Theme.font()` returns nil, which is exactly the failure mode the crash-recovery state should survive.)
- [x] Wire the second achievement batch — the run/economy lifecycle group from (promoted from PROPOSED.md, 2026-08-22) (done 2026-08-25, codex, ledger #543; copilot cross-review #544 APPROVE, no findings; all five sites match the ACHIEVEMENTS.md rows exactly — `FIRST_RUN_COMPLETE` fires on complete-or-failed per the spec's "win or lose" (:27), `VICTORY_RUN` on the victory branch only, `FIRST_ROUND_COMPLETE` gated on `totalSessions == 0` before `endSession`, `FIRST_PURCHASE` on `moneySpent == 0` before the deduction (`spendMoney` increments it at playerModel.lua:335), `MONEY_1000` on the lifetime crossing rather than a single session. The sweeper mutation-probed all four new gameplay lines: deleting any one fails exactly one test, so the tests drive the real call sites, not helpers. Suite 311 -> 316 green)
- [x] Delete the dead `modules/util/statTrackingIntegration.lua` and `modules/util/statVerifier.lua` (promoted from PROPOSED.md, 2026-08-18; NOTE: the promoted line was truncated — full spec in PROPOSED.md) (done 2026-08-18, copilot, ledger #454; commit c9719c6; cross-review opencode #455 APPROVE, no findings; suite 303 -> 302, the dropped test asserted only the deleted module)
- [x] Make a failed test bootstrap fail the run. `runTests()` in `main.lua:86-101` (promoted from PROPOSED.md, 2026-08-18) (done 2026-08-18, codex, ledger #460; commit e16eabf; cross-review opencode #461 APPROVE; bootstrap failure now prints ERROR + love.event.quit(1) and skips the suite; 302 tests still green)
- [x] Wire the first batch of achievement triggers from `docs/ACHIEVEMENTS.md` (done 2026-08-18, copilot, ledger #448; commit 800bb6f; cross-review opencode #449 APPROVE; 9 triggers wired, suite 294 -> 303; first codex attempt #447 produced no diff — stopped to ask for design approval)
  — the spec lists 24 achievements with exact trigger sites, `Steam.unlockAchievement`
  (modules/steam/steam.lua:72) is idempotent and safe headless, yet as of
  2026-08-16 zero gameplay modules call it (the only callers are
  tests/test_steam.lua). Start with the stat-threshold group whose sites already
  exist: `FIRST_KEYSTROKE` and `STREAK_50`/`STREAK_200` in
  `modules/typing/trainer.lua`, and `PERFECT_ROUND`, `FIVE_PERFECT_ROUNDS`,
  `WPM_60`/`WPM_100`/`WPM_150`, `ACCURACY_SURGEON` at the stat-commit sites in
  `modules/player/playerModel.lua` (spec rows 25, 30-37 name each site); add
  cases to `tests/test_steam.lua` exercising each trigger through the real stat
  pipeline.
  - files: modules/typing/trainer.lua, modules/player/playerModel.lua,
    tests/test_steam.lua, docs/ACHIEVEMENTS.md (reference only)
  - acceptance: `cd /data/code/RogueKeys && grep -rn "unlockAchievement" modules/typing/trainer.lua modules/player/playerModel.lua | wc -l` prints >= 6;
    `cd /data/code/RogueKeys && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . --test` ends with `ALL TESTS PASSED` and a count > 294
  - source: audit
- [x] Add `tools/build.sh` producing `dist/RogueKeys.love` (done 2026-08-19, codex, ledger #462) (zip of main.lua,
  conf.lua, engine/, modules/, states/, lib/, data/, resources/, tests/ —
  tests/ kept so the acceptance run below works; exclude tools/, docs/, .github/)
  — the only build path today is Windows-only `tools/build.ps1`, so there is
  no way to package a build from this Linux box or from CI, and
  `docs/STEAM_CHECKLIST.md` step 0 depends on a runnable build. Optionally add
  an artifact-upload step to `.github/workflows/ci.yml`.
  - files: tools/build.sh, .github/workflows/ci.yml (optional)
  - acceptance: `cd /data/code/RogueKeys && bash tools/build.sh` exits 0;
    `unzip -l /data/code/RogueKeys/dist/RogueKeys.love | grep -c "main.lua"` prints >= 1;
    `cd /data/code/RogueKeys && timeout 120 env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love dist/RogueKeys.love --test` ends with `ALL TESTS PASSED`
  - source: hygiene
- [x] Sync `steammvproadmap.md` sections 4–5 with reality (done 2026-08-19, codex, ledger #464; commit 3bfd416; opencode cross-review #465 APPROVE; DONE count 7 -> 11, 302 tests green), matching the Phase 0
  DONE-annotation style: Phase 1 items 1 (virtual 640×360 canvas —
  `modules/ui/screen.lua`, all 10 opt-in states converted), 2 (theme —
  `modules/ui/theme.lua` + `tests/test_theme.lua`), and 5 (state fades —
  `engine/stateManager.lua` + `tests/test_state_manager.lua`) are implemented,
  as is Phase 2's layered 32px keycap rendering (`modules/keyboard/capRenderer.lua`,
  `keyboardView.lua`). Doc-only change citing the satisfying file per item.
  - files: steammvproadmap.md
  - acceptance: `grep -c "DONE" /data/code/RogueKeys/steammvproadmap.md` prints >= 11 (currently 7);
    `cd /data/code/RogueKeys && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . --test` ends with `ALL TESTS PASSED`
  - source: audit
- [x] Migrate the last two hardcoded `love.graphics.setColor(<numeric>)` calls (done 2026-08-19, opencode, ledger #469; commit 071b27d; codex cross-review #470 APPROVE; suite 302 -> 304; first codex attempt #468 produced no diff — asked for design approval, cf. #447)
  in `engine/stateManager.lua` (line 300: fade overlay `(0, 0, 0, transitionAlpha)`;
  line 326: pause dim `(0, 0, 0, 0.55)`) to `modules/ui/theme.lua` references —
  the theme sweep is otherwise complete (states/ and modules/ are clean as of
  2026-08-16), so this finishes it.
  - files: engine/stateManager.lua, modules/ui/theme.lua
  - acceptance: `cd /data/code/RogueKeys && grep -rn "setColor(0" states/ modules/ engine/ | grep -v theme` prints nothing;
    `cd /data/code/RogueKeys && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . --test` ends with `ALL TESTS PASSED`
  - source: lint
- [x] Remove the legacy 16px sprite mapper `modules/keyboard/keySpriteMapper.lua` (done 2026-08-19, opencode, ledger #471; commit 60d424b; codex cross-review #472 APPROVE; suite 304 -> 298, 0 failed; both 16px sheets and the dead resourceManager load block removed; README.md:81 still lists the deleted PNG — doc-only leftover for the operator)
  — the 32px `capRenderer.lua`/`keyboardView.lua` path replaced it in game
  code; its only remaining consumers are `tests/test_keycaps.lua` and
  `tests/test_integration.lua` (confirmed 2026-08-16). Delete the module, drop
  or port the test cases that exercise it, and remove any 16px sheet in
  `resources/sprites/` it exclusively references (verify
  `keyboard_letters_and_symbols.png` / `keyboard_extras.png` usage before
  deleting).
  - files: modules/keyboard/keySpriteMapper.lua, tests/test_keycaps.lua,
    tests/test_integration.lua, resources/sprites/
  - acceptance: `cd /data/code/RogueKeys && grep -rn "keySpriteMapper" --include="*.lua" .` prints nothing;
    `cd /data/code/RogueKeys && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . --test` ends with `ALL TESTS PASSED`
  - source: hygiene

- [!] blocked: needs human (commits the operator's own uncommitted WIP; dispatch runs in an isolated worktree that cannot see it, and unreviewed operator work must not be auto-committed) (2026-08-15) Clean up working tree. Review the uncommitted changes in this repo, group them into logical commits with clear messages, do not push, and flag anything that needs operator judgment in the commit body (queued from hub, 2026-08-14)
- [x] Sync `steammvproadmap.md` with reality: Phase 0 items already implemented (done 2026-08-10, copilot, ledger #211 + fix round #213; codex cross-review #212)
  (setup.lua removed, serializers replaced, DEBUG_MODE unified, test harness with
  278 cases exists) should be annotated as DONE in section 3, citing the
  file/module that satisfies each. Doc-only change; test suite must still pass.
- [x] Phase 1 item 2 (theme module): create `modules/ui/theme.lua` exporting a
  single table of palette colors, font sizes, and spacing; migrate hardcoded
  `love.graphics.setColor(<numeric literals>)` calls in `states/` and
  `modules/` to theme references. Behavior-preserving (same effective values).
  Add a `tests/test_theme.lua` suite asserting the theme table's shape and that
  required keys exist. Full test suite must pass. (done 2026-08-10, copilot,
  ledger #216; theme.lua + migration pre-existed — remaining literals are
  white resets/computed gradients — so scope was the test suite: 12 tests,
  290 total pass; codex cross-review #217 approved the tests, its one finding
  was the embed-diff HEAD~1 artifact)
- [x] Phase 1 item 5 (state transitions): finish the stubbed fade in the state (done 2026-08-10, codex, ledger #226; commit 26618f9; fade pre-existed — roadmap note stale — scope was the 4 missing tests + a headless drawTransition guard; 294/294 pass; cursor cross-review #227 APPROVE)
  manager (roadmap says ~80% written) with a 0.2s fade; add tests in
  `tests/test_state_manager.lua` covering transition start/completion and that
  update/draw are safe headless during a fade. Full test suite must pass.

## Done

## Blocked

- [!] blocked: needs human — Lua gate requires `luacheck`, but the box has no luacheck/luarocks/lua/pip and installing needs sudo/apt (system config change the sweeper won't make). Install luacheck, then reopen. (2026-08-12) — Adopt the cc-orch standards pack (/data/code/cc-orch/standards/): add the lint/format/pre-commit gates matching this repo's toolchain (see STANDARDS.md table), fix or explicitly waive existing findings, and record the exact check commands here as this repo's standing acceptance gates. Acceptance: every gate command from the STANDARDS.md row for this toolchain exits 0 from a fresh checkout.
