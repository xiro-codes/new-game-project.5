extends MarginContainer
@export var buttons: Array[Button] = []
var select_index:int = 0

var current_state: Enums.EquipmentSelectionMenuState

func _ready() -> void:
	set_process_input(false)
	hide()
	set_state(Enums.EquipmentSelectionMenuState.INACTIVE)

	for button in buttons:
		button.pressed.connect(_on_equipment_button_press.bind(button))

func setup(member: PartyMember):
	set_state(Enums.EquipmentSelectionMenuState.ACTIVE)
	set_meta("member", member)
	set_process_input(true)
	setup_details_panel(member)

func setup_details_panel(member: PartyMember):
	%Headshot.texture = member.texture
	%Level.text = "Level {0}".format([member.level])
	%Name.text = "{0}".format([member.display_name])
	var main_hand = member.equipment_slots.get(PartyMember.Slot.MainHand);
	if main_hand is WeaponGearRes:
		%LHandButton.text = main_hand.display_name;
	var off_hand = member.equipment_slots.get(PartyMember.Slot.OffHand);
	if off_hand is WeaponGearRes:
		%RHandButton.text = off_hand.display_name;


func _on_equipment_button_press(button: Button):
	var items:Array[GearRes] = InvManager.get_items()
	%GearList.list_container.get_children().map(func(child): child.queue_free())
	for item in items:
		var label = Button.new()
		label.text = item.display_name
		%GearList.list_container.add_child(label)
		label.set_meta("item", item)
	%GearList.setup();
	set_state(Enums.EquipmentSelectionMenuState.SELECTING)
	%GearList.grab_focus()

func _input(event: InputEvent) -> void:
	if current_state != Enums.EquipmentSelectionMenuState.ACTIVE:
		return
	if event.is_action_pressed("ui_cancel"):
		set_state(Enums.EquipmentSelectionMenuState.INACTIVE)
		owner.set_state(Enums.EquipmentMenuState.EQUIPMENT_SELECTION_HIDE)

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


func set_state(new_state: Enums.EquipmentSelectionMenuState):
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		Enums.EquipmentSelectionMenuState.INACTIVE:
			hide()
		Enums.EquipmentSelectionMenuState.SELECTING:
			set_process_input(false)
		Enums.EquipmentSelectionMenuState.ACTIVE:
			set_process_input(true)
			update_focus()
			show()
