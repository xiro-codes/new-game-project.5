extends CanvasLayer
func _ready()->void:
	layer = 2
	set_process_mode(Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED)
	
func display_number(value: int, position: Vector2, is_miss: bool = false):
	var label = Label.new()
	label.global_position = position
	label.text = "{0}".format([value])
	label.z_index = 5
	add_child(label)
	label.pivot_offset = Vector2(label.size / 2)
	var tween = get_tree().create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()
	tween.tween_property(
		label, "position", Vector2(label.position.x,label.position.y -24), 0.25
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		label, "position", Vector2(label.position.x, label.position.y), 0.5
	).set_delay(0.25).set_ease(Tween.EASE_IN)

	tween.tween_property(label, "scale", Vector2.ZERO, 0.25).set_delay(0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free).set_delay(.75)
