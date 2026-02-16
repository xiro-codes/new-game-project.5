extends Resource
class_name GearRes
@export var display_name:String = "Default Gear"
@export var equiped:bool = false
@export var valid_slots: Array[PartyMember.Slot] = [PartyMember.Slot.MainHand, PartyMember.Slot.OffHand]
