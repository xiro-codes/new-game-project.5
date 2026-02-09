extends Control
@export var name_slots:Array[Label] = []
@export var exp_slots: Array[Label] = []
@export var exp_gained:int = 0
func setup(party: Array[PartyMember]):
	for i in range(party.size()):
		name_slots[i].get_parent().get_parent().show()
		name_slots[i].text = party[i].display_name
		exp_slots[i].text = "{0} EXP Gained".format([exp_gained])
		
	
