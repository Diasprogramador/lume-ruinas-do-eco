extends RefCounted

const NAMES = ["Jardins Esquecidos", "Brejo das Lanternas", "Minas de Ametista", "Aquedutos do Inverno", "Cidadela das Cinzas"]
const BOSSES = ["Guardião do Eco", "Vigia dos Esporos", "Sentinela de Vidro", "Cavaleiro da Geada", "Última Brasa"]
const ACCENTS = ["8eeed2", "dfb0ed", "bca5ff", "a5eaff", "ffb16e"]
const ROCKS = ["203745", "392942", "302c52", "284b60", "47302d"]
const SKIES = ["071222", "170f24", "100d25", "0b2030", "211016"]

static func build(index: int) -> Dictionary:
	var width := 8600 + index * 600
	var terrain: Array[Rect2] = []
	var seeds: Array[Vector2] = []
	var foes: Array[Vector2] = []
	var shrines: Array[Vector2] = []
	var hazards: Array[Rect2] = []
	if index == 0:
		terrain.assign([Rect2(0,640,850,160),Rect2(1050,640,700,160),Rect2(1900,640,2400,160),Rect2(560,520,180,24),Rect2(800,430,190,24),Rect2(1070,350,230,24),Rect2(1400,465,220,24),Rect2(1660,530,180,24),Rect2(2120,530,180,24),Rect2(2390,440,200,24),Rect2(2650,350,220,24),Rect2(2900,430,60,210)])
		seeds.assign([Vector2(640,478),Vector2(900,385),Vector2(1170,305),Vector2(1500,420),Vector2(1750,485),Vector2(2200,485),Vector2(2490,395),Vector2(2750,305)])
		foes.assign([Vector2(570,610),Vector2(1360,610),Vector2(2180,500),Vector2(2530,610),Vector2(3650,610)])
		shrines.append(Vector2(2010,602))
	else:
		terrain.append(Rect2(0,640,1000,200))
		shrines.append(Vector2(580,602))
	# Authored biome motifs repeat in different arrangements, with an upper reward route.
	var start := 4300 if index == 0 else 1000
	var section := 0
	for x in range(start, width - 1500, 1000):
		var base := float(x)
		match index:
			0: # Broken cloisters and raised garden terraces.
				terrain.append(Rect2(base,640,760,200))
				terrain.append(Rect2(base+680,520,200,28))
				terrain.append(Rect2(base+900,590,100,250))
			1: # Stepping islands above toxic pools, mushroom canopy above.
				terrain.append(Rect2(base,640,260,200))
				terrain.append(Rect2(base+360,575,260,240))
				terrain.append(Rect2(base+730,640,270,200))
				hazards.append(Rect2(base+260,710,470,30))
			2: # Alternating mine shelves and crystal columns.
				terrain.append(Rect2(base,640,1000,200))
				terrain.append(Rect2(base+360,460,60,180))
				terrain.append(Rect2(base+660,510,65,130))
				hazards.append(Rect2(base+470,624,120,16))
			3: # Long broken aqueduct spans, narrow landing piers.
				terrain.append(Rect2(base,610,340,200))
				terrain.append(Rect2(base+510,555,250,240))
				terrain.append(Rect2(base+890,610,110,210))
			4: # Furnace pits bridged by stairs of black stone.
				terrain.append(Rect2(base,640,310,200))
				terrain.append(Rect2(base+380,545,180,32))
				terrain.append(Rect2(base+620,460,160,32))
				terrain.append(Rect2(base+840,640,160,200))
				hazards.append(Rect2(base+310,740,530,28))
		terrain.append(Rect2(base+80,475,180,26))
		terrain.append(Rect2(base+300,335,180,26))
		terrain.append(Rect2(base+580,245 if section % 2 == 0 else 330,230,26))
		seeds.append(Vector2(base+670,203 if section % 2 == 0 else 288))
		seeds.append(Vector2(base+160,433))
		foes.append(Vector2(base+150,450))
		foes.append(Vector2(base+900,580))
		if section % 2 == 1:
			shrines.append(Vector2(base+160,437))
		section += 1
	# Safe approach, rest point and a broad, uninterrupted boss arena.
	terrain.append(Rect2(width-1700,640,1700,220))
	shrines.append(Vector2(width-1530,602))
	return {"index":index,"name":NAMES[index],"boss_name":BOSSES[index],"width":width,"platforms":terrain,"seeds":seeds,"enemies":foes,"shrines":shrines,"hazards":hazards,"accent":Color(ACCENTS[index]),"rock":Color(ROCKS[index]),"sky":Color(SKIES[index]),"arena":Vector2(width-1300,width-180),"boss":Vector2(width-730,590),"exit":Vector2(width-140,585)}
