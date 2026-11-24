extends Node3D

const WALL := preload("res://scenes/wall_segment.tscn")
const GATE := preload("res://scenes/gate.tscn")
const KEEP := preload("res://scenes/keep_tower.tscn")
const BRAZIER := preload("res://scenes/brazier.tscn")


func _ready() -> void:
	for j in World.height():
		for i in World.width():
			match World.cell(i, j):
				"W":
					_place(WALL, i, j)
				"G":
					_place(GATE, i, j)
				"K":
					_place_wall_block(i, j)
	var kt := KEEP.instantiate()
	kt.position = World.tile_center(World.GATE.x, 0)
	add_child(kt)
	for side in [-1.0, 1.0]:
		var b := BRAZIER.instantiate()
		b.position = World.tile_center(World.GATE.x + int(side), 2) + Vector3(0, 0.2, 0)
		add_child(b)


func _place(scene: PackedScene, i: int, j: int) -> void:
	var n := scene.instantiate()
	n.position = World.tile_center(i, j)
	add_child(n)


func _place_wall_block(i: int, j: int) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(World.TILE, 2.6, World.TILE)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.53, 0.56, 0.61)
	m.roughness = 0.95
	mi.material_override = m
	mi.position = World.tile_center(i, j) + Vector3(0, 1.3, 0)
	add_child(mi)
	if (i + j) % 4 == 0:
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 0.4, 0.5)
		cap.mesh = cm
		cap.material_override = m
		cap.position = World.tile_center(i, j) + Vector3(0, 2.8, 0)
		add_child(cap)
