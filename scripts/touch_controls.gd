extends Control

var world
var fingers: Dictionary = {}
var held: Dictionary = {}
var stick_index: int = -1
var stick := Vector2.ZERO
const Icons = preload("res://scripts/combat_icons.gd")
var buttons: Dictionary = {}
var layout: Dictionary = {}
var opacity: float = 0.85
var show_labels: bool = true
var editing: bool = false
var selected: String = "attack"
var drag_index: int = -1
var drag_offset := Vector2.ZERO
var was_paused: bool = false
var editor_ui: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(release_all)
	Settings.changed.connect(load_layout)
	load_layout()
	editor_ui = preload("res://scripts/hud_editor.gd").new()
	editor_ui.touch = self
	add_child(editor_ui)
	editor_ui.hide()

func load_layout() -> void:
	if editing: return
	layout = Settings.sanitize_touch_layout(Settings.hud_layout)
	opacity = Settings.hud_opacity
	show_labels = Settings.hud_labels
	update_buttons()

func update_buttons() -> void:
	buttons.clear()
	for action in Settings.TOUCH_DEFAULTS:
		if action == "stick": continue
		buttons[action] = [layout[action].position,Settings.TOUCH_DEFAULTS[action][1]*layout[action].scale,Settings.TOUCH_DEFAULTS[action][2]]
	queue_redraw()

func begin_edit() -> void:
	load_layout()
	release_all()
	was_paused = get_tree().paused
	get_tree().paused = true
	editing = true
	selected = "attack"
	editor_ui.show()
	editor_ui.refresh()
	visible = true

func finish_edit(save: bool) -> void:
	if save and Settings.save_touch_layout(layout,opacity,show_labels) != OK:
		editor_ui.hint.text = "Não foi possível salvar. Tente novamente ou cancele."
		return
	release_all()
	editing = false
	editor_ui.hide()
	load_layout()
	get_tree().paused = was_paused
	world.hud_ui.menu.block_shortcuts_until = Engine.get_process_frames()+3

func reset_draft() -> void:
	layout = Settings.default_touch_layout()
	opacity = 0.85
	show_labels = true
	update_buttons()
	editor_ui.refresh()

func playing() -> bool:
	return world.started and not world.won and not get_tree().paused and not world.hud_ui.help_open

func _process(_delta: float) -> void:
	visible = editing or (Settings.mobile_mode and playing())
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
	drag_index = -1

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
	if editing:
		edit_input(event)
		return
	if not Settings.mobile_mode or not playing(): return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			fingers.erase(event.index)
			if stick_index == event.index:
				stick_index = -1
				stick = Vector2.ZERO
		else:
			var target := ""
			var nearest := INF
			if stick_index < 0 and point.distance_to(layout.stick.position) < 100*layout.stick.scale:
				target = "stick"
				nearest = point.distance_to(layout.stick.position)/(88*layout.stick.scale)
			for action in buttons:
				var distance: float = point.distance_to(buttons[action][0])/buttons[action][1]
				if distance <= 1.08 and distance < nearest:
					target = action
					nearest = distance
			if target != "": fingers[event.index] = target
			if target == "stick":
				stick_index = event.index
				stick = ((point-layout.stick.position)/(76*layout.stick.scale)).limit_length()
	elif event.index == stick_index:
		stick = ((point-layout.stick.position)/(76*layout.stick.scale)).limit_length()
	sync_actions()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	if layout.is_empty(): return
	var amber := Color("e8bd80")
	var alpha: float = opacity
	amber.a = alpha
	var ink := Color(0.08,0.055,0.07,0.7*alpha)
	if editing:
		draw_rect(Rect2(0,0,1280,720),Color(0.01,0.02,0.04,0.38))
		for x in range(0,1280,40): draw_line(Vector2(x,0),Vector2(x,720),Color(1,1,1,0.035))
		for y in range(0,720,40): draw_line(Vector2(0,y),Vector2(1280,y),Color(1,1,1,0.035))
	var origin: Vector2 = layout.stick.position
	var factor: float = layout.stick.scale
	draw_circle(origin,88*factor,ink)
	draw_arc(origin,88*factor,0,TAU,48,Color(amber,0.5*alpha),2,true)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var p: Vector2 = origin+direction*72*factor
		draw_line(p-direction.rotated(PI/4)*9,p,amber,2,true)
		draw_line(p-direction.rotated(-PI/4)*9,p,amber,2,true)
	draw_circle(origin+stick*59*factor,31*factor,Color(amber,0.35*alpha))
	for action in buttons:
		var spec: Array = buttons[action]
		var center: Vector2 = spec[0]
		draw_circle(center,spec[1],Color(amber,0.3*alpha) if held.has(action) else ink)
		draw_arc(center,spec[1],0,TAU,40,Color(amber,0.9*alpha),2,true)
		var labeled: bool = show_labels or (editing and selected == action)
		Icons.paint(self,action,center-Vector2(0,9 if labeled else 0),spec[1]*0.63,amber)
		var font := ThemeDB.fallback_font
		var label: String = spec[2]
		var font_size := int(16*layout[action].scale)
		var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		if labeled:
			draw_string(font,center+Vector2(-width/2,spec[1]*0.62),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(Color("fff0d4"),alpha))
	if editing:
		var radius: float = Settings.TOUCH_DEFAULTS[selected][1]*layout[selected].scale
		draw_arc(layout[selected].position,radius+6,0,TAU,48,Color("fff0d4"),3,true)

func edit_input(event: InputEvent) -> void:
	var press := false
	var release := false
	var index := 1000
	var position_on_screen := Vector2.ZERO
	if event is InputEventScreenTouch:
		index = event.index
		press = event.pressed and not event.canceled
		release = not press
		position_on_screen = event.position
	elif event is InputEventScreenDrag:
		index = event.index
		position_on_screen = event.position
	elif event is InputEventMouseButton:
		if event.device == -1 or event.button_index != MOUSE_BUTTON_LEFT: return
		press = event.pressed
		release = not press
		position_on_screen = event.position
	elif event is InputEventMouseMotion:
		if event.device == -1: return
		position_on_screen = event.position
	else: return
	if release and drag_index == index:
		drag_index = -1
		get_viewport().set_input_as_handled()
		return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*position_on_screen
	if editor_ui.get_rect().has_point(point): return
	if press and drag_index < 0:
		var nearest := INF
		for action in layout:
			var distance: float = point.distance_to(layout[action].position)
			var radius: float = Settings.TOUCH_DEFAULTS[action][1]*layout[action].scale
			if distance <= radius+6 and distance < nearest:
				selected = action
				nearest = distance
		if nearest < INF:
			drag_index = index
			drag_offset = layout[selected].position-point
			editor_ui.refresh()
	elif not press and drag_index == index:
		layout[selected].position = point+drag_offset
		layout = Settings.sanitize_touch_layout(layout)
		update_buttons()
	get_viewport().set_input_as_handled()
