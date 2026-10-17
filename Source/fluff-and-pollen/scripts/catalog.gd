extends RefCounted
const ORDER = ["Speed","Bag","Dash","Shield","Magnet","Breeze","Lucky"]
const DATA = {
"Speed":{"name":"Swift Steps","type":"PASSIVE / MOVEMENT","price":40,"upgrade":55,"color":"edaaab","symbol":"S","description":"Move 15% faster.\nShorter trips, easier crossings.","next":"Level II: +25% movement speed."},
"Bag":{"name":"Roomy Satchel","type":"PASSIVE / CAPACITY","price":60,"upgrade":70,"color":"dfbf7b","symbol":"B","description":"Carry 15 pollen instead of 10.\nA bigger haul needs a safer route.","next":"Level II: carry up to 20 pollen."},
"Dash":{"name":"Petal Dash","type":"ACTIVE / SPACE","price":50,"upgrade":65,"color":"b5cce3","symbol":"D","description":"Dash forward with SPACE.\n5s cooldown. Walls still block you.\nDoes not grant invincibility.","next":"Level II: cooldown drops to 3.5s."},
"Shield":{"name":"Honey Guard","type":"PASSIVE / DEFENSE","price":60,"upgrade":0,"color":"e6ce82","symbol":"H","description":"Protect your haul from one hit.\nDeliver pollen to recharge.\nSwapping skills never refills it.","next":"Fully trained. One reliable shield."},
"Magnet":{"name":"Pollen Magnet","type":"PASSIVE / COLLECTION","price":70,"upgrade":70,"color":"bcb4dc","symbol":"M","description":"Gather flowers from 58 units away.\nCannot pull pollen through bushes.\nStill respects bag capacity.","next":"Level II: collection radius 78."},
"Breeze":{"name":"Meadow Breeze","type":"ACTIVE / Q","price":90,"upgrade":80,"color":"a7d4c8","symbol":"~","description":"Press Q to slow all bees by 55%\nfor 4 seconds. 12s cooldown.\nA breathing space for tricky trips.","next":"Level II: breeze lasts 6 seconds."},
"Lucky":{"name":"Lucky Bloom","type":"PASSIVE / BONUS POLLEN","price":80,"upgrade":75,"color":"d8baec","symbol":"+","description":"Every 4 fully harvested flowers\nadds up to 2 bonus pollen.\nExtra pollen needs space in your bag.","next":"Level II: bonus every 3 flowers."}}
