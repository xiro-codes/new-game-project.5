extends MarginContainer
@export var buttons:Array[Button] = []
var select_index = 0

func _ready()->void:
	hide()
	set_process_input(false)
	
func setup():
	buttons.clear()
	for i in %Items.get_children():
		i.queue_free()
	var items:Array[GearRes] = InvManager.get_items()
	for i in items:
		var b = Button.new()
		b.text = i.display_name
		b.set_meta("item", i)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		%Items.add_child(b)
		buttons.append(b)
		b.pressed.connect(_on_item_button_pressed.bind(b))
		
		
func _on_item_button_pressed(button: Button):
	print((button.get_meta("item") as GearRes).display_name)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		owner.set_state(Enums.MenuState.INV_MENU_HIDE)

	var navigated = false
	if event.is_action_pressed('move_backward'):
		select_index = ( select_index + 1) % buttons.size()
		get_viewport().set_input_as_handled()
		navigated = true
	elif event.is_action_pressed('move_forward'):
		if select_index == 0:
			select_index = buttons.size() - 1
		else:
			select_index -= 1
		navigated = true
		get_viewport().set_input_as_handled()
	if navigated:
		update_focus()

func update_focus():
	buttons[select_index].grab_focus()
