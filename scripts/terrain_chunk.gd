extends Node2D
# Draw commands are recorded once per spatial chunk, then reused by the renderer.
var source
var start: float
var biome: int
var accent: Color
var rock: Color
var roots: Array = []
var platforms: Array[Rect2] = []
var stones: Array = []
var plants: Array = []

func _ready() -> void:
	biome = source.biome
	accent = source.accent
	rock = source.rock
	for rect in get_parent().get_parent().platforms:
		var clip: Rect2 = rect.intersection(Rect2(start,-500,640,1600))
		if clip.has_area(): platforms.append(clip)
	for item in source.stones:
		if item.top.x >= start and item.top.x < start+640: stones.append(item)
	for item in source.plants:
		if item.p.x >= start and item.p.x < start+640:
			if not Settings.low_power or int(item.p.x)%3 == 0: plants.append(item)
	for line in source.roots:
		if line[0].x >= start and line[0].x < start+640: roots.append(line)

func _draw() -> void:
	draw_set_transform(Vector2(-start,0))
	for line in roots if biome < 2 else []:
		draw_polyline(line,Color("091923"),13,true)
		draw_polyline(line,Color("243b42"),3,true)
	for rect in platforms:
		draw_rect(rect,rock.darkened(0.5))
	for stone in stones:
		draw_colored_polygon(stone.points,stone.color)
		var p: Vector2 = stone.top
		draw_line(p+Vector2(3,10),p+Vector2(7,stone.depth*0.5),Color(0.3,0.5,0.54,0.18),1,true)
	for rect in platforms:
		draw_line(rect.position+Vector2(0,3),rect.position+Vector2(rect.size.x,3),rock.lightened(0.25),5,true)
		draw_line(rect.position,rect.position+Vector2(rect.size.x,0),accent.darkened(0.2),1.5,true)
	for plant in plants:
		var p: Vector2 = plant.p
		var h: float = plant.height
		var sway: float = sin(plant.phase)*2
		var end := p+Vector2(sway,-h)
		if biome >= 2:
			if int(plant.phase*10)%3 == 0:
				var tip := p+Vector2(sway,-h*(1.8 if biome == 2 else 0.7))
				draw_colored_polygon(PackedVector2Array([p-Vector2(5,0),tip,p+Vector2(6,0)]),Color(accent,0.6))
				draw_line(tip,p,Color(accent,0.85),1,true)
			continue
		draw_line(p,end,accent.darkened(0.55),1.5,true)
		if plant.mushroom:
			for radius in [22,15,9]:
				draw_circle(end,radius,Color(0.28,0.75,0.68,0.025))
			draw_set_transform(end-Vector2(start,0),0,Vector2(1.8,0.6))
			draw_circle(Vector2.ZERO,5,accent.darkened(0.1))
			draw_set_transform(Vector2(-start,0))
		else:
			draw_line(p+Vector2(0,-h*0.3),p+Vector2(-6+sway,-h*0.65),accent.darkened(0.6),2,true)
			draw_line(p+Vector2(0,-h*0.6),p+Vector2(5+sway,-h*0.8),accent.darkened(0.4),2,true)

