extends CharacterBody2D

var direction: float = 1
var lifetime: float = 1.4
var targets: Array = []
var elapsed: float = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = 4
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14
	collider.shape = shape
	add_child(collider)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	elapsed += delta
	var collision := move_and_collide(Vector2(direction*700*delta,0))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in targets or enemy.is_queued_for_deletion():
			continue
		if absf(enemy.position.x-position.x) < 50 and absf(enemy.position.y-position.y) < (65 if enemy.boss else 35):
			targets.append(enemy)
			enemy.take_hit(direction,3)
			get_parent().effects.ring(enemy.position,Color("a4cffb"),70)
			get_parent().burst(enemy.position,Color("a4cffb"),24)
			get_parent().player.shake = 6
	if collision or lifetime <= 0:
		get_parent().effects.ring(position,Color("a4cffb"),45)
		queue_free()
	queue_redraw()

func _draw() -> void:
	for strand in range(3):
		var ribbon := PackedVector2Array()
		for j in range(24):
			var t := j/23.0
			ribbon.append(Vector2(-direction*t*115,sin(t*8-elapsed*28+strand*2.1)*13*(1-t)))
		draw_polyline(ribbon,Color(0.4,0.7,1,0.12),13,true)
		draw_polyline(ribbon,Color(0.75,0.9,1,0.65),2,true)
	draw_arc(Vector2.ZERO,26,elapsed*10,elapsed*10+4.8,32,Color("e2f6ff"),2,true)
	for i in range(6):
		var p := Vector2(-direction*i*13,sin(elapsed*20+i)*4)
		draw_circle(p,21-i*2,Color(0.45,0.7,1.0,0.13))
	draw_set_transform(Vector2.ZERO,0,Vector2(1.5,0.75))
	draw_circle(Vector2.ZERO,16,Color("a4cffb"))
	draw_circle(Vector2(direction*4,0),10,Color("f0f7ff"))
	draw_set_transform(Vector2.ZERO)
