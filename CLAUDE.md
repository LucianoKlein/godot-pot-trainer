# Pot Trainer — Godot 4.6

## Project Structure
```
scripts/
  main.gd                          — Entry point, scene switching, audio, transition overlay (196)
  splash_screen.gd                 — Splash screen with logo bounce animation (105)
  autoload/
    game_manager.gd                — Game state, engine integration, signals (541)
    firebase_auth.gd               — Firebase authentication service (347)
    locale.gd                      — Localization EN/ZH (161)
  data/
    card_data.gd                   — Card suit/rank data model (60)
    player_data.gd                 — Player state (chips, template, status) (37)
    table_layout.gd                — Layout constants, pct_to_px/px_to_pct, chip presets (197)
    layout_config_manager.gd       — Layout config dict, import/export, file I/O, scale setters (183)
  pot_trainer/
    pot_engine.gd                  — Pure game logic engine (state machine, NPC AI, pot-limit) (358)
    player_templates.gd            — 6 AI personality types with weighted probabilities (247)
    table_presets.gd               — 6 table presets (GTO, Mixed, Casual, etc.) (101)
    training_config.gd             — Training config data class (16)
  main_menu/
    main_menu.gd                   — Main menu coordinator (entry panel, navigation) (319)
    login_panel.gd                 — Login/register/logout UI + Firebase callbacks (430)
    settings_panel.gd              — Settings panel (volume, language, layout adjust) (167)
  game/
    game_table.gd                  — Game UI coordinator (seats, signals, refresh) (432)
    layout_editor.gd               — Layout editor coordinator (408)
    layout/
      layout_drag_handler.gd       — Drag logic handler (216)
      layout_panel_ui.gd           — Layout panel UI builder (489)
      layout_preview_manager.gd    — Preview cards/buttons manager (229)
      layout_visibility_manager.gd — Element visibility control (281)
      layout_admin_panel_ui.gd     — Layout admin panel (385)
    components/
      seat_ui.gd                   — Single seat UI (avatar, labels, cards, chips) (561)
      table_center.gd              — Pot display, street badge, community cards (140)
      card_display.gd              — Card sprite display (64)
      answer_box.gd                — Training question input box (217)
      chip.gd                      — Single chip sprite (9 colors × 4 angles) (97)
      chip_stack.gd                — Single-color vertical chip stack (101)
      bet_chip_stack.gd            — Auto-switch scattered/ordered bet chips (108)
      ordered_chip_stacks.gd       — Multi-color ordered stacks (147)
      scattered_chips.gd           — Scattered triangle layout (172)
      pot_chip_area.gd             — Large scattered triangle (pot chips) (216)
      chip_record.gd               — Chip abacus display (188)
    ui/
      control_panel_manager.gd     — Bottom control panel (start/pause/reset/config) (351)
      question_panel_manager.gd    — Answer panel + numpad + feedback effects (245)
      game_over_manager.gd         — Game over overlay (58)
      action_box_manager.gd        — Action box auto-hide in game mode (32)
  util/
    card_textures.gd               — Card texture loading (27)
    chip_utils.gd                  — Chip amount-to-color conversion (74)
    pinch_zoom_detector.gd         — Mobile pinch-to-zoom (87)
assets/
  ui/launcher.png                  — App launcher icon
  ui/splash.png                    — Boot splash image
  ui/logo.png                      — Logo for splash animation
  shaders/outline.gdshader         — Gold outline shader (active player highlight)
  cards/                           — 52 card SVGs + card back
  chips/                           — 9 chip colors × 4 angles (SVG)
  music/                           — intro_music, main_music, sounds_effect/
scenes/
  main.tscn                        — Root (Main + SplashScreen)
  splash_screen.tscn               — Splash screen scene
  main_menu/main_menu.tscn         — Main menu scene
  game/game_table.tscn             — Game table scene
  game/components/                 — card_display.tscn, answer_box.tscn
```

## Architecture
- GameManager (autoload singleton) owns display state, integrates PotEngine, emits 20+ signals
- PotEngine (RefCounted) is the pure game logic layer — no UI, no signals, no side effects
- game_table.gd is a thin coordinator: delegates to QuestionPanelManager, GameOverManager, ActionBoxManager
- main_menu.gd delegates to LoginPanel and SettingsPanel
- main.gd handles scene transitions (splash fade, overlay fade) and audio
- Layout system uses percentage-based positioning (0-100) relative to table background
- Signal-driven: GameManager emits → game_table.gd reacts → delegates to managers

## Modification Guide
When changing:
- **Game logic** (betting, AI, pot calc): `pot_engine.gd`, `player_templates.gd`, `table_presets.gd`
- **Game flow** (step-by-step, questions, game over): `game_manager.gd` (_run_step_by_step, _handle_training_question, _handle_game_over)
- **Answer panel / feedback effects**: `question_panel_manager.gd`
- **Game over overlay**: `game_over_manager.gd`
- **Action box auto-hide**: `action_box_manager.gd`
- **Seat display** (avatar, chips, labels, cards): `seat_ui.gd`
- **Control panel** (start/pause/config dropdowns): `control_panel_manager.gd`
- **Layout editor**: `layout_editor.gd` + `layout/` subfolder (4 files)
- **Layout positions/scales**: `layout_config_manager.gd` (core) + `game_manager.gd` (thin wrappers) + `table_layout.gd` (constants)
- **Login/register/logout**: `login_panel.gd`
- **Settings** (volume, language): `settings_panel.gd`
- **Main menu navigation**: `main_menu.gd`
- **Scene transitions / audio**: `main.gd`
- **Splash screen animation**: `splash_screen.gd`
- **Translations**: `locale.gd` (TRANSLATIONS dict)
- **Chip rendering**: `chip.gd`, `chip_stack.gd`, `scattered_chips.gd`, `pot_chip_area.gd`, `chip_record.gd`

## Signal Flow
```
GameManager emits:
  state_changed, street_changed, pot_changed, community_cards_changed
  dealer_moved, current_player_changed, layout_changed, game_reset
  last_action_changed, npc_acted, blinds_changed
  training_question_appeared, training_question_cleared, answer_result
  game_over, hand_started, display_mode_changed, hole_cards_changed

game_table.gd listens → delegates:
  training_question_appeared → question_mgr.on_question_appeared()
  training_question_cleared  → question_mgr.on_question_cleared()
  answer_result              → question_mgr.on_answer_result()
  game_over                  → game_over_mgr.show()
  npc_acted                  → action_box_mgr.auto_hide()
  game_reset                 → question_mgr.on_game_reset() + game_over_mgr.hide()

LoginPanel emits:
  login_status_changed → main_menu rebuilds login status area
  play_sfx_requested   → main_menu forwards to Main.play_sfx()

SettingsPanel emits:
  layout_pressed → main_menu handles scene switch
```

## Chip System
- Default player stack: 3 separate stacks per seat — 10 purple (500), 20 black (100), 20 green (25) = 7500 total
- Each color stack is independently draggable in layout mode
- Pot chips: Large amount in triangle scatter layout
- Chip record: Abacus-style pot amount display

## Pot Trainer Game Flow
```
Start Game → create_initial_state (post blinds)
  → run_until_question loop (scenario mode) / run_step_by_step (game mode):
    ├─ advance_game (NPC acts: fold/check/call/bet/raise)
    ├─ If bet/raise → create_training_question
    │   ├─ max_raise_to > 7500 or all-in → skip question, auto-complete
    │   ├─ is_answer=true → show question panel, wait for user input
    │   └─ is_answer=false → auto-complete, continue loop
    ├─ User submits answer → validate against max_raise_to
    │   ├─ Correct → complete_raise, continue loop
    │   └─ Wrong → show error, retry
    └─ If game_over → show overlay (game mode) or restart (scenario mode)
```

## Game Mode Specifics
- Action boxes: show for 1 second then fade out (ActionBoxManager)
- Game over: prominent overlay with "本手结束！点击开始进行下一手" (GameOverManager)
- Step-by-step: 1 second delay between NPC actions

## Pot-Limit Max Raise Formula
- Bet (currentBet == 0): `maxRaiseTo = pot.total`
- Raise (currentBet > 0): `maxRaiseTo = currentBet * 3 + pot.total + otherPlayersContributions`
  - otherPlayersContributions excludes current player AND one player at max bet

## AI Player Templates (6 types)
- T1_GTO: Balanced | T2_CALLING_STATION: Passive | T3_LAG: Aggressive
- T4_TAG_MAX: Tight | T5_NORMAL: Live-like | T6_TRICKY: Deceptive

## Table Presets (6 types)
- P1: All GTO | P2: Half GTO | P3: 1 GTO | P4: Casual | P5: Crazy | P6: Normal

## Layout System
- Scale configs: `avatar_scale`, `dealer_button_scale`, `hole_card_scale`, `hole_card_gap`, `community_card_scale`, `muck_card_scale`
- Position categories (arrays of 9): `seats`, `cards`, `stacks`, `bets`, `dealer_buttons`, `chairs`, `purple_stacks`, `black_stacks`, `green_stacks`
- Position categories (single): `pot`, `muck`, `community_cards`, `chip_record`
- Coordinate conversion: `TableLayout.pct_to_px()` / `TableLayout.px_to_pct()`
- BG_OFFSET=Vector2(131,130), BG_SIZE=Vector2(1676,943)
- Saved to `user://layout.json`, auto-loaded on start

## Key Conventions
- Cards: base size Vector2(48, 66), scaled by category-specific scale factor
- Initial stack: 7500 chips per player (PotEngine.INITIAL_STACK)
- All amounts rounded to multiples of 25
- Dealer button: white circle with black border, corner radius = size/2
- Active player: gold outline shader on avatar (breathing animation)
- All UI built programmatically (no scene editor for game UI)
