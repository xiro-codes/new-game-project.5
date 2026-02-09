extends MarginContainer
@export var buttons: Array[InfoButton] = []
var select_index:int = 0
func _ready() -> void:
	set_process_input(false)
	hide()
	
func setup():
	var party:Array[PartyMember] = StateManager.load_player_data().party
	for i in range(buttons.size()):
		buttons[i].setup(party[i])
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		owner.set_state(Enums.MenuState.PARTY_MENU_HIDE)

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
	var member:PartyMember = StateManager.load_player_data().party[select_index]
	%Level.text = "Level {0}".format([member.level])
	%Name.text = member.display_name
	%Headshot.texture = member.texture
	%Exp.text = "Experience {0}".format([member.exp_owned])
	%Health.text = "{0} / {1}".format([member.current_hp, member.base_hp ])
	%Speed.text = "{0}".format([member.speed * 100])
	%PShield.text = "{0}".format([member.base_melee_shield])
	%MShield.text = "{0}".format([member.base_magic_shield])
