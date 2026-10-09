extends Panel

var touch
var size_slider: HSlider
var opacity_slider: HSlider
var names: CheckButton
var hint: Label
var size_label: Label
var opacity_label: Label

func _ready() -> void:
	position = Vector2(270,10)
	size = Vector2(740,275)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111922")
	style.border_color = Color("e8bd80")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel",style)
	var menu = touch.world.hud_ui.menu
	menu.button(self,"Salvar",Vector2(16,12),Vector2(175,64),func(): touch.finish_edit(true)).add_theme_font_size_override("font_size",23)
	menu.button(self,"Cancelar",Vector2(205,12),Vector2(175,64),func(): touch.finish_edit(false)).add_theme_font_size_override("font_size",23)
	menu.button(self,"Restaurar padrão",Vector2(394,12),Vector2(325,64),touch.reset_draft).add_theme_font_size_override("font_size",23)
	hint = menu.label(self,"Arraste um controle. Ajuste e salve ao terminar.",Vector2(16,84),20)
	size_label = menu.label(self,"",Vector2(16,126),22)
	size_slider = make_slider(Vector2(360,113),85,150)
	size_slider.value_changed.connect(func(value: float):
		touch.layout[touch.selected].scale = value/100
		touch.layout = Settings.sanitize_touch_layout(touch.layout)
		touch.update_buttons()
		refresh())
	opacity_label = menu.label(self,"",Vector2(16,180),22)
	opacity_slider = make_slider(Vector2(360,167),45,100)
	opacity_slider.value_changed.connect(func(value: float): touch.opacity = value/100; refresh())
	names = CheckButton.new()
	names.text = "Mostrar nomes junto aos ícones"
	names.position = Vector2(16,221)
	names.size = Vector2(700,48)
	names.add_theme_font_size_override("font_size",22)
	names.toggled.connect(func(value: bool): touch.show_labels = value)
	add_child(names)

func make_slider(pos: Vector2, low: float, high: float) -> HSlider:
	var slider := HSlider.new()
	slider.position = pos
	slider.size = Vector2(354,52)
	slider.min_value = low
	slider.max_value = high
	slider.step = 5
	add_child(slider)
	return slider

func refresh() -> void:
	size_slider.set_value_no_signal(touch.layout[touch.selected].scale*100)
	opacity_slider.set_value_no_signal(touch.opacity*100)
	names.set_pressed_no_signal(touch.show_labels)
	size_label.text = "%s: %d%%" % [Settings.TOUCH_DEFAULTS[touch.selected][2],size_slider.value]
	opacity_label.text = "Opacidade: %d%%" % opacity_slider.value
