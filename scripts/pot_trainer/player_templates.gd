class_name PlayerTemplates
extends RefCounted

# --- Types ---

# Action enums
enum NoAggressionAction { FOLD, CHECK, BET_SMALL, BET_BIG, BET_POT }
enum VsAggressionAction { FOLD, CALL, RAISE_SMALL, RAISE_BIG, RAISE_POT }
enum AggressionSize { SMALL, BIG, POT }
enum TemplateId { T1_GTO, T2_CALLING_STATION, T3_LAG, T4_TAG_MAX, T5_NORMAL, T6_TRICKY }

# --- Player Template Data ---

class PlayerTemplate:
	var id: TemplateId
	var template_name: String
	var no_aggression: Dictionary  # {NoAggressionAction: float}
	var vs_aggression_by_size: Dictionary  # {AggressionSize: {VsAggressionAction: float}}

	func _init(p_id: TemplateId, p_name: String, p_no_agg: Dictionary, p_vs_agg: Dictionary) -> void:
		id = p_id
		template_name = p_name
		no_aggression = p_no_agg
		vs_aggression_by_size = p_vs_agg


# --- Singleton template instances ---

static var _templates: Dictionary = {}  # {TemplateId: PlayerTemplate}
static var _initialized: bool = false


static func get_template(id: TemplateId) -> PlayerTemplate:
	if not _initialized:
		_init_templates()
	return _templates[id]


static func get_all_templates() -> Dictionary:
	if not _initialized:
		_init_templates()
	return _templates


static func _init_templates() -> void:
	_initialized = true

	# T1_GTO - 均衡玩家
	_templates[TemplateId.T1_GTO] = PlayerTemplate.new(
		TemplateId.T1_GTO, "均衡型",
		{
			NoAggressionAction.FOLD: 0.14,
			NoAggressionAction.CHECK: 0.46,
			NoAggressionAction.BET_SMALL: 0.16,
			NoAggressionAction.BET_BIG: 0.11,
			NoAggressionAction.BET_POT: 0.13,
		},
		{
			AggressionSize.SMALL: {
				VsAggressionAction.FOLD: 0.24, VsAggressionAction.CALL: 0.44,
				VsAggressionAction.RAISE_SMALL: 0.14, VsAggressionAction.RAISE_BIG: 0.08,
				VsAggressionAction.RAISE_POT: 0.1,
			},
			AggressionSize.BIG: {
				VsAggressionAction.FOLD: 0.34, VsAggressionAction.CALL: 0.42,
				VsAggressionAction.RAISE_SMALL: 0.1, VsAggressionAction.RAISE_BIG: 0.06,
				VsAggressionAction.RAISE_POT: 0.08,
			},
			AggressionSize.POT: {
				VsAggressionAction.FOLD: 0.46, VsAggressionAction.CALL: 0.39,
				VsAggressionAction.RAISE_SMALL: 0.06, VsAggressionAction.RAISE_BIG: 0.03,
				VsAggressionAction.RAISE_POT: 0.06,
			},
		}
	)

	# T2_CALLING_STATION - 温和跟注者
	_templates[TemplateId.T2_CALLING_STATION] = PlayerTemplate.new(
		TemplateId.T2_CALLING_STATION, "跟注站",
		{
			NoAggressionAction.FOLD: 0.18,
			NoAggressionAction.CHECK: 0.68,
			NoAggressionAction.BET_SMALL: 0.11,
			NoAggressionAction.BET_BIG: 0.025,
			NoAggressionAction.BET_POT: 0.005,
		},
		{
			AggressionSize.SMALL: {
				VsAggressionAction.FOLD: 0.1, VsAggressionAction.CALL: 0.82,
				VsAggressionAction.RAISE_SMALL: 0.06, VsAggressionAction.RAISE_BIG: 0.015,
				VsAggressionAction.RAISE_POT: 0.005,
			},
			AggressionSize.BIG: {
				VsAggressionAction.FOLD: 0.18, VsAggressionAction.CALL: 0.76,
				VsAggressionAction.RAISE_SMALL: 0.05, VsAggressionAction.RAISE_BIG: 0.008,
				VsAggressionAction.RAISE_POT: 0.002,
			},
			AggressionSize.POT: {
				VsAggressionAction.FOLD: 0.3, VsAggressionAction.CALL: 0.68,
				VsAggressionAction.RAISE_SMALL: 0.018, VsAggressionAction.RAISE_BIG: 0.002,
				VsAggressionAction.RAISE_POT: 0.0,
			},
		}
	)

	# T3_LAG - 积极进攻者
	_templates[TemplateId.T3_LAG] = PlayerTemplate.new(
		TemplateId.T3_LAG, "松凶型",
		{
			NoAggressionAction.FOLD: 0.06,
			NoAggressionAction.CHECK: 0.14,
			NoAggressionAction.BET_SMALL: 0.2,
			NoAggressionAction.BET_BIG: 0.23,
			NoAggressionAction.BET_POT: 0.37,
		},
		{
			AggressionSize.SMALL: {
				VsAggressionAction.FOLD: 0.06, VsAggressionAction.CALL: 0.26,
				VsAggressionAction.RAISE_SMALL: 0.22, VsAggressionAction.RAISE_BIG: 0.18,
				VsAggressionAction.RAISE_POT: 0.28,
			},
			AggressionSize.BIG: {
				VsAggressionAction.FOLD: 0.1, VsAggressionAction.CALL: 0.26,
				VsAggressionAction.RAISE_SMALL: 0.18, VsAggressionAction.RAISE_BIG: 0.16,
				VsAggressionAction.RAISE_POT: 0.3,
			},
			AggressionSize.POT: {
				VsAggressionAction.FOLD: 0.18, VsAggressionAction.CALL: 0.28,
				VsAggressionAction.RAISE_SMALL: 0.14, VsAggressionAction.RAISE_BIG: 0.12,
				VsAggressionAction.RAISE_POT: 0.28,
			},
		}
	)

	# T4_TAG_MAX - 谨慎重压者
	_templates[TemplateId.T4_TAG_MAX] = PlayerTemplate.new(
		TemplateId.T4_TAG_MAX, "紧凶型",
		{
			NoAggressionAction.FOLD: 0.34,
			NoAggressionAction.CHECK: 0.44,
			NoAggressionAction.BET_SMALL: 0.04,
			NoAggressionAction.BET_BIG: 0.06,
			NoAggressionAction.BET_POT: 0.12,
		},
		{
			AggressionSize.SMALL: {
				VsAggressionAction.FOLD: 0.42, VsAggressionAction.CALL: 0.3,
				VsAggressionAction.RAISE_SMALL: 0.05, VsAggressionAction.RAISE_BIG: 0.08,
				VsAggressionAction.RAISE_POT: 0.15,
			},
			AggressionSize.BIG: {
				VsAggressionAction.FOLD: 0.5, VsAggressionAction.CALL: 0.28,
				VsAggressionAction.RAISE_SMALL: 0.04, VsAggressionAction.RAISE_BIG: 0.06,
				VsAggressionAction.RAISE_POT: 0.12,
			},
			AggressionSize.POT: {
				VsAggressionAction.FOLD: 0.6, VsAggressionAction.CALL: 0.26,
				VsAggressionAction.RAISE_SMALL: 0.03, VsAggressionAction.RAISE_BIG: 0.04,
				VsAggressionAction.RAISE_POT: 0.07,
			},
		}
	)

	# T5_NORMAL - 普通玩家
	_templates[TemplateId.T5_NORMAL] = PlayerTemplate.new(
		TemplateId.T5_NORMAL, "普通型",
		{
			NoAggressionAction.FOLD: 0.18,
			NoAggressionAction.CHECK: 0.5,
			NoAggressionAction.BET_SMALL: 0.15,
			NoAggressionAction.BET_BIG: 0.1,
			NoAggressionAction.BET_POT: 0.07,
		},
		{
			AggressionSize.SMALL: {
				VsAggressionAction.FOLD: 0.28, VsAggressionAction.CALL: 0.42,
				VsAggressionAction.RAISE_SMALL: 0.13, VsAggressionAction.RAISE_BIG: 0.1,
				VsAggressionAction.RAISE_POT: 0.07,
			},
			AggressionSize.BIG: {
				VsAggressionAction.FOLD: 0.36, VsAggressionAction.CALL: 0.41,
				VsAggressionAction.RAISE_SMALL: 0.1, VsAggressionAction.RAISE_BIG: 0.08,
				VsAggressionAction.RAISE_POT: 0.05,
			},
			AggressionSize.POT: {
				VsAggressionAction.FOLD: 0.48, VsAggressionAction.CALL: 0.4,
				VsAggressionAction.RAISE_SMALL: 0.06, VsAggressionAction.RAISE_BIG: 0.04,
				VsAggressionAction.RAISE_POT: 0.02,
			},
		}
	)

	# T6_TRICKY - 善于隐藏者
	_templates[TemplateId.T6_TRICKY] = PlayerTemplate.new(
		TemplateId.T6_TRICKY, "诡诈型",
		{
			NoAggressionAction.FOLD: 0.14,
			NoAggressionAction.CHECK: 0.4,
			NoAggressionAction.BET_SMALL: 0.26,
			NoAggressionAction.BET_BIG: 0.12,
			NoAggressionAction.BET_POT: 0.08,
		},
		{
			AggressionSize.SMALL: {
				VsAggressionAction.FOLD: 0.2, VsAggressionAction.CALL: 0.34,
				VsAggressionAction.RAISE_SMALL: 0.26, VsAggressionAction.RAISE_BIG: 0.12,
				VsAggressionAction.RAISE_POT: 0.08,
			},
			AggressionSize.BIG: {
				VsAggressionAction.FOLD: 0.28, VsAggressionAction.CALL: 0.36,
				VsAggressionAction.RAISE_SMALL: 0.2, VsAggressionAction.RAISE_BIG: 0.1,
				VsAggressionAction.RAISE_POT: 0.06,
			},
			AggressionSize.POT: {
				VsAggressionAction.FOLD: 0.42, VsAggressionAction.CALL: 0.38,
				VsAggressionAction.RAISE_SMALL: 0.12, VsAggressionAction.RAISE_BIG: 0.06,
				VsAggressionAction.RAISE_POT: 0.02,
			},
		}
	)


# --- Utility: Weighted random roll ---

static func weighted_roll(weights: Dictionary) -> int:
	var total := 0.0
	for w in weights.values():
		total += w
	var rand := randf() * total
	for key in weights:
		rand -= weights[key]
		if rand <= 0.0:
			return key
	return weights.keys()[0]


# --- Utility: Get aggression size ---

static func get_aggression_size(bet_amount: float, pot_size: float) -> AggressionSize:
	if pot_size <= 0.0:
		return AggressionSize.POT
	var ratio := bet_amount / pot_size
	if ratio <= 0.4:
		return AggressionSize.SMALL
	if ratio <= 0.75:
		return AggressionSize.BIG
	return AggressionSize.POT
