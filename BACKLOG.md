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
