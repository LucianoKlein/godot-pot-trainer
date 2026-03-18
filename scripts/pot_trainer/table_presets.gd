class_name TablePresets
extends RefCounted

# --- Preset IDs ---
enum PresetId {
	P1_ROBOT_TABLE,
	P2_HALF_FISH_HALF_ROBOT,
	P3_ONE_ROBOT_REST_RANDOM,
	P4_FISH_HEAVEN,
	P5_ALL_CRAZY,
	P6_ALL_NORMAL,
}

# Preset display name keys (for Locale lookup)
const PRESET_NAME_KEYS := {
	PresetId.P1_ROBOT_TABLE: "preset_gto_table",
	PresetId.P2_HALF_FISH_HALF_ROBOT: "preset_mixed",
	PresetId.P3_ONE_ROBOT_REST_RANDOM: "preset_one_gto",
	PresetId.P4_FISH_HEAVEN: "preset_casual",
	PresetId.P5_ALL_CRAZY: "preset_crazy",
	PresetId.P6_ALL_NORMAL: "preset_normal",
}

static func get_preset_names() -> Dictionary:
	var names := {}
	for key in PRESET_NAME_KEYS:
		names[key] = Locale.tr_key(PRESET_NAME_KEYS[key])
	return names

# Non-GTO pool weights (live-like distribution)
const LIVE_LIKE_POOL := {
	PlayerTemplates.TemplateId.T2_CALLING_STATION: 0.25,
	PlayerTemplates.TemplateId.T3_LAG: 0.1,
	PlayerTemplates.TemplateId.T4_TAG_MAX: 0.05,
	PlayerTemplates.TemplateId.T5_NORMAL: 0.45,
	PlayerTemplates.TemplateId.T6_TRICKY: 0.15,
}

# Crazy pool weights
const CRAZY_POOL := {
	PlayerTemplates.TemplateId.T3_LAG: 0.45,
	PlayerTemplates.TemplateId.T5_NORMAL: 0.2,
	PlayerTemplates.TemplateId.T6_TRICKY: 0.35,
}


static func assign_player_templates(preset_id: PresetId, player_count: int) -> Array:
	var templates: Array = []
	templates.resize(player_count)

	match preset_id:
		PresetId.P1_ROBOT_TABLE:
			# All GTO
			for i in range(player_count):
				templates[i] = PlayerTemplates.get_template(PlayerTemplates.TemplateId.T1_GTO)

		PresetId.P2_HALF_FISH_HALF_ROBOT:
			# Half GTO, half random from live-like pool
			var gto_count := player_count / 2
			for i in range(player_count):
				if i < gto_count:
					templates[i] = PlayerTemplates.get_template(PlayerTemplates.TemplateId.T1_GTO)
				else:
					templates[i] = PlayerTemplates.get_template(_pick_from_pool(LIVE_LIKE_POOL))
			templates.shuffle()

		PresetId.P3_ONE_ROBOT_REST_RANDOM:
			# 1 GTO, rest random from live-like pool
			templates[0] = PlayerTemplates.get_template(PlayerTemplates.TemplateId.T1_GTO)
			for i in range(1, player_count):
				templates[i] = PlayerTemplates.get_template(_pick_from_pool(LIVE_LIKE_POOL))
			templates.shuffle()

		PresetId.P4_FISH_HEAVEN:
			# All from live-like pool, no GTO
			for i in range(player_count):
				templates[i] = PlayerTemplates.get_template(_pick_from_pool(LIVE_LIKE_POOL))

		PresetId.P5_ALL_CRAZY:
			# All from crazy pool
			for i in range(player_count):
				templates[i] = PlayerTemplates.get_template(_pick_from_pool(CRAZY_POOL))

		PresetId.P6_ALL_NORMAL:
			# All Normal
			for i in range(player_count):
				templates[i] = PlayerTemplates.get_template(PlayerTemplates.TemplateId.T5_NORMAL)

	return templates


static func _pick_from_pool(pool: Dictionary) -> PlayerTemplates.TemplateId:
	var total := 0.0
	for w in pool.values():
		total += w
	var rand := randf() * total
	for key in pool:
		rand -= pool[key]
		if rand <= 0.0:
			return key
	return pool.keys()[0]
