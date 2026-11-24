class_name World
extends RefCounted

const TILE := 2.0
const MAP := [
	"KKKKKKKKKKKKKKKKKKKK",
	"WWWWWWWWWWWWWGWWWWWW",
	"gggggggggggggrgggggg",
	"gggggggggggggrgggggg",
	"gggggggggggggrgggggg",
	"gggggggggggggrgggggg",
	"gggggggggggggrgggggg",
	"~~~~~~~~~~~~~B~~~~~~",
	"gggggggggggggrgggggg",
	"gggggggggggggrgggggg",
	"gggggggggggggrgggggg",
	"ggggrrrrrrrrrrgggggg",
	"ggggrggggggggggggggg",
	"ggggrggggggggggggggg",
]
const SPAWN := Vector2i(4, 13)
const GATE := Vector2i(13, 1)


static func width() -> int:
	return MAP[0].length()


static func height() -> int:
	return MAP.size()


static func cell(i: int, j: int) -> String:
	if j < 0 or j >= MAP.size() or i < 0 or i >= MAP[j].length():
		return " "
	return MAP[j][i]


static func tile_center(i: int, j: int) -> Vector3:
	return Vector3((i + 0.5 - width() / 2.0) * TILE, 0.0, (j + 0.5 - height() / 2.0) * TILE)


static func tile_at(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE + width() / 2.0)), int(floor(pos.z / TILE + height() / 2.0)))


static func find_path() -> PackedVector3Array:
	var parents := {SPAWN: Vector2i(-1, -1)}
	var frontier: Array[Vector2i] = [SPAWN]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == GATE:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if parents.has(nxt):
				continue
			if cell(nxt.x, nxt.y) in ["r", "B", "G"]:
				parents[nxt] = cur
				frontier.append(nxt)
	var pts := PackedVector3Array()
	var cur := GATE
	while cur != Vector2i(-1, -1):
		pts.append(tile_center(cur.x, cur.y))
		cur = parents[cur]
	pts.reverse()
	pts.insert(0, tile_center(SPAWN.x, height()) + Vector3(0, 0, TILE))
	return pts
