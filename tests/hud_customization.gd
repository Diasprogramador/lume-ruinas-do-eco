extends SceneTree

var failures := 0
var world
var touch
var settings

func _initialize() -> void:
	call_deferred("run")

func frames(n: int = 3) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(ok: bool, caption: String) -> void:
	print("PASS: " if ok else "FAIL: ",caption)
	if not ok: failures += 1

func finger(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = touch.get_global_transform_with_canvas()*point
	event.pressed = pressed
	root.push_input(event,true)

func drag(point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = touch.get_global_transform_with_canvas()*point
	root.push_input(event,true)

func run() -> void:
	settings = root.get_node("Settings")
	settings.reset_test_profile()
	settings.mobile_mode = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	touch = world.touch_controls
	await frames()
	world.hud_ui.menu.open_page("settings")
	check(world.hud_ui.menu.settings_tab == "touch","Celular abre configurações diretamente no HUD")
	touch.begin_edit()
	await frames()
	check(paused and touch.visible and not world.hud_ui.menu.visible,"Editor pausa e oculta menus atrás dos controles")
	finger(Vector2(1110,554),true)
	drag(Vector2(760,470))
	finger(Vector2(760,470),false)
	check(touch.layout.attack.position == Vector2(760,470) and not Input.is_action_pressed("attack"),"Arrastar ataque altera posição sem golpear")
	touch.editor_ui.size_slider.value = 125
	touch.editor_ui.opacity_slider.value = 60
	touch.editor_ui.names.button_pressed = false
	check(is_equal_approx(touch.buttons.attack[1],68.75) and is_equal_approx(touch.opacity,0.6) and not touch.show_labels,"Editor ajusta tamanho, transparência e nomes")
	touch.finish_edit(false)
	check(touch.layout.attack.position == Vector2(1110,554) and not paused,"Cancelar restaura layout anterior e estado da pausa")
	touch.begin_edit()
	finger(Vector2(1110,554),true)
	drag(Vector2(760,470))
	finger(Vector2(760,470),false)
	touch.editor_ui.size_slider.value = 125
	touch.editor_ui.opacity_slider.value = 60
	touch.editor_ui.names.button_pressed = false
	touch.finish_edit(true)
	check(settings.hud_layout.attack.position == Vector2(760,470),"Salvar aplica posição personalizada")
	var qa_path := "user://qa-hud-%d.cfg" % Time.get_ticks_usec()
	var real_path: String = settings.save_path
	settings.save_path = qa_path
	settings.test_mode = false
	check(settings.save_profile() == OK,"Perfil de HUD é gravado sem tocar no perfil real")
	settings.test_mode = true
	settings.save_path = real_path
	var reader = load("res://scripts/settings.gd").new()
	reader.save_path = qa_path
	reader.load_profile()
	check(reader.hud_layout.attack.position == Vector2(760,470) and is_equal_approx(reader.hud_layout.attack.scale,1.25) and is_equal_approx(reader.hud_opacity,0.6) and not reader.hud_labels,"Posição, tamanho, transparência e nomes sobrevivem ao recarregar")
	reader.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_path))
	world.hud_ui.menu.close_page()
	world.hud_ui.activate()
	await frames(30)
	finger(Vector2(760,470),true)
	await frames()
	check(world.player.attack_time > 0,"Ataque funciona na posição personalizada")
	finger(Vector2(760,470),false)
	await frames(25)
	finger(Vector2(1110,554),true)
	await frames()
	check(not Input.is_action_pressed("attack"),"Posição antiga não aciona o ataque")
	finger(Vector2(1110,554),false)
	paused = true
	touch.begin_edit()
	touch.reset_draft()
	check(touch.layout.attack.position == Vector2(1110,554),"Restaurar padrão recupera posições na prévia")
	touch.finish_edit(false)
	check(paused and settings.hud_layout.attack.position == Vector2(760,470),"Cancelar restauração mantém preferências e pausa anterior")
	touch.begin_edit()
	finger(Vector2(760,470),true)
	drag(Vector2(-400,1500))
	finger(Vector2(-400,1500),false)
	var point: Vector2 = touch.layout.attack.position
	check(point.x > 50 and point.y < 670,"Arrasto é limitado para manter controle dentro da tela")
	touch.finish_edit(false)
	var safe: Dictionary = settings.sanitize_touch_layout({"attack":{"position":"invalid","scale":NAN},"stick":{"position":Vector2(INF,0),"scale":900}})
	check(safe.attack.position == Vector2(1110,554) and safe.stick.scale == 1.5,"Dados inválidos recuperam valores seguros")
	settings.mobile_mode = false
	settings.apply_bindings()
	var menu = world.hud_ui.menu
	menu.open_page("settings")
	menu.select_tab("keys")
	await frames()
	menu.capture("attack")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	root.push_input(key,true)
	await frames()
	key = key.duplicate()
	key.pressed = false
	root.push_input(key,true)
	check(settings.key_label("attack") == "B" and menu.waiting_action == "","Teclas e ataques captura nova tecla no menu")
	check(settings.rebind("spell",KEY_B) != "","Magia não pode reutilizar tecla já atribuída ao ataque")
	menu.close_page()
	paused = false
	await frames(25)
	key = key.duplicate()
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	check(world.player.attack_time > 0,"Nova tecla B aciona golpe no combate real")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	settings.reset_keys()
	world.sound.stop_all()
	key = null
	await frames(5)
	print("RESULTADO HUD: ",failures," falhas")
	quit(1 if failures else 0)
