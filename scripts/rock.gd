extends MeshInstance3D

signal landed(pos: Vector3, radius: float, dmg: float)

var from := Vector3.ZERO
var to := Vector3.ZERO
var radius := 2.6
var dmg := 22.0
var dur := 0.8
var _t := 0.0


func arc(p_from: Vector3, p_to: Vector3, p_dmg: float, p_radius: float) -> void:
	from = p_from
	to = p_to
	dmg = p_dmg
	radius = p_radius
	global_position = p_from


func _process(delta: float) -> void:
	_t += delta
	var u := _t / dur
	if u >= 1.0:
		landed.emit(to, radius, dmg)
		queue_free()
		return
	var p := from.lerp(to, u)
	p.y += sin(u * PI) * 4.0
	global_position = p
