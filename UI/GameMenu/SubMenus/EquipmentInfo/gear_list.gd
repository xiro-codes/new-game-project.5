extends HBoxContainer
var current_state: Enums.EquipmentSelectionListState;
@onready var list_container: VBoxContainer = $PanelContainer/ScrollContainer/ListContainer

var buttons: Array[Button] = []
var select_index: int = 0

func _ready() -> void:
	set_process_input(false)
	hide()
	set_state(Enums.EquipmentSelectionListState.INACTIVE)

func setup():
	for button in list_container.get_children():
		button.pressed.connect(_on_item_button_press.bind(button))
		buttons.push_back(button)
	set_state(Enums.EquipmentSelectionListState.ACTIVE)

func _on_item_button_press(button: Button):
	var target:PartyMember = %InfoPanel.get_meta("member")
	var item = button.get_meta("item")
	print(item)
	print(target.display_name)

	# target.equip()
	print(button.text)

func update_focus():
	buttons[select_index].grab_focus()

func set_state(new_state: Enums.EquipmentSelectionListState):
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		Enums.EquipmentSelectionListState.INACTIVE:
			list_container.get_children().map(func(c): c.queue_free())
			buttons.clear()
			hide()
		Enums.EquipmentSelectionListState.ACTIVE:
			set_process_input(true)
			update_focus()
			show()

func _input(event: InputEvent) -> void:
	if current_state != Enums.EquipmentSelectionListState.ACTIVE:
		return
	if event.is_action_pressed("ui_cancel"):
		set_state(Enums.EquipmentSelectionListState.INACTIVE)
		%InfoPanel.set_state(Enums.EquipmentSelectionMenuState.ACTIVE)
	var navigated = false
	if event.is_action_pressed("move_backward"):
		select_index = (select_index + 1) % buttons.size()
		get_viewport().set_input_as_handled()
		navigated = true
	elif event.is_action_pressed("move_forward"):
		if select_index == 0:
			select_index  = buttons.size() - 1
		else:
			select_index -= 1
		navigated = true
		get_viewport().set_input_as_handled()
	if navigated:
		update_focus()
