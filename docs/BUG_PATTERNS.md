# 常见编译和功能 Bug 修复经验

## 本文件记录移植/修改过程中反复出现的 Bug 模式，避免重复踩坑。

---

## Bug 1：模式检测顺序导致归一化后状态丢失

**场景**：`training_config.gd` 的 `_update_mode()` 中，1/2/5 模式调用 `set_blinds(1, 5)` 后将 `big_blind` 归一化为 2。如果 1/2 分支（`sb==1, bb==2`）排在 1/2/5 分支（`sb==1, bb==5`）前面，归一化后再次调用 `_update_mode()` 就会错误匹配到 1/2。

**规则**：归一化前的原始值检测必须排在归一化后的值检测之前。检测条件越严格的分支越靠前。

**错误写法**：
```gdscript
if sb == 1 and bb == 2:       # 1/2 先匹配
    blinds_mode = "1/2"
elif sb == 1 and bb == 5:     # 1/2/5 永远到不了（归一化后 bb=2）
    big_blind = 2
    blinds_mode = "1/2/5"
```

**正确写法**：
```gdscript
if sb == 1 and bb == 5:       # 1/2/5 先匹配（bb=5 是原始输入值）
    big_blind = 2
    blinds_mode = "1/2/5"
elif sb == 1 and bb == 2:     # 1/2 后匹配
    blinds_mode = "1/2"
```

---

## Bug 2：complete_raise 中 _advance_street 传错参数

**场景**：`pot_engine.gd` 的 `complete_raise()` 调用 `_advance_street(pot_last_raise_size)`，但 `_advance_street` → `_reset_betting_round` 用这个参数设置下一街的 `pot_last_raise_size`。应该传 `big_blind`，否则下一街的最小加注基准会变成上一街的最后加注额。

**规则**：`complete_raise()` 没有 config 引用时，需要在 `create_initial_state()` 中缓存 `_big_blind`，供后续使用。

---

## Bug 3：可见性状态未完整重置

**场景**：`seat_chips.gd` 的 `set_default_display()` 只隐藏了部分筹码堆（white/red/purple），没有显式设置 `black_stack.visible` 和 `green_stack.visible`。切换盲注模式时，上一个模式的可见性状态残留。

**规则**：模式切换时，先将所有筹码堆设为统一初始状态（全部隐藏或全部显示），再按当前模式设置。不要依赖"上次的状态刚好是对的"。

**模板**：
```gdscript
# 先全部隐藏
white_stack.visible = false
red_stack_1.visible = false
purple_stack.visible = false
black_stack.visible = false
green_stack.visible = true  # green 所有模式都用

# 再按模式显示
if is_12:
    red_stack_1.visible = true
    white_stack.visible = true
elif is_small:
    black_stack.visible = true
    red_stack_1.visible = true
else:
    purple_stack.visible = true
    black_stack.visible = true
```

---

## Bug 4：新增 UI 元素未穿透引用链

**场景**：`seat_chips.gd` 创建了 `white_stack`，`seat_ui.gd` 也暴露了 getter，但 `game_table.gd` 没有把它传给 `layout_editor.gd`，`layout_editor.gd` 也没传给 `layout_visibility_manager.gd`。结果白色筹码堆在布局编辑器中不受可见性控制。

**规则**：新增任何可拖拽/可控制可见性的 UI 元素，必须完整穿透 5 层引用链：
1. `seat_chips.gd` — 创建节点
2. `seat_ui.gd` — 暴露 getter
3. `game_table.gd` — 收集到 refs dict
4. `layout_editor.gd` — 存储 + 传给子管理器
5. `layout_visibility_manager.gd` — 添加可见性逻辑

漏掉任何一层 = 布局编辑器中该元素不可控。

---

## Bug 5：调用不存在的 GameManager 方法

**场景**：`layout_admin_panel_ui.gd` 调用 `GameManager.set_hole_card_rotation(seat, deg)`，但 GameManager 没有这个方法。应该用通用的 `set_per_seat_value("hole_card_rotation", seat, deg)`。

**规则**：修改 GameManager API 后，全局搜索 `GameManager.set_` 确认所有调用点都更新了。新增功能时优先用已有的通用方法（`set_layout_scale`、`set_per_seat_value`），不要随意假设存在专用方法。

---

## Bug 6：chip_record 位数计算与参考实现不一致

**场景**：1/2 模式的算盘显示，参考实现用 百/十/个（`amount/100%10`、`amount/10%10`、`amount/1%10`），Godot 错误地用了 千/百/十。

**规则**：算盘位数计算必须严格对照参考实现 `ChipRecord.vue`。不同模式的位数含义不同：
- 25/50：万/千/百/低位(÷25)
- 5/10：千/百/十/低位(÷5)
- 1/2 & 1/2/5：百/十/个/low=0（先 ceil5 再分位）

---

## Bug 7：冗余的状态预设被后续调用覆盖

**场景**：`layout_editor.gd` 的 `_on_blinds_mode_changed()` 先设 `GameManager.blinds_mode = mode`，然后调 `GameManager.set_blinds()` 又通过 `_update_mode()` 覆盖了 `blinds_mode`。预设是多余的，还可能在 `_update_mode` 修复前掩盖 bug。

**规则**：不要在调用会自动设置状态的函数之前手动预设同一个状态。让单一入口（`set_blinds` → `_update_mode`）负责状态推导。

---

## Bug 8：5/10 模式检测条件过宽

**场景**：`_update_mode()` 中 `elif small_blind == 5:` 只检查了 sb，没检查 bb。任何 sb=5 的组合（5/20、5/50）都会被错误归类为 5/10。

**规则**：模式检测条件必须同时检查 sb 和 bb，写成 `sb == 5 and bb == 10`。

---

## Bug 9：无类型 const Array 迭代时 `:=` 推断失败

**场景**：`layout_slider_builder.gd` 中 `for mode in DISPLAY_MODES` 循环内用 `var m := mode` 捕获循环变量。`DISPLAY_MODES` 声明为 `const DISPLAY_MODES: Array = [...]`（无类型 Array），Godot 无法从无类型数组元素推断 `m` 的类型，编译报错 `Cannot infer the type of "m" variable because the value doesn't have a set type`。

**规则**：当 `for` 循环遍历无类型 `Array` 或 `const Array` 时，循环变量没有类型信息。用 `:=` 赋值会触发类型推断失败。必须显式声明类型。

**错误写法**：
```gdscript
const MODES: Array = ["numbers", "chips"]
for mode in MODES:
    var m := mode  # ERROR: Cannot infer type
    btn.pressed.connect(func(): do_something(m))
```

**正确写法**：
```gdscript
const MODES: Array = ["numbers", "chips"]
for mode in MODES:
    var m: String = mode  # 显式声明类型
    btn.pressed.connect(func(): do_something(m))
```

**替代方案**：将 const 声明为类型化数组 `Array[String]`（但 Godot 4.x 对 const 类型化数组支持有限，显式声明变量类型更可靠）。

---

## 通用检查清单（每次修改后执行）

1. **模式分支完整性**：所有 `if is_12 / elif is_small / else` 分支是否覆盖了全部 4 个模式？
2. **可见性完整性**：每个筹码堆在每个分支中是否都有显式的 `.visible = xxx`？
3. **引用链完整性**：新增的 UI 元素是否穿透了 seat_chips → seat_ui → game_table → layout_editor → visibility_manager？
4. **方法存在性**：`GameManager.set_xxx()` 调用的方法是否真的存在？全局搜索确认。
5. **参考对齐**：数值计算（raise 公式、算盘位数、筹码分解）是否与 TypeScript 参考实现逐行对照过？
6. **归一化安全**：如果某个函数会修改输入值（如 `big_blind = 2`），检测逻辑是否在修改之前执行？
7. **类型推断安全**：`for` 循环遍历无类型 `Array`/`const Array` 时，捕获变量是否用了显式类型声明而非 `:=`？
