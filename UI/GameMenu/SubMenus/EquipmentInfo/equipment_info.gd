extends MarginContainer
@export var buttons: Array[InfoButton] = []
var select_index:int = 0

var current_state: Enums.EquipmentMenuState

func _ready() -> void:
	set_process_input(false)
	hide()
	set_state(Enums.EquipmentMenuState.INACTIVE)
	for button in buttons:
		button.pressed.connect(_on_info_button_pressed.bind(button))


func setup():
	set_state(Enums.EquipmentMenuState.ACTIVE)
	var party_members:Array[PartyMember]= StateManager.load_player_data().party
	for i in range(buttons.size()):
		buttons[i].setup(party_members[i])

func _input(event: InputEvent) -> void:
	if current_state != Enums.EquipmentMenuState.ACTIVE:
		return
	if event.is_action_pressed("ui_cancel"):
		set_state(Enums.EquipmentMenuState.INACTIVE)
		owner.set_state(Enums.MenuState.EQUIPMENT_MENU_HIDE)

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
	var party_member:PartyMember= StateManager.load_player_data().party[select_index]
	buttons[select_index].set_meta("member",party_member)

func _on_info_button_pressed(button: InfoButton):
	print("button selected")
	set_state(Enums.EquipmentMenuState.EQUIPMENT_SELECTION_ACTIVE)
	for _button in buttons:
		_button.release_focus()
	%InfoPanel.show()
	var member = button.get_meta("member")
	%InfoPanel.setup(member)

func set_state(new_state: Enums.EquipmentMenuState):
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		Enums.EquipmentMenuState.INACTIVE:
			hide()
		Enums.EquipmentMenuState.ACTIVE:
			update_focus()
			show()
		Enums.EquipmentMenuState.EQUIPMENT_SELECTION_ACTIVE:
			set_process_input(false)
			pass
		Enums.EquipmentMenuState.EQUIPMENT_SELECTION_HIDE:
			%InfoPanel.hide()
			set_process_input(true)
			set_state(Enums.EquipmentMenuState.ACTIVE)
