extends Button
@export var slot_name = "Left Hand"
func setup(gear_name: String):
	%Label.text = slot_name
	%Gear.text = gear_name
