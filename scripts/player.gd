extends CharacterBody2D

signal health_changed
signal died
var health: int = 5
var facing: float = 1.0
var invincible: float = 0.0
var attack_time: float = 0.0
var attack_cooldown: float = 0.0
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var hit_targets: Array = []
var enabled: bool = false
var clock: float = 0.0
var air_jump: bool = true
var stun: float = 0.0
var attack_direction := Vector2.RIGHT
var camera: Camera2D
var was_grounded: bool = false
var trail: Array[Vector2] = []
var squash := Vector2.ONE
var shake: float = 0.0
var portrait: Texture2D = preload("res://assets/lume.svg")
var energy: int = 60
var combo: int = 0
var combo_window: float = 0
var attack_buffer: float = 0
var attack_damage: int = 1
var charge: float = 0
var focus: float = 0
var casting: float = 0
var diving: bool = false
var hit_pause: float = 0
var air_dash: bool = true
var charge_ready: bool = false
var portrait_variants := {
	"original":preload("res://assets/lume.svg"),"moon":preload("res://assets/lume-moon.svg"),
	"ember":preload("res://assets/lume-ember.svg"),"violet":preload("res://assets/lume-violet.svg")
}

func begin_attack(charged: bool = false) -> void:
	combo = combo%3+1 if combo_window > 0 and not charged else 1
	combo_window = 0.72
	attack_damage = 3 if charged else (2 if combo == 3 else 1)
	attack_time = 0.23 if charged else 0.16
	attack_cooldown = 0.42 if charged else 0.25
	attack_buffer = 0
	hit_targets.clear()
	attack_direction = Vector2(facing,0)
	if Input.is_action_pressed("up"):
		attack_direction = Vector2.UP
	elif Input.is_action_pressed("down") and not is_on_floor():
		attack_direction = Vector2.DOWN
	get_parent().effects.slash(position+Vector2(0,-5),attack_direction.angle(),attack_damage)
	get_parent().sound.play("heavy" if charged else "swing")
	if charged:
		shake = 5
		get_parent().effects.ring(position,Color("ffe2a2"),100)

func cast_spell() -> bool:
	if energy < 30 or casting > 0 or diving or stun > 0:
		if energy < 30:
			get_parent().hud_ui.notice = "Sem energia • Acerte golpes para recuperar sua luz."
			get_parent().hud_ui.notice_time = 2.0
		return false
	energy -= 30
	attack_time = 0
	attack_buffer = 0
	focus = 0
	charge = 0
	casting = 0.34
	if Input.is_action_pressed("down") and not is_on_floor():
		get_parent().sound.play("dive")
		diving = true
		velocity = Vector2(0,1050)
		get_parent().effects.ring(position,Color("a4cffb"),60)
	elif Input.is_action_pressed("up"):
		get_parent().sound.play("ascend")
		get_parent().effects.pillar(position)
		get_parent().effects.ring(position+Vector2(0,-95),Color("a4cffb"),150,0.55)
		get_parent().burst(position+Vector2(0,-95),Color("a4cffb"),48)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if absf(enemy.position.x-position.x) < 105 and enemy.position.y-position.y < 30 and enemy.position.y-position.y > -225:
				enemy.take_hit(facing,4)
		shake = 7
	else:
		get_parent().sound.play("magic")
		var spell = preload("res://scripts/spell.gd").new()
		spell.position = position+Vector2(facing*26,-8)
		spell.direction = facing
		spell.process_mode = Node.PROCESS_MODE_PAUSABLE
		get_parent().add_child(spell)
		velocity.x = -facing*100
	return true

func finish_dive() -> void:
	diving = false
	invincible = maxf(invincible,0.45)
	casting = 0.2
	shake = 12
	get_parent().effects.impact(position+Vector2(0,20))
	get_parent().burst(position+Vector2(0,20),Color("a4cffb"),55)
	get_parent().sound.play("impact")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if absf(enemy.position.x-position.x) < 175 and absf(enemy.position.y-position.y) < 90:
			enemy.take_hit(signf(enemy.position.x-position.x),4)

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13
	capsule.height = 48
	shape.shape = capsule
	add_child(shape)
	camera = Camera2D.new()
	camera.position = Vector2(0, -95)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6
	camera.limit_left = 0
	camera.limit_right = 4300
	camera.limit_top = -120
	camera.limit_bottom = 820
	add_child(camera)

func _physics_process(delta: float) -> void:
	clock += delta
	if charge <= 0:
		charge_ready = false
	if hit_pause > 0:
		hit_pause -= delta
		queue_redraw()
		return
	combo_window = maxf(0,combo_window-delta)
	attack_buffer = maxf(0,attack_buffer-delta)
	casting = maxf(0,casting-delta)
	stun = maxf(0, stun - delta)
	shake = move_toward(shake, 0, delta * 24)
	camera.offset = Vector2(sin(clock * 95), cos(clock * 77)) * shake if Settings.camera_shake else Vector2.ZERO
	camera.position.x = lerpf(camera.position.x, facing * 85, delta * 3)
	squash = squash.lerp(Vector2.ONE, delta * 12)
	invincible = maxf(0, invincible - delta)
	attack_time = maxf(0, attack_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	dash_time = maxf(0, dash_time - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	if not enabled:
		queue_redraw()
		return
	var axis := Input.get_axis("left", "right")
	if axis != 0:
		facing = signf(axis)
	if Input.is_action_just_pressed("spell") and dash_time <= 0:
		cast_spell()
	if Input.is_action_pressed("focus") and is_on_floor() and axis == 0 and energy >= 30 and health < 5 and stun <= 0 and casting <= 0 and not diving and attack_time <= 0:
		focus += delta
		if focus >= 0.9:
			health += 1
			energy -= 30
			focus = 0
			get_parent().effects.ring(position,Color("8eeed2"),85)
			get_parent().sound.play("shrine")
	else:
		focus = 0
	if Input.is_action_pressed("charge") and casting <= 0 and focus <= 0 and stun <= 0 and dash_time <= 0:
		charge = minf(0.85,charge+delta)
		if charge >= 0.65 and not charge_ready:
			charge_ready = true
			get_parent().sound.play("charge")
	elif charge > 0:
		if Input.is_action_just_released("charge") and attack_cooldown <= 0 and casting <= 0 and stun <= 0:
			begin_attack(charge >= 0.65)
		charge = 0
		charge_ready = false
	if is_on_floor():
		coyote = 0.12
		air_jump = true
		air_dash = true
		if not was_grounded:
			squash = Vector2(1.2, 0.8)
			get_parent().burst(position + Vector2(0, 24), Color("719f9b"), 10)
	else:
		coyote -= delta
	jump_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.14
	if jump_buffer > 0 and is_on_wall() and not is_on_floor() and not diving:
		velocity = Vector2(get_wall_normal().x*390,-580)
		facing = get_wall_normal().x
		stun = 0.13
		jump_buffer = 0
		air_jump = true
		get_parent().sound.play("jump")
	elif jump_buffer > 0 and (coyote > 0 or air_jump) and not diving and casting <= 0:
		if coyote <= 0:
			air_jump = false
			get_parent().burst(position, Color("8eeed2"), 14)
		velocity.y = -610
		get_parent().sound.play("jump")
		squash = Vector2(0.82, 1.16)
		coyote = 0
		jump_buffer = 0
	if Input.is_action_just_released("jump") and velocity.y < -200:
		velocity.y = -200
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and (is_on_floor() or air_dash) and casting <= 0 and not diving and stun <= 0:
		if not is_on_floor():
			air_dash = false
		charge = 0
		focus = 0
		dash_time = 0.17
		get_parent().sound.play("dash")
		dash_cooldown = 0.48
		get_parent().burst(position, Color("8eeed2"), 10)
	if diving:
		velocity = Vector2(0,1050)
	elif dash_time > 0:
		velocity = Vector2(facing * 740, 0)
	else:
		if stun <= 0:
			var speed := 130.0 if charge > 0 else (0.0 if focus > 0 or casting > 0 else 320.0)
			velocity.x = move_toward(velocity.x, axis * speed, (2800 if is_on_floor() else 1900) * delta)
		velocity.y += 1550 * delta
		if is_on_wall() and axis != 0 and velocity.y > 0:
			velocity.y = minf(velocity.y,160)
	was_grounded = is_on_floor()
	move_and_slide()
	if diving and is_on_floor():
		finish_dive()
	if dash_time > 0:
		trail.push_front(position)
	if trail.size() > 7 or (dash_time <= 0 and not trail.is_empty()):
		trail.pop_back()
	if Input.is_action_just_pressed("attack"):
		attack_buffer = 0.15
	if attack_buffer > 0 and attack_cooldown <= 0 and casting <= 0 and focus <= 0 and charge <= 0 and stun <= 0 and not diving:
		begin_attack()
	if attack_time > 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var offset: Vector2 = enemy.position - position
			var along := offset.dot(attack_direction)
			var across := absf(offset.cross(attack_direction))
			if along > -20 and along < (150 if attack_damage == 3 else 110) and across < (62 if enemy.boss else 42) and not enemy in hit_targets and not enemy.is_queued_for_deletion():
				hit_targets.append(enemy)
				enemy.take_hit(facing,attack_damage)
				energy = mini(90,energy+11)
				hit_pause = 0.045
				shake = 4
				get_parent().sound.play("hit")
				get_parent().burst(enemy.position, Color("e8efe5"), 16)
				if attack_direction == Vector2.DOWN:
					velocity.y = -490
					air_jump = true
					air_dash = true
	if position.y > 900:
		died.emit()
	queue_redraw()

func hurt(source: Vector2) -> void:
	if invincible > 0 or dash_time > 0 or diving or not enabled:
		return
	health -= 1
	focus = 0
	charge = 0
	attack_time = 0
	attack_buffer = 0
	invincible = 1.2
	stun = 0.22
	get_parent().sound.play("hurt")
	shake = 9
	get_parent().burst(position, Color("ed887c"), 20)
	velocity = Vector2(signf(position.x - source.x) * 350, -260)
	health_changed.emit()
	if health <= 0:
		died.emit()

func _draw() -> void:
	for i in range(trail.size()):
		draw_circle(trail[i] - position, 19, Color(0.45, 0.9, 0.8, (1.0 - float(i) / 7) * 0.18))
	if invincible > 0 and int(clock * 18) % 2 == 0:
		return
	if dash_time > 0:
		for i in range(1, 5):
			draw_circle(Vector2(-facing * i * 19, 4), 18 - i * 2, Color(0.4, 0.9, 0.8, 0.15))
	draw_set_transform(Vector2.ZERO, 0, squash)
	var sway := sin(clock * (14 if absf(velocity.x) > 50 else 3)) * 1.8
	draw_circle(Vector2(0, 0), 32, Color(0.35, 0.8, 0.7, 0.025))
	draw_set_transform(Vector2(0, sway if is_on_floor() else 0), -velocity.x * 0.00014, squash * Vector2(facing,1))
	draw_texture_rect(portrait_variants[Settings.equipped],Rect2(-27,-44,54,72),false)
	draw_set_transform(Vector2.ZERO)
	var blade_angle := -1.1 if facing > 0 else -2.0
	if attack_time > 0:
		var progress := 1.0-attack_time/(0.23 if attack_damage == 3 else 0.16)
		blade_angle = attack_direction.angle()+lerpf(-1.2,1.2,progress)*(1 if combo%2 else -1)
	draw_set_transform(Vector2(facing*16,3),blade_angle)
	draw_line(Vector2(-5,0),Vector2(6,0),Color("263c48"),4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(6,-2),Vector2(39,-2),Vector2(46,0),Vector2(39,2),Vector2(6,2)]),Color("ffe2a2") if charge >= 0.65 else Color("d6ece3"))
	draw_line(Vector2(5,-6),Vector2(5,6),Color("c6b282"),2,true)
	draw_set_transform(Vector2.ZERO)
	if charge > 0:
		var tint := Color("ffe2a2") if charge >= 0.65 else Color("8eeed2")
		draw_arc(Vector2(0,-5),36,-PI/2,-PI/2+TAU*minf(1,charge/0.65),30,tint,3,true)
		for i in range(6):
			var point := Vector2.from_angle(clock*4+i*TAU/6)* (39+sin(clock*9)*3)
			draw_circle(point,2,tint)
	if focus > 0:
		draw_arc(Vector2.ZERO,38,-PI/2,-PI/2+TAU*focus/0.9,40,Color("8eeed2"),3,true)
		draw_circle(Vector2.ZERO,28,Color(0.4,0.95,0.8,0.12))
	if diving:
		for i in range(6):
			draw_line(Vector2(-12+i*5,-30),Vector2(-12+i*5,-95-i*8),Color(0.5,0.75,1,0.45),3,true)
	if attack_time > 0:
		var angle := attack_direction.angle()
		var radius := 130.0 if attack_damage == 3 else 84.0
		var tint := Color("ffe2a2") if attack_damage > 1 else Color("e8efe5")
		draw_arc(Vector2(0,-5),radius,angle-1.0,angle+1.0,32,Color(tint,0.15),22,true)
		draw_arc(Vector2(0,-5),radius,angle-0.9,angle+0.9,32,tint,4,true)
	draw_set_transform(Vector2.ZERO)
