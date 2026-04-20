## 重要：移植和修复必读文档（不可删除）
移植新功能或修复 bug 前，必须先阅读 `docs/` 文件夹下的两个文件：
- `docs/PORTING_GUIDE.md` — 从 TypeScript 移植功能到 GDScript 的完整流程、检查清单、公式对照表、引用链说明
- `docs/BUG_PATTERNS.md` — 历次修复中总结的 8 种常见 bug 模式和通用检查清单，避免重复踩坑

这两个文件是项目经验积累，禁止删除。

# Pot Trainer — Godot 4.6

## Project Structure
```
scripts/
  main.gd                          — Entry point, audio, settings (198)
  splash_screen.gd                 — Splash screen with logo bounce animation (137)
  autoload/
    game_manager.gd                — Game state, engine integration, signals (380)
    firebase_auth.gd               — Firebase authentication service (370)
    locale.gd                      — Localization EN/ZH (190)
    google_sign_in.gd              — Google Sign-In wrapper: Native + GDExtension (92)
    apple_sign_in.gd               — Apple Sign-In wrapper: Native + GDExtension (74)
    admob_manager.gd               — Google AdMob rewarded ad singleton (140)
    guest_mode_manager.gd          — Guest mode: ad counter, progress persistence (75)
    subscription_manager.gd        — RevenueCat subscription: single $12.99/mo plan (170)
  core/
    game_loop_controller.gd        — Game loop, training questions, answer submission (113)
    deck_manager.gd                — Deck build, shuffle, deal, board cards (68)
  data/
    card_data.gd                   — Card suit/rank data model (60)
    player_data.gd                 — Player state (chips, template, status) (37)
    table_layout.gd                — Layout constants, pct_to_px/px_to_pct, chip presets (258)
    layout_config_manager.gd       — Layout config dict, import/export, file I/O, scale setters (321)
  pot_trainer/
    pot_engine.gd                  — Pure game logic engine (state machine, NPC AI, pot-limit) (432)
    player_templates.gd            — 6 AI personality types with weighted probabilities (247)
    table_presets.gd               — 6 table presets (GTO, Mixed, Casual, etc.) (101)
    training_config.gd             — Training config data class (54)
  main_menu/
    main_menu.gd                   — Main menu coordinator (entry panel, navigation) (289)
    login_panel.gd                 — Login/register UI + Firebase callbacks (252)
    logout_dialog.gd               — Logout confirmation dialog (87)
    settings_panel.gd              — Settings panel (volume, language, layout adjust) (167)
  features/                        — Feature modules (vertical slicing)
    training/
      numpad_ui.gd                 — Numeric keypad component (70)
      feedback_fx.gd               — Answer feedback effects (83)
      guest_dialog.gd              — Guest login prompt dialog (38)
    ads/
      ad_counter.gd                — Guest mode ad counter (32)
      ad_overlay_manager.gd        — Ad overlay UI (147)
  ui/
    managers/
      seat_manager.gd              — Seat creation, refresh, state update (82)
      chip_manager.gd              — Pot chip area and chip record management (82)
    components/
      dealer_button.gd             — Dealer button creation and animation (77)
  game/
    game_table.gd                  — Game UI coordinator (signals, refresh) (281)
    layout_editor.gd               — Layout editor coordinator, refs-dict driven (294)
    layout/
      layout_drag_handler.gd       — Drag logic handler (205)
      layout_panel_ui.gd           — Layout panel UI builder (160)
      layout_slider_builder.gd     — Data-driven slider builder (176)
      layout_preview_manager.gd    — Preview cards/buttons manager (230)
      layout_visibility_manager.gd — Element visibility control, helper-driven (216)
      layout_admin_panel_ui.gd     — Layout admin panel, data-driven (165)
    components/
      seat_ui.gd                   — Single seat UI (avatar, labels, cards, chips) (351)
      seat_chips.gd                — Seat chip stacks per blind mode (334)
      seat_hole_cards.gd           — Seat hole cards display (78)
      table_center.gd              — Pot display, street badge, community cards (173)
      card_display.gd              — Card sprite display (64)
      answer_box.gd                — Training question input box (204)
      chip.gd                      — Single chip sprite (9 colors × 4 angles) (101)
      chip_stack.gd                — Single-color vertical chip stack (95)
      bet_chip_stack.gd            — Auto-switch scattered/ordered bet chips (110)
      ordered_chip_stacks.gd       — Multi-color ordered stacks (157)
      scattered_chips.gd           — Scattered chip layout, uses ChipRenderUtils (131)
      pot_chip_area.gd             — Large scattered triangle, uses ChipRenderUtils (152)
      chip_record.gd               — Chip abacus display, uses ChipRenderUtils (190)
    ui/
      control_panel_manager.gd     — Bottom control panel coordinator (168)
      control_panel_styles.gd      — Button/option style factory, uses UiFactory (48)
      config_row_builder.gd        — Config row builder (player count, blinds, etc.) (132)
      question_panel_manager.gd    — Answer panel coordinator (155)
      game_over_manager.gd         — Game over overlay (59)
      action_box_manager.gd        — Action box auto-hide in game mode (33)
  util/
    card_textures.gd               — Card texture loading (27)
    chip_utils.gd                  — Chip amount-to-color conversion (170)
    chip_render_utils.gd           — Shared chip rendering: seeded_random, color map, node factory (75)
    ui_factory.gd                  — Shared UI builders: StyleBoxFlat, buttons, sliders, labels (158)
    pinch_zoom_detector.gd         — Mobile pinch-to-zoom (87)
    scene_switcher.gd              — Scene transition utility (199)
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
- **Game flow** (step-by-step, questions, game over): `core/game_loop_controller.gd` (113 lines)
- **Answer panel coordinator**: `question_panel_manager.gd` (155 lines)
- **Numeric keypad**: `features/training/numpad_ui.gd` (102 lines)
- **Answer feedback effects**: `features/training/feedback_fx.gd` (83 lines)
- **Guest login dialog**: `features/training/guest_dialog.gd` (39 lines)
- **Ad counter logic**: `features/ads/ad_counter.gd` (32 lines)
- **Ad overlay UI**: `features/ads/ad_overlay_manager.gd` (160 lines)
- **Game over overlay**: `game_over_manager.gd`
- **Action box auto-hide**: `action_box_manager.gd`
- **Seat display** (avatar, chips, labels, cards): `seat_ui.gd`
- **Seat management** (creation, refresh, positions): `ui/managers/seat_manager.gd` (82 lines)
- **Chip management** (pot chips, chip record): `ui/managers/chip_manager.gd` (82 lines)
- **Dealer button**: `ui/components/dealer_button.gd` (77 lines)
- **Control panel coordinator**: `control_panel_manager.gd` (176 lines)
- **Control panel styles**: `control_panel_styles.gd` (86 lines)
- **Config row** (player count, blinds, presets): `config_row_builder.gd` (124 lines)
- **Layout editor**: `layout_editor.gd` + `layout/` subfolder (4 files)
- **Layout positions/scales**: `layout_config_manager.gd` (core) + `game_manager.gd` (set_layout_scale) + `table_layout.gd` (constants)
- **Login/register/logout**: `login_panel.gd`
- **Settings** (volume, language): `settings_panel.gd`
- **Main menu navigation**: `main_menu.gd`
- **Scene transitions / audio**: `main.gd`
- **Splash screen animation**: `splash_screen.gd`
- **Translations**: `locale.gd` (TRANSLATIONS dict)
- **Chip rendering**: `chip.gd`, `chip_stack.gd`, `scattered_chips.gd`, `pot_chip_area.gd`, `chip_record.gd`
- **Shared UI builders** (StyleBoxFlat, buttons, sliders, labels): `util/ui_factory.gd`
- **Shared chip rendering** (seeded_random, color map, node factory): `util/chip_render_utils.gd`

## Refactoring Notes (2026-03-24)
- **game_table.gd** 450→275 (39%): SeatManager, ChipManager, DealerButton
- **control_panel_manager.gd** 357→176 (51%): ControlPanelStyles, ConfigRowBuilder
- **game_manager.gd** 576→377 (35%): GameLoopController, DeckManager, set_layout_scale()
- **question_panel_manager.gd** 328→155 (53%): NumpadUI, FeedbackFX, GuestDialog
- **seat_ui.gd** 564→336 (40%): SeatChips, SeatHoleCards
- **layout_panel_ui.gd** 508→185 (64%): LayoutSliderBuilder
- **login_panel.gd** 461→252 (45%): LoginAuthHandler, LogoutDialog
- **main.gd** 370→198 (46%): SceneSwitcher
- **layout_admin_panel_ui.gd** 386→317 (18%): merged per-seat row builders
- New directories: `features/`, `ui/managers/`, `ui/components/`, `core/`

## Refactoring Notes (2026-03-26) — Token 优化重构
- 新增 `util/ui_factory.gd` (158行): 共享 StyleBoxFlat/按钮/标签/滑块工厂
- 新增 `util/chip_render_utils.gd` (75行): 共享筹码渲染工具（seeded_random、颜色映射、节点创建）
- **layout_slider_builder.gd** 428→176 (59%): 数据驱动 SLIDER_DEFS 配置数组 + UiFactory
- **layout_admin_panel_ui.gd** 317→165 (48%): 数据驱动 GLOBAL_DEFS/PER_SEAT_DEFS + UiFactory
- **layout_panel_ui.gd** 189→160 (15%): UiFactory 替代手写 StyleBoxFlat
- **layout_visibility_manager.gd** 331→216 (35%): _set_array_visible/_set_single_visible 辅助方法 + refs dict
- **layout_editor.gd** 415→294 (29%): refs dict 替代20个成员变量 + DRAG_MAP const
- **scattered_chips.gd** 202→131 (35%): ChipRenderUtils 替代重复的 seeded_random/color mapping
- **pot_chip_area.gd** 235→152 (35%): ChipRenderUtils 替代重复代码
- **chip_record.gd** 231→190 (18%): ChipRenderUtils + UiFactory

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
