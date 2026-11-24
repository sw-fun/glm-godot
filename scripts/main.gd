extends Node3D

const GOLD_START := 130
const LIVES_START := 10
const WAVES := [
	[["grunt", 6, 1.4]],
	[["grunt", 8, 1.1], ["runner", 3, 0.8]],
	[["grunt", 10, 0.9], ["runner", 6, 0.7]],
	[["runner", 8, 0.6], ["brute", 2, 2.0], ["grunt", 8, 0.8]],
	[["brute", 4, 1.8], ["runner", 10, 0.5], ["grunt", 12, 0.6]],
]

const TOWER_SCENES := {
	"arrow": preload("res://scenes/tower_arrow.tscn"),
	"frost": preload("res://scenes/tower_frost.tscn"),
	"catapult": preload("res://scenes/tower_catapult.tscn"),
}
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ARROW_SCENE := preload("res://scenes/arrow.tscn")
const ROCK_SCENE := preload("res://scenes/rock.tscn")
const RING_SCENE := preload("res://scenes/ring.tscn")

var gold := GOLD_START
var lives := LIVES_START
var wave_idx := 0
var state := "build"  # build | running | won | lost
var now := 0.0
var selected := ""
var occupied := {}
var spawn_queue: Array = []
var spawn_timer := 0.0

@onready var enemies_node: Node3D = $Enemies
@onready var towers_node: Node3D = $Towers
@onready var fx_node: Node3D = $Fx
@onready var camera: Camera3D = $Camera
@onready var preview: MeshInstance3D = $Preview
@onready var range_ring: MeshInstance3D = $RangeRing
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	ui.tower_selected.connect(_select)
	ui.bind_wave(_send_wave)
	_update_ui()
	var shot_after := OS.get_environment("SCREENSHOT_AFTER")
	if shot_after != "":
		get_tree().create_timer(float(shot_after)).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SCREENSHOT_PATH"))
			get_tree().quit()
		)


func _process(delta: float) -> void:
	now += delta
	if state == "running":
		_run_spawner(delta)
	for t in towers_node.get_children():
		t.tick(delta, now, enemies_node.get_children())
	_update_preview()
	if state == "running" and spawn_queue.is_empty() and enemies_node.get_child_count() == 0:
		_wave_cleared()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select("arrow")
			KEY_2: _select("frost")
			KEY_3: _select("catapult")
			KEY_ESCAPE: _select("")
			KEY_SPACE:
				if state == "build":
					_send_wave()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_build_at_mouse(event.position)


func _select(kind: String) -> void:
	selected = kind
	ui.set_selection(kind, gold)
	range_ring.visible = selected != ""
	if selected != "":
		var r: float = Tower.STATS[selected]["range"]
		range_ring.scale = Vector3(r, 1.0, r)


func _mouse_ground(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t


func _try_build_at_mouse(screen_pos: Vector2) -> void:
	if selected == "" or state in ["lost", "won"]:
		return
	var g := _mouse_ground(screen_pos)
	if g == Vector3.INF:
		return
	var t := World.tile_at(g)
	if World.cell(t.x, t.y) != "g" or occupied.has(t):
		return
	var cost: int = Tower.STATS[selected]["cost"]
	if gold < cost:
		ui.flash_message("Not enough gold", Color(1.0, 0.5, 0.4))
		return
	gold -= cost
	occupied[t] = true
	var tower: Tower = TOWER_SCENES[selected].instantiate()
	tower.position = World.tile_center(t.x, t.y)
	towers_node.add_child(tower)
	tower.shoot_arrow.connect(_on_arrow)
	tower.shoot_rock.connect(_on_rock)
	tower.frost_pulse.connect(_on_frost)
	_update_ui()


func _update_preview() -> void:
	if selected == "":
		preview.visible = false
		range_ring.visible = false
		return
	var g := _mouse_ground(get_viewport().get_mouse_position())
	if g == Vector3.INF:
		preview.visible = false
		range_ring.visible = false
		return
	var t := World.tile_at(g)
	var ok := World.cell(t.x, t.y) == "g" and not occupied.has(t) and gold >= int(Tower.STATS[selected]["cost"])
	preview.visible = true
	preview.global_position = World.tile_center(t.x, t.y) + Vector3(0, 0.06, 0)
	(preview.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.9, 0.4, 0.4) if ok else Color(0.9, 0.3, 0.3, 0.4)
	range_ring.visible = true
	range_ring.global_position = preview.global_position


# --- waves ----------------------------------------------------------------


func _send_wave() -> void:
	if wave_idx >= WAVES.size():
		return
	state = "running"
	spawn_queue.clear()
	for entry in WAVES[wave_idx]:
		for n in entry[1]:
			spawn_queue.append([entry[0], float(n) * float(entry[2])])
	spawn_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	spawn_timer = 0.6
	ui.set_wave_enabled(false)
	ui.flash_message("Wave %d of %d" % [wave_idx + 1, WAVES.size()], Color(1, 0.95, 0.8))


func _run_spawner(delta: float) -> void:
	spawn_timer -= delta
	if not spawn_queue.is_empty() and spawn_timer <= 0.0:
		var item: Array = spawn_queue.pop_front()
		_spawn_enemy(item[0])
		if not spawn_queue.is_empty():
			spawn_timer = spawn_queue[0][1] - now


func _spawn_enemy(kind: String) -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(kind, 1.0 + 0.25 * wave_idx, World.find_path())
	enemies_node.add_child(e)
	e.died.connect(_on_enemy_died)
	e.leaked.connect(_on_enemy_leaked)


func _on_enemy_died(e: Enemy) -> void:
	gold += e.reward
	_update_ui()


func _on_enemy_leaked(_e: Enemy) -> void:
	lives -= 1
	ui.flash_message("A creep reached the gate!", Color(1.0, 0.45, 0.35))
	_update_ui()
	if lives <= 0:
		state = "lost"
		ui.set_wave_enabled(false)
		ui.flash_message("The gate has fallen. You are defeated.", Color(1.0, 0.4, 0.3))


func _wave_cleared() -> void:
	gold += 20 + 5 * wave_idx
	wave_idx += 1
	if wave_idx >= WAVES.size():
		state = "won"
		ui.flash_message("The castle stands! Victory!", Color(0.6, 1.0, 0.6))
	else:
		state = "build"
		ui.set_wave_enabled(true)
		ui.flash_message("Wave cleared. +gold. Send the next when ready.", Color(0.85, 0.95, 0.85))
	_update_ui()


func _update_ui() -> void:
	ui.set_gold(gold)
	ui.set_lives(lives)
	ui.set_wave(wave_idx, WAVES.size())
	_select(selected)


# --- projectiles ----------------------------------------------------------


func _on_arrow(target: Node3D, dmg: float, from: Vector3) -> void:
	var a := ARROW_SCENE.instantiate()
	a.launch(target, dmg)
	fx_node.add_child(a)
	a.global_position = from
	a.struck.connect(_on_arrow_struck)


func _on_arrow_struck(target: Node3D, dmg: float) -> void:
	if target is Enemy:
		target.hit(dmg, now)


func _on_rock(from: Vector3, target_pos: Vector3, dmg: float, radius: float) -> void:
	var r := ROCK_SCENE.instantiate()
	fx_node.add_child(r)
	r.arc(from, target_pos, dmg, radius)
	r.landed.connect(_on_rock_landed)


func _on_rock_landed(pos: Vector3, radius: float, dmg: float) -> void:
	_damage_area(pos, radius, dmg)
	_spawn_ring(pos, radius * 0.6, Color(0.5, 0.45, 0.4))


func _on_frost(pos: Vector3, radius: float, dmg: float, slow_dur: float, slow_f: float) -> void:
	_damage_area(pos + Vector3(0, 0.5, 0), radius, dmg, slow_dur, slow_f)
	_spawn_ring(pos + Vector3(0, 0.5, 0), radius, Color(0.6, 0.85, 1.0))


func _damage_area(pos: Vector3, radius: float, dmg: float, slow_dur := 0.0, slow_f := 1.0) -> void:
	for e in enemies_node.get_children():
		if e is Enemy and not e.dead and e.global_position.distance_to(pos) <= radius:
			e.hit(dmg, now, slow_dur, slow_f)


func _spawn_ring(pos: Vector3, radius: float, color: Color) -> void:
	var ring := RING_SCENE.instantiate()
	fx_node.add_child(ring)
	ring.burst(pos + Vector3(0, 0.05, 0), color, radius)
