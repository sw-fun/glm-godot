class_name Enemy
extends Node3D

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)

const COLORS := {
	"grunt": Color(0.42, 0.36, 0.31),
	"runner": Color(0.54, 0.29, 0.23),
	"brute": Color(0.33, 0.38, 0.32),
}
const SIZES := {"grunt": 1.0, "runner": 0.85, "brute": 1.5}

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
var _body: MeshInstance3D
var _body_mat: StandardMaterial3D
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D


func setup(p_kind: String, p_hp: float, p_speed: float, p_reward: int, p_path: PackedVector3Array) -> void:
	kind = p_kind
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	reward = p_reward
	path = p_path
	_build()
	position = path[0]


func _build() -> void:
	var s: float = SIZES[kind]
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = COLORS[kind]
	_body_mat.roughness = 0.9

	_body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.9, 0.4) * s
	_body.mesh = bm
	_body.material_override = _body_mat
	_body.position.y = 0.45 * s
	add_child(_body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.22 * s
	hm.height = 0.44 * s
	head.mesh = hm
	head.material_override = _body_mat
	head.position.y = 1.05 * s
	add_child(head)

	_bar_mat = StandardMaterial3D.new()
	_bar_mat.albedo_color = Color(0.3, 0.75, 0.3)
	_bar = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.9 * s, 0.08, 0.02)
	_bar.mesh = b
	_bar.material_override = _bar_mat
	_bar.position.y = 1.45 * s
	add_child(_bar)


func hit(dmg: float, now: float, slow_dur := 0.0, slow_f := 1.0) -> void:
	if dead:
		return
	hp -= dmg
	if slow_dur > 0.0 and slow_f < 1.0:
		slowed_until = now + slow_dur
		slow_factor = slow_f
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.6, 0.1, 0.05)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(_body_mat):
			_body_mat.emission_enabled = false
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
		_body_mat.albedo_color = Color(0.55, 0.7, 0.85)
	else:
		_body_mat.albedo_color = COLORS[kind]

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
	if cam and _bar:
		_bar.look_at(cam.global_position, Vector3.UP)
	var frac: float = clampf(hp / max_hp, 0.0, 1.0)
	_bar.scale = Vector3(frac, 1.0, 1.0)
	_bar_mat.albedo_color = Color(0.3, 0.75, 0.3).lerp(Color(0.8, 0.2, 0.15), 1.0 - frac)
