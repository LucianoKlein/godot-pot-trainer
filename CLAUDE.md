# Poker Dealer Simulator — Godot 4.6

## Project Structure
```
scripts/
  autoload/game_manager.gd    — Game state, layout system, signals (~900 lines)
  data/
    card_data.gd               — Card suit/rank data model
    player_data.gd             — Player state (chips, hole cards, folded, etc.)
    pitch_state.gd             — Pitch phase tracking
    table_layout.gd            — Layout constants, pct_to_px/px_to_pct conversion
  game/
    game_table.gd              — Main UI controller / orchestrator (~1700 lines)
    layout_editor.gd           — Layout editor (handles, sliders, preview, export/import, RefCounted)
    components/card_display.gd — Card display component (TextureRect-based)
  util/card_textures.gd        — Card texture loading
  main.gd                      — Entry point
  main_menu/main_menu.gd       — Main menu
assets/
  shaders/outline.gdshader     — Gold outline shader with breathing effect (for active player)
  cards/                       — 52 card SVGs + card back
  players/player 1-9.png       — Player avatars (70x70 base)
  chair/                       — 9 chair images
  table/                       — Poker table background
  ui/pitching_hand.png         — Pitching hand image (400x562, aspect 0.7117)
scenes/
  game/components/card_display.tscn — Card display scene
Poker table demonstrator/      — Original Vue.js web app (reference implementation)
```

## Architecture
- GameManager (autoload singleton) owns all game state and emits 20+ signals (including `mispitch_animated`)
- game_table.gd builds all UI programmatically (no scene tree UI nodes except card_display.tscn)
- layout_editor.gd is a RefCounted helper class, instantiated by game_table.gd with `LayoutEditor.new(parent, table_overlay, layout_btn)`
- Layout system uses percentage-based positioning (0-100) relative to table background
- All card base size unified to 48x66 px, scaled by per-category scale factors
- Signal-driven: GameManager emits → game_table.gd reacts

## Layout System
- Scale configs: `avatar_scale`, `dealer_button_scale`, `hole_card_scale`, `hole_card_gap`, `community_card_scale`, `muck_card_scale`, `pitch_hand_scale`, `pitch_hand_rotation`
- Position categories (arrays of 9): `seats`, `cards`, `stacks`, `bets`, `dealer_buttons`, `chairs`
- Position categories (single): `pot`, `muck`, `community_cards`, `pitch_hand`
- Coordinate conversion: `TableLayout.pct_to_px()` / `TableLayout.px_to_pct()`
- BG_OFFSET=Vector2(131,130), BG_SIZE=Vector2(1676,943)
- Saved to `user://layout.json`, auto-loaded on start
- Default `hole_card_scale` is 0.55 — use 0.55 (not 1.0) as fallback in `.get()` calls

## Key Conventions
- Cards: base size Vector2(48, 66), scaled by category-specific scale factor
- Hole card default scale: 0.55 (visually ~26x36), community card default: 1.0
- Pitch hand: base size Vector2(57, 80) constant `PITCH_HAND_BASE_SIZE`, preserves 400:562 aspect ratio via `STRETCH_KEEP_ASPECT_CENTERED`
- Pitch zones: dynamically sized to wrap hole cards exactly (hc_total_w x hc_size.y + 3px padding each side)
- Active player indicated by gold outline shader on avatar (breathing animation 30%-100% opacity) + orange action arrow from table center
- Action arrow: Control node with `_draw()`, orange `Color(1.0, 0.55, 0.0)`, rect body (80x18) + triangle head (30x36) + white "Action" text, positioned at 45% from table center toward seat, rotated via `direction.angle()`, looping radial bounce tween (12px, 0.4s, SINE ease), z_index=5, same show/hide condition as gold outline (`cp >= 0 && in_hand && !PITCH`)
- Context menu triggered by clicking player avatar or name label
- Game flow: PITCH → PREFLOP → FLOP → TURN → RIVER → SHOWDOWN
- Keyboard shortcuts: F=Fold, C=Call/Check, R=Raise, B=Bet
- Dealer button: white circle with black border (`border_color = Color.BLACK`, `set_border_width_all(2)`), corner radius = size/2 to stay circular at any scale. Child Label size must be explicitly set on resize to prevent square rendering.

## Game Mode & Blinds
- `GameMode` enum: `CASH`, `TOURNAMENT` (in GameManager)
- Default mode: `CASH`, default blinds: 1/2
- Cash blind presets: 1/2, 1/3, 2/3, 2/5, 3/5, 5/5, 5/10, 10/20, 10/25, 20/40, 25/50, 50/100, 100/100
- Tournament blind presets: 100/100, 100/200, 200/300, 200/400, 300/600, 400/800, 500/1000, 600/1200, 800/1600, 1000/1500, 1000/2000, 1500/3000
- Presets stored as `CASH_BLINDS` and `TOURNAMENT_BLINDS` const arrays in GameManager
- Control panel has two `OptionButton` dropdowns: Mode (Cash/Tournament) and Blinds (preset list)
- Switching mode repopulates blinds dropdown and auto-selects first preset
- `set_game_mode()` and `set_blinds()` emit `blinds_changed` signal

## Pitch System
- Card flight: linear path (TRANS_LINEAR) + continuous rotation (TAU*4 over 0.6s), starts from `_pitch_hand.position + _pitch_hand.pivot_offset`
- Mispitch to wrong player: card flies to wrong seat and STAYS on table (stored in `_mispitch_cards`), misdeal X appears
- Mispitch to table: click outside zones → `GameManager.mispitch()` draws a card from deck, emits `mispitch_animated` signal, card flies to click position and stays
- Misdeal X: clicking X toggles a menu with "Misdeal" button (not direct reset). Menu at `_misdeal_menu`, positioned above X button
- `_clear_pitched_cards()` cleans up both `_arrived_cards` and `_mispitch_cards` — called on misdeal, new hand, reset, street change
- Pitch zones color-coded: white=empty, green=1 card, gray=full(2), yellow=hover, red=replacement
- Auto-pitch timer: 0.15s interval, stops on mispitch or replacement phase
- Pitch hand follows mouse rotation in `_process()` with base rotation offset from layout config

## Card Assets
- Card SVGs in `assets/cards/{suit}/{rank}.svg`, card back in `assets/cards/card back/card back.svg`
- Card back SVG viewBox must match actual content bounds (was 735.61 height with transparent padding, trimmed to ~714.5)
- CardDisplay uses `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED` — SVG viewBox directly affects rendered size within Control bounds

## Refactoring Notes
- game_table.gd was 1800+ lines, layout editor extracted to layout_editor.gd (~380 lines saved)
- Further candidates for extraction: pitch controller (~180 lines), context menu + raise dialog
- Pattern for extraction: RefCounted class taking parent Control reference, called from game_table.gd
