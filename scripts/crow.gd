extends MeshInstance3D

@export var radius := 14.0
@export var height := 10.0
@export var speed := 0.5
@export var phase := 0.0


func _process(delta: float) -> void:
	phase += delta * speed
	global_position = Vector3(
		cos(phase) * radius,
		height + sin(phase * 3.0) * 0.5,
		sin(phase) * radius * 0.7
	)
	rotation.y = -phase + PI / 2.0
