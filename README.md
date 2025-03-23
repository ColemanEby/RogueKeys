# Typing Trainer Roguelike

A typing practice game with roguelike progression elements. Improve your typing speed and accuracy while upgrading your keyboard.

## Features

- **Typing Practice**: Test and improve your typing skills with progressively challenging text
- **Roguelike Progression**: Earn money and upgrade keys on your keyboard
- **Statistics Tracking**: Track your progress with detailed stats and visualizations
- **Customizable Keyboards**: Choose different keyboard layouts and upgrade specific keys
- **Visual Feedback**: See your keyboard on screen with visual feedback as you type

## Setup

1. Install the [LÖVE Framework](https://love2d.org/) (version 11.x recommended)
2. Clone this repository
3. Run the setup script (optional but recommended):
   ```
   lua setup.lua
   ```
4. Run the game:
   ```
   love .
   ```

## Keyboard Sprites

The game can use sprites for keyboard keys if you provide a sprite sheet. Place your sprite sheet at:
```
resources/sprites/keyboard_letters_and_symbols.png
```

The expected format is a 128x224 pixel image with 16x16 pixel key sprites arranged in an 8x14 grid. The sprite mapping follows the structure defined in `modules/keyboard/keySpriteMapper.lua`.

If no sprite sheet is found, the game will fall back to shape-based key rendering.

## Directory Structure

```
.
├── engine/                 # Game engine components
│   ├── configManager.lua   # Configuration management
│   ├── resourceManager.lua # Asset management (sprites, fonts, sounds)
│   └── stateManager.lua    # Game state management
├── modules/                # Game modules
│   ├── keyboard/           # Keyboard-related modules
│   │   ├── keyboardModel.lua  # Data model for keyboards
│   │   ├── keyboardView.lua   # Visual representation of keyboards
│   │   └── keySpriteMapper.lua # Sprite mapping for keyboard keys
│   ├── player/             # Player-related modules
│   │   └── playerModel.lua # Player progression and stats
│   ├── typing/             # Typing mechanics
│   │   ├── textGenerator.lua # Text generation for typing challenges
│   │   └── trainer.lua       # Core typing trainer functionality
│   └── ui/                 # UI components
│       └── menuBuilder.lua # Menu building system
├── states/                 # Game states
│   ├── menuState.lua       # Main menu
│   ├── roundState.lua      # Typing round gameplay
│   ├── shopState.lua       # Upgrade shop
│   └── statsState.lua      # Statistics display
├── resources/              # Game assets
│   ├── sprites/            # Image assets
│   ├── fonts/              # Font assets
│   └── sounds/             # Sound assets
├── data/                   # Game data
│   └── words.txt           # Word list for text generation
├── main.lua                # Main entry point
├── setup.lua               # Project setup script
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

## Issues
- [X] Not saving match history properly
- [ ] Not displaying match history stats properly on stats pages with the bar graph
- [ ] Not able to retrieve the match history stats from player module
- [ ] S key no longer brings to shop menu from post round screen


## Extending the Game

The modular architecture makes it easy to extend the game:

- Add new keyboard layouts in `engine/configManager.lua`
- Create new typing challenge modes by extending `modules/typing/textGenerator.lua`
- Add more upgrade types in `modules/keyboard/keyboardModel.lua`
- Implement new game states in the `states/` directory

## License

This project is released under the MIT License.