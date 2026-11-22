extends Node3D

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
const WAVES := [
	[["grunt", 6, 1.4]],
	[["grunt", 8, 1.1], ["runner", 3, 0.8]],
	[["grunt", 10, 0.9], ["runner", 6, 0.7]],
	[["runner", 8, 0.6], ["brute", 2, 2.0], ["grunt", 8, 0.8]],
	[["brute", 4, 1.8], ["runner", 10, 0.5], ["grunt", 12, 0.6]],
]
const ENEMY_STATS := {
	"grunt": {"hp": 30.0, "speed": 2.2, "reward": 8},
	"runner": {"hp": 18.0, "speed": 4.0, "reward": 10},
	"brute": {"hp": 95.0, "speed": 1.5, "reward": 25},
}
const GOLD_START := 130
const LIVES_START := 10

var rng := RandomNumberGenerator.new()
var gold := GOLD_START
var lives := LIVES_START
var wave_idx := 0
var state := "build"  # build | running | won | lost
var now := 0.0

var grid: Array[String] = []
var path := PackedVector3Array()
var selected := ""
var occupied := {}
var spawn_queue: Array = []
var spawn_timer := 0.0

var enemies_node: Node3D
var towers_node: Node3D
var fx_node: Node3D
var arrows: Array = []
var rocks: Array = []
var crows: Array = []
var preview: Node3D
var range_ring: MeshInstance3D
var cam: Camera3D

var ui: CanvasLayer
var gold_label: Label
var lives_label: Label
var wave_label: Label
var message_label: Label
var tower_buttons := {}
var wave_button: Button

var col_grass := Color(0.85, 0.88, 0.9)
var col_road := Color(0.52, 0.46, 0.4)
var col_river := Color(0.2, 0.34, 0.43)
var col_bridge := Color(0.48, 0.37, 0.26)
var col_wall := Color(0.6, 0.63, 0.67)
var col_keep := Color(0.53, 0.56, 0.61)
var col_wood := Color(0.37, 0.28, 0.2)


func _ready() -> void:
	rng.seed = 20261116
	for row in MAP:
		grid.append(row)
	_build_environment()
	_build_terrain()
	_build_castle()
	_build_decor()
	_build_game_nodes()
	_build_ui()
	path = _find_path()
	_update_ui()
	var shot_after := OS.get_environment("SCREENSHOT_AFTER")
	if shot_after != "":
		get_tree().create_timer(float(shot_after)).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SCREENSHOT_PATH"))
			get_tree().quit()
		)


func _process(delta: float) -> void:
	now += delta
	_animate_crows(delta)
	if state == "running":
		_run_spawner(delta)
	for t in towers_node.get_children():
		t.tick(delta, now, enemies_node.get_children())
	_tick_arrows(delta)
	_tick_rocks(delta)
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


func _tile_center(i: int, j: int) -> Vector3:
	return Vector3((i + 0.5 - MAP[0].length() / 2.0) * TILE, 0.0, (j + 0.5 - MAP.size() / 2.0) * TILE)


func _tile_at(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE + MAP[0].length() / 2.0)), int(floor(pos.z / TILE + MAP.size() / 2.0)))


func _cell(i: int, j: int) -> String:
	if j < 0 or j >= grid.size() or i < 0 or i >= grid[j].length():
		return " "
	return grid[j][i]


func _mouse_ground(event_pos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(event_pos)
	var dir := cam.project_ray_normal(event_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t


func _select(kind: String) -> void:
	selected = kind
	for k in tower_buttons:
		var b: Button = tower_buttons[k]
		var is_sel: bool = k == selected
		var cost: int = Tower.STATS[k]["cost"]
		b.modulate = Color(1.0, 0.9, 0.5) if is_sel else (Color(0.6, 0.6, 0.6) if gold < cost else Color.WHITE)
	if range_ring:
		range_ring.visible = selected != ""
	if selected != "":
		var r: float = Tower.STATS[selected]["range"]
		range_ring.scale = Vector3(r, 1.0, r)


func _try_build_at_mouse(screen_pos: Vector2) -> void:
	if selected == "" or state == "lost" or state == "won":
		return
	var g := _mouse_ground(screen_pos)
	if g == Vector3.INF:
		return
	var t := _tile_at(g)
	if _cell(t.x, t.y) != "g" or occupied.has(t):
		return
	var cost: int = Tower.STATS[selected]["cost"]
	if gold < cost:
		_flash_message("Not enough gold", Color(1.0, 0.5, 0.4))
		return
	gold -= cost
	occupied[t] = true
	var tower := Tower.new()
	tower.setup(selected)
	tower.position = _tile_center(t.x, t.y)
	towers_node.add_child(tower)
	tower.shoot_arrow.connect(_on_arrow)
	tower.shoot_rock.connect(_on_rock)
	tower.frost_pulse.connect(_on_frost)
	_select(selected)


func _send_wave() -> void:
	if wave_idx >= WAVES.size():
		return
	state = "running"
	spawn_queue.clear()
	for entry in WAVES[wave_idx]:
		for n in entry[1]:
			spawn_queue.append([entry[0], float(n) * float(entry[2])])
	spawn_timer = 0.6
	wave_button.disabled = true
	_flash_message("Wave %d of %d" % [wave_idx + 1, WAVES.size()], Color(1, 0.95, 0.8))


func _run_spawner(delta: float) -> void:
	spawn_timer -= delta
	if not spawn_queue.is_empty() and spawn_timer <= 0.0:
		var item: Array = spawn_queue.pop_front()
		_spawn_enemy(item[0])
		spawn_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		if not spawn_queue.is_empty():
			spawn_timer = spawn_queue[0][1] - now


func _spawn_enemy(kind: String) -> void:
	var st: Dictionary = ENEMY_STATS[kind]
	var scale_hp: float = 1.0 + 0.25 * wave_idx
	var e := Enemy.new()
	e.setup(kind, float(st["hp"]) * scale_hp, float(st["speed"]), int(st["reward"]), path)
	enemies_node.add_child(e)
	e.died.connect(_on_enemy_died)
	e.leaked.connect(_on_enemy_leaked)


func _on_enemy_died(e: Enemy) -> void:
	gold += e.reward
	_update_ui()


func _on_enemy_leaked(_e: Enemy) -> void:
	lives -= 1
	_flash_message("A creep reached the gate!", Color(1.0, 0.45, 0.35))
	_update_ui()
	if lives <= 0:
		state = "lost"
		wave_button.disabled = true
		_flash_message("The gate has fallen. You are defeated.", Color(1.0, 0.4, 0.3))


func _wave_cleared() -> void:
	gold += 20 + 5 * wave_idx
	wave_idx += 1
	if wave_idx >= WAVES.size():
		state = "won"
		_flash_message("The castle stands! Victory!", Color(0.6, 1.0, 0.6))
	else:
		state = "build"
		wave_button.disabled = false
		_flash_message("Wave cleared. +gold. Send the next when ready.", Color(0.85, 0.95, 0.85))
	_update_ui()


func _on_arrow(target: Node3D, dmg: float, from: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.7)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.8, 0.6)
	mi.material_override = m
	mi.position = from
	fx_node.add_child(mi)
	arrows.append({"node": mi, "target": target, "dmg": dmg, "speed": 22.0})


func _tick_arrows(delta: float) -> void:
	for a in arrows:
		var n: Node3D = a["node"]
		if not is_instance_valid(a["target"]) or a["target"].dead:
			n.queue_free()
			a["gone"] = true
			continue
		var to: Vector3 = a["target"].global_position + Vector3(0, 0.6, 0) - n.global_position
		var d := to.length()
		var step: float = a["speed"] * delta
		if d <= step:
			a["target"].hit(a["dmg"], now)
			n.queue_free()
			a["gone"] = true
			continue
		n.look_at(n.global_position + to, Vector3.UP)
		n.global_position += to * (step / d)
	arrows = arrows.filter(func(a: Dictionary) -> bool: return not a.get("gone", false))


func _on_rock(from: Vector3, target_pos: Vector3, dmg: float, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.3, 0.3)
	mi.material_override = m
	mi.position = from
	fx_node.add_child(mi)
	rocks.append({"node": mi, "from": from, "to": target_pos, "t": 0.0, "dur": 0.8, "dmg": dmg, "radius": radius})


func _tick_rocks(delta: float) -> void:
	for r in rocks:
		var n: Node3D = r["node"]
		r["t"] += delta
		var u: float = r["t"] / float(r["dur"])
		if u >= 1.0:
			_damage_area(r["to"], r["radius"], r["dmg"])
			_spawn_ring(r["to"], r["radius"] * 0.6, Color(0.5, 0.45, 0.4))
			n.queue_free()
			r["gone"] = true
			continue
		var p: Vector3 = r["from"].lerp(r["to"], u)
		p.y += sin(u * PI) * 4.0
		n.position = fx_node.to_local(p) if fx_node else p
	rocks = rocks.filter(func(r: Dictionary) -> bool: return not r.get("gone", false))


func _on_frost(pos: Vector3, radius: float, dmg: float, slow_dur: float, slow_f: float) -> void:
	_damage_area(pos + Vector3(0, 0.5, 0), radius, dmg, slow_dur, slow_f)
	_spawn_ring(pos + Vector3(0, 0.5, 0), radius, Color(0.6, 0.85, 1.0))


func _damage_area(pos: Vector3, radius: float, dmg: float, slow_dur := 0.0, slow_f := 1.0) -> void:
	for e in enemies_node.get_children():
		if e is Enemy and not e.dead and e.global_position.distance_to(pos) <= radius:
			e.hit(dmg, now, slow_dur, slow_f)


func _spawn_ring(pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.8
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3.ONE * 0.3
	fx_node.add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 2.0, 0.4)
	tw.parallel().tween_method(func(a: float) -> void: m.albedo_color.a = a, 0.8, 0.0, 0.4)
	tw.tween_callback(mi.queue_free)


# --- scene building -------------------------------------------------------


func _mat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_environment() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 30.0
	cam.position = Vector3(22, 26, 24)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	cam.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -140, 0)
	sun.light_color = Color(0.95, 0.93, 0.88)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.62, 0.71, 0.78)
	sm.sky_horizon_color = Color(0.78, 0.82, 0.85)
	sm.ground_bottom_color = Color(0.5, 0.53, 0.56)
	sm.ground_horizon_color = Color(0.78, 0.82, 0.85)
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.1
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.76, 0.8)
	e.fog_density = 0.008
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)

	var snow := CPUParticles3D.new()
	snow.amount = 500
	snow.lifetime = 9.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(24, 0.5, 18)
	snow.position = Vector3(0, 16, 0)
	snow.gravity = Vector3(0.3, -1.6, 0.1)
	snow.initial_velocity_min = 0.4
	snow.initial_velocity_max = 0.9
	snow.scale_amount_min = 0.03
	snow.scale_amount_max = 0.08
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_color = Color(1, 1, 1)
	sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow.mesh = SphereMesh.new()
	(snow.mesh as SphereMesh).radius = 0.5
	(snow.mesh as SphereMesh).height = 1.0
	snow.mesh.material = sm2
	add_child(snow)


func _terrain_tile(i: int, j: int, c: String) -> void:
	var pos := _tile_center(i, j)
	var m: StandardMaterial3D
	var top := 0.0
	var h := 0.5
	match c:
		"g":
			m = _mat(col_grass)
			m.albedo_color = col_grass.lerp(Color(0.78, 0.82, 0.86), rng.randf() * 0.4)
		"r":
			m = _mat(col_road)
		"~":
			m = _mat(col_river)
			m.roughness = 0.2
			top = -0.35
		"B":
			m = _mat(col_bridge)
			top = 0.05
		"K", "W", "G":
			m = _mat(col_grass.lerp(Color(0.7, 0.73, 0.77), 0.3))
	var mi := _box(self, Vector3(TILE, h, TILE), pos + Vector3(0, top - h / 2.0, 0), m)
	mi.position.y = top - h / 2.0


func _build_terrain() -> void:
	for j in grid.size():
		for i in grid[j].length():
			_terrain_tile(i, j, grid[j][i])


func _build_castle() -> void:
	var wall_m := _mat(col_wall)
	var keep_m := _mat(col_keep)
	var wood_m := _mat(col_wood)
	var banner_m := _mat(Color(0.6, 0.15, 0.12), 0.8)

	for j in grid.size():
		for i in grid[j].length():
			var c := _cell(i, j)
			var pos := _tile_center(i, j)
			if c == "W":
				_box(self, Vector3(TILE, 1.8, TILE), pos + Vector3(0, 0.9, 0), wall_m)
				for k in 3:
					_box(self, Vector3(0.5, 0.4, 0.5), pos + Vector3(-0.6 + k * 0.6, 2.0, 0), wall_m)
			elif c == "G":
				# gate towers flanking the road
				for side in [-1.0, 1.0]:
					var t := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.7
					cyl.bottom_radius = 0.8
					cyl.height = 2.6
					t.mesh = cyl
					t.material_override = wall_m
					t.position = pos + Vector3(side * 1.4, 1.3, 0)
					add_child(t)
					var roof := MeshInstance3D.new()
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0
					cone.bottom_radius = 1.0
					cone.height = 1.0
					roof.mesh = cone
					roof.material_override = _mat(Color(0.35, 0.25, 0.2))
					roof.position = pos + Vector3(side * 1.4, 3.1, 0)
					add_child(roof)
				_box(self, Vector3(0.5, 1.2, 1.8), pos + Vector3(0, 2.2, 0), wall_m)
				_box(self, Vector3(0.3, 1.4, 1.4), pos + Vector3(0, 0.7, 0), wood_m)
			elif c == "K":
				_box(self, Vector3(TILE, 2.6, TILE), pos + Vector3(0, 1.3, 0), keep_m)
				if (i + j) % 4 == 0:
					_box(self, Vector3(0.5, 0.4, 0.5), pos + Vector3(0, 2.8, 0), keep_m)
	# the keep tower behind the gate
	var kt := _tile_center(GATE.x, 0)
	var tower := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.3
	cyl.bottom_radius = 1.5
	cyl.height = 4.5
	tower.mesh = cyl
	tower.material_override = keep_m
	tower.position = kt + Vector3(0, 4.5, 0)
	add_child(tower)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.8
	cone.height = 1.6
	roof.mesh = cone
	roof.material_override = _mat(Color(0.35, 0.25, 0.2))
	roof.position = kt + Vector3(0, 7.5, 0)
	add_child(roof)
	# banners on the keep tower
	for side in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.5, 1.0)
		b.mesh = pm
		b.material_override = banner_m
		b.position = kt + Vector3(side * 1.4, 5.4, 0.3)
		b.rotation_degrees = Vector3(0, side * 35, 0)
		add_child(b)
	# braziers with fire + smoke by the gate
	for side in [-1.0, 1.0]:
		var bp := _tile_center(GATE.x + side, 2) + Vector3(0, 0.4, 0)
		_box(self, Vector3(0.4, 0.5, 0.4), bp, _mat(Color(0.25, 0.24, 0.23)))
		var fire := CPUParticles3D.new()
		fire.amount = 14
		fire.lifetime = 0.7
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 0.15
		fire.position = bp + Vector3(0, 0.35, 0)
		fire.direction = Vector3.UP
		fire.spread = 12.0
		fire.gravity = Vector3.ZERO
		fire.initial_velocity_min = 0.6
		fire.initial_velocity_max = 1.1
		fire.scale_amount_min = 0.1
		fire.scale_amount_max = 0.2
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(1.0, 0.55, 0.15)
		fm.emission_enabled = true
		fm.emission = Color(1.0, 0.45, 0.1)
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fire.mesh = SphereMesh.new()
		(fire.mesh as SphereMesh).radius = 0.5
		(fire.mesh as SphereMesh).height = 1.0
		fire.mesh.material = fm
		add_child(fire)
		var smoke := CPUParticles3D.new()
		smoke.amount = 10
		smoke.lifetime = 3.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.1
		smoke.position = bp + Vector3(0, 0.8, 0)
		smoke.direction = Vector3(0.4, 1, 0.2)
		smoke.spread = 10.0
		smoke.gravity = Vector3.ZERO
		smoke.initial_velocity_min = 0.5
		smoke.initial_velocity_max = 0.8
		smoke.scale_amount_min = 0.15
		smoke.scale_amount_max = 0.35
		var skm := StandardMaterial3D.new()
		skm.albedo_color = Color(0.6, 0.6, 0.6, 0.5)
		skm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		skm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke.mesh = SphereMesh.new()
		(smoke.mesh as SphereMesh).radius = 0.5
		(smoke.mesh as SphereMesh).height = 1.0
		smoke.mesh.material = skm
		add_child(smoke)
		var lamp := OmniLight3D.new()
		lamp.position = bp + Vector3(0, 0.8, 0)
		lamp.light_color = Color(1.0, 0.6, 0.25)
		lamp.omni_range = 5.0
		lamp.light_energy = 1.4
		add_child(lamp)


func _build_decor() -> void:
	# bridge rails
	for j in [7]:
		var pos := _tile_center(13, j)
		for side in [-1.0, 1.0]:
			_box(self, Vector3(0.15, 0.5, TILE), pos + Vector3(side * 0.9, 0.4, 0), _mat(col_wood))
	# trees on quiet grass
	for attempt in 40:
		var i := rng.randi_range(0, MAP[0].length() - 1)
		var j := rng.randi_range(0, MAP.size() - 1)
		if _cell(i, j) != "g":
			continue
		var near_road := false
		for dj in [-1, 0, 1]:
			for di in [-1, 0, 1]:
				if _cell(i + di, j + dj) in ["r", "B", "~"]:
					near_road = true
		if near_road:
			continue
		var p := _tile_center(i, j)
		var trunk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.18
		cyl.height = 0.9
		trunk.mesh = cyl
		trunk.material_override = _mat(col_wood)
		trunk.position = p + Vector3(0, 0.45, 0)
		add_child(trunk)
		for layer in 2:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.9 - layer * 0.3
			cm.height = 1.0
			cone.mesh = cm
			cone.material_override = _mat(Color(0.3, 0.42, 0.34).lerp(Color(0.85, 0.88, 0.9), 0.35))
			cone.position = p + Vector3(0, 1.2 + layer * 0.6, 0)
			add_child(cone)
	# crows overhead
	for n in 2:
		var crow := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.08, 0.15)
		crow.mesh = bm
		crow.material_override = _mat(Color(0.12, 0.12, 0.14))
		add_child(crow)
		crows.append({"node": crow, "phase": rng.randf() * TAU, "r": 14.0 + n * 4.0, "h": 10.0 + n * 2.0})


func _animate_crows(delta: float) -> void:
	for c in crows:
		c["phase"] += delta * 0.5
		var p: float = c["phase"]
		var n: Node3D = c["node"]
		n.global_position = Vector3(cos(p) * c["r"], c["h"] + sin(p * 3.0) * 0.5, sin(p) * c["r"] * 0.7)
		n.rotation.y = -p + PI / 2.0


func _build_game_nodes() -> void:
	enemies_node = Node3D.new()
	enemies_node.name = "Enemies"
	add_child(enemies_node)
	towers_node = Node3D.new()
	towers_node.name = "Towers"
	add_child(towers_node)
	fx_node = Node3D.new()
	fx_node.name = "Fx"
	add_child(fx_node)

	range_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.97
	tm.outer_radius = 1.0
	range_ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 0.7, 0.5)
	m.emission_enabled = true
	m.emission = Color(1, 1, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	range_ring.material_override = m
	range_ring.visible = false
	add_child(range_ring)

	preview = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TILE * 0.9, TILE * 0.9)
	preview.mesh = pm
	var pm2 := StandardMaterial3D.new()
	pm2.albedo_color = Color(0.4, 0.9, 0.4, 0.4)
	pm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview.material_override = pm2
	preview.visible = false
	add_child(preview)


func _update_preview() -> void:
	if selected == "":
		preview.visible = false
		range_ring.visible = false
		return
	var mouse := get_viewport().get_mouse_position()
	var g := _mouse_ground(mouse)
	if g == Vector3.INF:
		preview.visible = false
		range_ring.visible = false
		return
	var t := _tile_at(g)
	var ok := _cell(t.x, t.y) == "g" and not occupied.has(t) and gold >= int(Tower.STATS[selected]["cost"])
	preview.visible = true
	preview.global_position = _tile_center(t.x, t.y) + Vector3(0, 0.06, 0)
	(preview.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.9, 0.4, 0.4) if ok else Color(0.9, 0.3, 0.3, 0.4)
	range_ring.visible = true
	range_ring.global_position = preview.global_position


func _find_path() -> PackedVector3Array:
	var start := SPAWN
	var goal := GATE
	var parents := {start: Vector2i(-1, -1)}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if parents.has(nxt):
				continue
			var c := _cell(nxt.x, nxt.y)
			if c in ["r", "B", "G"]:
				parents[nxt] = cur
				frontier.append(nxt)
	var pts := PackedVector3Array()
	var cur := goal
	while cur != Vector2i(-1, -1):
		pts.append(_tile_center(cur.x, cur.y))
		cur = parents[cur]
	pts.reverse()
	pts.insert(0, _tile_center(SPAWN.x, MAP.size()) + Vector3(0, 0, TILE))
	return pts


# --- UI -------------------------------------------------------------------


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 10
	ui.add_child(top)

	gold_label = _make_label(22, Color(1, 0.85, 0.4))
	lives_label = _make_label(22, Color(0.9, 0.4, 0.35))
	wave_label = _make_label(22, Color(0.85, 0.9, 0.95))
	for l in [gold_label, lives_label, wave_label]:
		top.add_child(l)
		var sep := Control.new()
		sep.custom_minimum_size = Vector2(30, 0)
		top.add_child(sep)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -12
	bottom.offset_top = -64
	bottom.add_theme_constant_override("separation", 12)
	ui.add_child(bottom)

	for kind in ["arrow", "frost", "catapult"]:
		var st: Dictionary = Tower.STATS[kind]
		var b := Button.new()
		b.text = "%d  %s  %dg" % [["arrow", "frost", "catapult"].find(kind) + 1, kind.capitalize(), st["cost"]]
		b.custom_minimum_size = Vector2(150, 48)
		b.pressed.connect(_select.bind(kind))
		bottom.add_child(b)
		tower_buttons[kind] = b

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	wave_button = Button.new()
	wave_button.text = "Send wave  (Space)"
	wave_button.custom_minimum_size = Vector2(200, 48)
	wave_button.pressed.connect(_send_wave)
	bottom.add_child(wave_button)

	var hint := _make_label(14, Color(1, 1, 1, 0.7))
	hint.text = "Pick a tower (1/2/3), click grass to build. Space sends the next wave."
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 18
	hint.offset_top = -88
	hint.offset_right = -18
	hint.offset_bottom = -66
	ui.add_child(hint)

	message_label = _make_label(26, Color(1, 0.95, 0.8))
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_left = -300
	message_label.offset_right = 300
	message_label.offset_top = 60
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(message_label)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _update_ui() -> void:
	gold_label.text = "Gold: %d" % gold
	lives_label.text = "Lives: %d" % lives
	wave_label.text = "Wave: %d / %d" % [mini(wave_idx + 1, WAVES.size()), WAVES.size()]
	for k in tower_buttons:
		var cost: int = Tower.STATS[k]["cost"]
		tower_buttons[k].disabled = gold < cost
	_select(selected)


var _msg_until := 0.0


func _flash_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.visible = true
	_msg_until = now + 3.5
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(message_label, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		message_label.modulate.a = 1.0
		message_label.visible = false
	)
