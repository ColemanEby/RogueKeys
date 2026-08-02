# RogueKeys

A typing-roguelite built on LÖVE 11.5. Type to fight the clock, earn money
each round, and spend it in the shop on keycap upgrades that change how your
keyboard scores. `steammvproadmap.md` in the repo root is the living plan for
taking this from prototype to a Steam release — read it for the full picture
of where the project is headed.

## Features

- **Typing Practice**: progressively challenging text, WPM/APM/accuracy/streak
  tracking
- **Roguelike Progression**: earn money and upgrade keys on your keyboard
- **Statistics Tracking**: match history and lifetime stats, with a
  session-over-session graph
- **Customizable Keyboards**: QWERTY and Dvorak layouts, per-key upgrades
- **Visual Feedback**: on-screen keyboard reflects your upgrades as you type

## Running the game

Install [LÖVE 11.5](https://love2d.org/) and run:

```
love .
```

No install available or don't want one? `tools/get-love.ps1` fetches a
portable copy (no admin rights) and prints the path to `love.exe`:

```powershell
$love = pwsh tools/get-love.ps1   # or: powershell tools/get-love.ps1
& $love .
```

## Running the tests

The pure-logic suite runs headless (no window, no audio) and is the fast
feedback loop for anything that isn't visual:

```powershell
& $love . --test
```

Every `tests/test_*.lua` file is auto-discovered — see `tests/helpers.lua`
for the assertion library and `tests/test_foundation.lua` /
`tests/test_steam.lua` for examples.

For a visual check of a specific screen, use the screenshot mode (boots the
game, switches to the named state, captures one frame, quits):

```powershell
& $love . --shot menuState
```

The PNG lands under `%APPDATA%\LOVE\RogueKeys\screenshots\`.

## Building

`tools/build.ps1` produces a distributable build:

```powershell
pwsh tools/build.ps1            # or: powershell tools/build.ps1
pwsh tools/build.ps1 -Clean     # wipe dist/ first
pwsh tools/build.ps1 -LovePath "C:\path\to\love.exe"
```

It stages the game source (excluding dev-only files), zips it to
`dist/RogueKeys.love`, verifies the zip actually boots by running it with
`--test`, then fuses it onto the LÖVE runtime to produce
`dist/win64/RogueKeys.exe` alongside LÖVE's DLLs and license. It downloads a
LÖVE runtime via `tools/get-love.ps1` if `-LovePath` isn't given, and exits
non-zero on any failure. `dist/` is gitignored — nothing under it should be
committed.

## Keyboard Sprites

The game can use sprites for keyboard keys if you provide a sprite sheet.
The legacy 16x16 sheet goes at:

```
resources/sprites/keyboard_letters_and_symbols.png
```

(128x224 pixels, an 8x14 grid; mapping defined in
`modules/keyboard/keySpriteMapper.lua`.) If no sprite sheet is found, the
game falls back to shape-based key rendering — nothing crashes without art.

## Adding assets

The licensed art/font/audio packs referenced in `steammvproadmap.md` and
`CREDITS.txt` aren't bundled in this repo, but the loaders check for them
automatically and fall back to procedural placeholders when absent. Drop
real assets in and restart — no code changes needed:

```
resources/fonts/                    # monogram (typing line), m6x11 (display)
resources/sprites/keycaps_32.png    # 32px keycap sheet (Phase 2 rendering)
resources/sounds/                   # key thocks, UI/coin SFX, music loops
```

## Directory Structure

```
.
├── engine/                 # Game engine components
│   ├── configManager.lua   # Configuration management
│   ├── resourceManager.lua # Asset management (sprites, fonts, sounds)
│   └── stateManager.lua    # Game state management
├── modules/                # Game modules
│   ├── audio/              # Audio facade (Audio.playSfx/playMusic/...)
│   ├── game/                # Shared game context (Context.player(), Context.run)
│   ├── keyboard/           # Keyboard-related modules
│   │   ├── keyboardModel.lua  # Data model for keyboards
│   │   ├── keyboardView.lua   # Visual representation of keyboards
│   │   └── keySpriteMapper.lua # Sprite mapping for keyboard keys
│   ├── player/             # Player-related modules
│   │   └── playerModel.lua # Player progression and stats
│   ├── steam/              # Optional Steamworks wrapper (no-ops without luasteam)
│   ├── typing/             # Typing mechanics
│   │   ├── textGenerator.lua # Text generation for typing challenges
│   │   └── trainer.lua       # Core typing trainer functionality
│   ├── ui/                 # UI components, theme and the logical canvas
│   │   ├── menuBuilder.lua # Menu building system
│   │   ├── screen.lua      # 640x360 logical pixel canvas
│   │   └── theme.lua       # Colors, fonts, spacing — the only source of both
│   └── util/               # Serialization, file I/O, stat helpers
├── states/                 # Game states
│   ├── menuState.lua       # Main menu
│   ├── roundState.lua      # Typing round gameplay
│   ├── shopState.lua       # Upgrade shop
│   └── statsState.lua      # Statistics display
├── resources/              # Game assets (see "Adding assets" above)
│   ├── sprites/            # Image assets
│   ├── fonts/              # Font assets
│   └── sounds/             # Sound assets
├── data/                   # Game data
│   └── words.txt           # Word list for text generation
├── tests/                  # Headless logic test suite (`love . --test`)
├── tools/                  # Dev tooling (get-love.ps1, build.ps1)
├── docs/                   # Steam release checklist, achievements spec
├── main.lua                # Main entry point
├── conf.lua                # LÖVE window/identity configuration
├── steammvproadmap.md      # The living plan to a Steam-ready build
└── README.md               # This file
```

## Controls

- **Typing**: Type the displayed text
- **Backspace**: Delete the last character
- **Enter/Return**: Complete the round
- **Arrow keys**: Navigate menus
- **Escape**: Return to previous menu

## Progression

1. **Earn Money**: Complete typing rounds to earn money based on your score
2. **Upgrade Keys**: Visit the shop to upgrade specific keys on your keyboard
3. **Challenge Yourself**: Progress through increasingly difficult rounds
4. **Track Your Progress**: View your statistics to see your improvement

## Player Save Structure

```lua
-- $HOME/.local/share/love/RogueKeys/save/player.lua
return {
    totalMoney = 85,
    currentRound = 2,
    maxRoundReached = 2,
    level = 1,
    matchHistory = {
        [1] = { timestamp = 1741116286, wpm = 0.00, accuracy = 0.00, keystrokes = 0, mistakes = 0, apm = 0.00 },
        [2] = { timestamp = 1741116284, wpm = 46.73, accuracy = 100.00, keystrokes = 71, mistakes = 0, apm = 233.64 },
        [3] = { timestamp = 1741116256, wpm = 0.00, accuracy = 0.00, keystrokes = 0, mistakes = 0, apm = 0.00 },
    },
    keyboard = {
        layoutType = "qwerty",
        name = "QWERTY",
        upgrades = {
        },
        multiplier = 1,
        description = "Standard QWERTY keyboard layout",
    },
    stats = {
        moneyEarned = 70,
        totalKeystrokes = 71,
        bestAPM = 233.63689449259,
        bestAccuracy = 100,
        bestStreak = 71,
        roundsWithoutError = 1,
        perfectRounds = 1,
        moneySpent = 0,
        totalSessions = 3,
        bestWPM = 46.727378898519,
        totalPlayTime = 20.138336843,
        totalMistakes = 0,
        totalCorrect = 71,
    },
    selectedKeyboardLayout = "qwerty",
}
```

```lua
-- $HOME/.local/share/love/RogueKeys/config/progression.lua
return {
    moneyMultiplier = 1,
    roundDifficultyScale = 1.2,
    upgradeBaseCost = 20,
    upgradeMinBonus = 0.05,
    upgradeMaxBonus = 0.3,
    startingMoney = 50,
}
```

```lua
-- $HOME/.local/share/love/RogueKeys/config/game.lua
return {
    windowWidth = 800,
    windowHeight = 600,
    sfxVolume = 0.8,
    volume = 0.7,
    vsync = true,
    transitionDuration = 0.3,
    fullscreen = false,
    showFPS = false,
    musicVolume = 0.5,
}
```

```lua
-- $HOME/.local/share/love/RogueKeys/config/difficulties.lua
return {
    easy = {
        timeLimit = 60,
        baseScorePerChar = 1,
        name = "Easy",
        sentenceLength = 8,
        maxWordSize = 6,
    },
    medium = {
        timeLimit = 45,
        baseScorePerChar = 1.5,
        name = "Medium",
        sentenceLength = 12,
        maxWordSize = 8,
    },
    hard = {
        timeLimit = 30,
        baseScorePerChar = 2,
        name = "Hard",
        sentenceLength = 16,
        maxWordSize = 12,
    },
}
```

```lua
-- $HOME/.local/share/love/RogueKeys/config/keyboards.lua
return {
    qwerty = {
        description = "Standard QWERTY keyboard layout",
        name = "QWERTY",
        layout = {
            {
                {
                    key = "Q",
                    w = 1,
                },
                {
                    key = "W",
                    w = 1,
                },
                {
                    key = "E",
                    w = 1,
                },
                {
                    key = "R",
                    w = 1,
                },
                {
                    key = "T",
                    w = 1,
                },
                {
                    key = "Y",
                    w = 1,
                },
                {
                    key = "U",
                    w = 1,
                },
                {
                    key = "I",
                    w = 1,
                },
                {
                    key = "O",
                    w = 1,
                },
                {
                    key = "P",
                    w = 1,
                },
            },
            {
                {
                    key = "A",
                    w = 1,
                },
                {
                    key = "S",
                    w = 1,
                },
                {
                    key = "D",
                    w = 1,
                },
                {
                    key = "F",
                    w = 1,
                },
                {
                    key = "G",
                    w = 1,
                },
                {
                    key = "H",
                    w = 1,
                },
                {
                    key = "J",
                    w = 1,
                },
                {
                    key = "K",
                    w = 1,
                },
                {
                    key = "L",
                    w = 1,
                },
            },
            {
                {
                    key = "Z",
                    w = 1,
                },
                {
                    key = "X",
                    w = 1,
                },
                {
                    key = "C",
                    w = 1,
                },
                {
                    key = "V",
                    w = 1,
                },
                {
                    key = "B",
                    w = 1,
                },
                {
                    key = "N",
                    w = 1,
                },
                {
                    key = "M",
                    w = 1,
                },
            },
            {
                {
                    key = ",",
                    w = 1,
                },
                {
                    key = ".",
                    w = 1,
                },
                {
                    key = "?",
                    w = 1,
                },
                {
                    key = "!",
                    w = 1,
                },
            },
            {
                {
                    key = "Space",
                    w = 5,
                },
            },
        },
    },
    dvorak = {
        description = "Dvorak simplified keyboard layout",
        name = "Dvorak",
        layout = {
            {
                {
                    key = "'",
                    w = 1,
                },
                {
                    key = ",",
                    w = 1,
                },
                {
                    key = ".",
                    w = 1,
                },
                {
                    key = "P",
                    w = 1,
                },
                {
                    key = "Y",
                    w = 1,
                },
                {
                    key = "F",
                    w = 1,
                },
                {
                    key = "G",
                    w = 1,
                },
                {
                    key = "C",
                    w = 1,
                },
                {
                    key = "R",
                    w = 1,
                },
                {
                    key = "L",
                    w = 1,
                },
            },
            {
                {
                    key = "A",
                    w = 1,
                },
                {
                    key = "O",
                    w = 1,
                },
                {
                    key = "E",
                    w = 1,
                },
                {
                    key = "U",
                    w = 1,
                },
                {
                    key = "I",
                    w = 1,
                },
                {
                    key = "D",
                    w = 1,
                },
                {
                    key = "H",
                    w = 1,
                },
                {
                    key = "T",
                    w = 1,
                },
                {
                    key = "N",
                    w = 1,
                },
                {
                    key = "S",
                    w = 1,
                },
            },
            {
                {
                    key = ";",
                    w = 1,
                },
                {
                    key = "Q",
                    w = 1,
                },
                {
                    key = "J",
                    w = 1,
                },
                {
                    key = "K",
                    w = 1,
                },
                {
                    key = "X",
                    w = 1,
                },
                {
                    key = "B",
                    w = 1,
                },
                {
                    key = "M",
                    w = 1,
                },
                {
                    key = "W",
                    w = 1,
                },
                {
                    key = "V",
                    w = 1,
                },
                {
                    key = "Z",
                    w = 1,
                },
            },
            {
                {
                    key = "?",
                    w = 1,
                },
                {
                    key = "!",
                    w = 1,
                },
            },
            {
                {
                    key = "Space",
                    w = 5,
                },
            },
        },
    },
}
```

## Known Issues

- The stats screen's bar graph (`states/statsState.lua`) computes a
  "reversed" bar position but re-uses the un-reversed match index to look up
  the value, so bars are positioned in one order and colored/sized from
  another. Match history saving, loading and retrieval from `PlayerModel`
  are otherwise working.

See `steammvproadmap.md` (Phase 0, "Stabilize the foundation") for the
broader stabilization scope this and future work is tracked against.

## Extending the Game

The modular architecture makes it easy to extend the game:

- Add new keyboard layouts in `engine/configManager.lua`
- Create new typing challenge modes by extending `modules/typing/textGenerator.lua`
- Add more upgrade types in `modules/keyboard/keyboardModel.lua`
- Implement new game states in the `states/` directory

## License

This project is released under the MIT License.