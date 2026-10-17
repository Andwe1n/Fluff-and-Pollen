extends Node2D
var id: String = "Magnet"
var radius: float = 22
const COLORS = {"Magnet":"bcb4dc","Breeze":"a7d4c8","Lucky":"d8baec"}
func _draw() -> void:
	var color = Color(COLORS.get(id,"dfbf7b"))
	draw_circle(Vector2.ZERO,radius,Color("243f38"))
	if id=="Magnet":
		draw_arc(Vector2(0,-radius*0.18),radius*0.51,0,PI,24,color,6,true)
		for x in [-1,1]:
			draw_line(Vector2(x*radius*0.51,-radius*0.18),Vector2(x*radius*0.51,-radius*0.62),color,6,true)
	elif id=="Breeze":
		for i in 3:
			var y = (i-1)*radius*0.45
			draw_line(Vector2(-radius*0.6,y),Vector2(radius*0.3,y),color,2.5,true)
			draw_arc(Vector2(radius*0.3,y-radius*0.15),radius*0.15,-PI/2,PI/2,12,color,2.5,true)
	elif id=="Lucky":
		for i in 4:
			draw_circle(Vector2.from_angle(i*PI/2+PI/4)*radius*0.35,radius*0.32,color)
		draw_circle(Vector2.ZERO,radius*0.15,Color("f6cf67"))
