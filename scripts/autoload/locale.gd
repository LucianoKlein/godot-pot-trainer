extends Node
## Locale — 语言切换单例
## 支持中英文切换，默认英文，持久化到 settings.json

signal language_changed()

var current_language: String = "en":
	set(v):
		if v != current_language:
			current_language = v
			language_changed.emit()

const TRANSLATIONS := {
	# === Splash Screen ===
	"splash_continue": {"en": "Press any key to continue", "zh": "按任意键继续"},

	# === Main Menu ===
	"title": {"en": "Pot Trainer", "zh": "底池训练器"},
	"start_game": {"en": "Start Game", "zh": "开始游戏"},
	"settings": {"en": "Settings", "zh": "设置"},
	"back": {"en": "← Back", "zh": "← 返回"},
	"music_volume": {"en": "Music Volume", "zh": "背景音乐音量"},
	"sfx_volume": {"en": "SFX Volume", "zh": "音效音量"},
	"layout_adjust": {"en": "Layout Adjust", "zh": "布局调整"},
	"language": {"en": "Language", "zh": "语言"},

	# === Login ===
	"login": {"en": "Login", "zh": "登录"},
	"logout": {"en": "Logout", "zh": "登出"},
	"register": {"en": "Register", "zh": "注册"},
	"guest_mode": {"en": "Guest Mode", "zh": "游客模式"},
	"email": {"en": "Email", "zh": "邮箱"},
	"password": {"en": "Password", "zh": "密码"},
	"email_placeholder": {"en": "Enter email", "zh": "请输入邮箱"},
	"password_placeholder": {"en": "Enter password", "zh": "请输入密码"},
	"google_login": {"en": "G  Sign in with Google", "zh": "G  使用 Google 登录"},
	"no_account": {"en": "No account? Register", "zh": "没有账号？注册"},
	"has_account": {"en": "Have an account? Login", "zh": "已有账号？登录"},
	"please_wait": {"en": "Please wait...", "zh": "请稍候..."},
	"confirm_logout": {"en": "Confirm logout?", "zh": "确定要登出吗？"},
	"cancel": {"en": "Cancel", "zh": "取消"},

	# Login errors
	"err_email_required": {"en": "Please enter email", "zh": "请输入邮箱"},
	"err_email_invalid": {"en": "Invalid email format", "zh": "邮箱格式不正确"},
	"err_password_required": {"en": "Please enter password", "zh": "请输入密码"},
	"err_password_short": {"en": "Password must be at least 6 characters", "zh": "密码至少6位"},
	"err_email_not_found": {"en": "Email not found", "zh": "邮箱不存在"},
	"err_invalid_password": {"en": "Wrong password", "zh": "密码错误"},
	"err_email_exists": {"en": "Email already registered", "zh": "邮箱已注册"},
	"err_weak_password": {"en": "Password must be at least 6 characters", "zh": "密码至少6位"},
	"err_too_many_attempts": {"en": "Too many attempts, try later", "zh": "尝试次数过多，请稍后再试"},
	"err_network": {"en": "Network error, check connection", "zh": "网络错误，请检查连接"},
	"err_login_failed": {"en": "Login failed: ", "zh": "登录失败："},
	"err_google_not_available": {"en": "Google Sign-In not available", "zh": "Google 登录不可用"},
	"err_google_signin_failed": {"en": "Google sign-in failed: ", "zh": "Google 登录失败："},
	"err_google_signin_cancelled": {"en": "Google sign-in cancelled", "zh": "已取消 Google 登录"},
	"err_google_failed": {"en": "Google sign-in failed: ", "zh": "Google 登录失败："},
	"err_google_cancelled": {"en": "Google sign-in cancelled", "zh": "已取消 Google 登录"},
	"apple_login": {"en": "  Sign in with Apple", "zh": "  使用 Apple 登录"},
	"err_apple_failed": {"en": "Apple sign-in failed: ", "zh": "Apple 登录失败："},
	"err_apple_cancelled": {"en": "Apple sign-in cancelled", "zh": "已取消 Apple 登录"},

	# Guest mode
	"guest_login_required": {"en": "Login required to submit answers", "zh": "需要登录才能提交答案"},
	"go_to_login": {"en": "Go to Login", "zh": "去登录"},

	# Ad overlay
	"ad_title": {"en": "Advertisement", "zh": "广告时间"},
	"ad_countdown": {"en": "Close in %d seconds", "zh": "%d 秒后可关闭"},
	"ad_can_close": {"en": "You can close now", "zh": "现在可以关闭"},
	"ad_login_hint": {"en": "Login to remove ads", "zh": "登录即可免广告"},
	"ad_close": {"en": "Close", "zh": "关闭"},
	"ad_watch_title": {"en": "Watch Ad to Continue", "zh": "观看广告继续"},
	"ad_watch_msg": {"en": "You've completed 3 questions!\nWatch an ad to unlock 3 more.", "zh": "你已完成 3 题！\n观看一次广告解锁 3 题。"},
	"ad_watch_btn": {"en": "▶ Watch Ad (15-20s)", "zh": "▶ 观看广告 (15-20秒)"},
	"ad_debug_skip": {"en": "[DEBUG] Skip Ad", "zh": "[测试] 跳过广告"},
	"ad_loading": {"en": "Loading ad...", "zh": "广告加载中..."},
	"ad_unavailable": {"en": "Ad not available.\nPlease try again later.", "zh": "广告暂不可用。\n请稍后再试。"},
	"ad_reward_title": {"en": "✓ Reward Unlocked!", "zh": "✓ 奖励已解锁！"},
	"ad_reward_msg": {"en": "You've unlocked 3 more questions!\nKeep playing.", "zh": "已解锁 3 题！\n继续答题吧。"},
	"continue_btn": {"en": "Continue", "zh": "继续"},
	"ok": {"en": "OK", "zh": "确定"},

	# === Game Table ===
	"question_text": {"en": "What is the pot-limit max raise?", "zh": "底池限注最大加注是多少？"},
	"correct_answer": {"en": "Correct! %d", "zh": "正确！%d"},
	"wrong_answer": {"en": "Wrong! You: %d, Correct: %d", "zh": "错误！你答: %d，正确: %d"},
	"hand_over": {"en": "Hand over.", "zh": "本手结束。"},
	"game_mode_hand_over": {"en": "Hand finished! Press Start for next hand.", "zh": "本手结束！点击开始进行下一手。"},
	"seat_raise_question": {"en": "Seat %d raises — what is the pot-limit max?", "zh": "座位 %d 加注 — 底池限注最大是多少？"},
	"seat_raise_to": {"en": "Seat %d raises to %d", "zh": "座位 %d 加注到 %d"},

	# === Seat UI ===
	"player_n": {"en": "Player %d", "zh": "玩家%d"},
	"fold": {"en": "Fold", "zh": "弃牌"},
	"seat_n": {"en": "S%d", "zh": "座%d"},
	"action_blind": {"en": "Blind", "zh": "盲注"},
	"action_fold": {"en": "Fold", "zh": "弃牌"},
	"action_check": {"en": "Check", "zh": "过牌"},
	"action_call": {"en": "Call", "zh": "跟注"},
	"action_bet": {"en": "Bet", "zh": "下注"},
	"action_raise": {"en": "Raise", "zh": "加注"},
	"seat_action_prefix": {"en": "S%d ", "zh": "座%d "},

	# === Table Center ===
	"pot_display": {"en": "Pot: %d", "zh": "底池: %d"},
	"street_preflop": {"en": "Preflop", "zh": "翻牌前"},
	"street_flop": {"en": "Flop", "zh": "翻牌"},
	"street_turn": {"en": "Turn", "zh": "转牌"},
	"street_river": {"en": "River", "zh": "河牌"},
	"street_showdown": {"en": "Showdown", "zh": "摊牌"},

	# === Answer Box ===
	"submit": {"en": "Submit", "zh": "确认"},
	"amount_placeholder": {"en": "Enter amount...", "zh": "输入金额..."},
	"seat_label": {"en": "Seat %d", "zh": "座位 %d"},
	"seat_label_template": {"en": "Seat %d · %s", "zh": "座位 %d · %s"},
	"err_invalid_number": {"en": "Please enter a valid number", "zh": "请输入有效数字"},
	"numpad_confirm": {"en": "OK", "zh": "确定"},
	"numpad_cancel": {"en": "CLR", "zh": "取消"},
	"preview": {"en": "Preview", "zh": "预览"},

	# === Control Panel ===
	"player_count": {"en": "Players:", "zh": "人数:"},
	"blinds": {"en": "Blinds:", "zh": "盲注:"},
	"table_preset": {"en": "Table:", "zh": "牌桌:"},
	"mode_label": {"en": "Mode:", "zh": "模式:"},
	"scenario_mode": {"en": "Spot Mode", "zh": "场景模式"},
	"game_mode": {"en": "Game Mode", "zh": "游戏模式"},
	"dealer_label": {"en": "Dealer:", "zh": "庄家:"},
	"display_mode_label": {"en": "Display:", "zh": "展示模式:"},
	"chips_mode": {"en": "Chips", "zh": "筹码"},
	"numbers_mode": {"en": "Numbers", "zh": "数字"},
	"config_expand": {"en": "⚙ Config ▲", "zh": "⚙ 配置 ▲"},
	"config_collapse": {"en": "⚙ Config ▼", "zh": "⚙ 配置 ▼"},
	"start": {"en": "Start", "zh": "开始"},
	"pause": {"en": "Pause", "zh": "暂停"},
	"reset": {"en": "Reset", "zh": "重置"},
	"layout": {"en": "Layout", "zh": "布局"},
	"back_to_menu": {"en": "Back to Menu", "zh": "返回主菜单"},
	"seat_option": {"en": "Seat %d", "zh": "座位 %d"},

	# === Layout Editor ===
	"layout_editor_title": {"en": "Layout Editor  (drag here)", "zh": "布局编辑器  (拖动此处)"},
	"dealer_button_label": {"en": "Dealer Btn", "zh": "庄位按钮"},
	"hole_cards_label": {"en": "Hole Cards", "zh": "手牌"},
	"hole_card_gap_label": {"en": "Card Gap", "zh": "手牌间距"},
	"community_cards_label": {"en": "Community", "zh": "公共牌"},
	"bet_label_label": {"en": "Bet Label", "zh": "下注标签"},
	"stack_label_label": {"en": "Stack Label", "zh": "本金标签"},
	"pot_display_label": {"en": "Pot Display", "zh": "底池显示"},
	"player_chips_label": {"en": "Player Chips", "zh": "玩家筹码"},
	"bet_chips_label": {"en": "Bet Chips", "zh": "下注筹码"},
	"bet_spread_label": {"en": "Bet Spread", "zh": "散落间距"},
	"pot_chips_label": {"en": "Pot Chips", "zh": "底池筹码"},
	"chip_record_label": {"en": "Chip Record", "zh": "筹码记录"},
	"ordered_chips_label": {"en": "Ordered Chips", "zh": "整齐筹码"},
	"ordered_chip_v_gap_label": {"en": "Chip V-Gap", "zh": "筹码纵向间距"},
	"answer_box_label": {"en": "Answer Box", "zh": "答题框"},
	"action_box_label": {"en": "Action Box", "zh": "行动框"},
	"street_badge_label": {"en": "Street Badge", "zh": "轮次标签"},
	"save_to_file": {"en": "Save to File", "zh": "保存到文件"},
	"reset_layout": {"en": "Reset Layout", "zh": "重置布局"},
	"display_mode_toggle": {"en": "Display Mode:", "zh": "显示模式:"},
	"blinds_mode_toggle": {"en": "Blinds Mode:", "zh": "盲注模式:"},
	"select_all": {"en": "Select/Deselect All", "zh": "全选/取消全选"},

	# === Player Templates ===
	"template_gto": {"en": "GTO", "zh": "均衡型"},
	"template_calling_station": {"en": "Calling Station", "zh": "跟注站"},
	"template_lag": {"en": "LAG", "zh": "松凶型"},
	"template_tag_max": {"en": "TAG Max", "zh": "紧凶型"},
	"template_normal": {"en": "Normal", "zh": "普通型"},
	"template_tricky": {"en": "Tricky", "zh": "诡诈型"},

	# === Table Presets ===
	"preset_gto_table": {"en": "GTO Table", "zh": "GTO牌桌"},
	"preset_mixed": {"en": "Mixed Table", "zh": "混合牌桌"},
	"preset_one_gto": {"en": "1 GTO Table", "zh": "单GTO牌桌"},
	"preset_casual": {"en": "Casual Table", "zh": "休闲牌桌"},
	"preset_crazy": {"en": "Crazy Table", "zh": "激进牌桌"},
	"preset_normal": {"en": "Normal Table", "zh": "常规牌桌"},

}


func tr_key(key: String) -> String:
	if TRANSLATIONS.has(key):
		var entry: Dictionary = TRANSLATIONS[key]
		var lang := GameManager.language if GameManager else "en"
		if entry.has(lang):
			return entry[lang]
		return entry.get("en", key)
	return key
