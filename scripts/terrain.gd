extends Node3D

const COLORS := {
	"g": Color(0.85, 0.88, 0.9),
	"r": Color(0.52, 0.46, 0.4),
	"~": Color(0.2, 0.34, 0.43),
	"B": Color(0.48, 0.37, 0.26),
	"K": Color(0.76, 0.79, 0.83),
	"W": Color(0.76, 0.79, 0.83),
	"G": Color(0.76, 0.79, 0.83),
}


func _ready() -> void:
	for j in World.height():
		for i in World.width():
			_tile(i, j, World.cell(i, j))


func _tile(i: int, j: int, c: String) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(World.TILE, 0.5, World.TILE)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.roughness = 0.2 if c == "~" else 0.95
	var col: Color = COLORS[c]
	if c == "g":
		col = col.lerp(Color(0.78, 0.82, 0.86), randf() * 0.4)
	m.albedo_color = col
	mi.material_override = m
	var top := -0.35 if c == "~" else (0.05 if c == "B" else 0.0)
	mi.position = World.tile_center(i, j) + Vector3(0, top - 0.25, 0)
	add_child(mi)
