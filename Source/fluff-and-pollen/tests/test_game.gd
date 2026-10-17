extends SceneTree
var failures: int = 0
var checks: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL: " + description)
		failures += 1
		return
	print("PASS: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var C = load("res://scripts/campaign.gd")
	var c = C.new()
	c.save_path = "user://test_campaign.json"
	check(c.collect(9)==9,"initial collection")
	check(c.collect(5)==1 and c.pollen==10,"partial flower respects capacity")
	check(c.collect(1)==0,"full bag rejects collection")
	check(c.deposit()==10 and c.coins==20 and c.delivered==10,"atomic delivery")
	check(c.deposit()==0 and c.coins==20,"no repeated reward")
	check(not c.buy_and_equip("Speed") and c.coins==20,"insufficient funds")
	c.coins = 250
	check(c.buy_and_equip("Speed") and c.speed()==184,"speed purchase")
	check(not c.buy_and_equip("Speed") and c.coins==210,"duplicate blocked")
	check(c.buy_and_equip("Bag") and c.capacity()==15,"bag purchase")
	check(c.buy_and_equip("Shield") and c.shield,"new shield charged")
	check(not c.buy_and_equip("Dash") and c.coins==90,"fourth skill requires replacement")
	c.pollen = 15
	check(not c.buy_and_equip("Dash",1),"bag capacity loss blocked")
	check(c.hit() and c.pollen==15 and not c.shield,"shield protects haul once")
	check(not c.hit() and c.pollen==0 and c.coins==90,"unprotected hit spills only pollen")
	check(c.deposit()==0 and not c.shield,"empty deposit cannot charge shield")
	c.collect(1)
	c.deposit()
	check(c.shield,"nonempty delivery charges shield")
	c.shield = false
	check(c.buy_and_equip("Dash",2),"fourth skill replacement")
	c.dash_cooldown = 3.0
	check(c.buy_and_equip("Shield",2) and not c.shield,"reequip cannot recharge shield")
	check(c.buy_and_equip("Dash",2) and c.dash_cooldown==3.0,"reequip preserves dash cooldown")
	check(c.unequip("Dash") and "Dash" not in c.equipped,"unequip retains ownership")
	check(c.buy_and_equip("Dash") and c.dash_cooldown==3.0,"free re-equip retains cooldown")
	var coins_before = c.coins
	c.save_game()
	var restored = C.new()
	restored.save_path = c.save_path
	check(restored.load_game(),"save reload")
	check(restored.coins==coins_before and restored.equipped==c.equipped and restored.dash_cooldown==3,"persistent state preserved")
	check(restored.pollen==0 and restored.delivered==11,"banked quota independent of spending")
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.state = c
	for level in 3:
		c.level = level
		c.delivered = 0
		scene.build_level()
		check(scene.bees.size()==2+level*2,"level %d bee count" % level)
		for b in scene.bees:
			for k in b.path.size():
				var a: Vector2 = b.path[k]
				var z: Vector2 = b.path[(k+1)%b.path.size()]
				for s in 21:
					var pos = a.lerp(z,float(s)/20)
					for w in scene.walls:
						check(not w.has_point(pos),"patrol stays out of hedge")
		for f in scene.flowers:
			check(scene.walkable(f.pos),"flower reachable")
		var w: Rect2 = scene.walls[0]
		scene.player = Vector2(w.position.x-30,w.get_center().y)
		scene.move_player(Vector2(120,0))
		check(scene.player.x < w.position.x,"dash cannot tunnel through hedge")
		# Full campaign transition through actual delivery callback.
		scene.player = scene.CRATE
		c.delivered = c.QUOTAS[level]-1
		c.pollen = 1
		scene.mode = "play"
		scene._process(0.016)
		check(scene.mode=="results","quota opens results")
		if level==2:
			check(c.finished,"final level ends campaign")
	# Pause/shop must freeze gameplay and skill timers.
	c.dash_cooldown = 4
	scene.mode = "shop"
	var pos_before: Vector2 = scene.player
	scene._process(2)
	check(c.dash_cooldown==4 and scene.player==pos_before,"shop pauses simulation")
	scene.show_shop()
	scene.choose_skill("Shield")
	check(scene.mode=="replace","three slots open replacement dialog")
	scene.show_settings("pause")
	scene.show_help()
	scene.show_pause()
	scene.show_title()
	DirAccess.remove_absolute(c.save_path)
	print("%d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
