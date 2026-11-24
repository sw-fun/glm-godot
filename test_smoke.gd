extends SceneTree

var frames := 0
var game: Node


func _initialize() -> void:
	Engine.time_scale = 8.0
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 5:
		game._send_wave()
		print("wave sent; state=", game.state)
	if frames == 300:
		print("enemies mid-wave: ", game.enemies_node.get_child_count(), " gold=", game.gold)
	if frames > 2000 or game.state in ["won", "lost"]:
		print("RESULT state=", game.state, " gold=", game.gold, " lives=", game.lives,
			" wave=", game.wave_idx, " enemies_left=", game.enemies_node.get_child_count())
		quit()
