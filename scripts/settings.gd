extends Node

signal changed

const DEFAULT_KEYS := {
	"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],
	"jump":[KEY_SPACE,KEY_Z],"attack":[KEY_J,KEY_X],"charge":[KEY_K],"spell":[KEY_Q],"focus":[KEY_F],
	"dash":[KEY_SHIFT,KEY_C],"interact":[KEY_E],"help":[KEY_H],"pause":[KEY_ESCAPE],"start":[KEY_ENTER],"restart":[KEY_R]
}
const ACTION_NAMES := {
	"left":"Mover à esquerda","right":"Mover à direita","up":"Mirar para cima","down":"Mirar para baixo",
	"jump":"Pular","attack":"Atacar","charge":"Corte carregado","spell":"Magia","focus":"Curar",
	"dash":"Dash","interact":"Interagir","help":"Ajuda","pause":"Pausar"
}
const ITEMS := {
	"original":{"name":"Capa dos jardins","cost":0,"color":Color.WHITE,"accent":Color("8eeed2"),"description":"A luz verde dos jardins esquecidos."},
	"moon":{"name":"Capa lunar","cost":2,"color":Color(0.8,0.9,1),"accent":Color("a8d7ff"),"description":"Tecido azul sob o brilho da lua."},
	"ember":{"name":"Capa de brasa","cost":3,"color":Color(1,0.7,0.55),"accent":Color("ffba83"),"description":"Uma centelha nas ruínas silenciosas."},
	"violet":{"name":"Capa crepuscular","cost":3,"color":Color(0.85,0.65,1),"accent":Color("d2b4ff"),"description":"O violeta das últimas horas do dia."}
}
var browser_pause_callback
var mobile_mode: bool = false
var low_power: bool = false
var bindings: Dictionary = {}
var master_volume: float = 0.85
var music_volume: float = 0.65
var effects_volume: float = 0.8
var fullscreen: bool = false
var camera_shake: bool = true
var wallet: int = 0
var claimed_seeds: Array = []
var owned: Array = ["original"]
var equipped: String = "original"
var save_path: String = "user://preferences.cfg"
var test_mode: bool = false
var last_save_error: Error = OK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_mode = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--mobile" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		mobile_mode = bool(JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches",true))
	if OS.has_feature("web"):
		browser_pause_callback = JavaScriptBridge.create_callback(_web_pause)
		JavaScriptBridge.get_interface("window").lumePause = browser_pause_callback
	low_power = mobile_mode
	Engine.max_fps = 60
	load_profile()
	apply_bindings()
	setup_audio_buses()
	apply_audio()
	if fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for action in ACTION_NAMES:
		var key: int = int(config.get_value("keys",action,0))
		if key > 0:
			bindings[action] = key
	master_volume = clampf(float(config.get_value("audio","master",0.85)),0,1)
	music_volume = clampf(float(config.get_value("audio","music",0.65)),0,1)
	effects_volume = clampf(float(config.get_value("audio","effects",0.8)),0,1)
	fullscreen = bool(config.get_value("display","fullscreen",false))
	camera_shake = bool(config.get_value("display","shake",true))
	wallet = maxi(0,int(config.get_value("shop","wallet",0)))
	var saved_seeds = config.get_value("shop","seeds",[])
	claimed_seeds = saved_seeds if saved_seeds is Array else []
	var saved_owned = config.get_value("shop","owned",["original"])
	owned = ["original"]
	if saved_owned is Array:
		for item in saved_owned:
			if ITEMS.has(item) and item not in owned:
				owned.append(item)
	var saved_equipped: String = str(config.get_value("shop","equipped","original"))
	equipped = saved_equipped if saved_equipped in owned else "original"

func save_profile() -> Error:
	if test_mode:
		return OK
	var config := ConfigFile.new()
	for action in bindings:
		config.set_value("keys",action,bindings[action])
	config.set_value("audio","master",master_volume)
	config.set_value("audio","music",music_volume)
	config.set_value("audio","effects",effects_volume)
	config.set_value("display","fullscreen",fullscreen)
	config.set_value("display","shake",camera_shake)
	config.set_value("shop","wallet",wallet)
	config.set_value("shop","seeds",claimed_seeds)
	config.set_value("shop","owned",owned)
	config.set_value("shop","equipped",equipped)
	last_save_error = config.save(save_path)
	return last_save_error

func apply_bindings() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var keys: Array = [bindings[action]] if bindings.has(action) else DEFAULT_KEYS[action]
		for key in keys:
			var event := InputEventKey.new()
			event.physical_keycode = int(key)
			InputMap.action_add_event(action,event)
	# Mouse remains available as an alternative to keyboard attacks.
	for spec in ([] if mobile_mode else [["attack",MOUSE_BUTTON_LEFT],["spell",MOUSE_BUTTON_RIGHT]]):
		var event := InputEventMouseButton.new()
		event.button_index = spec[1]
		InputMap.action_add_event(spec[0],event)
	changed.emit()

func rebind(action: String, key: int) -> String:
	if not ACTION_NAMES.has(action):
		return "Ação desconhecida."
	if key in [KEY_ESCAPE,KEY_ENTER,KEY_TAB] or key <= 0:
		return "Esc, Enter e Tab ficam reservados para navegar nos menus."
	for other in DEFAULT_KEYS:
		if other == action:
			continue
		var keys: Array = [bindings[other]] if bindings.has(other) else DEFAULT_KEYS[other]
		if key in keys:
			return "Essa tecla já está em uso: %s." % ACTION_NAMES.get(other,"Menu / reiniciar")
	bindings[action] = key
	apply_bindings()
	save_profile()
	return ""

func reset_keys() -> void:
	bindings.clear()
	apply_bindings()
	save_profile()

func key_label(action: String, all_keys: bool = false) -> String:
	var keys: Array = [bindings[action]] if bindings.has(action) else DEFAULT_KEYS.get(action,[])
	var labels := PackedStringArray()
	for key in keys:
		var name := OS.get_keycode_string(int(key))
		name = {"Space":"Espaço","Left":"←","Right":"→","Up":"↑","Down":"↓","Escape":"Esc"}.get(name,name)
		labels.append(name)
		if not all_keys:
			break
	return " / ".join(labels)

func setup_audio_buses() -> void:
	for name in ["Music","Effects"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count-1
			AudioServer.set_bus_name(index,name)
			AudioServer.set_bus_send(index,"Master")

func apply_audio() -> void:
	for spec in [["Master",master_volume],["Music",music_volume],["Effects",effects_volume]]:
		var index := AudioServer.get_bus_index(spec[0])
		if index >= 0:
			AudioServer.set_bus_mute(index,spec[1] <= 0)
			AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.001,spec[1])))
	changed.emit()

func set_volume(kind: String, amount: float) -> void:
	var value := clampf(amount,0,1)
	match kind:
		"master": master_volume = value
		"music": music_volume = value
		"effects": effects_volume = value
	apply_audio()
	save_profile()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	save_profile()
	changed.emit()

func collect_seed(id: String) -> bool:
	if id in claimed_seeds:
		return false
	claimed_seeds.append(id)
	wallet += 1
	save_profile()
	changed.emit()
	return true

func purchase(item: String) -> String:
	if not ITEMS.has(item):
		return "Item desconhecido."
	if item not in owned:
		var cost: int = ITEMS[item].cost
		if wallet < cost:
			return "Faltam %d sementes. Explore os caminhos altos para coletar mais." % (cost-wallet)
		wallet -= cost
		owned.append(item)
	equipped = item
	save_profile()
	changed.emit()
	return ""

func reset_test_profile() -> void:
	test_mode = true
	bindings.clear()
	wallet = 0
	claimed_seeds.clear()
	owned = ["original"]
	equipped = "original"
	master_volume = 0.85
	music_volume = 0.65
	effects_volume = 0.8
	camera_shake = true
	apply_bindings()
	apply_audio()

func _web_pause(_args: Array) -> void:
	var world = get_tree().current_scene
	if world and world.get("started") and not world.get("won"):
		get_tree().paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not test_mode:
		_web_pause([])
