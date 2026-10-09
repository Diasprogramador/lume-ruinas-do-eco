extends Control

var world
var body: Font
var display: Font
var menu: Control
var help_open: bool = false
const Icons = preload("res://scripts/combat_icons.gd")
var previous_health: int = 5
var damage_flash: float = 0
var display_energy: float = 60
var display_boss_health: float = 14
var help_paused: bool = false
var notice: String = ""
var notice_time: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	body = ThemeDB.fallback_font
	display = preload("res://assets/fonts/CormorantGaramond.ttf")
	menu = preload("res://scripts/menu_pages.gd").new()
	menu.world = world
	add_child(menu)

func activate() -> void:
	if menu.page != "main" or menu.waiting_action != "":
		return
	help_open = false
	help_paused = false
	if world.won:
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif get_tree().paused:
		get_tree().paused = false
	else:
		world.started = true
		world.player.enabled = true
		world.overlay.hide()
		world.title.hide()

func toggle_help() -> void:
	if not help_open:
		help_paused = world.started and not world.won and not get_tree().paused
		if help_paused:
			get_tree().paused = true
	else:
		if help_paused:
			get_tree().paused = false
		help_paused = false
	help_open = not help_open

func _process(delta: float) -> void:
	scale = get_viewport_rect().size / Vector2(1280,720)
	if world.touch_controls and world.touch_controls.editing:
		menu.hide()
		queue_redraw()
		return
	if Input.is_action_just_pressed("help"):
		if menu.page == "main" and Engine.get_process_frames() > menu.block_shortcuts_until:
			toggle_help()
	if world.player.health < previous_health:
		damage_flash = 0.3
	previous_health = world.player.health
	damage_flash = maxf(0,damage_flash-delta)
	if not get_tree().paused:
		notice_time = maxf(0,notice_time-delta)
	display_energy = move_toward(display_energy,world.player.energy,delta*160)
	menu.visible = not world.started or world.won or get_tree().paused
	queue_redraw()

func text(value: String, pos: Vector2, size: int = 16, tint: Color = Color("d6e8df"), title_font: bool = false) -> void:
	draw_string(display if title_font else body,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,tint)

func panel(rect: Rect2) -> void:
	draw_style_box(make_panel(),rect)

func make_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.07,0.1,0.9)
	style.border_color = Color(0.45,0.65,0.6,0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func diamond(center: Vector2, radius: float, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)]),tint)

func _draw() -> void:
	if not world or not world.player:
		return
	if world.touch_controls and world.touch_controls.editing:
		return
	if menu.visible and not help_open:
		draw_rect(Rect2(0,0,1280,720),Color(0.015,0.02,0.035,0.72 if menu.page == "main" else 0.9))
		return
	var player = world.player
	# Ivory filigree sits directly over the world, with quiet ink shadows.
	for i in range(6):
		draw_circle(Vector2(145,63),130-i*12,Color(0.015,0.02,0.04,0.035))
	var vessel := Vector2(66,68)
	draw_set_transform(vessel,0,Vector2(0.78,1))
	draw_circle(Vector2.ZERO,32,Color("111a25"))
	draw_arc(Vector2.ZERO,34,0,TAU,64,Color("d6d9cd"),2,true)
	draw_arc(Vector2.ZERO,28,-PI/2,-PI/2+TAU*display_energy/90,64,Color("e7eee3"),7,true)
	draw_set_transform(Vector2.ZERO)
	diamond(vessel,9,Color("ebf6e7") if player.energy >= 30 else Color("58616a"))
	ornament(Vector2(66,28),22)
	ornament(Vector2(66,110),22)
	for i in range(5):
		var center := Vector2(125+i*35,57)
		var tint := (Color("ffe1ad") if Settings.mobile_mode else Color("edf0df")) if i < player.health else Color("36414b")
		var petal := PackedVector2Array([center+Vector2(0,-14),center+Vector2(10,-4),center+Vector2(8,8),center+Vector2(0,15),center+Vector2(-8,8),center+Vector2(-10,-4)])
		draw_colored_polygon(petal,tint)
		draw_line(center-Vector2(0,8),center+Vector2(0,8),Color("647875"),1,true)
	for i in range(3):
		diamond(Vector2(126+i*16,91),3,Color("dae7dc") if player.energy >= (i+1)*30 else Color("38454e"))
	text("%d" % player.energy,Vector2(183,96),13,Color("d5ded8"))
	diamond(Vector2(238,90),5,Color("bccfbb"))
	text("%d" % Settings.wallet,Vector2(252,96),16,Color("e0e5d8"),true)
	text("%s  ·  %d / %d" % [world.level.name,world.collected,world.total_seeds],Vector2(30,140),14,Color("d0d5ce"),true)
	var contextual: String = notice if notice_time > 0 else world.message.text
	if Settings.mobile_mode:
		contextual = contextual.replace(Settings.key_label("interact")+" •", "Usar •")
	if notice_time > 0 or "•" in contextual and not "/ 05" in contextual:
		var tw := body.get_string_size(contextual,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_rect(Rect2(630-tw/2,347 if Settings.mobile_mode else 557,tw+20,31),Color(0.015,0.02,0.03,0.75))
		text(contextual,Vector2(640-tw/2,368 if Settings.mobile_mode else 578),14,Color("eee8d6"))
	if not Settings.mobile_mode:
		text("%s  •  habilidades     Esc  •  pausa" % Settings.key_label("help"),Vector2(30,692),12,Color("bdc8c5"))
		var actions := ["attack","charge","spell","focus","dash"]
		for i in range(5):
			var center := Vector2(1020+i*49,658)
			var available: bool = player.energy >= 30 if i in [2,3] else (player.dash_cooldown <= 0 if i == 4 else true)
			var tint := Color("e2e8de") if available else Color("6a777c")
			draw_circle(center,16,Color(0.02,0.03,0.05,0.65))
			Icons.paint(self,actions[i],center,23,tint)
			var key: String = Settings.key_label(actions[i])
			text(key,center+Vector2(-body.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x/2,32),11,tint)
			var fill: float = player.charge/0.65 if i == 1 else (player.focus/0.9 if i == 3 else (1-player.dash_cooldown/0.48 if i == 4 else 0))
			if fill > 0:
				draw_arc(center,18,-PI/2,-PI/2+TAU*clampf(fill,0,1),32,tint,1,true)
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.boss and world.boss_encounter() and not world.won:
			display_boss_health = lerpf(display_boss_health,float(enemy.health),0.15)
			ornament(Vector2(640,606),275)
			text(world.level.boss_name.to_upper(),Vector2(640-display.get_string_size(world.level.boss_name.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x/2,632),15,Color("ecd9c4"),true)
			draw_rect(Rect2(401,649,478,5),Color("342c36"))
			draw_rect(Rect2(401,649,478*display_boss_health/14,5),Color("e4987d"))
			diamond(Vector2(389,651),5,Color("e4987d"))
			diamond(Vector2(891,651),5,Color("e4987d"))
			break
	if world.started and not world.won:
		var progress: float = clampf(player.position.x / world.level.width,0,1)
		draw_line(Vector2(1075,103),Vector2(1245,103),Color("456277"),2,true)
		draw_line(Vector2(1075,103),Vector2(1075+170*progress,103),world.level.accent,3,true)
		for i in range(5):
			diamond(Vector2(1075+i*42.5,103),5 if i == world.level_index else 3,world.level.accent if i <= world.level_index else Color("456277"))
		text("REGIÃO %d / 5" % (world.level_index+1),Vector2(1050,124),11)
		if world.arrival_time > 0 and world.time > 0.2:
			var alpha: float = minf(1,world.arrival_time)
			var label: String = world.level.name
			var width: float = display.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
			draw_rect(Rect2(360,188,560,86),Color(0.02,0.04,0.08,alpha*0.7))
			text(label,Vector2(640-width/2,231),34,Color(world.level.accent,alpha),true)
			text("R E G I Ã O   %02d" % (world.level_index+1),Vector2(582,256),12,Color("e8efe5",alpha))
	if damage_flash > 0:
		draw_rect(Rect2(0,0,1280,720),Color(0.8,0.14,0.08,damage_flash*0.3))
	if menu.visible or help_open:
		draw_rect(Rect2(0,0,1280,720),Color(0.015,0.02,0.035,0.84 if menu.page != "main" or help_open else 0.72))
		if help_open:
			panel(Rect2(280,55,720,570))
			text("A arte do combate",Vector2(330,116),36,Color("dff5e7"),true)
			var rows := [
				[Settings.key_label("attack")+" / clique esquerdo","Combo de três golpes. Acertar recupera 11 de energia."],
				[Settings.key_label("up")+" ou "+Settings.key_label("down")+" + ataque","Corte vertical. Para baixo no ar: rebote ao acertar."],
				[Settings.key_label("charge")+" • segure e solte","Carregue por 0,65 s: corte solar causa 3 de dano."],
				[Settings.key_label("spell")+" / clique direito","Eco arcano: projétil penetrante, 3 de dano."],
				[Settings.key_label("up")+" + "+Settings.key_label("spell"),"Explosão ascendente, 4 de dano acima de você."],
				[Settings.key_label("down")+" + "+Settings.key_label("spell")+" no ar","Mergulho espectral: impacto em área, 4 de dano."],
				[Settings.key_label("focus")+" • segure parado","Concentre por 0,9 s para curar uma vida."],
				[Settings.key_label("dash")+" / "+Settings.key_label("jump"),"Dash invulnerável / pulo duplo e salto na parede."]
			]
			for i in range(rows.size()):
				text(rows[i][0],Vector2(330,166+i*51),16,Color("8eeed2"))
				text(rows[i][1],Vector2(330,187+i*51),14)
			text("Cada magia e cada cura gastam 30 de energia. Máximo: 90.",Vector2(330,599),15,Color("ffe2a2"))

func ornament(center: Vector2, width: float) -> void:
	var tint := Color("abb8b3")
	for side in [-1,1]:
		var points := PackedVector2Array()
		for i in range(25):
			var t := i/24.0
			points.append(center+Vector2(side*(8+t*width),sin(t*TAU)*5*(1-t)))
		draw_polyline(points,tint,1,true)
		for i in range(3):
			var p := center+Vector2(side*(width*0.55+i*9),0)
			draw_line(p,p+Vector2(-side*6,-5-i),tint,1,true)
	diamond(center,4,Color("dde3d4"))
