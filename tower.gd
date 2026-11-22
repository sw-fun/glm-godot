class_name Tower
extends Node3D

signal shoot_arrow(target: Node3D, dmg: float, from: Vector3)
signal shoot_rock(from: Vector3, target_pos: Vector3, dmg: float, radius: float)
signal frost_pulse(pos: Vector3, radius: float, dmg: float, slow_dur: float, slow_f: float)

var kind := "arrow"
var range_f := 9.0
var damage := 8.0
var cooldown := 1.0
var _cd := 0.0

const STATS := {
	"arrow": {"range": 9.0, "dmg": 8.0, "rate": 1.1, "cost": 50},
	"frost": {"range": 8.0, "dmg": 2.0, "rate": 0.8, "cost": 70},
	"catapult": {"range": 12.0, "dmg": 22.0, "rate": 0.35, "cost": 80},
}


func setup(p_kind: String) -> void:
	kind = p_kind
	var st: Dictionary = STATS[kind]
	range_f = st["range"]
	damage = st["dmg"]
	cooldown = 1.0 / float(st["rate"])
	_build()


func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.62, 0.66)
	m.roughness = 0.95
	return m


func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.48, 0.37, 0.26)
	m.roughness = 0.9
	return m


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _build() -> void:
	var stone := _stone()
	var wood := _wood()

	match kind:
		"arrow":
			var base := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.7
			cyl.bottom_radius = 0.85
			cyl.height = 0.9
			base.mesh = cyl
			base.material_override = stone
			base.position.y = 0.45
			add_child(base)
			_box(Vector3(1.1, 0.5, 1.1), wood, Vector3(0, 1.15, 0))
			_box(Vector3(0.12, 0.12, 1.2), wood, Vector3(0, 1.5, 0))
			var limb := _box(Vector3(1.2, 0.1, 0.1), wood, Vector3(0, 1.5, -0.45))
			limb.rotation.x = 0.4
		"frost":
			var base := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.7
			cyl.bottom_radius = 0.85
			cyl.height = 0.8
			base.mesh = cyl
			base.material_override = stone
			base.position.y = 0.4
			add_child(base)
			var cr := MeshInstance3D.new()
			var cm := SphereMesh.new()
			cm.radius = 0.42
			cm.height = 1.1
			cr.mesh = cm
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.55, 0.75, 0.95)
			gm.roughness = 0.3
			gm.emission_enabled = true
			gm.emission = Color(0.15, 0.3, 0.5)
			cr.mesh = cm
			cr.material_override = gm
			cr.position.y = 1.3
			add_child(cr)
		"catapult":
			_box(Vector3(1.6, 0.5, 1.6), stone, Vector3(0, 0.25, 0))
			var arm := _box(Vector3(0.18, 1.8, 0.18), wood, Vector3(0, 1.0, -0.2))
			arm.rotation.x = -0.6
			var bowl := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.44
			bowl.mesh = sm
			bowl.material_override = wood
			bowl.position = Vector3(0, 1.75, -0.6)
			add_child(bowl)


func tick(delta: float, now: float, enemies: Array) -> void:
	if _cd > 0.0:
		_cd -= delta
		return
	var best: Node3D = null
	var best_prog := -1.0
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.global_position.distance_to(global_position) > range_f:
			continue
		if e.progress > best_prog:
			best_prog = e.progress
			best = e
	if best == null:
		return
	_cd = cooldown
	var from := global_position + Vector3(0, 1.4, 0)
	match kind:
		"arrow":
			shoot_arrow.emit(best, damage, from)
		"catapult":
			shoot_rock.emit(from, best.global_position, damage, 2.6)
		"frost":
			frost_pulse.emit(global_position, range_f, damage, 2.0, 0.5)
