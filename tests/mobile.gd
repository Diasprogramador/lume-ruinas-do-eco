extends SceneTree
var world
var touch
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func frames(n: int = 2) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures += 1
func finger(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = touch.get_global_transform_with_canvas()*point
	event.pressed = pressed
	root.push_input(event,true)
func run() -> void:
	var settings = root.get_node("Settings")
	settings.reset_test_profile()
	settings.mobile_mode = true
	settings.low_power = true
	settings.apply_bindings()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	touch = world.find_child("TouchControls",true,false)
	await frames()
	check(not touch.visible,"Controles de toque ficam ocultos no menu")
	world.hud_ui.activate()
	await frames(25)
	check(touch.visible,"Iniciar mostra controles de toque")
	var x: float = world.player.position.x
	finger(0,Vector2(225,620),true)
	await frames(12)
	check(world.player.position.x > x+20,"Direcional de toque movimenta com física real")
	finger(1,Vector2(1202,641),true)
	await frames(2)
	check(world.player.velocity.y < 0 and Input.is_action_pressed("right"),"Multitoque permite correr e pular juntos")
	finger(1,Vector2(1202,641),false)
	await frames()
	check(not Input.is_action_pressed("jump") and Input.is_action_pressed("right"),"Soltar pulo mantém outro dedo no direcional")
	finger(2,Vector2(1110,554),true)
	await frames()
	check(world.player.attack_time > 0,"Botão Golpe aciona o ataque")
	finger(2,Vector2(1110,554),false)
	finger(0,Vector2(225,620),false)
	await frames()
	check(not Input.is_action_pressed("right"),"Soltar direcional interrompe movimento")
	finger(0,Vector2(160,545),true)
	await frames()
	check(Input.is_action_pressed("up"),"Direcional permite mirar magia para cima")
	finger(3,Vector2(1202,453),true)
	await frames()
	check(world.player.energy == 60,"Magia por toque consome energia")
	touch.release_all()
	finger(0,Vector2(225,620),true)
	await frames()
	paused = true
	await frames()
	check(touch.held.is_empty() and not Input.is_action_pressed("right"),"Pausa libera todos os dedos e evita movimento preso")
	paused = false
	await frames()
	finger(0,Vector2(225,620),true)
	await frames()
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed("right"),"Perder foco libera entradas")
	check(InputMap.action_get_events("attack").all(func(e): return not e is InputEventMouseButton),"Toque em menus não dispara ataque por emulação do mouse")
	world.sound.stop_all()
	await frames(4)
	print("RESULTADO MOBILE: ",failures," falhas")
	quit(1 if failures else 0)

