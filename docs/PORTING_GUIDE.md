# 从 TypeScript 移植功能到 Godot GDScript 指南

## 参考源项目
- 路径：`C:\Users\Administrator\Desktop\zsj\code\reg\chip-trainer-src`
- 核心文件：`src/pages/PotTrainer/engine.ts`、`blindLevelConfig.ts`、`components/ChipRecord.vue`

## 移植流程（以 1/2 和 1/2/5 盲注模式为例）

### 1. 理解参考实现的模式区分机制
TypeScript 用 `smallBlind` 数值区分模式：
- `25` → 25/50 标准模式
- `5` → 5/10 模式
- `1` → 1/2 模式
- `1.25` → 1/2/5 WSOP 模式（`getActualSmallBlind(1.25)` 返回 `1`）

Godot 用 `set_blinds(sb, bb)` 入口 + `_update_mode()` 自动推断：
- `set_blinds(25, 50)` → "25/50"
- `set_blinds(5, 10)` → "5/10"
- `set_blinds(1, 2)` → "1/2"
- `set_blinds(1, 5)` → "1/2/5"（内部将 bb 归一化为 2，bbb=5）

### 2. 移植新盲注模式的完整检查清单

#### 配置层
- [ ] `training_config.gd` — `_update_mode()` 添加新模式分支，设置 `blinds_mode`、`round_unit`、`initial_stack`、`has_bbb`、`bbb_amount`
- [ ] `game_manager.gd` — `POT_BLINDS` 数组添加新盲注对 `[sb, bb]`

#### 引擎层
- [ ] `pot_engine.gd` — `create_initial_state()` 处理新模式的盲注发布（SB/BB/BBB）
- [ ] `pot_engine.gd` — `_create_training_question()` 添加新模式的 max raise 公式
- [ ] `pot_engine.gd` — bet 分支（`current_bet == 0`）处理 ceil5 等特殊逻辑

#### 筹码显示层
- [ ] `chip_utils.gd` — `amount_to_chips_by_mode()` 添加新模式的筹码分解函数
- [ ] `table_layout.gd` — 添加 `get_default_bet_chips_xxx()` 和 `get_default_player_stack_chips_xxx()`
- [ ] `chip_record.gd` — `_rebuild_chips()` 添加新模式的位数计算和颜色映射
- [ ] `seat_chips.gd` — `build()`、`set_default_display()`、`update_stack()`、`_set_all_stacks_zero()` 全部处理新模式
- [ ] `seat_ui.gd` — `refresh()` 中的筹码可见性分支覆盖新模式

#### 布局/可见性层
- [ ] `layout_visibility_manager.gd` — `update_element_visibility("player_chips")` 和 `restore_all_visibility()` 处理新模式的筹码堆可见性
- [ ] `layout_editor.gd` — `_on_blinds_mode_changed()` 添加新模式的 `set_blinds()` 调用
- [ ] `layout_slider_builder.gd` — 添加新模式的切换按钮
- [ ] `layout_config_manager.gd` — `_mode_configs` 添加新模式的默认配置

#### UI 层
- [ ] `config_row_builder.gd` — 盲注下拉菜单添加新模式标签
- [ ] `locale.gd` — 如需要，添加新模式相关翻译

### 3. 关键公式对照表

| 模式 | 盲注 | 单位 | 初始筹码 | 筹码组成 | Preflop 有效开注 | Max Raise 公式 |
|---|---|---|---|---|---|---|
| 25/50 | 25/50 | 25 | 7500 | purple500×10 + black100×20 + green25×20 | 50 (BB) | `currentBet*3 + pot + others` |
| 5/10 | 5/10 | 5 | 1300 | black100×5 + green25×20 + red5×60 | 10 (BB) | `currentBet*3 + pot + others` |
| 1/2 | 1/2 | 5 | 520 | green25×8 + red5×60 + white1×20 | 5 (固定) | `ceil5(lastBetter)*3 + ceil5(othersTotal) + ceil5(pot)` |
| 1/2/5 | 1/2/5 | 5 | 520 | green25×8 + red5×60 + white1×20 | 5 (固定) | `ceil5(currentBet)*3 + Σceil5(each other) + ceil5(pot)` |

### 4. 1/2 vs 1/2/5 的关键差异
- **1/2/5 有 BBB**：dealer+3 位置发 5 的大大盲
- **Raise 公式不同**：1/2 对 othersTotal 整体 ceil5；1/2/5 对每个玩家单独 ceil5 后求和
- **1/2 Preflop 特殊规则**：无人 call 时，SB+BB 合并视为"前一个玩家"
- **筹码组成相同**：两个模式共用 green25+red5+white1 的筹码集

### 5. 新增筹码颜色时的检查清单
- [ ] `chip.gd` — `ChipColor` 枚举添加新颜色，`COLOR_NAMES` 映射到资源目录名
- [ ] `assets/chips/` — 创建对应目录，放入 4 个角度的 SVG
- [ ] `chip_utils.gd` — 分解函数中使用新颜色
- [ ] `scattered_chips.gd` — `_color_sort_order()` 添加排序权重
- [ ] `pot_chip_area.gd` — `_color_sort_order()` 添加排序权重

### 6. 引用传递链（新增 UI 元素时必须完整穿透）
```
seat_chips.gd (创建节点)
  → seat_ui.gd (暴露 getter)
    → game_table.gd (收集到 refs Dictionary)
      → layout_editor.gd (存储引用 + 传递给子管理器)
        → layout_visibility_manager.gd (控制可见性)
        → layout_drag_handler.gd (控制拖拽)
```
漏掉任何一层都会导致新元素在布局编辑器中不可见或不可拖拽。
