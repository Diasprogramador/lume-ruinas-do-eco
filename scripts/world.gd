extends Node2D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Levels = preload("res://scripts/levels.gd")
var level_index: int = 0
var level: Dictionary = {}
var level_cleared: bool = false
var cleared_levels: Array[int] = []
var scenery: Node2D
var terrain_nodes: Array[Node] = []
var total_seeds: int = 0
var arrival_time: float = 0
var player
var platforms: Array[Rect2] = []
var enemies: Array = []
var motes: Array[Vector2] = []
var seeds: Array[Vector2] = []
var collected: int = 0
var checkpoint := Vector2(140, 580)
var checkpoint_lit: bool = false
var started: bool = false
var won: bool = false
var time: float = 0
var hud_ui: Control
var message: Label
var title: Label
var overlay: ColorRect
var effects: Node2D
var toast_time: float = 0
var sound: Node
var escape_held: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input()
	effects = Node2D.new()
	effects.set_script(preload("res://scripts/effects.gd"))
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	sound = Node.new()
	sound.set_script(preload("res://scripts/sound.gd"))
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sound)
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = checkpoint
	player.died.connect(respawn)
	add_child(player)
	load_level(0)
	setup_hud()

func setup_input() -> void:
	Settings.apply_bindings()

func seed_id(location: Vector2) -> String:
	return ("" if level_index == 0 else "area%d:" % level_index) + "%d:%d" % [int(location.x),int(location.y)]

func spawn_enemies() -> void:
	for old in get_tree().get_nodes_in_group("enemies"):
		old.free()
	enemies.clear()
	var locations: Array = level.enemies.duplicate()
	if not level_cleared:
		locations.append(level.boss)
	for location in locations:
		var enemy = Enemy.new()
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.position = location
		enemy.boss = location == level.boss
		enemy.arena = level.arena
		enemy.biome = level_index
		enemy.defeated.connect(on_defeated)
		add_child(enemy)
		enemies.append(enemy)

func load_level(index: int, from_right: bool = false) -> void:
	level_index = clampi(index,0,4)
	level = Levels.build(level_index)
	level_cleared = level_index in cleared_levels
	for body in terrain_nodes:
		body.free()
	terrain_nodes.clear()
	if is_instance_valid(scenery):
		scenery.free()
	for child in get_children():
		if child.get_script() == preload("res://scripts/spell.gd"):
			child.queue_free()
	platforms.assign(level.platforms)
	for rect in platforms:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		terrain_nodes.append(body)
	scenery = Node2D.new()
	scenery.set_script(preload("res://scripts/scenery.gd"))
	scenery.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scenery)
	seeds.assign(level.seeds)
	total_seeds = seeds.size()
	collected = 0
	for i in range(seeds.size()-1,-1,-1):
		if seed_id(seeds[i]) in Settings.claimed_seeds:
			seeds.remove_at(i)
			collected += 1
	motes.clear()
	var random := RandomNumberGenerator.new()
	random.seed = 71 + index
	for i in range(220):
		motes.append(Vector2(random.randf_range(0,level.width),random.randf_range(80,650)))
	checkpoint = Vector2(level.width-260,580) if from_right else Vector2(140,580)
	checkpoint_lit = false
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.camera.limit_right = level.width
	player.camera.reset_smoothing()
	player.health = 5
	player.energy = 90
	player.invincible = 1.5
	player.diving = false
	player.casting = 0
	player.attack_time = 0
	player.dash_time = 0
	player.charge = 0
	player.focus = 0
	player.trail.clear()
	player.hit_targets.clear()
	player.hit_pause = 0
	player.stun = 0
	player.attack_cooldown = 0
	player.attack_buffer = 0
	player.combo_window = 0
	player.charge_ready = false
	player.air_jump = true
	player.air_dash = true
	player.dash_cooldown = 0
	effects.waves.clear()
	effects.particles.clear()
	spawn_enemies()
	arrival_time = 4.0
	queue_redraw()

func boss_encounter() -> bool:
	return started and not level_cleared and not won and player.position.x > level.arena.x - 120


func setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	# Hidden state labels keep contextual messages separate from presentation.
	message = Label.new()
	message.hide()
	layer.add_child(message)
	overlay = ColorRect.new()
	overlay.hide()
	layer.add_child(overlay)
	title = Label.new()
	title.hide()
	layer.add_child(title)
	hud_ui = Control.new()
	hud_ui.set_script(preload("res://scripts/hud.gd"))
	hud_ui.world = self
	layer.add_child(hud_ui)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 20
	add_child(touch_layer)
	var touch := preload("res://scripts/touch_controls.gd").new()
	touch.name = "TouchControls"
	touch.world = self
	touch_layer.add_child(touch)

func _process(delta: float) -> void:
	var can_shortcut: bool = Engine.get_process_frames() > hud_ui.menu.block_shortcuts_until
	var escape_pressed := Input.is_key_pressed(KEY_ESCAPE)
	var escape_just_pressed := escape_pressed and not escape_held
	escape_held = escape_pressed
	if (Input.is_action_just_pressed("pause") or escape_just_pressed) and can_shortcut:
		if hud_ui.menu.waiting_action != "" or hud_ui.menu.page != "main":
			hud_ui.menu.close_page()
		elif hud_ui.help_open:
			hud_ui.toggle_help()
		elif started and not won:
			get_tree().paused = not get_tree().paused
	if get_tree().paused:
		return
	time += delta
	arrival_time = maxf(0,arrival_time-delta)
	toast_time = maxf(0,toast_time-delta)
	if not started and Input.is_action_just_pressed("start") and not hud_ui.help_open and hud_ui.menu.page == "main" and can_shortcut:
		started = true
		player.enabled = true
		overlay.hide()
		title.hide()
	if Input.is_action_just_pressed("restart") and won and hud_ui.menu.page == "main" and can_shortcut:
		get_tree().reload_current_scene()
	if started and not won:
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.active = absf(enemy.position.x-player.position.x) < 760
				enemy.visible = absf(enemy.position.x-player.position.x) < 920
				enemy.set_process(enemy.visible)
		for i in range(seeds.size()-1,-1,-1):
			if player.position.distance_to(seeds[i]) < 37:
				Settings.collect_seed(seed_id(seeds[i]))
				seeds.remove_at(i)
				collected += 1
				burst(player.position,Color("8eeed2"),20)
				sound.play("seed")
		player.position.x = clampf(player.position.x,20,level.width-25)
		var near_shrine := false
		for shrine in level.shrines:
			if player.position.distance_to(shrine) < 75:
				near_shrine = true
				message.text = "%s • Descansar e marcar retorno" % Settings.key_label("interact")
				if Input.is_action_just_pressed("interact"):
					checkpoint = shrine - Vector2(0,22)
					checkpoint_lit = true
					player.health = 5
					player.energy = 90
					burst(player.position,level.accent,35)
					sound.play("shrine")
				break
		for hazard in level.hazards:
			if hazard.grow(12).has_point(player.position):
				player.hurt(hazard.get_center())
		if player.position.distance_to(level.exit) < 110:
			message.text = "%s • Próxima região" % Settings.key_label("interact") if level_cleared else "Derrote o guardião para abrir a passagem"
			if level_cleared and Input.is_action_just_pressed("interact") and level_index < 4:
				load_level(level_index+1)
		elif level_index > 0 and player.position.x < 190:
			message.text = "%s • Voltar à região anterior" % Settings.key_label("interact")
			if Input.is_action_just_pressed("interact"):
				load_level(level_index-1,true)
		elif not near_shrine:
			message.text = level.boss_name + " • Atravesse os golpes com dash" if boss_encounter() else "%02d / 05   •   %s" % [level_index+1,level.name.to_upper()]
	queue_redraw()

func respawn() -> void:
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.health = 5
	player.invincible = 2
	player.dash_time = 0
	player.attack_time = 0
	player.hit_targets.clear()
	player.air_jump = true
	player.air_dash = true
	player.energy = 60
	player.charge = 0
	player.charge_ready = false
	player.focus = 0
	player.casting = 0
	player.diving = false
	player.combo_window = 0
	player.attack_buffer = 0
	player.hit_pause = 0
	player.trail.clear()
	for child in get_children():
		if child.get_script() == preload("res://scripts/spell.gd"):
			child.queue_free()
	player.camera.reset_smoothing()
	toast_time = 2.5
	message.text = "Sua luz voltou ao santuário." if checkpoint_lit else "Sua luz voltou. Tente novamente."
	call_deferred("spawn_enemies")

func burst(location: Vector2, tint: Color, amount: int) -> void:
	if effects:
		effects.burst(location,tint,amount)

func on_defeated(_location: Vector2, is_boss: bool) -> void:
	if is_boss:
		level_cleared = true
		if level_index not in cleared_levels:
			cleared_levels.append(level_index)
		sound.play("shrine")
		hud_ui.notice = "Passagem aberta! Explore ou siga para a próxima região."
		hud_ui.notice_time = 5
		if level_index == 4:
			won = true
			player.enabled = false


func _draw() -> void:
	var view_x: float = player.camera.get_screen_center_position().x if player else 640
	for mote in motes:
		if absf(mote.x-view_x) > 730 or (Settings.low_power and int(mote.x)%3 != 0): continue
		var p := mote + Vector2(sin(time*0.6+mote.x)*9,cos(time+mote.x)*7)
		draw_circle(p,8,Color(0.4,0.8,0.7,0.035))
		draw_circle(p,1.5,Color(0.55,0.93,0.82,0.6))
	for seed in seeds:
		if absf(seed.x-view_x) > 750: continue
		var pos := seed+Vector2(0,sin(time*3+seed.x)*5)
		for radius in [30,22,14]:
			draw_circle(pos,radius,Color(0.55,0.93,0.82,0.05))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-10),pos+Vector2(6,0),pos+Vector2(0,10),pos+Vector2(-6,0)]),Color("8eeed2"))
		draw_line(pos+Vector2(0,-6),pos+Vector2(0,5),Color("e8efe5"),2,true)
	for shrine_position in level.shrines:
		var shrine: Vector2 = shrine_position + Vector2(0,15)
		var lit: bool = checkpoint_lit and absf(checkpoint.x-shrine.x) < 5
		draw_rect(Rect2(shrine-Vector2(36,8),Vector2(72,20)),level.rock.lightened(0.2))
		draw_line(shrine,shrine-Vector2(0,48),Color("e8efe5"),4)
		draw_circle(shrine-Vector2(0,56),14,level.accent if lit else Color("456277"))
		draw_circle(shrine-Vector2(0,56),45,Color(level.accent,0.06))
		draw_arc(shrine-Vector2(0,56),23,0,TAU,32,level.accent,2,true)
	for hazard in level.hazards:
		draw_rect(hazard,Color(level.accent,0.25))
		for x in range(int(hazard.position.x),int(hazard.end.x),18):
			var p := Vector2(x,hazard.position.y)
			draw_colored_polygon(PackedVector2Array([p,p+Vector2(9,-18),p+Vector2(18,0)]),level.accent)
	var gate: Vector2 = level.exit
	for i in range(4):
		draw_arc(gate,48+i*9,PI,TAU,48,Color(level.accent,0.6 if level_cleared else 0.15),3,true)
	for side in [-1,1]:
		draw_line(gate+Vector2(side*65,0),gate+Vector2(side*65,55),level.rock.lightened(0.3),12,true)
	if level_cleared:
		draw_circle(gate,42,Color(level.accent,0.14+sin(time*3)*0.04))
		draw_line(gate-Vector2(20,0),gate+Vector2(20,0),level.accent,3,true)
		draw_line(gate+Vector2(20,0),gate+Vector2(8,-12),level.accent,3,true)
