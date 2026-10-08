extends CharacterBody2D

signal defeated(location: Vector2, boss: bool)
var arena := Vector2(3040,4090)
var biome: int = 0
var boss: bool = false
var health: int = 3
var direction: float = -1
var hit_flash: float = 0
var attack_clock: float = 0
var active: bool = false
var home: Vector2
var stagger: float = 0.0
var charge_direction: float = -1
var phase: float = 0.0
var portrait: Texture2D
var visual_clock: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	portrait = load("res://assets/characters/%s-%d.svg" % ["guardian" if boss else "scout",biome])
	collision_layer = 4
	collision_mask = 1
	home = position
	if boss:
		health = 14
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(65, 88) if boss else Vector2(36, 34)
	collision.shape = rectangle
	add_child(collision)

func _physics_process(delta: float) -> void:
	hit_flash = maxf(0, hit_flash - delta)
	stagger = maxf(0, stagger - delta)
	if not active:
		return
	var player = get_tree().get_first_node_in_group("player")
	attack_clock += delta
	velocity.y += 1550 * delta
	if boss:
		phase = fmod(attack_clock, 3.8)
		if phase < 1.5:
			direction = signf(player.position.x - position.x)
			charge_direction = direction
			velocity.x = direction * 60
		elif phase < 2.15:
			velocity.x = 0
		elif phase < 2.85:
			velocity.x = charge_direction * 420
		else:
			velocity.x = move_toward(velocity.x, 0, delta * 1300)
		if is_on_floor() and phase >= 3.2 and phase < 3.2 + delta:
			velocity.y = -490
		position.x = clampf(position.x, arena.x, arena.y)
	else:
		var probe := PhysicsRayQueryParameters2D.create(global_position+Vector2(direction*32,0),global_position+Vector2(direction*32,70),1)
		var edge: bool = is_on_floor() and get_world_2d().direct_space_state.intersect_ray(probe).is_empty()
		if absf(position.x - home.x) > 120 or is_on_wall() or edge:
			direction *= -1
		velocity.x = direction * 70
	if stagger > 0 and not boss:
		velocity.x = direction * -90
	move_and_slide()
	if player.enabled and absf(player.position.x - position.x) < (49 if boss else 31) and absf(player.position.y - position.y) < (65 if boss else 38):
		player.hurt(position)
	queue_redraw()

func take_hit(side: float, damage: int = 1) -> void:
	if is_queued_for_deletion():
		return
	health -= damage
	stagger = 0.22
	hit_flash = 0.15
	position.x += side * (10 if boss else 22)
	if health <= 0:
		get_parent().burst(position, Color("8eeed2"), 28)
		defeated.emit(position, boss)
		queue_free()
	queue_redraw()

func _process(delta: float) -> void:
	visual_clock += delta
	queue_redraw()

func _draw() -> void:
	if not portrait:
		return
	var accent: Color = get_parent().level.accent
	var bob := sin(visual_clock*(7 if active else 2))*1.5
	if biome == 3:
		bob = sin(visual_clock*5)*4
	var scale_x := 1.0 + sin(visual_clock*5)*0.025
	var dimensions := Vector2(110,147) if boss else Vector2(64,64)
	var origin := Vector2(-55,-101) if boss else Vector2(-32,-44)
	draw_set_transform(Vector2(0,bob),sin(visual_clock*4)*0.025,Vector2(scale_x,1))
	if boss and phase > 1.5 and phase < 2.15:
		draw_circle(Vector2(0,-20),65,Color(accent,0.12))
		draw_line(Vector2(0,10),Vector2(charge_direction*130,10),Color("ed887c"),2,true)
	draw_texture_rect(portrait,Rect2(origin,dimensions),false,Color(2,1.5,1.3) if hit_flash > 0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if biome in [1,4]:
		for i in range(3):
			var p := Vector2(sin(visual_clock+i*2)*22,-fposmod(visual_clock*15+i*19,60)-10)
			draw_circle(p,1.5,Color(accent,0.4))
