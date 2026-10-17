extends Node2D

const Catalog = preload("res://scripts/catalog.gd")
const SkillIcon = preload("res://scripts/skill_icon.gd")
const Campaign = preload("res://scripts/campaign.gd")
const LEVEL_NAMES = ["Clover Corner", "Blossom Crossing", "Golden Grove"]
const INK = Color("203c38")
const CREAM = Color("fff4d4")
const GOLD = Color("f6cf67")
var state = Campaign.new()
var textures: Dictionary = {}
var player = Vector2(200,410)
var facing = Vector2.RIGHT
var moving: bool = false
var invincible: float = 0.0
var dash_time: float = 0.0
var knock = Vector2.ZERO
var clock: float = 0.0
var flowers: Array = []
var bees: Array = []
var walls: Array[Rect2] = []
var particles: Array = []
var ui: Control
var mode: String = "title"
var campaign_active: bool = false
var message: String = ""
var message_time: float = 0.0
var pending_skill: String = ""
var selected_skill: String = "Speed"
var shop_tab: String = "Abilities"
var shop_note: String = ""
var settings_return: String = "title"
var dash_direction = Vector2.RIGHT
var dash_trail: Array = []
var trail_timer: float = 0.0
var shake: bool = true
var effects_volume: float = 0.65
var music_volume: float = 0.3
var music: AudioStreamPlayer
var font: Font
const BASE = Rect2(46,155,264,552)
const CRATE = Vector2(158,295)
const SHOP = Vector2(157,586)

func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_art()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	var settings = ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		effects_volume = settings.get_value("audio","effects",0.65)
		music_volume = settings.get_value("audio","music",0.3)
		shake = settings.get_value("visual","shake",true)
	setup_music()
	build_level()
	show_title()

func load_art() -> void:
	# Keep the original sheets untouched. Remove their green matte at runtime.
	var specs = {
		"alpaca":["characters",Rect2i(5,15,313,389)],
		"pollen":["characters",Rect2i(320,15,383,389)],
		"crate":["characters",Rect2i(710,15,339,389)],
		"coin":["shop",Rect2i(5,15,350,389)],
		"bee":["shop",Rect2i(370,15,390,379)],
		"shop":["shop",Rect2i(770,15,390,379)],
		"Bag":["skills",Rect2i(5,15,310,310)],
		"Shield":["skills",Rect2i(330,15,300,310)],
		"Speed":["skills",Rect2i(645,15,300,310)]}
	for key in specs:
		var spec = specs[key]
		var source: Texture2D = load("res://assets/" + spec[0] + ".png")
		var img: Image = source.get_image().get_region(spec[1])
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c = img.get_pixel(x,y)
				if absf(c.r-0.478) < 0.065 and absf(c.g-0.780) < 0.065 and absf(c.b-0.459) < 0.065:
					img.set_pixel(x,y,Color.TRANSPARENT)
		textures[key] = ImageTexture.create_from_image(img)
	textures["Dash"] = textures["Speed"]
	var bee_image: Image = textures["bee"].get_image()
	textures["bee_wings"] = ImageTexture.create_from_image(bee_image.get_region(Rect2i(0,0,390,145)))
	textures["bee_body"] = ImageTexture.create_from_image(bee_image.get_region(Rect2i(0,145,390,234)))

func build_level() -> void:
	player = Vector2(215,419)
	flowers.clear()
	bees.clear()
	particles.clear()
	dash_trail.clear()
	moving = false
	message_time = 0
	walls.clear()
	invincible = 0
	dash_time = 0
	knock = Vector2.ZERO
	var layouts = [
		[Rect2(490,290,145,44),Rect2(785,491,160,44)],
		[Rect2(468,330,150,44),Rect2(758,220,44,148),Rect2(805,512,167,44)],
		[Rect2(445,250,140,44),Rect2(650,430,44,150),Rect2(875,285,155,44),Rect2(970,580,145,44)]]
	for w in layouts[state.level]:
		walls.append(w)
	var patches = [Vector2(363,232),Vector2(400,575),Vector2(671,199),Vector2(704,622),Vector2(1056,214),Vector2(1070,443)]
	for p in patches.size():
		for j in 5:
			var pos: Vector2 = patches[p] + Vector2((j%3)*34,(j/3)*35)
			var amount = 1 if p < 2 else (2 if p < 4 else 5)
			flowers.append({"pos":pos,"max":amount,"left":amount,"timer":0.0})
	var paths = [
		[Vector2(475,170),Vector2(475,630)],
		[Vector2(760,395),Vector2(1140,395)],
		[Vector2(570,405),Vector2(725,405),Vector2(725,540),Vector2(570,540)],
		[Vector2(890,175),Vector2(1135,175),Vector2(1135,350),Vector2(890,350)],
		[Vector2(340,475),Vector2(590,475),Vector2(590,635),Vector2(340,635)],
		[Vector2(755,610),Vector2(930,610),Vector2(930,450),Vector2(755,450)]]
	# Routes are adjusted per map to keep patrols clear of solid hedges.
	if state.level == 1:
		paths[0] = [Vector2(650,165),Vector2(650,650)]
	if state.level == 2:
		paths[0] = [Vector2(600,165),Vector2(600,650)]
		paths[2] = [Vector2(735,360),Vector2(1130,360)]
		paths[3] = [Vector2(850,165),Vector2(1150,165)]
		paths[4] = [Vector2(350,475),Vector2(570,475),Vector2(570,635),Vector2(350,635)]
	for i in 2+state.level*2:
		bees.append({"path":paths[i],"pos":paths[i][0],"target":1,"speed":70.0+i*8,"dir":Vector2.RIGHT,"from":paths[i][0],"progress":0.0,"phase":i*1.73,"flip":1.0,"tilt":0.0})

func _process(delta: float) -> void:
	# Small simulation steps keep dash distance and bee contacts frame-rate independent.
	var remaining = minf(maxf(delta,0),0.25)
	while remaining > 0.000001 and mode == "play":
		var step = minf(remaining,1.0/120.0)
		simulate(step)
		remaining -= step
	queue_redraw()

func simulate(delta: float) -> void:
	if mode == "play":
		clock += delta
		state.elapsed += delta
		message_time = maxf(0,message_time-delta)
		invincible = maxf(0, invincible-delta)
		state.tick(delta)
		var direction = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
		moving = direction.length() > 0
		if moving:
			facing = direction
		var velocity = direction * state.speed()
		if dash_time > 0:
			var dash_fraction = minf(dash_time,delta)/delta
			velocity = dash_direction*state.speed()*2.5*dash_fraction + velocity*(1.0-dash_fraction)
			dash_time = maxf(0,dash_time-delta)
			trail_timer -= delta
			if trail_timer <= 0:
				dash_trail.append({"pos":player,"life":0.25})
				trail_timer = 0.035
		if knock.length() > 1:
			velocity = knock
			knock = knock.move_toward(Vector2.ZERO,1800*delta)
		move_player(velocity*delta)
		for f in flowers:
			if f.left <= 0:
				f.timer -= delta
				if f.timer <= 0:
					f.left = f.max
			elif player.distance_to(f.pos) < state.collection_radius() and state.pollen < state.capacity() and clear_collection_line(player,f.pos):
				var taken = state.collect(f.left)
				f.left -= taken
				if f.left == 0:
					f.timer = 8.0
					var bonus = state.flower_completed()
					if bonus>0:
						notify("Lucky Bloom! +%d bonus pollen" % bonus)
				burst(f.pos,GOLD,7)
				tone(650+state.pollen*24,0.06)
				if state.pollen == state.capacity():
					notify("Bag full! Bring your pollen home.")
		for b in bees:
			update_bee(b,delta)
			if player.distance_to(b.pos) < 29 and invincible <= 0:
				var protected = state.hit()
				invincible = 1.25
				dash_time = 0
				if not protected:
					knock = (player-b.pos).normalized()*280
					if knock == Vector2.ZERO:
						knock = -facing*280
				burst(player,GOLD,24)
				notify("Shield saved your pollen! Deposit to recharge." if protected else "Pollen spilled! Your banked coins are safe.")
				tone(240 if protected else 110,0.18)
		if player.distance_to(CRATE) < 65 and state.pollen > 0:
			var amount = state.deposit()
			burst(CRATE,GOLD,25)
			tone(880,0.2)
			notify("+%d coins  •  Safe and sound!" % (amount*2))
			if state.delivered >= state.QUOTAS[state.level]:
				show_results()
		for p in particles:
			p.life -= delta
			p.pos += p.vel*delta
			p.vel *= exp(-3.0*delta)
		particles = particles.filter(func(p): return p.life > 0)
		for ghost in dash_trail:
			ghost.life -= delta
		dash_trail = dash_trail.filter(func(g): return g.life>0)
	queue_redraw()

func move_player(displacement: Vector2) -> void:
	# Small substeps prevent tunnelling while dashing or at low frame rates.
	var steps = maxi(1,ceili(displacement.length()/7.0))
	var step = displacement/steps
	for i in steps:
		var next = player + Vector2(step.x,0)
		if walkable(next):
			player = next
		next = player + Vector2(0,step.y)
		if walkable(next):
			player = next

func walkable(pos: Vector2) -> bool:
	if not Rect2(61,164,1158,529).has_point(pos):
		return false
	for w in walls:
		if w.grow(15).has_point(pos):
			return false
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if mode == "play":
			show_pause()
		elif mode in ["pause","shop"]:
			resume()
		elif mode == "replace":
			show_shop()
		elif mode == "settings":
			save_settings()
			if settings_return=="title": show_title()
			else: show_pause()
		elif mode in ["help","confirm"]:
			show_title()
	elif mode == "play" and event.physical_keycode == KEY_E and player.distance_to(SHOP)<110:
		show_shop()
	elif mode == "play" and event.physical_keycode == KEY_SPACE:
		activate_dash()
	elif mode == "play" and event.physical_keycode == KEY_Q:
		if state.activate_breeze():
			burst(player,Color("b9e1d9"),24)
			notify("Meadow Breeze! Bees slow down for a moment.")
			tone(540,0.2)

func notify(text: String) -> void:
	message = text
	message_time = 3.5

func burst(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		particles.append({"pos":pos,"vel":Vector2.from_angle(randf()*TAU)*randf_range(25,100),"life":randf_range(0.3,0.8),"color":color})

func box(rect: Rect2,color: Color,radius: int=12,border: Color=Color.TRANSPARENT) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	draw_style_box(style,rect)

func text_at(value: String,pos: Vector2,size: int=18,color: Color=CREAM) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func art(id: String,pos: Vector2,size: Vector2,flip: bool=false,tint: Color=Color.WHITE) -> void:
	draw_set_transform(pos,0,Vector2(-1 if flip else 1,1))
	draw_texture_rect(textures[id],Rect2(-size/2,size),false,tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),Color("192e2b"))
	# A framed meadow with a dedicated HUD and footer.
	box(Rect2(32,136,1216,584),Color("546e58"),20)
	box(Rect2(42,146,1196,564),Color("a5bd8c"),16)
	var rng = RandomNumberGenerator.new()
	rng.seed = 829+state.level
	for i in 410:
		var p = Vector2(rng.randf_range(54,1224),rng.randf_range(156,701))
		draw_line(p,p+Vector2(0,-3),Color("91aa7e"),2)
		if i%5==0:
			draw_circle(p,1.6,Color("c5d1a8"))
	box(BASE,Color("bacb9f"),12)
	draw_line(Vector2(310,170),Vector2(310,690),Color("d8dfb8"),2)
	text_at("THE HOMESTEAD",Vector2(83,185),16,INK)
	# Footpaths connect the base to the meadow's central crossing.
	draw_line(Vector2(300,419),Vector2(1198,419),Color("c7c6a0"),40)
	draw_line(Vector2(704,180),Vector2(704,675),Color("c7c6a0"),32)
	for f in flowers:
		draw_flower(f)
	for b in bees:
		var path: Array = b.path
		for i in path.size():
			draw_dashed_line(path[i],path[(i+1)%path.size()],Color(0.25,0.38,0.22,0.28),1,5)
	for w in walls:
		draw_shrub(w)
	draw_circle(CRATE,66,Color(0.92,0.89,0.57,0.35))
	art("crate",CRATE-Vector2(0,20),Vector2(95,110))
	text_at("POLLEN DEPOT",CRATE+Vector2(-64,67),16,INK)
	text_at("Walk here to bank",CRATE+Vector2(-70,86),14,INK)
	art("shop",SHOP-Vector2(0,20),Vector2(127,123))
	box(Rect2(106,554,104,16),Color("684126"),0)
	text_at("HIVE SHOP",Vector2(118,567),12,CREAM)
	text_at("[ E ]  Hive Shop",SHOP+Vector2(-69,65),18,INK)
	for b in bees:
		draw_bee(b)
	if state.breeze_time>0:
		for i in 6:
			var x = 330+fmod(clock*70+i*161,870)
			var y = 215+i*68
			draw_arc(Vector2(x,y),32,0.2,1.3,12,Color(0.79,0.94,0.89,0.65),2,true)
	if "Magnet" in state.equipped:
		draw_arc(player,state.collection_radius(),0,TAU,60,Color(0.75,0.65,0.88,0.28),1.3,true)
	for ghost in dash_trail:
		art("alpaca",ghost.pos-Vector2(0,12),Vector2(53,66),dash_direction.x>0,Color(0.8,0.9,1,ghost.life*1.5))
	draw_set_transform(player+Vector2(0,18),0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,24,Color(0.1,0.2,0.1,0.25))
	draw_set_transform(Vector2.ZERO)
	if "Shield" in state.equipped and state.shield:
		draw_arc(player,34,0,TAU,48,Color("c7eced"),2,true)
	if invincible <= 0 or int(invincible*14)%2 == 0:
		var bob = sin(clock*16)*2 if moving and mode=="play" else sin(clock*3)*1.2
		var jitter = Vector2(sin(clock*90)*2,0) if invincible>1 and shake else Vector2.ZERO
		art("alpaca",player+Vector2(0,-12+bob)+jitter,Vector2(53,66),facing.x>0)
		if state.pollen > 0:
			box(Rect2(player+Vector2(5,0),Vector2(15,16)),Color("bd874b"),3)
			draw_circle(player+Vector2(13,0),5,GOLD)
	for p in particles:
		draw_circle(p.pos,3,Color(p.color,clampf(p.life*2,0,1)))
	if state.pollen >= state.capacity():
		var arrow = player.direction_to(CRATE)
		draw_line(player+arrow*42,player+arrow*62,GOLD,4)
		draw_circle(player+arrow*64,5,GOLD)
	draw_hud()
	if not state.save_error.is_empty():
		box(Rect2(338,610,640,38),Color("723b3b"),8)
		text_at(state.save_error,Vector2(350,636),16,CREAM)
	if message_time>0 and mode == "play":
		box(Rect2(340,654,620,39),INK,10)
		text_at(message,Vector2(360,680),17,CREAM)
	if mode == "play" and player.distance_to(SHOP)<110:
		box(Rect2(72,466,192,35),INK,8)
		text_at("E  •  Browse upgrades",Vector2(86,490),16,GOLD)

func draw_flower(f: Dictionary) -> void:
	var pos: Vector2 = f.pos
	if f.left <= 0:
		draw_line(pos,pos+Vector2(0,9),Color("67865c"),2)
		draw_circle(pos,4,Color("78945f"))
		draw_arc(pos,7,-PI/2,-PI/2+TAU*(1-f.timer/8.0),16,Color("b7cf8c"),2)
		return
	var color = Color("fff0be") if f.max == 1 else (Color("d6b2d5") if f.max == 2 else Color("f6cb62"))
	draw_line(pos,pos+Vector2(0,11),Color("4b7948"),3)
	for k in 5:
		draw_circle(pos+Vector2.from_angle(k*TAU/5+sin(clock*2+pos.x)*0.1)*7,5,color)
	draw_circle(pos,4,Color("946133"))
	if f.max == 5:
		draw_circle(pos,2,CREAM)

func draw_hud() -> void:
	text_at("FLUFF & POLLEN",Vector2(43,49),29,CREAM)
	text_at("A little alpaca. One more trip.",Vector2(44,77),15,Color("a9c3ad"))
	text_at("0%d  /  %s" % [state.level+1,LEVEL_NAMES[state.level]],Vector2(43,115),18,GOLD)
	box(Rect2(476,24,227,89),Color("2c4841"),12)
	art("pollen",Vector2(505,54),Vector2(27,27))
	text_at("POLLEN",Vector2(529,49),13,Color("b9cebb"))
	text_at("%d / %d" % [state.pollen,state.capacity()],Vector2(529,76),25)
	box(Rect2(493,93,192,5),Color("40584a"),2)
	box(Rect2(493,93,192*float(state.pollen)/state.capacity(),5),GOLD,2)
	box(Rect2(715,24,169,89),Color("2c4841"),12)
	text_at("BANKED COINS",Vector2(734,49),13,Color("b9cebb"))
	text_at(str(state.coins),Vector2(734,84),30,GOLD)
	box(Rect2(896,24,342,89),Color("2c4841"),12)
	text_at("MEADOW DELIVERY GOAL",Vector2(915,49),13,Color("b9cebb"))
	text_at("%d / %d" % [state.delivered,state.QUOTAS[state.level]],Vector2(915,77),24)
	box(Rect2(915,93,303,5),Color("40584a"),2)
	box(Rect2(915,93,303*minf(1,float(state.delivered)/state.QUOTAS[state.level]),5),Color("a8d5a2"),2)
	text_at("WASD  Move   SPACE  Dash   Q  Breeze   E  Shop   Esc  Pause",Vector2(44,756),14,Color("b9cebb"))
	text_at("Flowers regrow. Banked coins are always safe.",Vector2(44,781),14,Color("8ea792"))
	for i in 3:
		var x = 664+i*194
		box(Rect2(x,734,182,51),Color("2c4841"),9)
		if i<state.equipped.size():
			var id: String = state.equipped[i]
			draw_skill_icon(id,Vector2(x+27,759),28)
			text_at(id + (" II" if state.rank_of(id)==2 else ""),Vector2(x+50,755),16)
			var detail = "Equipped"
			if id=="Dash":
				detail = "SPACE • ready" if state.dash_cooldown<=0 else "%.1fs cooldown" % state.dash_cooldown
			elif id=="Breeze":
				detail = "Q • ready" if state.breeze_cooldown<=0 else "%.1fs cooldown" % state.breeze_cooldown
			elif id=="Lucky":
				detail = "%d / %d flowers" % [state.lucky_count,4 if state.rank_of("Lucky")==1 else 3]
			elif id=="Shield":
				detail = "Charged" if state.shield else "Deposit to refill"
			text_at(detail,Vector2(x+50,774),12,Color("b9cebb"))
		else:
			text_at("+  Empty skill slot",Vector2(x+16,765),15,Color("93ae98"))

func clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func label_on(parent: Node,value: String,pos: Vector2,size: int=22,color: Color=CREAM) -> Label:
	var label = Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func button_on(parent: Node,value: String,rect: Rect2,action: Callable,primary: bool=false) -> Button:
	var b = Button.new()
	b.text = value
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",18)
	for style_name in ["normal","hover","pressed","focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = GOLD if primary else Color("3f6052")
		if style_name=="hover":
			style.bg_color = style.bg_color.lightened(0.13)
		if style_name=="pressed":
			style.bg_color = style.bg_color.darkened(0.15)
		style.set_corner_radius_all(9)
		if style_name=="focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = CREAM
			style.set_border_width_all(2)
		b.add_theme_stylebox_override(style_name,style)
	b.add_theme_color_override("font_color",INK if primary else CREAM)
	b.add_theme_color_override("font_hover_color",INK if primary else CREAM)
	b.add_theme_color_override("font_pressed_color",INK if primary else CREAM)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func modal(title: String,subtitle: String,width: float=700,height: float=530) -> Panel:
	clear_ui()
	var shade = ColorRect.new()
	shade.color = Color(0.035,0.09,0.07,0.83)
	shade.size = Vector2(1280,800)
	ui.add_child(shade)
	var panel = Panel.new()
	panel.position = Vector2((1280-width)/2,(800-height)/2)
	panel.size = Vector2(width,height)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("243f38")
	style.border_color = Color("789276")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)
	label_on(panel,title,Vector2(32,25),32)
	label_on(panel,subtitle,Vector2(32,72),16,Color("b9cebb"))
	return panel

func show_title() -> void:
	mode = "title"
	var panel = modal("FLUFF & POLLEN","A little alpaca. A big meadow. One more trip.",730,565)
	var portrait = Sprite2D.new()
	portrait.texture = textures["alpaca"]
	portrait.position = Vector2(573,239)
	portrait.scale = Vector2(176,221)/portrait.texture.get_size()
	panel.add_child(portrait)
	label_on(panel,"GATHER. DODGE. DELIVER.",Vector2(34,133),19,GOLD)
	label_on(panel,"Carry pollen home through three lively meadows.\nDodge the bees. Build your perfect three-skill kit.\nRisk another flower — or keep your haul safe.",Vector2(34,175),17)
	button_on(panel,"New campaign",Rect2(34,279,345,48),confirm_new,true)
	var continue_button = button_on(panel,"Continue",Rect2(34,339,345,48),continue_game)
	continue_button.disabled = not FileAccess.file_exists(state.save_path)
	button_on(panel,"How to play",Rect2(34,399,345,44),show_help)
	button_on(panel,"Settings",Rect2(394,399,302,44),func(): show_settings("title"))
	label_on(panel,"Your artwork • An original meadow adventure",Vector2(34,486),16,Color("b9cebb"))
	label_on(panel,"v1.1  /  Meadow & Magic  /  Single player",Vector2(34,512),13,Color("8ea792"))

func confirm_new() -> void:
	mode = "confirm"
	if FileAccess.file_exists(state.save_path):
		var p = modal("Start a new adventure?","This replaces the saved campaign.",620,260)
		button_on(p,"Keep my save",Rect2(32,153,263,52),show_title)
		button_on(p,"New campaign",Rect2(310,153,277,52),start_new,true)
	else:
		start_new()

func start_new() -> void:
	campaign_active = true
	state = Campaign.new()
	state.save_game()
	build_level()
	resume()
	notify("Gather flowers, then walk to the pollen depot to bank them.")

func continue_game() -> void:
	if state.load_game():
		campaign_active = true
		build_level()
		if state.finished or state.delivered >= state.QUOTAS[state.level]:
			show_results()
		else:
			resume()
			notify("Welcome home! Your saved progress is ready.")
	else:
		var p = modal("Save could not be opened","Start a new campaign to play.",620,250)
		button_on(p,"Back",Rect2(32,150,555,50),show_title)

func resume() -> void:
	clear_ui()
	mode = "play"

func show_help() -> void:
	mode = "help"
	var p = modal("A meadow field guide","Small trips. Brave choices. Safe deliveries.",730,530)
	label_on(p,"01  GATHER",Vector2(32,121),20,GOLD)
	label_on(p,"Walk over flowers. Your bag starts with room for 10 pollen.",Vector2(32,154),17)
	label_on(p,"02  DODGE",Vector2(32,201),20,GOLD)
	label_on(p,"Bees follow dotted paths. A hit spills your current haul.\nDelivered coins and purchased skills are always safe.",Vector2(32,234),17)
	label_on(p,"03  DELIVER & GROW",Vector2(32,300),20,GOLD)
	label_on(p,"Return to the wooden depot. Visit the shop with E.\nEquip up to 3 skills. Meet the delivery goal to advance.",Vector2(32,333),17)
	label_on(p,"WASD: move   •   SPACE: Dash   •   Q: Breeze   •   Esc: pause",Vector2(32,402),17)
	button_on(p,"Ready for the meadow",Rect2(32,453,666,48),show_title,true)

func show_pause() -> void:
	mode = "pause"
	state.save_game()
	var p = modal("Take a breather","Your meadow is paused.",540,415)
	button_on(p,"Back to the meadow",Rect2(32,121,476,51),resume,true)
	button_on(p,"Settings",Rect2(32,190,476,51),func(): show_settings("pause"))
	button_on(p,"Save & return to title",Rect2(32,259,476,51),func(): state.save_game(); show_title())
	label_on(p,"Carried pollen is not saved. Bank it before leaving.",Vector2(32,346),15,Color("b9cebb"))

func shop_icon(parent: Node,id: String,pos: Vector2,size: float) -> void:
	if textures.has(id):
		var icon = Sprite2D.new()
		icon.texture = textures[id]
		icon.position = pos
		icon.scale = Vector2(size,size)/icon.texture.get_size()
		parent.add_child(icon)
	else:
		var icon = SkillIcon.new()
		icon.id = id
		icon.radius = size/2
		icon.position = pos
		parent.add_child(icon)

func show_shop() -> void:
	mode = "shop"
	var p = modal("THE HIVE ATELIER","Little upgrades. Bigger adventures.",1100,688)
	label_on(p,"%d" % state.coins,Vector2(920,24),34,GOLD)
	label_on(p,"BANKED COINS",Vector2(916,68),13,Color("b9cebb"))
	button_on(p,"Abilities",Rect2(32,112,257,38),func(): shop_tab="Abilities"; show_shop(),shop_tab=="Abilities")
	button_on(p,"Training / Level II",Rect2(301,112,257,38),func(): shop_tab="Training"; show_shop(),shop_tab=="Training")
	var index = 0
	for id in Catalog.ORDER:
		if shop_tab=="Training" and id not in state.owned: continue
		var data: Dictionary = Catalog.DATA[id]
		var x = 32+(index%2)*269
		var y = 164+(index/2)*85
		var selected: String = id
		var card = button_on(p,"",Rect2(x,y,257,76),func(): selected_skill=selected; shop_note=""; show_shop())
		if id==selected_skill:
			var style = card.get_theme_stylebox("normal").duplicate()
			style.border_color = GOLD
			style.set_border_width_all(2)
			card.add_theme_stylebox_override("normal",style)
		shop_icon(p,id,Vector2(x+32,y+37),40)
		label_on(p,data.name,Vector2(x+61,y+12),17,CREAM)
		var status = "%d coins" % data.price
		if id in state.owned:
			status = "Equipped" if id in state.equipped else "Owned"
			status += " / Lv.%d" % state.rank_of(id)
		if shop_tab=="Training": status = "Fully trained" if state.rank_of(id)==2 or data.upgrade==0 else "%d coins to train" % data.upgrade
		label_on(p,status,Vector2(x+61,y+42),13,Color("c7d5bd"))
		index += 1
	if index==0: label_on(p,"Buy an ability first.\nTraining makes owned skills stronger.",Vector2(43,192),18,Color("c7d5bd"))
	var data: Dictionary = Catalog.DATA[selected_skill]
	shop_icon(p,selected_skill,Vector2(654,190),60.0)
	label_on(p,data.type,Vector2(700,163),13,Color(data.color))
	label_on(p,data.name,Vector2(700,184),24,CREAM)
	label_on(p,"LEVEL %d / %s" % [state.rank_of(selected_skill),"OWNED" if selected_skill in state.owned else "AVAILABLE"],Vector2(616,236),14,GOLD)
	label_on(p,skill_description(selected_skill),Vector2(616,272),18,CREAM)
	label_on(p,"Level II mastered. Your training is permanent." if state.rank_of(selected_skill)==2 else data.next,Vector2(616,362),16,Color("b9cebb"))
	if selected_skill in state.owned:
		var is_equipped = selected_skill in state.equipped
		var equip = button_on(p,"Unequip" if is_equipped else "Equip ability",Rect2(616,409,450,46),func(): choose_skill(selected_skill),not is_equipped)
		equip.disabled = selected_skill=="Bag" and is_equipped and state.pollen>10
		if data.upgrade>0 and state.rank_of(selected_skill)<2:
			var train = button_on(p,"Train to Level II  /  %d coins" % data.upgrade,Rect2(616,466,450,46),func(): train_skill(selected_skill),true)
			train.disabled = state.coins<data.upgrade
		else: label_on(p,"Fully trained. Ready for the meadow.",Vector2(616,478),16,Color("b9cebb"))
	else:
		var buy = button_on(p,"Buy & equip  /  %d coins" % data.price,Rect2(616,409,450,51),func(): choose_skill(selected_skill),true)
		buy.disabled = state.coins<data.price
		if state.coins<data.price: label_on(p,"Deliver pollen for %d more coins." % (data.price-state.coins),Vector2(616,477),16,Color("b9cebb"))
		elif state.equipped.size()==3: label_on(p,"Choose a slot next. Nothing is spent yet.",Vector2(616,477),16,Color("b9cebb"))
	var note = shop_note
	if selected_skill=="Bag" and selected_skill in state.equipped and state.pollen>10: note = "Deposit pollen before removing your bag skill."
	if note.is_empty(): note = "All purchases are permanent. Swap owned abilities for free."
	label_on(p,note,Vector2(32,526),16,GOLD)
	label_on(p,"YOUR LOADOUT  /  %d OF 3 SLOTS" % state.equipped.size(),Vector2(32,570),13,Color("b9cebb"))
	for i in 3:
		var x = 32+i*205
		if i<state.equipped.size():
			var id: String = state.equipped[i]
			button_on(p,"%s  /  Lv.%d" % [id,state.rank_of(id)],Rect2(x,598,193,48),func(): selected_skill=id; show_shop())
		else:
			var empty = button_on(p,"Empty slot",Rect2(x,598,193,48),func(): pass)
			empty.disabled = true
	button_on(p,"Return to meadow  /  Esc",Rect2(722,587,344,59),resume,true)

func train_skill(id: String) -> void:
	if state.upgrade(id):
		shop_note = Catalog.DATA[id].name+" reached Level II!"
		tone(1100,0.16)
	show_shop()

func choose_skill(id: String) -> void:
	if id in state.equipped:
		state.unequip(id)
		shop_note = Catalog.DATA[id].name+" unequipped. You still own it."
		show_shop()
		return
	if state.equipped.size() == 3:
		pending_skill = id
		mode = "replace"
		var p = modal("Make room for " + id,"Choose one equipped skill to replace. You keep ownership.",660,410)
		for i in 3:
			var slot = i
			var b = button_on(p,"Replace " + str(state.equipped[i]),Rect2(32,120+i*61,596,50),func(): finish_purchase(pending_skill,slot))
			b.disabled = state.equipped[i]=="Bag" and state.pollen>10
		button_on(p,"Cancel — keep my loadout",Rect2(32,320,596,50),show_shop)
	else:
		finish_purchase(id)

func finish_purchase(id: String,slot: int=-1) -> void:
	if state.buy_and_equip(id,slot):
		shop_note = Catalog.DATA[id].name+" equipped!"
		tone(980,0.15)
	show_shop()

func show_results() -> void:
	mode = "results"
	if state.level == 2:
		state.finished = true
	state.save_game()
	var p = modal("A blooming success!" if state.finished else "Meadow complete!","Every safe delivery made a difference.",690,474)
	label_on(p,LEVEL_NAMES[state.level],Vector2(32,126),27,GOLD)
	label_on(p,"Pollen delivered: %d / %d\nBanked coins: %d\nBee encounters: %d\nMeadow time: %d:%02d" % [state.delivered,state.QUOTAS[state.level],state.coins,state.hits,int(state.elapsed)/60,int(state.elapsed)%60],Vector2(32,177),22)
	if state.finished:
		label_on(p,"All three meadows restored. Thanks for playing!",Vector2(32,333),18)
		button_on(p,"Return to title",Rect2(32,384,626,52),show_title,true)
	else:
		button_on(p,"Next meadow  →",Rect2(32,384,400,52),next_level,true)
		button_on(p,"Title",Rect2(448,384,210,52),show_title)

func next_level() -> void:
	state.level += 1
	state.delivered = 0
	state.pollen = 0
	state.hits = 0
	state.elapsed = 0
	state.dash_cooldown = 0
	state.breeze_cooldown = 0
	state.breeze_time = 0
	state.shield = "Shield" in state.equipped
	state.save_game()
	build_level()
	resume()
	notify("Welcome to " + LEVEL_NAMES[state.level] + ". Choose your route!")

func show_settings(return_to: String) -> void:
	settings_return = return_to
	mode = "settings"
	var p = modal("Meadow settings","Make yourself at home.",610,435)
	label_on(p,"Music",Vector2(32,122),21)
	label_on(p,"Sound effects",Vector2(32,189),21)
	for i in 2:
		var slider = HSlider.new()
		slider.position = Vector2(240,125+i*67)
		slider.size = Vector2(331,28)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = music_volume if i == 0 else effects_volume
		var kind = i
		slider.value_changed.connect(func(v):
			if kind == 0:
				music_volume = v
				music.volume_db = linear_to_db(v*0.18)
			else:
				effects_volume = v)
		p.add_child(slider)
	var toggle = CheckButton.new()
	toggle.text = "Hit shake"
	toggle.position = Vector2(32,258)
	toggle.button_pressed = shake
	toggle.add_theme_font_size_override("font_size",21)
	toggle.toggled.connect(func(v): shake = v)
	p.add_child(toggle)
	button_on(p,"Save settings",Rect2(32,344,546,51),func():
		save_settings()
		if return_to == "title": show_title()
		else: show_pause(),true)

func tone(frequency: float,duration: float) -> void:
	if effects_volume <= 0 or DisplayServer.get_name() == "headless":
		return
	var rate = 22050
	var bytes = PackedByteArray()
	bytes.resize(int(rate*duration)*2)
	for i in int(rate*duration):
		var t = float(i)/rate
		var envelope = minf(1,t*100)*pow(1-t/duration,2)
		var sample = sin(TAU*frequency*t)*envelope*12000
		bytes.encode_s16(i*2,int(sample))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	var audio = AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = linear_to_db(effects_volume*0.4)
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func setup_music() -> void:
	if DisplayServer.get_name() == "headless":
		music = AudioStreamPlayer.new()
		add_child(music)
		return
	var rate = 22050
	var duration = 16.0
	var bytes = PackedByteArray()
	bytes.resize(int(rate*duration)*2)
	var melody = [261.63,329.63,392.0,329.63,293.66,349.23,440.0,349.23,329.63,392.0,493.88,392.0,293.66,349.23,392.0,293.66]
	for i in int(rate*duration):
		var t = float(i)/rate
		var beat = fmod(t,1.0)
		var frequency: float = melody[int(t)%melody.size()]
		var envelope = sin(PI*beat)*exp(-beat*3)
		var sample = (sin(TAU*frequency*t)+0.3*sin(TAU*frequency*2*t))*envelope
		bytes.encode_s16(i*2,int(sample*10000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(rate*duration)
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = linear_to_db(music_volume*0.18)
	add_child(music)
	music.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if campaign_active and mode != "title":
			state.save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play":
		show_pause()

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null

func activate_dash() -> bool:
	if "Dash" not in state.equipped or state.dash_cooldown>0 or knock.length()>1:
		return false
	dash_time = 0.18
	dash_direction = facing
	state.dash_cooldown = state.dash_delay()
	trail_timer = 0
	tone(420,0.08)
	return true

func clear_collection_line(a: Vector2,b: Vector2) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/4.0))
	for i in range(steps+1):
		var point = a.lerp(b,float(i)/steps)
		for w in walls:
			if w.has_point(point): return false
	return true

func update_bee(b: Dictionary,delta: float) -> void:
	var target: Vector2 = b.path[b.target]
	var length: float = b.from.distance_to(target)
	var factor = 0.45 if state.breeze_time>0 else 1.0
	b.progress = minf(1.0,b.progress+delta*b.speed*factor/maxf(length,1))
	var t: float = b.progress
	var old: Vector2 = b.pos
	b.pos = b.from.lerp(target,t*t*(3.0-2.0*t))
	if b.pos.distance_to(old)>0.00001: b.dir = (b.pos-old).normalized()
	var desired_flip = -1.0 if b.dir.x < -0.05 else (1.0 if b.dir.x>0.05 else b.flip)
	b.flip = lerpf(b.flip,desired_flip,1.0-exp(-10.0*delta))
	b.tilt = lerp_angle(b.tilt,b.dir.y*0.12,1.0-exp(-7.0*delta))
	if t>=1:
		b.from = target
		b.target = (b.target+1)%b.path.size()
		b.progress = 0.0

func draw_bee(b: Dictionary) -> void:
	var phase: float = clock*TAU*7+b.phase
	var lift = sin(clock*3.8+b.phase)*2.3
	draw_set_transform(b.pos+Vector2(0,15),0,Vector2(1,0.30))
	draw_circle(Vector2.ZERO,18,Color(0.12,0.2,0.1,0.15))
	var sx = (-1.0 if b.flip<0 else 1.0)*maxf(0.15,absf(b.flip))
	draw_set_transform(b.pos+Vector2(0,lift),b.tilt,Vector2(sx,1))
	var wing_h = 18.0*(0.40+0.60*(0.5+0.5*sin(phase)))
	draw_texture_rect(textures["bee_wings"],Rect2(-23.5,-5.0-wing_h,47,wing_h),false,Color(1,1,1,0.92))
	draw_texture_rect(textures["bee_body"],Rect2(-23.5,-5.3,47,28),false)
	draw_set_transform(Vector2.ZERO)
	if state.breeze_time>0: draw_arc(b.pos,29,-0.7,0.9,20,Color("c9eee4"),2,true)

func draw_shrub(w: Rect2) -> void:
	box(Rect2(w.position+Vector2(0,7),w.size),Color(0.19,0.29,0.20,0.18),16)
	box(w,Color("557e62"),16,Color("496c53"))
	var vertical = w.size.y>w.size.x
	var count = maxi(2,int(maxf(w.size.x,w.size.y)/23))
	for i in count:
		var t = float(i+0.5)/count
		var pos = Vector2(w.position.x+20,w.position.y+w.size.y*t) if vertical else Vector2(w.position.x+w.size.x*t,w.position.y+21)
		draw_circle(pos,18,Color("6e956c"))
		draw_circle(pos+Vector2(-3,-6),12,Color("87aa78"))
		draw_circle(pos+Vector2(5,-4),5,Color("a0bc8c"))
		if i%2==0:
			for j in 4: draw_circle(pos+Vector2(5,3)+Vector2.from_angle(j*PI/2)*3.1,2.6,Color("cdbbd4"))
			draw_circle(pos+Vector2(5,3),1.6,GOLD)

func draw_skill_icon(id: String,pos: Vector2,size: float) -> void:
	if textures.has(id):
		art(id,pos,Vector2(size,size))
	else:
		draw_circle(pos,size*0.48,Color(Catalog.DATA[id].color))
		text_at(Catalog.DATA[id].symbol,pos+Vector2(-size*0.2,size*0.23),int(size*0.6),INK)

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio","music",music_volume)
	cfg.set_value("audio","effects",effects_volume)
	cfg.set_value("visual","shake",shake)
	cfg.save("user://settings.cfg")

func skill_description(id: String) -> String:
	var description: String = Catalog.DATA[id].description
	if state.rank_of(id)==2:
		match id:
			"Speed": description = description.replace("15%","25%")
			"Bag": description = description.replace("15 pollen","20 pollen")
			"Dash": description = description.replace("5s cooldown","3.5s cooldown")
			"Magnet": description = description.replace("58 units","78 units")
			"Breeze": description = description.replace("4 seconds","6 seconds")
			"Lucky": description = description.replace("Every 4","Every 3")
	return description
