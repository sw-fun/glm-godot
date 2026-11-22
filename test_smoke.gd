extends SceneTree

var frames := 0
var game: Node


func _initialize() -> void:
	Engine.time_scale = 8.0
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.path = game._find_path()
	game._send_wave()
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 5:
		print("path points: ", game.path.size())
		print("enemies spawned after 5 frames: ", game.enemies_node.get_child_count())
	if frames > 1500 or game.state in ["won", "lost"]:
		print("RESULT state=", game.state, " gold=", game.gold, " lives=", game.lives,
			" wave=", game.wave_idx, " enemies_left=", game.enemies_node.get_child_count())
		quit()
