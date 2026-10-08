extends SceneTree

var world
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ",description)
	if not ok:
		failures += 1

func interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)

func route_connected() -> bool:
	# Conservative double-jump reach: platforms must link to the entry floor.
	var reached: Array[int] = [0]
	var cursor := 0
	while cursor < reached.size():
		var origin: Rect2 = world.platforms[reached[cursor]]
		cursor += 1
		for i in range(world.platforms.size()):
			if i in reached:
				continue
			var target: Rect2 = world.platforms[i]
			var gap := maxf(0,maxf(target.position.x-origin.end.x,origin.position.x-target.end.x))
			if origin.position.y-target.position.y <= 225 and gap <= 240:
				reached.append(i)
	return reached.size() == world.platforms.size()

func run() -> void:
	root.get_node("Settings").reset_test_profile()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.started = true
	world.player.enabled = true
	await frames(4)
	var ids: Array[String] = []
	for index in range(5):
		check(world.level_index == index,"Progressão chega à região %d" % (index+1))
		check(world.level.width >= 8600 and world.player.camera.limit_right == world.level.width,"Extensão e câmera da região %d" % (index+1))
		check(world.level.shrines.size() >= 3 and world.total_seeds >= 14,"Santuários e recompensas da região %d" % (index+1))
		check(world.scenery.biome == index,"Cenário específico da região %d" % (index+1))
		check(route_connected(),"Todas as plataformas conectam ao percurso com alcance conservador de salto")
		var collectible: Vector2 = world.seeds[0]
		var id: String = world.seed_id(collectible)
		check(id not in ids,"Sementes têm identidade independente por região")
		ids.append(id)
		world.player.position = collectible
		world.player.velocity = Vector2.ZERO
		await frames(2)
		check(world.collected == 1,"Coleta na região %d" % (index+1))
		world.player.position = world.level.shrines.back()
		await frames(2)
		await interact()
		var checkpoint: Vector2 = world.checkpoint
		world.player.position.y = 1000
		await frames(4)
		check(world.player.position.distance_to(checkpoint) < 45,"Queda volta ao santuário da região %d" % (index+1))
		world.player.position = world.level.exit
		world.player.velocity = Vector2.ZERO
		await interact()
		check(world.level_index == index,"Guardião vivo bloqueia saída")
		var boss = world.enemies.back()
		boss.take_hit(1,14)
		await frames(2)
		if index < 4:
			check(not world.won and world.level_cleared,"Guardião abre passagem sem encerrar campanha")
			world.player.position = world.level.exit
			await interact()
		else:
			check(world.won and not world.player.enabled,"Último guardião encerra a campanha")
	world.won = false
	world.player.enabled = true
	world.load_level(1)
	world.player.position.x = 130
	await interact()
	check(world.level_index == 0 and world.level_cleared,"Retorno à região anterior preserva guardião derrotado")
	check(world.collected == 1 and not world.seeds.has(world.level.seeds[0]),"Revisitar preserva coleta e não duplica dinheiro")
	check(world.enemies.all(func(enemy): return not enemy.boss),"Guardião derrotado não reaparece na revisita")
	world.sound.stop_all()
	await frames(4)
	print("RESULTADO: ",failures," falhas")
	quit(1 if failures else 0)
