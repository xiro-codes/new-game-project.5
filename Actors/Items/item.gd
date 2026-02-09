extends Area3D
class_name Item
@export var tile_id: String =  "00"
@export_range(0, 2) var is_for:int = 0
@export_range(0, 1) var slot: int = 0
@export var gear: GearRes

func _ready() -> void:
	$Label3D.text = tile_id
