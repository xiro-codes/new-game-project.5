extends GearRes
class_name WeaponGearRes
enum DmgType {
	Fixed,
	Random,
}
enum AtkType {
	Ranged,
	Melee,
	Magic,
}
enum TargetType {
	Single,
	All,
}
@export var dmg_type: DmgType = DmgType.Fixed
@export var atk_type: AtkType = AtkType.Melee
@export var target_type: TargetType = TargetType.Single
@export var damage: int = 10
 
