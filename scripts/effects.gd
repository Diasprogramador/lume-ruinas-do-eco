extends Node2D

var particles: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var waves: Array[Dictionary] = []

func ring(location: Vector2, tint: Color, radius: float, duration: float = 0.4) -> void:
	waves.append({"p":location,"color":tint,"radius":radius,"life":duration,"duration":duration})

func slash(location: Vector2, angle: float, power: int) -> void:
	for i in range(12 if power > 1 else 6):
		var direction := Vector2.from_angle(angle+random.randf_range(-0.65,0.65))
		particles.append({"p":location+direction*40,"v":direction*random.randf_range(180,480),"life":random.randf_range(0.18,0.38),"color":Color("ffe2a2") if power > 1 else Color("c8ffec"),"size":random.randf_range(1.5,3.5)})
	waves.append({"p":location,"color":Color("ffe2a2") if power > 1 else Color("c8ffec"),"radius":150.0 if power > 1 else 105.0,"life":0.24,"duration":0.24,"angle":angle,"slash":true})

func pillar(location: Vector2) -> void:
	waves.append({"p":location,"color":Color("a4cffb"),"radius":100.0,"life":0.48,"duration":0.48,"pillar":true})

func impact(location: Vector2) -> void:
	ring(location,Color("a4cffb"),190,0.55)
	waves.append({"p":location,"color":Color("a4cffb"),"radius":175.0,"life":0.4,"duration":0.4,"impact":true})

func _ready() -> void:
	z_index = 5

func burst(location: Vector2, tint: Color, amount: int) -> void:
	for i in range(mini(amount,12) if Settings.low_power else amount):
		if particles.size() >= (80 if Settings.low_power else 240): break
		var angle := random.randf_range(-PI,PI)
		particles.append({"p":location,"v":Vector2.from_angle(angle)*random.randf_range(50,240),"life":random.randf_range(0.25,0.6),"color":tint,"size":random.randf_range(1.5,4.0)})

func _process(delta: float) -> void:
	for i in range(waves.size()-1,-1,-1):
		waves[i].life -= delta
		if waves[i].life <= 0:
			waves.remove_at(i)
	for i in range(particles.size()-1,-1,-1):
		particles[i].life -= delta
		particles[i].p += particles[i].v * delta
		particles[i].v.y += 350 * delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for wave in waves:
		var fraction: float = 1.0-wave.life/wave.duration
		var tint: Color = wave.color
		tint.a = (1.0-fraction)*0.8
		var radius: float = lerpf(wave.radius*0.5,wave.radius,fraction)
		if wave.get("pillar",false):
			for side in [-1,1]:
				var ribbon := PackedVector2Array()
				for k in range(25):
					var t := k/24.0
					ribbon.append(wave.p+Vector2(side*(20+sin(t*9-fraction*8)*25)*(1-t*0.6),-t*235))
				draw_polyline(ribbon,Color(tint,tint.a*0.16),24,true)
				draw_polyline(ribbon,Color("eaf8ff",tint.a),3,true)
			draw_circle(wave.p-Vector2(0,190*fraction),24*(1-fraction),Color("effbff",tint.a*0.8))
			for i in range(7):
				var x := (i-3)*18.0
				var length := 200.0-absf(x)*0.7
				var p: Vector2 = wave.p+Vector2(x,0)
				draw_line(p,p+Vector2(sin(fraction*9+i)*12,-length),Color(tint, tint.a*0.6),8*(1-fraction)+1,true)
				draw_line(p+Vector2(0,-length*0.6),p+Vector2(0,-length),Color("f0f7ff",tint.a),2,true)
		elif wave.get("impact",false):
			draw_set_transform(wave.p,0,Vector2(1,0.24))
			draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("eaf8ff",tint.a),8*(1-fraction)+1,true)
			draw_arc(Vector2.ZERO,radius*0.8,0,TAU,64,Color(tint,tint.a*0.25),20,true)
			draw_set_transform(Vector2.ZERO)
			for i in range(13):
				var p: Vector2 = wave.p+Vector2((i-6)*27,0)
				var height := (55-absf(i-6)*5)*(1-fraction)
				draw_colored_polygon(PackedVector2Array([p-Vector2(7,0),p+Vector2(4,-height),p+Vector2(10,0)]),tint)
		elif wave.get("slash",false):
			# A tapered blade of light sweeps across the actual attack direction.
			var sweep: float = wave.angle + lerpf(-0.45,0.45,fraction)
			for layer in range(3):
				var outside := PackedVector2Array()
				var inside := PackedVector2Array()
				var width: float = (24.0-layer*8)*(1.0-fraction)
				for i in range(33):
					var t := i/32.0
					var a: float = sweep+lerpf(-1.25,1.1,t)
					var r: float = radius+layer*2
					outside.append(wave.p+Vector2.from_angle(a)*r)
					inside.append(wave.p+Vector2.from_angle(a)*(r-width*sin(t*PI)))
				inside.reverse()
				outside.append_array(inside)
				draw_colored_polygon(outside,Color(tint.lightened(layer*0.3),tint.a*(0.3+layer*0.3)))
			for j in range(3):
				draw_arc(wave.p,radius-14-j*9,sweep-0.85,sweep+0.9,32,Color(tint,tint.a*0.22),2,true)

		else:
			draw_arc(wave.p,radius,0,TAU,48,tint,4*(1.0-fraction)+1,true)
			for i in range(8):
				var point: Vector2 = wave.p+Vector2.from_angle(i*TAU/8+fraction)*radius
				draw_line(point,point+Vector2.from_angle(i*TAU/8+fraction)*12,tint,2,true)
	for particle in particles:
		var tint: Color = particle.color
		tint.a = minf(1, particle.life * 3)
		draw_line(particle.p,particle.p-particle.v*0.022,tint,particle.size,true)
