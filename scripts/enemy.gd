class_name Enemy
extends Node3D

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)

const KINDS := {
	"grunt": {"color": Color(0.42, 0.36, 0.31), "size": 1.0, "hp": 30.0, "speed": 2.2, "reward": 8},
	"runner": {"color": Color(0.54, 0.29, 0.23), "size": 0.85, "hp": 18.0, "speed": 4.0, "reward": 10},
	"brute": {"color": Color(0.33, 0.38, 0.32), "size": 1.5, "hp": 95.0, "speed": 1.5, "reward": 25},
}

var kind := "grunt"
var hp := 30.0
var max_hp := 30.0
var speed := 2.2
var reward := 8

var path := PackedVector3Array()
var seg := 1
var progress := 0.0
var slowed_until := -1.0
var slow_factor := 1.0
var dead := false

var _t := 0.0
@onready var _body: MeshInstance3D = $Body
@onready var _head: MeshInstance3D = $Head
@onready var _bar: MeshInstance3D = $Bar
var _mat: StandardMaterial3D
var _bar_mat: StandardMaterial3D


func setup(p_kind: String, scale_hp: float, p_path: PackedVector3Array) -> void:
	kind = p_kind
	var st: Dictionary = KINDS[kind]
	max_hp = float(st["hp"]) * scale_hp
	hp = max_hp
	speed = float(st["speed"])
	reward = int(st["reward"])
	path = p_path


func _ready() -> void:
	var st: Dictionary = KINDS[kind]
	var s: float = st["size"]
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = st["color"]
	_mat.roughness = 0.9
	_body.material_override = _mat
	_head.material_override = _mat
	var base := _body.mesh.duplicate()
	base.size = (base as BoxMesh).size * Vector3(s, s, s)
	_body.mesh = base
	_body.scale = Vector3.ONE * s
	_head.scale = Vector3.ONE * s
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.albedo_color = Color(0.3, 0.75, 0.3)
	_bar.material_override = _bar_mat
	_body.position.y = 0.45 * s
	_head.position.y = 1.05 * s
	_bar.position.y = 1.45 * s
	(_bar.mesh as BoxMesh).size.x *= s
	if not path.is_empty():
		position = path[0]


func hit(dmg: float, now: float, slow_dur := 0.0, slow_f := 1.0) -> void:
	if dead:
		return
	hp -= dmg
	if slow_dur > 0.0 and slow_f < 1.0:
		slowed_until = now + slow_dur
		slow_factor = slow_f
	_mat.emission_enabled = true
	_mat.emission = Color(0.6, 0.1, 0.05)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(_mat):
			_mat.emission_enabled = false
	)
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()


func _process(delta: float) -> void:
	if dead:
		return
	_t += delta
	var now := Time.get_ticks_msec() / 1000.0
	var eff := speed
	if now < slowed_until:
		eff *= slow_factor
		_mat.albedo_color = Color(0.55, 0.7, 0.85)
	else:
		_mat.albedo_color = KINDS[kind]["color"]

	if seg >= path.size():
		dead = true
		leaked.emit(self)
		queue_free()
		return

	var target := path[seg]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var step := eff * delta
	if dist <= step:
		position = target
		seg += 1
		progress = float(seg)
	else:
		position += to * (step / dist)
		progress = float(seg) + step / dist

	_body.position.y += sin(_t * 9.0) * 0.05
	var cam := get_viewport().get_camera_3d()
	if cam:
		_bar.look_at(cam.global_position, Vector3.UP)
	var frac: float = clampf(hp / max_hp, 0.0, 1.0)
	_bar.scale = Vector3(frac, 1.0, 1.0)
	_bar_mat.albedo_color = Color(0.3, 0.75, 0.3).lerp(Color(0.8, 0.2, 0.15), 1.0 - frac)
