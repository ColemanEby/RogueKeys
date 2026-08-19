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
- [ ] Remove the legacy 16px sprite mapper `modules/keyboard/keySpriteMapper.lua`
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
