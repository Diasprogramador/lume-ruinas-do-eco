extends Node2D

var biome: int = 0
var accent: Color
var rock: Color
var sky: Color
var texture: Texture2D
var clock: float = 0.0
var stones: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var roots: Array[PackedVector2Array] = []
var random := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = -10
	biome = get_parent().level_index
	accent = get_parent().level.accent
	rock = get_parent().level.rock
	sky = get_parent().level.sky
	random.seed = 932 + biome
	var background: String = ["cavern","brejo","minas","inverno","cinzas"][biome]
	if ResourceLoader.exists("res://assets/%s.png" % background):
		texture = load("res://assets/%s.png" % background)
	for rect in get_parent().platforms:
		for i in range(int(rect.size.x / 32)):
			var x: float = rect.position.x + i * 32
			var depth: float = random.randf_range(28, 70) if rect.size.y < 30 else random.randf_range(90, 210)
			stones.append({"points":PackedVector2Array([Vector2(x,rect.position.y+5),Vector2(x+36,rect.position.y+5),Vector2(x+40,rect.position.y+depth*0.4),Vector2(x+22,rect.position.y+depth),Vector2(x-3,rect.position.y+depth*0.6)]),"color":rock.lerp(sky,random.randf()*0.8),"top":Vector2(x,rect.position.y),"depth":depth})
		for i in range(int(rect.size.x / 18)):
			plants.append({"p":Vector2(rect.position.x+i*18+random.randf_range(0,14),rect.position.y),"height":random.randf_range(7,26),"mushroom":random.randf() < 0.14,"phase":random.randf()*TAU})
	for i in range(int(get_parent().level.width/240)+1):
		var x := i * 240.0
		var line := PackedVector2Array()
		for j in range(12):
			line.append(Vector2(x+sin(j*0.45+i)*48,-180+j*random.randf_range(20,25)))
		roots.append(line)
	for x in range(0,int(get_parent().level.width),640):
		var chunk := preload("res://scripts/terrain_chunk.gd").new()
		chunk.position.x = x
		chunk.source = self
		chunk.start = x
		add_child(chunk)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	clock += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-800,-500,get_parent().level.width+1600,1700),sky)
	var camera := get_viewport().get_camera_2d()
	var camera_x := camera.get_screen_center_position().x if camera else 640.0
	if texture:
		var shift := camera_x * 0.25
		for i in range(int((camera_x*0.75-350)/1792)-1,int((camera_x*0.75-350)/1792)+3):
			var rect := Rect2(i*1792+shift-350,-220,1792,1050)
			if rect.end.x < camera_x-700 or rect.position.x > camera_x+700: continue
			if i%2 != 0:
				draw_set_transform(rect.position+Vector2(rect.size.x,0),0,Vector2(-1,1))
				draw_texture_rect(texture,Rect2(Vector2.ZERO,rect.size),false,Color(0.8,0.85,0.9,0.85))
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect(texture,rect,false,Color(0.8,0.85,0.9,0.85))
	else:
		draw_biome(camera_x)
	if biome > 0 and texture:
		for i in range(16 if Settings.low_power else 32):
			var x := fposmod(i*139.7+clock*(12 if biome == 3 else -6),1450)+camera_x-725
			var y := fposmod(i*73.9+clock*(40 if biome == 3 else -14),900)-140
			draw_circle(Vector2(x,y),2 if biome == 3 else 1.3,Color(accent,0.38))
	for i in range(16):
		var x := i * 320.0
		draw_colored_polygon(PackedVector2Array([Vector2(x,-200),Vector2(x+140,-200),Vector2(x+390,700),Vector2(x+190,700)]),Color(0.5,0.85,0.87,0.025))

func draw_biome(camera_x: float) -> void:
	# Three parallax layers, each with different silhouette scale and material.
	for layer in range(3):
		var spacing := 390.0 if biome != 3 else 460.0
		var parallax := camera_x * (0.78-layer*0.23)
		var first := int((camera_x-parallax)/spacing)-3
		for i in range(first,first+10):
			var x := i*spacing+parallax
			var y := 500.0+layer*65
			var shade := sky.lerp(rock,0.35+layer*0.22)
			var height := 230.0+sin(i*7.3+layer)*100+layer*40
			match biome:
				1:
					# Giant luminous fungi, curved stems and hanging spores.
					var top := Vector2(x,y-height)
					draw_line(Vector2(x+30,y+200),top,shade,25+layer*8,true)
					draw_set_transform(top,0,Vector2(1.8,0.48))
					draw_circle(Vector2.ZERO,80+layer*15,shade.lightened(0.035))
					draw_arc(Vector2.ZERO,75+layer*15,0,PI,40,Color(accent,0.12+layer*0.08),5,true)
					draw_set_transform(Vector2.ZERO)
					for j in range(6):
						var lamp := top+Vector2((j-3)*32,30+sin(j+i)*12)
						draw_line(lamp,lamp+Vector2(0,42+sin(clock+j)*8),Color(accent,0.1),2,true)
						draw_circle(lamp+Vector2(0,45),4,Color(accent,0.35))
				2:
					var origin := Vector2(x,y+200)
					var tip := Vector2(x+sin(i)*75,y-height-150)
					draw_colored_polygon(PackedVector2Array([origin-Vector2(90,0),tip,origin+Vector2(100,0)]),shade)
					draw_colored_polygon(PackedVector2Array([origin,tip,origin+Vector2(100,0)]),shade.lightened(0.04))
					draw_line(tip,origin,Color(accent,0.12+layer*0.04),2,true)
					if layer == 2:
						draw_line(Vector2(x-200,500),Vector2(x+200,430),rock.darkened(0.1),9,true)
				3:
					draw_rect(Rect2(x-25,y-height,50,height+240),shade)
					draw_arc(Vector2(x+230,y-height+100),230,PI,TAU,48,shade,30,true)
					draw_line(Vector2(x,y-height-10),Vector2(x+460,y-height-10),shade.lightened(0.08),16,true)
					for j in range(8):
						var p := Vector2(x+j*55,y-height)
						draw_colored_polygon(PackedVector2Array([p,p+Vector2(12,65+sin(i+j)*30),p+Vector2(25,0)]),Color(accent,0.11))
				4:
					draw_rect(Rect2(x-75,y-height,150,height+200),shade)
					for j in range(4):
						draw_rect(Rect2(x-80+j*45,y-height-24,28,35),shade)
					for j in range(3):
						var window := Vector2(x,y-height+65+j*90)
						draw_rect(Rect2(window-Vector2(12,28),Vector2(24,52)),Color(accent,0.06+layer*0.035))
						draw_circle(window,40,Color(accent,0.025))
					draw_line(Vector2(x+90,-150),Vector2(x+50,400),shade,5,true)
	for i in range(45):
		var x := fposmod(i*139.7+clock*(12 if biome == 3 else -6),1450)+camera_x-725
		var y := fposmod(i*73.9+clock*(40 if biome == 3 else -14),900)-140
		draw_circle(Vector2(x,y),2 if biome == 3 else 1.3,Color(accent,0.35))
	# Ground mist or furnace glow remains behind the playable silhouettes.
	for j in range(8):
		draw_rect(Rect2(camera_x-750,680+j*20,1500,20),Color(accent,0.025+j*0.003))
