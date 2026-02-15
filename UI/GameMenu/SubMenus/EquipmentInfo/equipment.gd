extends GridContainer
@export var buttons: Array[Button] = []
var select_index:int = 0

func _ready() -> void:
	hide()
	set_process_input(false)

func setup():
	for i in get_children():
		if not i is Button:
			continue
		buttons.append(i)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		#owner.set_state(owner.MenuState.EQUIPMENT_MENU_HIDE)
		pass
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



