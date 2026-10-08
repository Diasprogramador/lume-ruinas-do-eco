extends SceneTree

var world
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func frames(amount: int) -> void:
	for i in range(amount):
		await physics_frame
		await process_frame

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func press(action: String, duration: int = 2) -> void:
	Input.action_press(action)
	await frames(duration)
	Input.action_release(action)
	await frames(2)

func run() -> void:
	root.get_node("Settings").reset_test_profile()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(4)
	check(not world.player.enabled,"Menu impede movimento antes de iniciar")
	await press("start")
	await frames(25)
	check(world.started and world.player.is_on_floor(),"Enter inicia e jogador pousa na fase")
	var start_x: float = world.player.position.x
	await press("right",16)
	check(world.player.position.x > start_x+50,"Movimento desloca jogador com colisão real")
	await press("jump")
	await frames(10)
	var jump_y: float = world.player.position.y
	await press("jump")
	check(world.player.position.y < jump_y and world.player.velocity.y < 0,"Segundo pulo sobe no ar")
	check(not world.player.air_jump,"Pulo duplo consome salto extra")
	await press("dash",2)
	var hp: int = world.player.health
	world.player.hurt(world.player.position-Vector2(20,0))
	check(world.player.health == hp,"Dash protege contra dano")
	await frames(45)
	world.player.position = Vector2(350,610)
	world.player.velocity = Vector2.ZERO
	await frames(4)
	var enemy = world.enemies[0]
	enemy.position = world.player.position+Vector2(65,0)
	world.player.facing = 1
	var enemy_hp: int = enemy.health
	await press("attack",12)
	check(enemy.health == enemy_hp-1,"Um golpe causa dano uma única vez por alvo")
	await frames(20)
	world.player.position = Vector2(2010,520)
	world.player.velocity = Vector2.ZERO
	enemy.position = Vector2(2010,610)
	var before_pogo: int = enemy.health
	Input.action_press("down")
	await press("attack",2)
	Input.action_release("down")
	check(enemy.health == before_pogo-1 and world.player.velocity.y < 0,"Ataque para baixo acerta e rebate jogador para cima")
	world.player.position = Vector2(2010,610)
	world.player.health = 2
	await frames(3)
	await press("interact")
	check(world.checkpoint_lit and world.player.health == 5,"Santuário cura e ativa checkpoint")
	world.player.position = Vector2(2750,305)
	world.player.velocity = Vector2.ZERO
	await frames(2)
	check(world.collected == 1,"Contato coleta uma semente")
	await press("pause")
	var paused_position: Vector2 = world.player.position
	await frames(12)
	check(paused and world.player.position == paused_position,"Pausa congela física do jogador")
	await press("pause")
	check(not paused,"Esc retoma o jogo")
	world.player.position.y = 950
	await frames(4)
	check(absf(world.player.position.x-2010) < 5 and world.player.health == 5,"Queda retorna ao checkpoint com vida restaurada")
	check(world.collected == 1,"Retorno preserva semente coletada")
	await combat_checks()
	var boss = world.enemies.back()
	for i in range(14):
		boss.take_hit(1)
	await frames(2)
	check(world.level_cleared and not world.won and world.player.enabled,"Derrotar primeiro chefe abre passagem e mantém exploração")
	print("RESULTADO: ",failures," falhas")
	world.sound.stop_all()
	await frames(5)
	quit(1 if failures else 0)

func combat_checks() -> void:
	var player = world.player
	player.position = Vector2(150,610)
	player.velocity = Vector2.ZERO
	await frames(4)
	var target = load("res://scripts/enemy.gd").new()
	target.position = Vector2(215,610)
	target.health = 100
	world.add_child(target)
	player.energy = 0
	player.facing = 1
	player.combo_window = 0
	for i in range(3):
		target.position = Vector2(215,610)
		await press("attack",2)
		await frames(20)
	check(target.health == 96,"Combo completo causa 1 + 1 + 2 de dano")
	check(player.energy == 33,"Três golpes recarregam energia sem multiplicar acertos")
	target.position = Vector2(235,610)
	player.combo_window = 0
	await press("charge",46)
	await frames(6)
	check(target.health == 93,"Corte carregado causa três pontos de dano ao soltar")
	await frames(28)
	player.energy = 90
	player.health = 3
	player.position = Vector2(150,610)
	player.velocity = Vector2.ZERO
	await frames(3)
	await press("focus",58)
	check(player.health == 4 and player.energy == 60,"Concentração cura uma vida e consome 30 de energia")
	player.focus = 0
	Input.action_press("focus")
	await frames(20)
	Input.action_press("right")
	await frames(2)
	Input.action_release("focus")
	Input.action_release("right")
	check(player.health == 4 and player.energy == 60,"Mover cancela cura incompleta sem consumir energia")
	player.position = Vector2(150,610)
	player.velocity = Vector2.ZERO
	target.position = Vector2(315,610)
	var before_spell: int = target.health
	await press("spell",2)
	await frames(18)
	check(target.health == before_spell-3 and player.energy == 30,"Projétil causa três de dano e custa 30 de energia")
	await frames(35)
	player.energy = 0
	var before_empty: int = target.health
	await press("spell",2)
	await frames(20)
	check(target.health == before_empty and player.energy == 0,"Energia insuficiente impede magia")
	player.energy = 90
	player.casting = 0
	target.position = player.position+Vector2(0,-100)
	var before_up: int = target.health
	Input.action_press("up")
	await press("spell",2)
	Input.action_release("up")
	check(target.health == before_up-4 and player.energy == 60,"Explosão ascendente atinge alvo acima e consome energia")
	await frames(25)
	player.position = Vector2(150,470)
	player.velocity = Vector2.ZERO
	await frames(2)
	target.position = Vector2(250,610)
	var before_dive: int = target.health
	Input.action_press("down")
	await press("spell",2)
	Input.action_release("down")
	await frames(20)
	check(target.health == before_dive-4 and player.energy == 30 and not player.diving,"Mergulho causa dano em área ao pousar e encerra estado")
	target.queue_free()
	await frames(3)
	player.position = Vector2(2860,520)
	player.velocity = Vector2.ZERO
	player.casting = 0
	player.stun = 0
	Input.action_press("right")
	await frames(12)
	check(player.is_on_wall(),"Coluna possui colisão para escalada")
	await press("jump",2)
	Input.action_release("right")
	check(player.velocity.x < 0 and player.velocity.y < 0,"Salto na parede afasta jogador e dá impulso vertical")
	await press("help")
	check(paused and world.hud_ui.help_open,"Ajuda pausa combate enquanto explica habilidades")
	await press("help")
	check(not paused and not world.hud_ui.help_open,"Fechar ajuda retoma o combate")
