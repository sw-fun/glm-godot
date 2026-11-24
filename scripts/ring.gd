extends MeshInstance3D

var color := Color(0.6, 0.85, 1.0)
var radius := 8.0


func burst(p_pos: Vector3, p_color: Color, p_radius: float) -> void:
	color = p_color
	radius = p_radius
	global_position = p_pos


func _ready() -> void:
	var m := material_override.duplicate() as StandardMaterial3D
	m.albedo_color = color
	m.emission = color
	m.albedo_color.a = 0.8
	material_override = m
	scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * radius * 2.0, 0.4)
	tw.parallel().tween_method(func(a: float) -> void: m.albedo_color.a = a, 0.8, 0.0, 0.4)
	tw.tween_callback(queue_free)
