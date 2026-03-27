class_name ConfigRowBuilder
extends RefCounted
## ConfigRowBuilder — 配置行构建器
## 负责构建控制面板的配置行（人数、盲注、牌桌、模式、庄家、展示模式）

signal player_count_changed(count: int)
signal blinds_changed(sb: int, bb: int)
signal preset_changed(preset: int)
signal mode_changed(mode: String)
signal display_mode_changed(mode: String)
signal dealer_changed(index: int)

var player_count_option: OptionButton
var blinds_option: OptionButton
var preset_option: OptionButton
var mode_option: OptionButton
var dealer_option: OptionButton
var _display_mode_option: OptionButton


func build(config_row: HBoxContainer) -> void:
	# 人数
	var pc_group := ControlPanelStyles.make_option_group(Locale.tr_key("player_count"))
	player_count_option = ControlPanelStyles.make_styled_option()
	for n in range(2, 10):
		player_count_option.add_item("%d" % n, n)
	player_count_option.selected = 6
	player_count_option.item_selected.connect(func(index: int) -> void:
		player_count_changed.emit(index + 2)
	)
	ControlPanelStyles.style_popup(player_count_option)
	pc_group.add_child(player_count_option)
	config_row.add_child(pc_group)

	# 盲注
	var bl_group := ControlPanelStyles.make_option_group(Locale.tr_key("blinds"))
	blinds_option = ControlPanelStyles.make_styled_option()
	var blind_labels := {
		"1_2": "1/2 Pot Limit",
		"1_5": "1/2/5 Pot Limit(WSOP)",
	}
	for pair in GameManager.POT_BLINDS:
		var key := "%d_%d" % [pair[0], pair[1]]
		if blind_labels.has(key):
			blinds_option.add_item(blind_labels[key])
		else:
			blinds_option.add_item("%d/%d" % [pair[0], pair[1]])
	blinds_option.selected = 3  # 默认 25/50（index 3: [1,2],[1,5],[5,10],[25,50],...）
	blinds_option.item_selected.connect(func(index: int) -> void:
		var pair: Array = GameManager.POT_BLINDS[index]
		blinds_changed.emit(pair[0], pair[1])
	)
	bl_group.add_child(blinds_option)
	ControlPanelStyles.style_popup(blinds_option)
	config_row.add_child(bl_group)

	# 牌桌
	var tp_group := ControlPanelStyles.make_option_group(Locale.tr_key("table_preset"))
	preset_option = ControlPanelStyles.make_styled_option()
	var preset_names := TablePresets.get_preset_names()
	for key in preset_names:
		preset_option.add_item(preset_names[key], key)
	preset_option.selected = 0
	preset_option.item_selected.connect(func(index: int) -> void:
		preset_changed.emit(index)
	)
	tp_group.add_child(preset_option)
	ControlPanelStyles.style_popup(preset_option)
	config_row.add_child(tp_group)

	# 模式
	var mo_group := ControlPanelStyles.make_option_group(Locale.tr_key("mode_label"))
	mode_option = ControlPanelStyles.make_styled_option()
	mode_option.add_item(Locale.tr_key("scenario_mode"))
	mode_option.add_item(Locale.tr_key("game_mode"))
	mode_option.selected = 0
	mode_option.item_selected.connect(func(index: int) -> void:
		var mode: String = "scenario" if index == 0 else "game"
		mode_changed.emit(mode)
	)
	mo_group.add_child(mode_option)
	ControlPanelStyles.style_popup(mode_option)
	config_row.add_child(mo_group)

	# 庄家
	var dl_group := ControlPanelStyles.make_option_group(Locale.tr_key("dealer_label"))
	dealer_option = ControlPanelStyles.make_styled_option()
	_rebuild_dealer_options()
	dealer_option.item_selected.connect(func(index: int) -> void:
		dealer_changed.emit(index)
	)
	dl_group.add_child(dealer_option)
	ControlPanelStyles.style_popup(dealer_option)
	config_row.add_child(dl_group)

	# 展示模式
	var dm_group := ControlPanelStyles.make_option_group(Locale.tr_key("display_mode_label"))
	_display_mode_option = ControlPanelStyles.make_styled_option()
	_display_mode_option.add_item(Locale.tr_key("chips_mode"), 0)
	_display_mode_option.add_item(Locale.tr_key("numbers_mode"), 1)
	_display_mode_option.selected = 0 if GameManager.display_mode == "chips" else 1
	_display_mode_option.item_selected.connect(func(index: int) -> void:
		var mode: String = "chips" if index == 0 else "numbers"
		display_mode_changed.emit(mode)
	)
	dm_group.add_child(_display_mode_option)
	ControlPanelStyles.style_popup(_display_mode_option)
	config_row.add_child(dm_group)


func update_dealer_options() -> void:
	_rebuild_dealer_options()


func update_display_mode_styles() -> void:
	if _display_mode_option:
		_display_mode_option.selected = 0 if GameManager.display_mode == "chips" else 1


func _rebuild_dealer_options() -> void:
	if not dealer_option:
		return
	var prev_selected := dealer_option.selected
	dealer_option.clear()
	var count: int = GameManager.config.player_count
	for i in range(count):
		var physical_seat: int = GameManager.get_physical_seat(i)
		dealer_option.add_item(Locale.tr_key("seat_option") % (physical_seat + 1), i)
	if prev_selected >= 0 and prev_selected < count:
		dealer_option.selected = prev_selected
	else:
		dealer_option.selected = 0
