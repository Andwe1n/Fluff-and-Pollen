extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const PRICES = {"Speed":40,"Bag":60,"Dash":50,"Shield":60,"Magnet":70,"Breeze":90,"Lucky":80}
const QUOTAS = [60, 100, 150]
var coins: int = 0
var pollen: int = 0
var delivered: int = 0
var level: int = 0
var owned: Array = []
var equipped: Array = []
var ranks: Dictionary = {}
var breeze_time: float = 0.0
var breeze_cooldown: float = 0.0
var lucky_count: int = 0
var save_error: String = ""
var shield: bool = false
var dash_cooldown: float = 0.0
var finished: bool = false
var hits: int = 0
var elapsed: float = 0.0
var save_path: String = "user://campaign.json"

func capacity() -> int:
	return 10+5*rank_of("Bag") if "Bag" in equipped else 10

func speed() -> float:
	return (184.0 if rank_of("Speed")==1 else 200.0) if "Speed" in equipped else 160.0

func collect(amount: int) -> int:
	var taken: int = mini(maxi(0,amount),maxi(0,capacity()-pollen))
	pollen += taken
	return taken

func deposit() -> int:
	var amount: int = pollen
	if amount <= 0:
		return 0
	coins += amount * 2
	delivered += amount
	pollen = 0
	if "Shield" in equipped:
		shield = true
	save_game()
	return amount

func buy_and_equip(id: String, replace_slot: int = -1) -> bool:
	if not PRICES.has(id) or id in equipped:
		return false
	if id not in owned and coins < PRICES[id]:
		return false
	if equipped.size() >= 3 and (replace_slot < 0 or replace_slot >= 3):
		return false
	if replace_slot >= 0 and replace_slot < equipped.size():
		if equipped[replace_slot] == "Bag" and pollen > 10:
			return false
	if id not in owned:
		coins -= PRICES[id]
		owned.append(id)
		ranks[id] = 1
		if id == "Shield":
			shield = true
	if equipped.size() < 3:
		equipped.append(id)
	else:
		equipped[replace_slot] = id
	save_game()
	return true

func hit() -> bool:
	hits += 1
	if "Shield" in equipped and shield:
		shield = false
		save_game()
		return true
	pollen = 0
	save_game()
	return false

func save_game() -> bool:
	var data = {"version":2,"coins":coins,"delivered":delivered,"level":level,
		"owned":owned,"equipped":equipped,"ranks":ranks,"shield":shield,"dash_cooldown":dash_cooldown,
		"breeze_cooldown":breeze_cooldown,"breeze_time":breeze_time,"lucky_count":lucky_count,
		"finished":finished,"hits":hits,"elapsed":elapsed}
	if FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".v1-backup"):
		var previous = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if previous is Dictionary and previous.get("version",0)==1:
			if DirAccess.copy_absolute(save_path,save_path+".v1-backup") != OK:
				save_error = "Could not back up the previous save. Progress not written."
				return false
	var file = FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null:
		save_error = "Could not write save. Check available storage."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		save_error = "Save write failed. Your previous save is unchanged."
		return false
	if DirAccess.rename_absolute(save_path+".tmp",save_path) != OK:
		save_error = "Could not commit save. Your previous save is unchanged."
		return false
	save_error = ""
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or (data.get("version",0)!=1 and data.get("version",0)!=2):
		return false
	for key in ["coins","level","delivered","dash_cooldown","hits","elapsed","breeze_cooldown","breeze_time","lucky_count"]:
		var value = data.get(key,0)
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	if not data.get("owned",[]) is Array or not data.get("equipped",[]) is Array or not data.get("ranks",{}) is Dictionary:
		return false
	coins = clampi(int(data.get("coins",0)),0,9999999)
	level = clampi(int(data.get("level",0)),0,2)
	delivered = clampi(int(data.get("delivered",0)),0,999999)
	owned = []
	equipped = []
	ranks = {}
	for id in data.get("owned",[]):
		if id is String and PRICES.has(id) and id not in owned:
			owned.append(id)
			var rank_value = data.get("ranks",{}).get(id,1)
			ranks[id] = clampi(int(rank_value),1,2) if (rank_value is float or rank_value is int) else 1
	for id in data.get("equipped",[]):
		if id in owned and id not in equipped and equipped.size()<3:
			equipped.append(id)
	shield = data.get("shield",false)==true
	dash_cooldown = clampf(float(data.get("dash_cooldown",0)),0,5)
	breeze_cooldown = clampf(float(data.get("breeze_cooldown",0)),0,12)
	breeze_time = clampf(float(data.get("breeze_time",0)),0,6)
	lucky_count = clampi(int(data.get("lucky_count",0)),0,3)
	finished = data.get("finished",false)==true and level==2 and delivered>=QUOTAS[2]
	hits = maxi(0,int(data.get("hits",0)))
	elapsed = maxf(0,float(data.get("elapsed",0)))
	pollen = 0
	save_error = ""
	return true

func unequip(id: String) -> bool:
	if id not in equipped or (id == "Bag" and pollen > 10):
		return false
	equipped.erase(id)
	save_game()
	return true

func rank_of(id: String) -> int:
	return clampi(int(ranks.get(id,1)),1,2)

func dash_delay() -> float:
	return 5.0 if rank_of("Dash")==1 else 3.5

func collection_radius() -> float:
	return (58.0 if rank_of("Magnet")==1 else 78.0) if "Magnet" in equipped else 23.0

func flower_completed() -> int:
	if "Lucky" not in equipped: return 0
	lucky_count += 1
	if lucky_count >= (4 if rank_of("Lucky")==1 else 3):
		lucky_count = 0
		return collect(2)
	return 0

func upgrade(id: String) -> bool:
	if id not in owned or rank_of(id)>=2: return false
	var cost: int = Catalog.DATA[id].upgrade
	if cost<=0 or coins<cost: return false
	coins -= cost
	ranks[id] = 2
	save_game()
	return true

func activate_breeze() -> bool:
	if "Breeze" not in equipped or breeze_cooldown>0: return false
	breeze_time = 4.0 if rank_of("Breeze")==1 else 6.0
	breeze_cooldown = 12.0
	return true

func tick(delta: float) -> void:
	dash_cooldown = maxf(0,dash_cooldown-delta)
	breeze_cooldown = maxf(0,breeze_cooldown-delta)
	breeze_time = maxf(0,breeze_time-delta)
