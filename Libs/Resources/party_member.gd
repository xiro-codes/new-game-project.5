## Defines the data structure for a party member using a Resource.
## This allows creating party member templates or saving/loading character data
## independently from scenes. It stores core stats, equipment, and visual information.
extends Resource
class_name PartyMember
## The name of the party member as it should be displayed in the UI.
@export var display_name: String = "Default"

## The current level of the party member. Often influences stats and abilities.
@export var level: int = 1

## The base Health Points of the party member before any modifiers (like level ups, gear, or status effects) are applied.
@export var base_hp: int = 100
@export var current_hp: int = 100
@export var speed: float = .075
## The base defense value against physical/melee attacks. Represents inherent toughness or starting armor value.
@export var base_melee_shield: int = 25

## The base defense value against magical attacks. Represents inherent magical resistance.
@export var base_magic_shield: int = 15

## An array holding references to the equipped weapon(s).
## Expected to contain Resource items inheriting from a custom 'GearRes' class (or similar).
@export var weapon_gear: Array[GearRes] = [] 
##TODO: This well be the new Equipment system variables
enum ArmSlot {
	LeftHand,
	RightHand,
}
enum BodySlot {
	Head,
	Chest,
	Feet,
	Ring,
}
@export var weapon_slots: Dictionary[ArmSlot, WeaponGearRes] = {}
@export var body_slots: Dictionary[BodySlot, DefenceGearRes] = {}
## The primary texture used for this party member's visual representation.
## This could be a portrait, a sprite sheet, or another texture used in the game.
@export var texture: Texture

@export var exp_owned:int : set = set_exp_owned

func set_exp_owned(value):
	exp_owned = value
	if exp_owned > 100:
		exp_owned -= 100
		level += 1
		base_hp += randi_range(2, 15)
		base_melee_shield += randi_range(2, 15)
		base_melee_shield += randi_range(2, 15)
		speed += .005
