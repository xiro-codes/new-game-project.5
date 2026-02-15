extends PartyMember
class_name MonsterPartyMember

@export var exp_value = 10

func scale(value: float):
	base_hp *= value
	#for weapon in weapon_gear:
	#	weapon.damage *= value
	base_magic_shield *= value
	base_melee_shield *= value
	current_hp = base_hp
	level *= value
