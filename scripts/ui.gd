extends CanvasLayer

signal tower_selected(kind: String)

@onready var gold_label: Label = $Top/Gold
@onready var lives_label: Label = $Top/Lives
@onready var wave_label: Label = $Top/Wave
@onready var message_label: Label = $Message
@onready var wave_button: Button = $Bottom/Wave
@onready var buttons := {
	"arrow": $Bottom/Arrow,
	"frost": $Bottom/Frost,
	"catapult": $Bottom/Catapult,
}


func _ready() -> void:
	for kind in buttons:
		buttons[kind].pressed.connect(func() -> void: tower_selected.emit(kind))
	wave_button.pressed.connect(func() -> void: pass)  # replaced by Main


func bind_wave(action: Callable) -> void:
	wave_button.pressed.connect(action)


func set_gold(v: int) -> void:
	gold_label.text = "Gold: %d" % v
	for kind in buttons:
		buttons[kind].disabled = v < Tower.STATS[kind]["cost"]


func set_lives(v: int) -> void:
	lives_label.text = "Lives: %d" % v


func set_wave(idx: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [mini(idx + 1, total), total]


func set_wave_enabled(enabled: bool) -> void:
	wave_button.disabled = not enabled


func set_selection(kind: String, gold: int) -> void:
	for k in buttons:
		var cost: int = Tower.STATS[k]["cost"]
		var sel: bool = k == kind
		buttons[k].modulate = Color(1.0, 0.9, 0.5) if sel else (Color(0.6, 0.6, 0.6) if gold < cost else Color.WHITE)


func flash_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.visible = true
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(message_label, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		message_label.modulate.a = 1.0
		message_label.visible = false
	)
