extends CanvasLayer

var current_state: Enums.MenuState

@export var buttons:Array[Button] = []
var select_index = 0
func _ready()->void:
	hide()
	%PartyButton.pressed.connect(_on_party_button_pressed)
	%EquipmentButton.pressed.connect(_on_equipment_button_pressed)
	%InvButton.pressed.connect(_on_inv_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	set_state(Enums.MenuState.INACTIVE)
	if buttons.is_empty():
		for button in %Options.get_children():
			buttons.append(button)
	
func _on_party_button_pressed():
	set_state(Enums.MenuState.PARTY_MENU_SHOWN)

func _on_equipment_button_pressed():
	set_state(Enums.MenuState.EQUIPMENT_MENU_SHOWN)
	
func _on_inv_button_pressed():
	set_state(Enums.MenuState.INV_MENU_SHOWN)
func _on_quit_button_pressed():
	set_state(Enums.MenuState.QUIT_GAME)
	
func _input(event: InputEvent) -> void:
	if current_state != Enums.MenuState.ACTIVE:
		return
	if event.is_action_pressed('ui_cancel'):
		set_state(Enums.MenuState.CLOSE)
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
	
func set_state(new_state: Enums.MenuState):
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		Enums.MenuState.INACTIVE:
			hide()
		Enums.MenuState.ACTIVE:
			update_focus()
			show()
		Enums.MenuState.PARTY_MENU_SHOWN:
			for button in buttons:
				button.release_focus()
			%PartyInfo.show()
			%PartyInfo.setup()
			%PartyInfo.update_focus()
			%PartyInfo.set_process_input(true)
			set_process_input(false)
		Enums.MenuState.PARTY_MENU_HIDE:
			%PartyInfo.hide()
			set_process_input(true)
			%PartyInfo.set_process_input(false)
			set_state(Enums.MenuState.ACTIVE)
		Enums.MenuState.EQUIPMENT_MENU_SHOWN:
			for button in buttons:
				button.release_focus()
			%EquipmentInfo.show()
			%EquipmentInfo.setup()
			%EquipmentInfo.update_focus()
			%EquipmentInfo.set_process_input(true)
			set_process_input(false)
		Enums.MenuState.EQUIPMENT_MENU_HIDE:
			%EquipmentInfo.hide()
			set_process_input(true)
			%EquipmentInfo.set_process_input(false)
			set_state(Enums.MenuState.ACTIVE)
		Enums.MenuState.INV_MENU_SHOWN:
			for button in buttons:
				button.release_focus()
			%InventoryInfo.show()
			%InventoryInfo.setup()
			%InventoryInfo.update_focus()
			%InventoryInfo.set_process_input(true)
			set_process_input(false)
		Enums.MenuState.INV_MENU_HIDE:
			%InventoryInfo.hide()
			set_process_input(true)
			%InventoryInfo.set_process_input(false)
			set_state(Enums.MenuState.ACTIVE)
		Enums.MenuState.QUIT_GAME:
			get_tree().quit(0)
			
		Enums.MenuState.CLOSE:
			get_tree().call_deferred("set_pause", false)
			set_state(Enums.MenuState.INACTIVE)
