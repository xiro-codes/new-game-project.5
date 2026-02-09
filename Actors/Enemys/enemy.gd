extends Node3D
class_name Enemy

@export var monster_party : Array[MonsterPartyMember] = []
@export var tile_id: String =  "00"

func _ready() -> void:
	$Label3D.text = tile_id
