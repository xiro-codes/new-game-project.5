extends CanvasLayer

func setup(party_member_id: int, slot_id: int, gear: GearRes):
	var member: PartyMember = StateManager.load_player_data().party[party_member_id]
	%NameGot.text = "{0} GOT".format([member.display_name])
	%ItemName.text = "Item {0}".format([gear.display_name])
	show()
	await get_tree().create_timer(2.5).timeout
	hide()
