# Pot Trainer — Godot 4.6

## Project Structure
```
scripts/
  autoload/game_manager.gd    — Game state, engine integration, layout, signals
  data/
    card_data.gd               — Card suit/rank data model
    player_data.gd             — Player state (chips, template, round_contribution, status)
    table_layout.gd            — Layout constants, pct_to_px/px_to_pct conversion, chip presets
  pot_trainer/
    pot_engine.gd              — Pure game logic engine (state machine, NPC AI, pot-limit calc)
    player_templates.gd        — 6 AI personality types with weighted action probabilities
    table_presets.gd           — 6 table presets (GTO, Mixed, Casual, etc.)
    training_config.gd         — Training config data class (blinds, probability, mode)
  game/
    game_table.gd              — Main UI controller
    layout_editor.gd           — Layout editor coordinator
    layout/
      layout_drag_handler.gd   — Drag logic handler (~189 lines)
      layout_panel_ui.gd       — Layout panel UI builder (~440 lines)
      layout_preview_manager.gd — Preview cards/buttons manager (~282 lines)
      layout_visibility_manager.gd — Element visibility control (~205 lines)
    components/
      seat_ui.gd               — Single seat UI manager
      table_center.gd          — Table center UI manager
      card_display.gd          — Card display component
      chip.gd                  — Single chip component (9 colors × 4 angles)
      chip_stack.gd            — Single-color vertical chip stack
      ordered_chip_stacks.gd   — Multi-color ordered stacks (player chips)
      scattered_chips.gd       — Scattered triangle layout (bet chips)
      pot_chip_area.gd         — Large scattered triangle (pot chips)
      chip_record.gd           — Chip abacus (算盘式底池金额显示)
      answer_box.gd            — Answer input box for training questions
    ui/
      control_panel_manager.gd — Control panel manager
  util/
    card_textures.gd           — Card texture loading
    chip_utils.gd              — Chip amount-to-color conversion
  main.gd                      — Entry point
  main_menu/main_menu.gd       — Main menu
assets/
  shaders/outline.gdshader     — Gold outline shader (active player highlight)
  cards/                       — 52 card SVGs + card back
  chips/                       — 9 chip colors × 4 angles (SVG)
  players/player 1-9.png       — Player avatars (70x70 base)
  chair/                       — 9 chair images
  table/                       — Poker table background
scenes/
  game/components/card_display.tscn — Card display scene
```

## Architecture
- GameManager (autoload singleton) owns display state, integrates PotEngine, emits signals
- PotEngine (RefCounted) is the pure game logic layer — no UI, no signals, no side effects
- game_table.gd builds all UI programmatically, reacts to GameManager signals
- Layout system uses percentage-based positioning (0-100) relative to table background
- Signal-driven: GameManager emits → game_table.gd reacts
- Chip system: 3 components for different layouts (ordered stacks, scattered, pot area) + chip record abacus

## Chip System
- Default player stack: 3 separate stacks per seat — 10 purple (500), 20 black (100), 20 green (25) = 7500 total
- Each color stack is independently draggable in layout mode with its own position (`purple_stacks`, `black_stacks`, `green_stacks`)
- Default bet chips: 1 purple, 2 black, 1 green = 725 total
- Pot chips: Large amount (7500) in triangle scatter layout
- Layout editor: Draggable positions + scale sliders for all chip types
- Mobile support: Pinch-to-zoom for chip scale adjustment

## Pot Trainer Game Flow
```
Start Game → create_initial_state (post blinds)
  → run_until_question loop:
    ├─ advance_game (NPC acts: fold/check/call/bet/raise)
    ├─ If bet/raise → create_training_question
    │   ├─ is_answer=true → show question panel, wait for user input
    │   └─ is_answer=false → auto-complete, continue loop
    ├─ User submits answer → validate against max_raise_to
    │   ├─ Correct → complete_raise, continue loop
    │   └─ Wrong → show error, retry
    └─ If game_over → restart (scenario) or stop (single hand)
```

## Pot-Limit Max Raise Formula
- Bet (currentBet == 0): `maxRaiseTo = pot.total`
- Raise (currentBet > 0): `maxRaiseTo = currentBet * 3 + pot.total + otherPlayersContributions`
  - otherPlayersContributions excludes current player AND one player at max bet

## AI Player Templates (6 types)
- T1_GTO: Balanced
- T2_CALLING_STATION: Passive, calls a lot
- T3_LAG: Aggressive, high bet/raise frequency
- T4_TAG_MAX: Tight, folds often, goes big when playing
- T5_NORMAL: Live-like, moderate
- T6_TRICKY: Deceptive, small/big probes

## Table Presets (6 types)
- P1: All GTO | P2: Half GTO, half random | P3: 1 GTO, rest random
- P4: No GTO (casual) | P5: All crazy (LAG/Normal/Tricky) | P6: All Normal

## Layout System
- Hardcoded rotation: `DEFAULT_HOLE_CARD_ROTATION` in table_layout.gd — per-seat card rotation (not editable in layout editor)
- Scale configs: `avatar_scale`, `dealer_button_scale`, `hole_card_scale`, `hole_card_gap`, `community_card_scale`, `muck_card_scale`
- Position categories (arrays of 9): `seats`, `cards`, `stacks`, `bets`, `dealer_buttons`, `chairs`, `purple_stacks`, `black_stacks`, `green_stacks`
- Position categories (single): `pot`, `muck`, `community_cards`, `chip_record`
- Coordinate conversion: `TableLayout.pct_to_px()` / `TableLayout.px_to_pct()`
- BG_OFFSET=Vector2(131,130), BG_SIZE=Vector2(1676,943)
- Saved to `user://layout.json`, auto-loaded on start

## Key Conventions
- Cards: base size Vector2(48, 66), scaled by category-specific scale factor
- Initial stack: 7500 chips per player
- All amounts rounded to multiples of 25
- Dealer button: white circle with black border, corner radius = size/2
- Active player: gold outline shader on avatar (breathing animation)
