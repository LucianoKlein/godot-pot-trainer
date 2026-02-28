# Poker Dealer Simulator — Web to Godot 迁移计划

## 已完成的基础设施

- [x] **GameManager autoload** (`scripts/autoload/game_manager.gd`, 781行)
  - 完整牌局流程: PITCH → PREFLOP → FLOP → TURN → RIVER → SHOWDOWN
  - 9人桌、牌组管理、盲注系统
  - 完整下注逻辑 (fold/call/raise/check/bet)
  - 发牌阶段 + 发错牌检测 + 替换阶段
  - Undo/快照系统
  - 右键菜单/加注对话框状态管理
  - 非轮次模式、激进者追踪
  - 布局配置系统 (百分比定位)
  - 所有状态变化信号

- [x] **数据类**
  - `CardData` (`scripts/data/card_data.gd`) — 花色、点数、face_up、id、显示文本
  - `PlayerData` (`scripts/data/player_data.gd`) — id、名字、筹码、手牌、当前下注、弃牌、已行动
  - `PitchState` (`scripts/data/pitch_state.gd`) — 发牌追踪、发错牌、替换阶段
  - `TableLayout` (`scripts/data/table_layout.gd`) — 百分比布局 + pct_to_px转换 + 所有默认位置

- [x] **场景结构**
  - `scenes/main.tscn` — 主场景 + CurrentScene容器
  - `scenes/main_menu/main_menu.tscn` — Play按钮
  - `scenes/game/game_table.tscn` — 背景(131,130 尺寸1676x943) + 9把椅子
  - `scenes/game/components/card_display.tscn` — 卡牌显示组件(26x36)

- [x] **game_table.gd** — 目前只有调试布局编辑功能(拖拽椅子、调整大小、打印位置)

- [x] **资源文件** — 牌桌PNG、9把椅子PNG、52张牌SVG + 牌背SVG、pitching_hand.png

---

## 待完成的迁移工作 (7个步骤)

### Step 1: 脚手架 + 控制面板
**状态: [x] 已完成**

**目标:** 替换 game_table.gd 中的调试代码，搭建基础框架，实现控制面板。

**修改文件:** `scripts/game/game_table.gd`

**内容:**
- 移除所有 debug_mode 代码
- `_ready()` 中调用 `GameManager.init_game()`
- 创建 ControlPanel (HBoxContainer, 锚定在屏幕底部)
- 按钮: New Hand, Reset, Move Dealer, Undo
- CheckBox: Out of Turn, Show Action, Show Aggressor
- BlindInfoLabel 显示 "Blinds: $10 / $20"
- 连接按钮信号到 GameManager 方法
- 连接 `hand_started` / `hand_ended` 信号控制按钮启用/禁用

---

### Step 2: 每个座位的 UI (名牌、筹码、下注、庄家按钮、状态指示器)
**状态: [x] 已完成**

**目标:** 在布局位置显示玩家名字、筹码、下注金额、庄家按钮和状态指示器。

**修改文件:** `scripts/game/game_table.gd`

**内容:**
- 创建 TableOverlay (Control, full rect, mouse_filter=IGNORE)
- 每个座位 (0..8):
  - `_name_labels[i]`: 玩家名字 (白色文字, 深色半透明背景)
  - `_seat_badges[i]`: "#N" 座位号 (橙色圆形背景)
  - `_fold_labels[i]`: "FOLD" (红色, 初始隐藏)
  - `_action_indicators[i]`: "Action" 标签 + 箭头 (红色背景, 初始隐藏)
  - `_aggressor_indicators[i]`: "Aggressor" 标签 (橙色背景, 初始隐藏)
  - `_stack_labels[i]`: 筹码金额 (绿色文字, 深色背景)
  - `_bet_labels[i]`: 下注金额 (金色文字, 深色背景)
- 庄家按钮: 白色 "D" 圆圈, 跟随 dealer_index 移动 (Tween动画)
- 信号连接: `hand_started`, `player_acted`, `dealer_moved`, `current_player_changed`, `game_reset`, `muck_changed`

---

### Step 3: 桌面中央 UI (底池、公共牌、弃牌堆、街道徽章、最后操作)
**状态: [x] 已完成**

**目标:** 显示底池金额、公共牌、弃牌堆、当前街道和最后操作文本。

**修改文件:** `scripts/game/game_table.gd`

**内容:**
- `_pot_display`: VBoxContainer ("POT" + 金额, 黄色 #f1c40f)
- `_community_cards_container`: HBoxContainer (最多5张 CardDisplay, 每张48x66)
- `_muck_pile`: Control (扇形牌背 + 数量标签)
- `_street_badge`: Label (黄色背景, 深色文字, 大写)
- `_last_action_label`: Label (灰色文字)
- 信号连接: `pot_changed`, `community_cards_changed`, `street_changed`, `last_action_changed`, `muck_changed`

---

### Step 4: 桌面上的手牌
**状态: [x] 已完成**

**目标:** 在每个玩家的卡牌位置显示手牌。

**修改文件:** `scripts/game/game_table.gd`

**内容:**
- `_card_slots[0..8]`: Control 节点在 `get_layout_position_px("cards", i)`
- 每个槽位容纳 0-2 张 CardDisplay
- 发牌阶段: 只显示已到达的牌 (动画完成后)
- 下注阶段: 显示牌背 (未弃牌玩家)
- 使用 `_arrived_cards` 数组追踪动画完成的牌

---

### Step 5: 发牌阶段 — 发牌手、点击区域、飞行动画、发错牌
**状态: [x] 已完成**

**目标:** 完整的发牌阶段交互。

**修改文件:** `scripts/game/game_table.gd`

**内容:**

**A. 发牌手 (Pitching Hand):**
- TextureRect 加载 `pitching_hand.png`
- 位置: `TableLayout.DEFAULT_PITCH_HAND_PCT` (50%, 97%)
- `_process()` 中计算鼠标角度, 设置旋转
- 显示剩余牌数

**B. 卡牌着陆区域 (Pitch Zones):**
- 9个 Control 节点 (60x42) 在卡牌位置
- `_draw()` 绘制虚线边框
- 点击处理: 调用 `GameManager.pitch_card_to_player()`
- 视觉状态: 默认(白色虚线)、悬停(黄色)、已填1张(绿色)、已填2张(暗淡)、替换(红色脉冲)

**C. 卡牌飞行动画:**
- 从发牌手位置飞向目标位置 (0.8秒)
- Tween: position + rotation (7-8圈旋转)
- 动画完成后: 移除飞行精灵, 记录到达, 刷新手牌显示

**D. 桌面点击 = 发错牌 (Mispitch):**
- TableOverlay 的 gui_input 处理
- 点击非区域位置 → `GameManager.mispitch(x_pct, y_pct)`
- 卡牌飞向错误位置, 红色发光

**E. Misdeal X 覆盖层:**
- 红色 "X" 按钮 (80x80, 脉冲动画)
- 点击 X → 显示 Misdeal 菜单
- "Misdeal" 按钮 → `GameManager.declare_misdeal()`

**F. 自动发牌按钮:**
- Timer (0.15秒间隔) 自动发牌给 expected_player
- 发错牌/替换阶段/发牌完成时停止

**G. U键 = 面朝上发牌:**
- `Input.is_key_pressed(KEY_U)` 检测

---

### Step 6: 右键菜单 + 加注对话框
**状态: [x] 已完成**

**目标:** 点击玩家座位打开操作菜单, Raise/Bet 打开金额对话框。

**修改文件:** `scripts/game/game_table.gd`

**内容:**

**A. 右键菜单 (Context Menu):**
- `_context_overlay`: Control (z_index=50, 初始隐藏)
- `_click_catcher`: 全屏 Control (点击关闭菜单)
- `_context_menu`: PanelContainer (深色背景 #2a2a3e)
  - 有下注时: Fold(红), Call $X(绿), Raise(橙)
  - 无下注时: Check(蓝), Bet(橙), Fold(红)
- 触发: 左键点击座位标签 → `GameManager.open_context_menu()`
- 定位: 在玩家座位附近, 夹紧到视口内

**B. 加注对话框 (Raise Dialog):**
- `_raise_overlay`: Control (z_index=60, 初始隐藏)
- `_dim_bg`: ColorRect (半透明黑色)
- `_raise_dialog`: PanelContainer (居中)
  - 标题: "Raise - Player N"
  - 信息: "Min: $X" + "Stack: $Y"
  - LineEdit 输入金额
  - Cancel + Confirm 按钮
- 最小加注 = current_bet + last_raise_increment (或 big_blind)
- 验证输入 → `GameManager.player_action(id, "raise"/"bet", amount)`

---

### Step 7: 键盘快捷键 + 动画打磨
**状态: [x] 已完成**

**目标:** 键盘快捷键、非轮次警告、动画效果。

**修改文件:** `scripts/game/game_table.gd`

**内容:**

**A. 键盘快捷键:**
- `_unhandled_key_input()` 处理
- F = fold, C = call/check, R/B = raise/bet
- 仅在下注阶段 + 手牌进行中 + 非发牌阶段生效

**B. 非轮次警告 (Out-of-Turn Warning):**
- 红色 "!" 圆圈, 脉冲动画
- 可见条件: `GameManager.has_out_of_turn_action == true`
- 点击显示 "Go Back" 按钮 → `GameManager.undo_last_action()`

**C. 动画效果:**
- Action 指示器弹跳动画 (Tween循环)
- Misdeal X 脉冲动画 (scale 1.0 ↔ 1.15)
- 下注金额弹出动画 (scale 0 → 1, TRANS_BACK)
- 替换区域红色脉冲 (modulate alpha 0.7 ↔ 1.0)

---

## 架构说明

### 脚本架构 (只需3个脚本)
| 脚本 | 角色 | 状态 |
|------|------|------|
| `scripts/game/game_table.gd` | 主UI控制器, 创建所有节点, 连接信号, 渲染更新, 发牌输入, 键盘快捷键 | 需要重写 |
| `scripts/game/components/card_display.gd` | 卡牌显示组件 | 已完成 |
| `scripts/util/card_textures.gd` | 卡牌纹理加载 | 已完成 |

### 定位策略
- 所有位置来自 `GameManager.get_layout_position_px()` → `TableLayout.pct_to_px()`
- 相对于背景纹理 (offset 131,130 size 1676x943)
- 居中: `position -= size / 2`

### 输入层级
- 发牌阶段: pitch zones (mouse_filter=STOP) 拦截点击, TableOverlay 捕获漏网点击(发错牌)
- 下注阶段: zones 隐藏, seat labels 可点击(右键菜单)
- 覆盖层: context menu (z=50), raise dialog (z=60), misdeal (z=100)

### 关键文件
- `scripts/game/game_table.gd` — 主要重写目标
- `scripts/autoload/game_manager.gd` — 信号源和状态权威
- `scripts/data/table_layout.gd` — 定位系统
- `scripts/game/components/card_display.gd` — 卡牌渲染组件
- `poker table demonstrator/src/components/PokerTable.vue` — 参考实现

---

## 验证方法
1. 启动游戏 → 主菜单 → 点击 Play → 进入牌桌
2. 看到9个座位的玩家名字、筹码、座位号
3. 点击 New Hand → 盲注扣除, 进入 PITCH 阶段
4. 发牌手跟随鼠标旋转, 点击座位区域发牌, 卡牌飞行动画
5. 按住 U 键发面朝上的牌, 触发发错牌逻辑
6. 点击桌面空白处触发 mispitch
7. 发完牌后进入 PRE-FLOP, 公共牌区域空
8. 点击当前玩家座位 → 弹出操作菜单
9. 选择 Raise → 弹出金额对话框
10. 键盘 F/C/R 快捷键生效
11. 街道推进: FLOP(3张公共牌) → TURN(1张) → RIVER(1张) → SHOWDOWN
