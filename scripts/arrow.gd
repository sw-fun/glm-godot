extends MeshInstance3D

signal struck(target: Node3D, dmg: float)

var target: Node3D
var dmg := 8.0
var speed := 22.0


func launch(p_target: Node3D, p_dmg: float) -> void:
	target = p_target
	dmg = p_dmg


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var to: Vector3 = target.global_position + Vector3(0, 0.6, 0) - global_position
	var d := to.length()
	var step := speed * delta
	if d <= step:
		struck.emit(target, dmg)
		queue_free()
		return
	look_at(global_position + to, Vector3.UP)
	global_position += to * (step / d)
