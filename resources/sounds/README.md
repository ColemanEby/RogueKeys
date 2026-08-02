# resources/sounds

`modules/audio/audio.lua` synthesizes every sound procedurally at
`Audio.init()`, so the game ships with audio even though the licensed packs
below cannot be downloaded automatically. Drop a real file in this folder
using the exact name below and it is used automatically instead of the
synthesized fallback — **no code change required**. `.wav` is checked before
`.ogg` for one-shot SFX; music checks `.ogg` before `.wav`.

## One-shot SFX (`<name>.wav` or `<name>.ogg`)

| Filename | Used for |
|---|---|
| `key_linear.wav` | Keystroke thock, linear switch |
| `key_tactile.wav` | Keystroke thock, tactile switch |
| `key_clicky.wav` | Keystroke thock, clicky switch |
| `error.wav` | Wrong key pressed |
| `coin.wav` | Purchase / coin gained |
| `crit.wav` | Crit proc sting |
| `ui_move.wav` | Menu cursor move |
| `ui_confirm.wav` | Menu confirm |
| `ui_back.wav` | Menu back/cancel |
| `streak.wav` | Streak milestone |
| `round_complete.wav` | Round complete |
| `game_over.wav` | Game over |

## Music (`music_<track>.ogg` or `music_<track>.wav`, looping)

| Filename | Used for |
|---|---|
| `music_menu.ogg` | Main menu |
| `music_game.ogg` | In-round gameplay |
| `music_shop.ogg` | Shop |

If a music file is missing, that track plays silence rather than a
synthesized loop — a bad generated loop is worse than no music. With
`_G.DEBUG_MODE` on, missing tracks are logged once at init.

## Where to get the real assets (from the Steam-MVP roadmap shopping list)

All CC0 unless noted; keep license files alongside anything requiring
attribution and add it to `CREDITS.txt`.

- **Key thocks** — filter freesound.org for `License: CC0` mechanical
  keyboard recordings, or synthesize your own with
  [jsfxr](https://sfxr.me/) / [ChipTone](https://sfbgames.itch.io/chiptone)
  (both export CC0). Slice/trim to a single short strike per switch type.
- **UI / coin / stinger sounds** — [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds),
  [Kenney UI Audio](https://kenney.nl/assets/ui-audio),
  [Kenney Music Jingles](https://kenney.nl/assets/music-jingles) (all CC0).
- **Music** — [Three Red Hearts — Prepare to Dev](https://tallbeard.itch.io/three-red-hearts-prepare-to-dev)
  by Tallbeard/Abstraction, 24 seamless chiptune loops, explicitly CC0. Pick
  one loop each for menu/game/shop and rename to the filenames above.
  Backup: Abstraction's 100-loop bundle (attribution requested) or Kevin
  MacLeod (CC-BY, needs a credit line).

## Adding a new sound name

If a caller reaches for `Audio.playSfx("something_new")` that isn't in the
list above, it is a safe no-op (no sound plays) until both a synthesis
recipe is added to `SFX_SYNTH` in `modules/audio/audio.lua` and/or a real
file is dropped in here under that name.
