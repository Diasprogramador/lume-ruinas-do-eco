extends Control

var world
var page: String = "main"
var settings_tab: String = "keys"
var waiting_action: String = ""
var status: String = ""
var block_shortcuts_until: int = 0
var main_controls: Control
var settings_controls: Control
var key_controls: Control
var audio_controls: Control
var touch_settings: Control
const Icons = preload("res://scripts/combat_icons.gd")
var shop_controls: Control
var back_button: Button
var play_button: Button
var home_button: Button
var quit_button: Button
var key_buttons: Dictionary = {}
var purchase_buttons: Dictionary = {}
var sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var fullscreen_check: CheckButton
var shake_check: CheckButton
var body: Font
var display: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	body = ThemeDB.fallback_font
	display = preload("res://assets/fonts/CormorantGaramond.ttf")
	main_controls = group()
	settings_controls = group()
	key_controls = group(settings_controls)
	audio_controls = group(settings_controls)
	touch_settings = group(settings_controls)
	settings_tab = "touch" if Settings.mobile_mode else "keys"
	shop_controls = group()
	play_button = button(main_controls,"Jogar",Vector2(766,220),Vector2(365,55),world.hud_ui.activate)
	button(main_controls,"Configurações / HUD" if Settings.mobile_mode else "Configurações e teclas",Vector2(766,285),Vector2(365,51),func(): open_page("settings"))
	button(main_controls,"Loja de capas",Vector2(766,346),Vector2(365,51),func(): open_page("shop"))
	button(main_controls,"Controles e habilidades",Vector2(766,407),Vector2(365,51),world.hud_ui.toggle_help)
	home_button = button(main_controls,"Menu inicial",Vector2(766,468),Vector2(365,47),return_home)
	quit_button = button(main_controls,"Sair do jogo",Vector2(766,525),Vector2(365,47),func(): get_tree().quit())
	button(settings_controls,"Teclas e ataques",Vector2(130,134),Vector2(225,40),func(): select_tab("keys"))
	button(settings_controls,"Áudio e vídeo",Vector2(365,134),Vector2(225,40),func(): select_tab("audio"))
	var touch_tab := button(settings_controls,"HUD do celular",Vector2(600,134),Vector2(225,40),func(): select_tab("touch"))
	touch_tab.visible = Settings.mobile_mode
	label(touch_settings,"Seus controles, do seu jeito",Vector2(150,230),30)
	label(touch_settings,"Arraste os botões e o direcional. Ajuste o tamanho de cada controle.",Vector2(150,297),22)
	label(touch_settings,"Escolha a transparência e mantenha ou esconda os nomes.",Vector2(150,337),22)
	label(touch_settings,"O jogo fica pausado enquanto você edita. Salve ou cancele ao terminar.",Vector2(150,377),20)
	button(touch_settings,"Personalizar HUD",Vector2(150,447),Vector2(450,65),func(): world.touch_controls.begin_edit())
	var index := 0
	for action in Settings.ACTION_NAMES:
		var column := index%2
		var row := index/2
		var x := 130.0+column*520
		var y := 204.0+row*48
		label(key_controls,Settings.ACTION_NAMES[action],Vector2(x+(26 if action in ["attack","charge","spell","focus","dash","jump","interact","pause"] else 0),y+9),16)
		key_buttons[action] = button(key_controls,"",Vector2(x+190,y),Vector2(240,38),func(): capture(action))
		index += 1
	button(key_controls,"Restaurar teclas padrão",Vector2(130,573),Vector2(280,40),func(): Settings.reset_keys(); status = "Teclas padrão restauradas."; refresh())
	for i in range(3):
		var kind: String = ["master","music","effects"][i]
		var caption: String = ["Volume geral","Trilha sonora","Efeitos sonoros"][i]
		var y := 219.0+i*68
		label(audio_controls,caption,Vector2(150,y),18)
		var slider := HSlider.new()
		slider.position = Vector2(450,y+5)
		slider.size = Vector2(490,30)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.mouse_filter = Control.MOUSE_FILTER_STOP
		var value: float = Settings.get(kind+"_volume")
		slider.value = value*100
		slider.value_changed.connect(func(amount: float): Settings.set_volume(kind,amount/100); refresh_volumes())
		slider.drag_ended.connect(func(_changed: bool): world.sound.play("ui"))
		audio_controls.add_child(slider)
		sliders[kind] = slider
		volume_labels[kind] = label(audio_controls,"",Vector2(969,y),18)
	button(audio_controls,"Ouvir um ataque",Vector2(150,432),Vector2(255,42),func(): world.sound.play("heavy"))
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Tela cheia"
	fullscreen_check.position = Vector2(450,430)
	fullscreen_check.size = Vector2(220,44)
	fullscreen_check.button_pressed = Settings.fullscreen
	fullscreen_check.toggled.connect(Settings.set_fullscreen)
	audio_controls.add_child(fullscreen_check)
	shake_check = CheckButton.new()
	shake_check.text = "Tremida da câmera"
	shake_check.position = Vector2(450,494)
	shake_check.size = Vector2(310,44)
	shake_check.button_pressed = Settings.camera_shake
	shake_check.toggled.connect(func(value: bool): Settings.camera_shake = value; Settings.save_profile(); Settings.changed.emit())
	audio_controls.add_child(shake_check)
	label(audio_controls,"Mudanças são aplicadas e salvas automaticamente.",Vector2(150,572),16)
	var slot := 0
	for item in Settings.ITEMS:
		var x := 95.0+slot*277
		purchase_buttons[item] = button(shop_controls,"",Vector2(x+16,487),Vector2(227,44),func(): buy(item))
		slot += 1
	back_button = button(self,"Voltar",Vector2(935,629),Vector2(220,42),close_page)
	for i in range(main_controls.get_child_count()):
		var entry = main_controls.get_child(i)
		entry.position = Vector2(450,284+i*49)
		entry.size = Vector2(380,44)
		entry.add_theme_font_override("font",display)
		entry.add_theme_font_size_override("font_size",30 if Settings.mobile_mode else 24)
		for state in ["normal","hover","pressed","focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.75,0.83,0.8,0.07 if state in ["hover","focus"] else 0)
			style.border_color = Color("dbe2d4")
			style.border_width_left = 2 if state in ["hover","focus"] else 0
			style.border_width_right = style.border_width_left
			entry.add_theme_stylebox_override(state,style)
	Settings.changed.connect(refresh)
	refresh()
	play_button.grab_focus()

func group(parent: Node = null) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else self).add_child(node)
	return node

func label(parent: Node, caption: String, pos: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.text = caption
	node.position = pos
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("d6e8df"))
	parent.add_child(node)
	return node

func button(parent: Node, caption: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = caption
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",17)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("283238") if state == "hover" else Color("111922")
		style.border_color = Color("e5e8da") if state == "focus" else Color("7a8b89")
		if state == "disabled":
			style.bg_color = Color("101e29")
			style.border_color = Color("304852")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(1)
		node.add_theme_stylebox_override(state,style)
	node.pressed.connect(func(): world.sound.play("ui"); callback.call())
	parent.add_child(node)
	return node

func refresh() -> void:
	for action in key_buttons:
		key_buttons[action].text = Settings.key_label(action,true)
	for item in purchase_buttons:
		var node: Button = purchase_buttons[item]
		node.disabled = item == Settings.equipped
		if item == Settings.equipped:
			node.text = "Equipada"
		elif item in Settings.owned:
			node.text = "Equipar"
		else:
			node.text = "Comprar • %d sementes" % Settings.ITEMS[item].cost
	refresh_volumes()
	queue_redraw()

func refresh_volumes() -> void:
	for kind in volume_labels:
		volume_labels[kind].text = "%d%%" % roundi(Settings.get(kind+"_volume")*100)

func open_page(next: String) -> void:
	page = next
	status = ""
	select_tab(settings_tab)
	refresh()
	back_button.grab_focus()

func select_tab(tab: String) -> void:
	settings_tab = tab
	key_controls.visible = tab == "keys"
	audio_controls.visible = tab == "audio"
	touch_settings.visible = tab == "touch"
	queue_redraw()

func close_page() -> void:
	if waiting_action != "":
		waiting_action = ""
		status = "Alteração cancelada."
	elif world.hud_ui.help_open:
		world.hud_ui.toggle_help()
	else:
		page = "main"
		status = ""
	play_button.grab_focus()
	block_shortcuts_until = Engine.get_process_frames()+2
	queue_redraw()

func return_home() -> void:
	get_tree().paused = false
	world.started = false
	world.player.enabled = false
	world.player.velocity = Vector2.ZERO
	for enemy in world.enemies:
		if is_instance_valid(enemy):
			enemy.active = false
	world.hud_ui.help_open = false
	page = "main"
	play_button.grab_focus()

func capture(action: String) -> void:
	waiting_action = action
	status = ""
	block_shortcuts_until = Engine.get_process_frames()+2
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or waiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		block_shortcuts_until = Engine.get_process_frames()+2
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_ESCAPE:
			waiting_action = ""
			status = "Alteração cancelada."
		else:
			var error := Settings.rebind(waiting_action,key)
			if error == "":
				status = "%s: tecla %s salva." % [Settings.ACTION_NAMES[waiting_action],Settings.key_label(waiting_action)]
				waiting_action = ""
				world.sound.play("ui")
			else:
				status = error
		refresh()

func buy(item: String) -> void:
	var error := Settings.purchase(item)
	if error == "":
		status = "%s equipada. Sua escolha foi salva." % Settings.ITEMS[item].name
		world.sound.play("purchase")
	else:
		status = error
	refresh()

func _process(_delta: float) -> void:
	var help: bool = world.hud_ui.help_open
	main_controls.visible = page == "main" and not help
	settings_controls.visible = page == "settings" and not help and waiting_action == ""
	shop_controls.visible = page == "shop" and not help
	back_button.visible = (page != "main" or help) and waiting_action == ""
	play_button.text = "Jogar novamente" if world.won else ("Continuar" if world.started else "Jogar")
	home_button.visible = world.started and not world.won
	quit_button.position.y = 529 if home_button.visible else 480
	quit_button.visible = not OS.has_feature("web")
	queue_redraw()

func text(value: String, pos: Vector2, size: int = 16, tint: Color = Color("d6e8df"), serif: bool = false) -> void:
	draw_string(display if serif else body,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,tint)

func panel(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.07,0.1,0.95)
	style.border_color = Color(0.45,0.65,0.6,0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	draw_style_box(style,rect)

func _draw() -> void:
	if world.hud_ui.help_open:
		return
	if page == "main":
		var heading := "L U M E" if not world.started else ("A luz resiste" if world.won else "Entre dois ecos")
		var title_width := display.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
		text(heading,Vector2(640-title_width/2,163),64,Color("edf0e4"),true)
		text("Â M B A R   &   N O I T E" if Settings.mobile_mode else "R U Í N A S   D O   E C O",Vector2(500,207),18,Color("e8bd80") if Settings.mobile_mode else Color("b8c8c2"))
		ornament(Vector2(640,238),230)
		ornament(Vector2(640,601),185)
		text("Uma luz pequena em um reino que esqueceu o sol.",Vector2(439,649),16,Color("b4c4bf"),true)
		text("%d sementes  ·  %s" % [Settings.wallet,Settings.ITEMS[Settings.equipped].name],Vector2(30,687),13,Color("aabbb4"))
	elif page == "settings":
		panel(Rect2(90,40,1100,635))
		text("Configurações",Vector2(130,91),38,Color("e8efe5"),true)
		text("Clique na tecla ao lado do ataque para trocar. Esc cancela; teclas duplicadas são bloqueadas." if settings_tab == "keys" else ("Personalize seus controles de toque." if settings_tab == "touch" else "Ajuste os volumes, teste os sons e escolha como prefere jogar."),Vector2(130,118),15)
		var tab_x: int = {"keys":130,"audio":365,"touch":600}[settings_tab]
		draw_line(Vector2(tab_x,180),Vector2(tab_x+225,180),Color("8eeed2"),2)
		text(status if status != "" else "Preferências guardadas neste dispositivo. No editor de HUD, toque em Salvar.",Vector2(130,554),14,Color("ffe2a2") if status != "" else Color("90b6aa"))
		if settings_tab == "keys":
			var index := 0
			for action in Settings.ACTION_NAMES:
				Icons.paint(self,action,Vector2(140+(index%2)*520,225+(index/2)*48),19,Color("e8bd80"))
				index += 1
	elif page == "shop":
		panel(Rect2(70,60,1140,620))
		text("O ateliê dos ecos",Vector2(108,117),38,Color("e8efe5"),true)
		text("Capas cosméticas • Colete sementes explorando os caminhos altos.",Vector2(108,151),16)
		text("CARTEIRA  %d" % Settings.wallet,Vector2(971,118),20,Color("8eeed2"))
		var slot := 0
		for item in Settings.ITEMS:
			var spec: Dictionary = Settings.ITEMS[item]
			var x := 95.0+slot*277
			panel(Rect2(x,185,259,365))
			var center := Vector2(x+130,304)
			draw_circle(center,73,Color(spec.accent,0.05))
			draw_arc(center,73,0,TAU,50,Color(spec.accent,0.35),1,true)
			draw_texture_rect(world.player.portrait_variants[item],Rect2(x+86,233,88,118),false)
			text(spec.name,Vector2(x+16,393),19,spec.accent,true)
			text("Adquirida" if item in Settings.owned else "%d sementes" % spec.cost,Vector2(x+16,425),15)
			text("Visual exclusivo • sem bônus",Vector2(x+16,453),13,Color("90b6aa"))
			slot += 1
		text(status if status != "" else "Compras e capas equipadas ficam salvas. Sem dinheiro real.",Vector2(110,595),16,Color("ffe2a2") if status != "" else Color("90b6aa"))
	if Settings.last_save_error != OK:
		text("Não foi possível salvar as preferências. Verifique a pasta de dados do jogo.",Vector2(130,650),14,Color("ed887c"))
	if waiting_action != "":
		draw_rect(Rect2(0,0,1280,720),Color(0.01,0.02,0.04,0.86))
		panel(Rect2(230,240,820,218))
		text("Escolha uma nova tecla",Vector2(280,294),32,Color("e8efe5"),true)
		text(Settings.ACTION_NAMES[waiting_action],Vector2(280,333),22,Color("8eeed2"))
		text("Pressione a tecla desejada. Esc para cancelar.",Vector2(280,373),18)
		text(status,Vector2(280,418),15,Color("ffe2a2"))

func ornament(center: Vector2, width: float) -> void:
	for side in [-1,1]:
		var points := PackedVector2Array()
		for i in range(40):
			var t := i/39.0
			points.append(center+Vector2(side*(9+t*width),sin(t*TAU*1.5)*7*(1-t)))
		draw_polyline(points,Color("e8bd80") if Settings.mobile_mode else Color("a6b8b3"),1,true)
		draw_arc(center+Vector2(side*35,-6),8,0,PI,20,Color("e8bd80") if Settings.mobile_mode else Color("a6b8b3"),1,true)
	draw_circle(center,3,Color("e8eedc"))
