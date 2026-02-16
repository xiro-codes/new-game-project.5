extends Control
class_name BattleMenu

signal action_selected(gear: GearRes)


var buttons:Array[Button] = []
var select_index = 0
func _ready():
	# Create action buttons.
	for i:Button in %GearActions.get_children():
		buttons.append(i)
	action_selected.connect(owner._on_action_selected)
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_action_selected.bind(buttons[i]))

func on_turn_started(c: Combatant):
	if c.is_in_group("player"):
		show()
		setup_buttons()
	else:
		buttons.all(func(b): b.hide())

func on_turn_ended(c: Combatant):
	hide()
	for i in buttons:
		i.hide()
		i.text = ""
		#i.pressed.disconnect(owner._on_action_selected)
		i.set_meta("gear", null)
	c.action_finished()

func _on_action_selected(b: Button):
	var gear:GearRes = b.get_meta("gear")
	action_selected.emit(gear)

func _input(event: InputEvent) -> void:
	if !buttons.any(func(b): return b.visible) or (owner as BattleManager).current_state == BattleManager.BATTLE_STATE.SELECTING_TARGET :
		return
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

func setup_buttons():
		var data: PartyMember = owner.current_combatant.member_data;
		var main_hand:WeaponGearRes = data.equipment_slots.get(PartyMember.Slot.MainHand)
		var off_hand: WeaponGearRes = data.equipment_slots.get(PartyMember.Slot.OffHand)

		if main_hand:
			buttons[0].text = main_hand.display_name
			buttons[0].set_meta("gear", main_hand)
			buttons[0].show()
		if off_hand:
			buttons[1].text = off_hand.display_name
			buttons[1].set_meta("gear", off_hand)
			buttons[1].show()
