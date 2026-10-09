extends RefCounted

# Shared vector symbols stay sharp at every desktop and touch-control size.
static func paint(canvas: CanvasItem, action: String, center: Vector2, size: float, tint: Color) -> void:
	canvas.draw_set_transform(center,0,Vector2.ONE*size/32.0)
	match action:
		"attack", "charge":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-6,4),Vector2(7,-12),Vector2(12,-14),Vector2(11,-7),Vector2(-2,8)]),tint)
			canvas.draw_line(Vector2(-10,1),Vector2(2,12),tint,2.5,true)
			canvas.draw_line(Vector2(-5,7),Vector2(-11,13),tint,3,true)
			if action == "charge":
				canvas.draw_arc(Vector2.ZERO,16,-2.9,-0.2,22,tint,2,true)
				canvas.draw_line(Vector2(1,-20),Vector2(1,-24),tint,2,true)
				canvas.draw_line(Vector2(-13,-15),Vector2(-16,-18),tint,2,true)
		"spell":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-16),Vector2(5,-5),Vector2(14,0),Vector2(5,5),Vector2(0,16),Vector2(-5,5),Vector2(-14,0),Vector2(-5,-5)]),tint)
			canvas.draw_arc(Vector2.ZERO,19,-1,1,16,tint,1.5,true)
			canvas.draw_arc(Vector2.ZERO,19,2.1,4.1,16,tint,1.5,true)
		"focus":
			canvas.draw_arc(Vector2.ZERO,15,-PI,0,24,tint,2,true)
			canvas.draw_line(Vector2(0,-7),Vector2(0,9),tint,3,true)
			canvas.draw_line(Vector2(-8,1),Vector2(8,1),tint,3,true)
			canvas.draw_polyline(PackedVector2Array([Vector2(-14,7),Vector2(-7,16),Vector2(0,18),Vector2(7,16),Vector2(14,7)]),tint,2,true)
		"dash":
			for i in range(2):
				var x := -4.0+i*10
				canvas.draw_polyline(PackedVector2Array([Vector2(x-4,-11),Vector2(x+6,0),Vector2(x-4,11)]),tint,3,true)
			for y in [-7,0,7]: canvas.draw_line(Vector2(-20,y),Vector2(-12,y),tint,2,true)
		"jump":
			canvas.draw_line(Vector2(0,13),Vector2(0,-11),tint,3,true)
			canvas.draw_polyline(PackedVector2Array([Vector2(-11,-2),Vector2(0,-14),Vector2(11,-2)]),tint,3,true)
			canvas.draw_line(Vector2(-11,17),Vector2(11,17),tint,2,true)
		"pause":
			canvas.draw_rect(Rect2(-10,-13,6,26),tint)
			canvas.draw_rect(Rect2(4,-13,6,26),tint)
		"interact":
			canvas.draw_arc(Vector2.ZERO,14,0.3,TAU-0.3,28,tint,2,true)
			canvas.draw_line(Vector2(18,0),Vector2(-5,0),tint,2,true)
			canvas.draw_polyline(PackedVector2Array([Vector2(1,-6),Vector2(-5,0),Vector2(1,6)]),tint,2,true)
	canvas.draw_set_transform(Vector2.ZERO)
