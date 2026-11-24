class_name Tower
extends Node3D

signal shoot_arrow(target: Node3D, dmg: float, from: Vector3)
signal shoot_rock(from: Vector3, target_pos: Vector3, dmg: float, radius: float)
signal frost_pulse(pos: Vector3, radius: float, dmg: float, slow_dur: float, slow_f: float)

const STATS := {
	"arrow": {"range": 9.0, "dmg": 8.0, "rate": 1.1, "cost": 50},
	"frost": {"range": 8.0, "dmg": 2.0, "rate": 0.8, "cost": 70},
	"catapult": {"range": 12.0, "dmg": 22.0, "rate": 0.35, "cost": 80},
}

@export var kind := "arrow"

var range_f := 9.0
var damage := 8.0
var cooldown := 1.0
var _cd := 0.0


func _ready() -> void:
	var st: Dictionary = STATS[kind]
	range_f = st["range"]
	damage = st["dmg"]
	cooldown = 1.0 / float(st["rate"])


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
