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

## Extending the Game

The modular architecture makes it easy to extend the game:

- Add new keyboard layouts in `engine/configManager.lua`
- Create new typing challenge modes by extending `modules/typing/textGenerator.lua`
- Add more upgrade types in `modules/keyboard/keyboardModel.lua`
- Implement new game states in the `states/` directory

## License

This project is released under the MIT License.