extends SceneTree
var checks = 0
var failures = 0
func check(value: bool,reason: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL: "+reason)
		failures += 1
		return
	print("PASS: "+reason)
func _initialize() -> void:
	call_deferred("run")
func write_json(path: String,data) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run() -> void:
	var C = load("res://scripts/campaign.gd")
	var c = C.new()
	c.save_path = "user://upgrade_test.json"
	c.coins = 1000
	check(c.collect(-5)==0 and c.pollen==0,"negative collection rejected")
	check(c.buy_and_equip("Speed"),"buy initial speed")
	check(c.upgrade("Speed") and c.speed()==200,"rank II speed")
	var coins_before = c.coins
	check(not c.upgrade("Speed") and c.coins==coins_before,"no repeated upgrade charge")
	check(c.buy_and_equip("Bag") and c.upgrade("Bag") and c.capacity()==20,"rank II capacity")
	c.collect(17)
	check(not c.unequip("Bag"),"rank II bag cannot silently discard pollen")
	c.deposit()
	check(c.buy_and_equip("Dash") and c.upgrade("Dash") and c.dash_delay()==3.5,"rank II dash cooldown")
	c.dash_cooldown = 2.0
	check(c.buy_and_equip("Breeze",2),"breeze replaces dash")
	check(c.activate_breeze() and c.breeze_time==4 and c.breeze_cooldown==12,"breeze activation")
	check(not c.activate_breeze(),"breeze cannot be spammed")
	check(c.upgrade("Breeze") and c.breeze_cooldown==12 and c.breeze_time==4,"training does not reset running power")
	c.tick(4)
	check(c.breeze_time==0 and c.breeze_cooldown==8,"breeze duration and cooldown tick independently")
	c.unequip("Breeze")
	c.buy_and_equip("Breeze")
	check(c.breeze_cooldown==8,"unequip cannot bypass breeze cooldown")
	c.tick(8)
	check(c.activate_breeze() and c.breeze_time==6,"rank II breeze lasts 6 seconds")
	c.save_game()
	var restored = C.new()
	restored.save_path = c.save_path
	check(restored.load_game() and restored.ranks==c.ranks and restored.breeze_time==6 and restored.breeze_cooldown==12,"new power state and ranks persist")
	write_json(c.save_path,{"version":1,"coins":83,"level":1,"delivered":21,"owned":["Speed","Bag"],"equipped":["Bag"],"shield":false})
	check(restored.load_game() and restored.coins==83 and restored.rank_of("Bag")==1 and restored.capacity()==15,"v1 saves migrate without losing progress")
	check(restored.save_game() and FileAccess.file_exists(c.save_path+".v1-backup"),"old-format save backed up")
	write_json(c.save_path,{"version":2,"coins":"invalid"})
	check(not restored.load_game() and restored.coins==83,"malformed save rejected without mutating progress")
	write_json(c.save_path,{"version":2,"owned":null})
	check(not restored.load_game(),"malformed inventory rejected")
	var bad = C.new()
	bad.save_path = "user://missing_directory_for_test/save.json"
	check(not bad.save_game() and not bad.save_error.is_empty(),"save failure reported")
	c.equipped = ["Magnet","Lucky"]
	c.owned = ["Magnet","Lucky"]
	c.ranks = {}
	c.pollen = 0
	c.lucky_count = 0
	check(c.collection_radius()==58,"magnet collection range")
	check(c.flower_completed()==0 and c.flower_completed()==0 and c.flower_completed()==0 and c.flower_completed()==2,"fourth-flower reward")
	c.pollen = 9
	c.lucky_count = 3
	check(c.flower_completed()==1 and c.pollen==10,"bonus respects capacity")
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.state = c
	scene.walls.clear()
	scene.walls.append(Rect2(470,280,20,60))
	check(not scene.clear_collection_line(Vector2(440,310),Vector2(500,310)),"magnet blocked by shrub")
	check(scene.clear_collection_line(Vector2(440,360),Vector2(500,360)),"magnet works along open route")
	scene.build_level()
	var b = scene.bees[0].duplicate(true)
	var slowed = b.duplicate(true)
	c.breeze_time = 0
	scene.update_bee(b,1)
	c.breeze_time = 4
	scene.update_bee(slowed,1)
	check(slowed.progress < b.progress and is_equal_approx(slowed.progress/b.progress,0.45),"actual patrol slowdown")
	c.equipped = ["Dash"]
	c.ranks = {}
	c.pollen = 0
	scene.bees.clear()
	scene.flowers.clear()
	scene.walls.clear()
	scene.mode = "play"
	scene.player = Vector2(500,400)
	scene.facing = Vector2.RIGHT
	c.dash_cooldown = 0
	scene.activate_dash()
	scene._process(0.25)
	var low_fps = scene.player.x
	scene.player = Vector2(500,400)
	c.dash_cooldown = 0
	scene.activate_dash()
	for i in 30: scene._process(1.0/120.0)
	check(absf(low_fps-scene.player.x)<0.1 and absf(low_fps-572)<0.1,"dash distance identical across frame rates")
	scene.build_level()
	scene.flowers.clear()
	scene.walls.clear()
	scene.player = Vector2(400,400)
	scene.bees = [{"path":[Vector2(430,400),Vector2(440,400)],"pos":Vector2(430,400),"from":Vector2(430,400),"target":1,"speed":0.0,"progress":0.0,"dir":Vector2.RIGHT,"phase":0.0,"flip":1.0,"tilt":0.0}]
	c.pollen = 5
	c.hits = 0
	c.dash_cooldown = 0
	scene.activate_dash()
	scene._process(0.25)
	check(c.pollen==0 and c.hits==1,"low FPS dash cannot tunnel through bee or chain-hit")
	c.breeze_cooldown = 7
	c.breeze_time = 3
	scene.show_shop()
	scene._process(0.25)
	check(c.breeze_cooldown==7 and c.breeze_time==3,"shop freezes power timers")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene.show_settings("pause")
	scene._unhandled_key_input(escape)
	check(scene.mode=="pause","Escape exits settings")
	scene.show_help()
	scene._unhandled_key_input(escape)
	check(scene.mode=="title","Escape exits instructions")
	c.coins = 1000
	c.owned = []
	c.equipped = []
	c.ranks = {}
	c.pollen = 0
	scene.shop_tab = "Abilities"
	scene.show_shop()
	var panel = scene.ui.get_child(scene.ui.get_child_count()-1)
	var cards: Array = []
	for child in panel.get_children():
		if child is Button and child.text=="": cards.append(child)
	check(cards.size()==7,"seven ability cards visible")
	cards[4].pressed.emit()
	check(scene.selected_skill=="Magnet","card selects correct ability")
	panel = scene.ui.get_child(scene.ui.get_child_count()-1)
	for child in panel.get_children():
		if child is Button and child.text.begins_with("Buy & equip"):
			child.pressed.emit()
			break
	check("Magnet" in c.equipped and c.coins==930,"shop button charges correct price")
	panel = scene.ui.get_child(scene.ui.get_child_count()-1)
	for child in panel.get_children():
		if child is Button and child.text.begins_with("Train to"):
			child.pressed.emit()
			break
	check(c.rank_of("Magnet")==2 and c.coins==860,"training button applies upgrade once")
	check("78 units" in scene.skill_description("Magnet"),"description reflects upgraded stats")
	DirAccess.remove_absolute(c.save_path)
	DirAccess.remove_absolute(c.save_path+".v1-backup")
	print("%d upgrade checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
