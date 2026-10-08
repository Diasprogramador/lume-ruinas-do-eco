extends Control

var world
var fingers: Dictionary = {}
var held: Dictionary = {}
var stick_index: int = -1
var stick := Vector2.ZERO
var buttons := {
	"attack": [Vector2(1110,554),55.0,"Golpe"],
	"jump": [Vector2(1202,641),51.0,"Pulo"],
	"dash": [Vector2(1005,641),46.0,"Dash"],
	"spell": [Vector2(1202,453),45.0,"Magia"],
	"charge": [Vector2(1100,430),43.0,"Carregar"],
	"focus": [Vector2(1000,525),42.0,"Curar"],
	"interact": [Vector2(860,643),43.0,"Usar"],
	"pause": [Vector2(1210,48),39.0,"Pausa"]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(release_all)

func playing() -> bool:
	return world.started and not world.won and not get_tree().paused and not world.hud_ui.help_open

func _process(_delta: float) -> void:
	visible = Settings.mobile_mode and playing()
	scale = get_viewport_rect().size / Vector2(1280,720)
	if not visible and not fingers.is_empty():
		release_all()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()

func release_all() -> void:
	for action in held:
		Input.action_release(action)
	held.clear()
	fingers.clear()
	stick_index = -1
	stick = Vector2.ZERO

func sync_actions() -> void:
	var desired: Dictionary = {}
	for action in fingers.values():
		if action != "stick":
			desired[action] = true
	if stick.x < -0.23: desired.left = true
	if stick.x > 0.23: desired.right = true
	if stick.y < -0.35: desired.up = true
	if stick.y > 0.35: desired.down = true
	for action in held:
		if not desired.has(action): Input.action_release(action)
	for action in desired:
		if not held.has(action): Input.action_press(action)
	held = desired

func _input(event: InputEvent) -> void:
	if not Settings.mobile_mode or not playing(): return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			fingers.erase(event.index)
			if stick_index == event.index:
				stick_index = -1
				stick = Vector2.ZERO
		elif point.distance_to(Vector2(160,620)) < 132 and stick_index < 0:
			stick_index = event.index
			fingers[event.index] = "stick"
			stick = ((point-Vector2(160,620))/76).limit_length()
		else:
			for action in buttons:
				if point.distance_to(buttons[action][0]) <= buttons[action][1]+5:
					fingers[event.index] = action
					break
	elif event.index == stick_index:
		stick = ((point-Vector2(160,620))/76).limit_length()
	sync_actions()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var amber := Color("e8bd80")
	var ink := Color(0.08,0.055,0.07,0.7)
	draw_circle(Vector2(160,620),88,ink)
	draw_arc(Vector2(160,620),88,0,TAU,48,Color(amber,0.5),2,true)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var p: Vector2 = Vector2(160,620)+direction*72
		draw_line(p-direction.rotated(PI/4)*9,p,amber,2,true)
		draw_line(p-direction.rotated(-PI/4)*9,p,amber,2,true)
	draw_circle(Vector2(160,620)+stick*59,31,Color(amber,0.35))
	for action in buttons:
		var spec: Array = buttons[action]
		var center: Vector2 = spec[0]
		draw_circle(center,spec[1],Color(amber,0.3) if held.has(action) else ink)
		draw_arc(center,spec[1],0,TAU,40,Color(amber,0.9),2,true)
		var font := ThemeDB.fallback_font
		var label: String = spec[2]
		var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_string(font,center+Vector2(-width/2,6),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff0d4"))
