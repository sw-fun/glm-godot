extends Node3D

const TREE := preload("res://scenes/tree.tscn")
const CROW := preload("res://scenes/crow.tscn")


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	for attempt in 40:
		var i := rng.randi_range(0, World.width() - 1)
		var j := rng.randi_range(0, World.height() - 1)
		if World.cell(i, j) != "g" or _near_road(i, j):
			continue
		var t := TREE.instantiate()
		t.position = World.tile_center(i, j)
		t.rotation.y = rng.randf() * TAU
		add_child(t)
	for n in 2:
		var c := CROW.instantiate()
		c.radius = 14.0 + n * 4.0
		c.height = 10.0 + n * 2.0
		c.phase = rng.randf() * TAU
		add_child(c)


func _near_road(i: int, j: int) -> bool:
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			if World.cell(i + di, j + dj) in ["r", "B", "~"]:
				return true
	return false
