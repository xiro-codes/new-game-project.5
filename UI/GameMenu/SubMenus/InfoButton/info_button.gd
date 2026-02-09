extends Button
class_name InfoButton

func setup(party_member: PartyMember):
	%Level.text = "Lvl. {0}".format([party_member.level])
	%Name.text = "{0}".format([party_member.display_name])
	%Health.text = "{0} / {1}".format([party_member.base_hp, party_member.base_hp])
	%HeadShot.texture = party_member.texture
