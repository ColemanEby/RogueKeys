# Steam Release Checklist

The operational path to a Steam release, per `steammvproadmap.md` section 8
("Phase 5 — Steam"). This is a manual, human-driven checklist — nothing here
is automated by this batch. Work top to bottom; the dates in the "wait"
column are the reason to start this early, not late.

**Rule of thumb:** pay the fee the moment you have a build you'd be willing
to ship in a pinch, even if content isn't final — the 30-day clock only
starts once you pay it, and it does not care whether you're ready.

## 0. Before you start

- [ ] `tools/build.ps1` produces a working `dist/win64/RogueKeys.exe` (run it,
      confirm the window opens and a round is playable).
- [ ] `CREDITS.txt` is up to date with every shipped asset's license
      (Caz, Kyrise, Shikashi, Daniel Linssen/m6x11, any CC-BY audio).
- [ ] `conf.lua` has `t.identity = "RogueKeys"` — this is the exact string
      Steam Auto-Cloud below is pointed at. Do not change it after players
      have cloud saves.

## 1. Steamworks account

- [ ] Register a Steamworks partner account (separate from a personal Steam
      account) at partner.steamgames.com.
- [ ] Pay the **$100 USD** app fee. It is recouped once the app earns
      **$1,000** in adjusted gross revenue — budget it as a loan, not a cost.
- [ ] Complete identity/tax verification. Budget **2–7 business days** —
      this can stall on paperwork; do it in the same sitting as paying the fee.
- [ ] **Start the 30-day clock now.** Steam enforces a **mandatory 30-day
      wait between paying the fee and being allowed to release the app.**
      Write the earliest possible release date on a calendar the day you pay.

## 2. Store page (can start once the app is created in Steamworks)

- [ ] Write store copy: short description, long description, feature bullets,
      system requirements (LÖVE 11.5 is lightweight — requirements will be
      trivial; still fill in a real Windows minimum).
- [ ] Produce store assets at the **current required dimensions**
      (verify against Steamworks docs before final upload — sizes have
      changed before and will again):
  - [ ] Header capsule — **920 × 430**
  - [ ] Small capsule — **462 × 174**
  - [ ] Main capsule — **1232 × 706**
  - [ ] Vertical capsule — **748 × 896**
  - [ ] Library capsule — **600 × 900**
  - [ ] Library hero — **3840 × 1240**
  - [ ] Logo (transparent PNG, sized to taste, fits within the hero)
  - [ ] Client icon — **256 × 256**
  - [ ] Small icon — **184 × 184**
  - [ ] **5+ screenshots at 1920 × 1080**, real gameplay (not mockups) —
        capture with the Phase 2 juice pass in place, not the debug skin.
  - [ ] Trailer (optional but pages without one measurably underperform) —
        a 30–45s gameplay capture is enough for an MVP.
- [ ] Set the app to **"Coming Soon"** and publish the store page **at least
      2 weeks before the intended launch date**. This is a hard Valve
      requirement, not just marketing advice — plan the 2 weeks to overlap
      with, not follow, the 30-day fee wait.
- [ ] Submit the store page for **store review** (~**3–5 business days**
      turnaround; can bounce back with required fixes — leave slack).

## 3. Build & packaging

- [ ] Run `tools/build.ps1` to produce:
  - `dist/RogueKeys.love`
  - `dist/win64/RogueKeys.exe` + LÖVE's DLLs + `license.txt`
- [ ] Upload the Windows depot via SteamPipe (`steamcmd`/`ContentBuilder`
      scripts, set up separately from this repo's tooling).
- [ ] Set the branch to `default` only once verified on an internal/beta
      branch first — do not publish straight to default.
- [ ] Linux: not required for MVP. Proton runs the LÖVE build fine on Deck
      without a native Linux depot; revisit as a nice-to-have post-launch.
- [ ] Submit the build for **build review** (~**3–5 business days**,
      separate from and in addition to store review).

## 4. Steamworks features

- [ ] **Achievements:** configure each id from `docs/ACHIEVEMENTS.md` in the
      App Admin panel (Stats & Achievements page) — display name,
      description, hidden/visible flag, icon (achieved + not-achieved states,
      typically 64×64). The **id must match exactly** what
      `modules/steam/steam.lua` / `Steam.unlockAchievement(id)` sends.
- [ ] **Stats:** configure any backing stats used by achievement logic
      (e.g. cumulative counters) before wiring up `Steam.setStat`.
- [ ] **Cloud saves — Steam Auto-Cloud (zero code):** in App Admin →
      Cloud, point the save-file root at the LÖVE identity path, i.e. the
      directory `t.identity = "RogueKeys"` in `conf.lua` resolves to
      (`%appdata%\LOVE\RogueKeys\` on Windows). No code changes needed —
      Auto-Cloud syncs the whole directory. Verify it actually syncs by
      testing on two machines (or one machine + Steam's cloud debug page)
      before launch, not after a bug report.
- [ ] **Overlay:** works automatically for LÖVE builds — confirm Shift+Tab
      opens it in the packaged `.exe`, not just in dev.
- [ ] **luasteam integration** (see `modules/steam/steam.lua`): requires a
      real Steamworks appid and a `steam_appid.txt` (or Steam-launched
      process) to initialize — neither exists in this repo today, and
      `Steam.init()` is expected to report unavailable until an appid is
      issued in step 1. Do not treat that as a bug.

## 5. Platform notes

- [ ] **Steam Deck:** a typing game will reasonably rate **"Playable"** or
      **"Unsupported"** on Deck Verified, never "Verified" — an on-screen
      keyboard input method doesn't map well to fast typing. This is fine
      and does not block release; be honest about it in the store
      description rather than implying full Deck support.
- [ ] If claiming any Deck compatibility tier, actually boot it on Deck
      hardware (or the Deck compatibility mode in Steam's dev tools) once
      before launch.

## 6. Pre-launch validation

- [ ] Publish a free **itch.io demo build** (same `dist/win64` output,
      zipped) at least a few weeks before Steam launch. Costs nothing,
      de-risks packaging and surfaces layout/locale bugs early — a typing
      game is unusually exposed to non-QWERTY and non-US keyboard layouts,
      which itch.io playtesters will hit that the dev machine never will.
- [ ] Run the demo through `& $love . --test` and the `--shot` smoke test
      recipe (see repo README) as a final regression pass before zipping.
- [ ] Recruit outside playtesters (not just people who already know the
      controls) during the 2-week Coming Soon window; this is also when
      wishlists accumulate, which materially affects launch-day visibility.

## 7. Launch day

- [ ] Confirm the 30-day post-fee wait has actually elapsed (Steamworks will
      block the release button if not, but don't schedule announcements
      assuming it if you haven't double-checked the date).
- [ ] Flip the app from "Coming Soon" to released at the scheduled time.
- [ ] Watch the first-24-hours crash/error reports and Deck Verified queue.
- [ ] Post-launch: keep `CREDITS.txt` and the in-game credits screen in sync
      with anything added after this checklist was last run.
