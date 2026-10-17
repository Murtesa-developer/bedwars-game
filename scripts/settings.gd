extends RefCounted
# Saved settings + rebindable keys (user://settings.cfg). Static, so any script can read them.

const PATH := "user://settings.cfg"
const ACTIONS := [
	["move_forward", "Move forward", KEY_W], ["move_back", "Move back", KEY_S],
	["move_left", "Move left", KEY_A], ["move_right", "Move right", KEY_D],
	["jump", "Jump", KEY_SPACE], ["sneak", "Sneak (slow, safe edge)", KEY_SHIFT],
	["sprint", "Sprint", KEY_CTRL], ["drop", "Drop item", KEY_Q],
	["shop", "Open shop", KEY_E], ["inventory", "Manage hotbar", KEY_B], ["map", "Open big map", KEY_M],
	["slot_1", "Hotbar slot 1", KEY_1], ["slot_2", "Hotbar slot 2", KEY_2], ["slot_3", "Hotbar slot 3", KEY_3],
	["slot_4", "Hotbar slot 4", KEY_4], ["slot_5", "Hotbar slot 5", KEY_5], ["slot_6", "Hotbar slot 6", KEY_6],
	["slot_7", "Hotbar slot 7", KEY_7], ["slot_8", "Hotbar slot 8", KEY_8], ["slot_9", "Hotbar slot 9", KEY_9],
]
static var sensitivity := 0.0025
static var master_vol := 0.8
static var music_vol := 0.4
static var fullscreen := false
static var friendly_fire := false
static var keys := {}

static func _num(v, d: float) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	return d

static func load_settings() -> void:
	keys.clear()
	for a in ACTIONS:
		keys[a[0]] = a[2]
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:   # missing or corrupted file -> defaults
		sensitivity = clampf(_num(cf.get_value("input", "sensitivity", sensitivity), sensitivity), 0.0005, 0.01)
		master_vol = clampf(_num(cf.get_value("audio", "master", master_vol), master_vol), 0.0, 1.0)
		music_vol = clampf(_num(cf.get_value("audio", "music", music_vol), music_vol), 0.0, 1.0)
		fullscreen = bool(cf.get_value("video", "fullscreen", false))
		friendly_fire = bool(cf.get_value("game", "friendly_fire", false))
		for a in ACTIONS:
			var k = cf.get_value("keys", a[0], a[2])
			if typeof(k) == TYPE_INT and int(k) > 0:
				keys[a[0]] = int(k)
	apply()

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("input", "sensitivity", sensitivity)
	cf.set_value("audio", "master", master_vol)
	cf.set_value("audio", "music", music_vol)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("game", "friendly_fire", friendly_fire)
	for a in ACTIONS:
		cf.set_value("keys", a[0], keys[a[0]])
	cf.save(PATH)

static func apply() -> void:
	for a in ACTIONS:
		var act: String = a[0]
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		InputMap.action_erase_events(act)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[act]
		InputMap.action_add_event(act, ev)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_vol, 0.0001)))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
