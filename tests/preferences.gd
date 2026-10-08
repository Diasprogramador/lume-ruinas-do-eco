extends SceneTree

var world
var failures: int = 0
var settings

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
		push_error("FAIL: "+description)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(3)

func run() -> void:
	settings = root.get_node("Settings")
	settings.reset_test_profile()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(4)
	var menu = world.hud_ui.menu
	check(menu.play_button.visible and menu.page == "main","Menu inicial oferece Jogar")
	menu.open_page("settings")
	await frames(2)
	check(menu.settings_controls.visible and menu.key_buttons.size() == 13,"Configurações apresentam treze ações remapeáveis")
	menu.key_buttons.jump.pressed.emit()
	await key(KEY_A,true)
	await key(KEY_A,false)
	check(menu.waiting_action == "jump" and not settings.bindings.has("jump"),"Tecla já usada é rejeitada sem mudar controles")
	await key(KEY_ESCAPE,true)
	await frames(8)
	check(menu.waiting_action == "" and menu.page == "settings","Esc cancela captura sem fechar configurações mesmo se mantido")
	await key(KEY_ESCAPE,false)
	menu.key_buttons.jump.pressed.emit()
	await key(KEY_L,true)
	await key(KEY_L,false)
	check(settings.bindings.get("jump",0) == KEY_L and menu.key_buttons.jump.text == "L","Captura troca pulo para L e atualiza interface")
	var events: Array = InputMap.action_get_events("jump")
	check(events.size() == 1 and events[0].physical_keycode == KEY_L,"Remapeamento remove teclas antigas da ação")
	menu.close_page()
	await frames(4)
	menu.play_button.pressed.emit()
	await frames(28)
	await key(KEY_L,true)
	check(world.player.velocity.y < 0,"Nova tecla movimenta jogador através do InputMap real")
	await key(KEY_L,false)
	settings.reset_keys()
	check(settings.key_label("jump") == "Espaço" and InputMap.action_get_events("jump").size() == 2,"Restaurar padrão recupera atalhos e alternativas")
	Input.action_press("pause")
	await frames(2)
	Input.action_release("pause")
	menu.open_page("settings")
	await frames(2)
	var frozen: Vector2 = world.player.position
	await frames(6)
	check(paused and world.player.position == frozen,"Configurações na pausa impedem combate por trás da tela")
	menu.select_tab("audio")
	menu.sliders.music.value = 24
	await frames(2)
	check(is_equal_approx(settings.music_volume,0.24) and menu.volume_labels.music.text == "24%","Slider altera volume da música e mostra porcentagem")
	settings.set_volume("music",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")),"Silenciar música preserva efeitos")
	settings.set_volume("music",0.24)
	settings.set_volume("effects",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"Silenciar efeitos preserva música")
	settings.set_volume("effects",0.8)
	settings.set_volume("master",0)
	check(AudioServer.is_bus_mute(0),"Volume geral em zero silencia toda a mixagem")
	settings.set_volume("master",0.85)
	menu.shake_check.button_pressed = false
	check(not settings.camera_shake,"Opção de tremida altera preferência")
	check(world.sound.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and world.sound.music.stream.get_length() > 50,"Trilha ambiente tem mais de cinquenta segundos e repete em loop")
	check(world.sound.battle_music.stream.get_length() > 17 and world.sound.music.bus == "Music","Chefe possui trilha própria no canal de música")
	world.sound.music.play()
	world.sound.battle_music.play()
	await frames(4)
	check(world.sound.music.playing and paused,"Música continua durante a pausa")
	var original_position: Vector2 = world.player.position
	world.player.position.x = world.level.boss.x
	await frames(90)
	check(world.sound.battle_mix > 0.9 and world.sound.battle_music.volume_db > world.sound.music.volume_db,"Arena cruza gradualmente para trilha do chefe")
	world.player.position = original_position
	await frames(90)
	check(world.sound.battle_mix < 0.1,"Sair da arena devolve a trilha de exploração")
	check(world.sound.sounds.size() == 15 and world.sound.sounds.swing.data.size() > 1000,"Quinze efeitos carregam áudio real, incluindo corte")
	world.sound.play("heavy")
	var last_voice = world.sound.voices[(world.sound.voice+9)%10]
	check(last_voice.playing and last_voice.stream == world.sound.sounds.heavy and last_voice.bus == "Effects","Ataque carregado reproduz som no canal de efeitos")
	menu.open_page("shop")
	await frames(2)
	check(menu.purchase_buttons.size() == 4 and menu.purchase_buttons.original.disabled,"Loja mostra quatro capas e identifica a equipada")
	menu.purchase_buttons.moon.pressed.emit()
	check(settings.wallet == 0 and "moon" not in settings.owned and menu.status.begins_with("Faltam"),"Compra sem saldo é bloqueada e explica o motivo")
	for i in range(8):
		settings.collect_seed("qa-%d" % i)
	check(not settings.collect_seed("qa-0") and settings.wallet == 8,"Semente repetida não duplica moedas")
	menu.purchase_buttons.moon.pressed.emit()
	check(settings.wallet == 6 and settings.equipped == "moon" and "moon" in settings.owned,"Compra debita preço e equipa a capa")
	settings.purchase("moon")
	check(settings.wallet == 6,"Reequipar capa adquirida não cobra novamente")
	menu.purchase_buttons.ember.pressed.emit()
	menu.purchase_buttons.moon.pressed.emit()
	check(settings.wallet == 3 and settings.equipped == "moon","Troca entre capas adquiridas mantém saldo correto")
	await persistence_check()
	menu.close_page()
	await frames(4)
	menu.return_home()
	await frames(3)
	check(not paused and not world.started and not world.player.enabled,"Menu inicial interrompe partida e libera navegação")
	world.sound.stop_all()
	await frames(5)
	print("RESULTADO PREFERÊNCIAS: ",failures," falhas")
	quit(1 if failures else 0)

func persistence_check() -> void:
	var real_path: String = settings.save_path
	var qa_path := "user://qa-preferences-%d.cfg" % Time.get_ticks_usec()
	settings.rebind("jump",KEY_L)
	settings.save_path = qa_path
	settings.test_mode = false
	check(settings.save_profile() == OK,"Preferências e loja são gravadas em arquivo")
	settings.test_mode = true
	settings.save_path = real_path
	var reader = load("res://scripts/settings.gd").new()
	reader.save_path = qa_path
	reader.load_profile()
	check(reader.bindings.get("jump",0) == KEY_L and is_equal_approx(reader.music_volume,0.24) and not reader.camera_shake,"Teclas, volumes e tremida sobrevivem ao recarregar arquivo")
	check(reader.wallet == 3 and "ember" in reader.owned and reader.equipped == "moon" and reader.claimed_seeds.size() == 8,"Saldo, compras, capa equipada e sementes sobrevivem ao recarregar")
	reader.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_path))
	settings.reset_keys()
