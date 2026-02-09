extends Node
@export var items: Array[GearRes] = []

# Function to add an item
func add_item(item_resource: GearRes):
	if not item_resource:
		printerr("Attempted to add a null item resource.")
		return
	items.append(item_resource)

func get_items()->Array[GearRes]:
	return items

# Function to remove an item
func remove_item(item_resource: GearRes, quantity_to_remove: int = 1):
	if not item_resource:
		printerr("Attempted to remove a null item resource.")
		return
	items.remove_at(items.find(item_resource))
