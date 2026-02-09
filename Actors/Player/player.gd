extends Node3D
class_name Player
@export var move_speed = 5.0
var target_grid_position: Vector3i = Vector3i.ZERO # Store grid coordinates
var is_moving: bool = false
@export var grid_map: GridMap # Assuming the GridMap is the parent
@export var init_player_party: Array[PartyMember] = []
var pdata: PlayerData
var player_party: Array[PartyMember]
func _ready():
	call_deferred("_find_and_set_start_position")
	if grid_map == null:
		printerr("Error: GridMap not found as parent!")
		set_process(false)
		set_physics_process(false)
	
	pdata = StateManager.load_player_data()
	if pdata:
		player_party = pdata.party
	else:
		pdata = PlayerData.new()
		player_party = init_player_party
		pdata.party
	snap_to_grid() # Snap to the initial grid cell
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		GameMenu.set_state(Enums.MenuState.ACTIVE)
		get_tree().call_deferred("set_pause", true)

		
## Searches the GridMap for the entrance tile and sets the player's position to it.
## Returns true if the entrance was found and position set, false otherwise.
func _find_and_set_start_position() -> bool:
	if not grid_map:
		printerr("Player Error: Cannot find start position, grid_map is null.")
		return false

	# Try to get the ENTRANCE_ITEM_ID from the GridMap node, assuming it's the Dungeon script
	var entrance_id: int = -1
	if grid_map is Dungeon:
		# Use the constant directly from the Dungeon class instance
		entrance_id = (grid_map as Dungeon).ENTRANCE_ITEM_ID
	else:
		printerr("Player Error: GridMap node is not the 'Dungeon' script. Cannot determine ENTRANCE_ITEM_ID.")
		# Alternative: Hardcode if necessary, e.g., entrance_id = 2
		# Alternative: Search for the Dungeon node elsewhere if structure is different
		return false # Cannot proceed without knowing the entrance ID

	if entrance_id == GridMap.INVALID_CELL_ITEM or entrance_id < 0: # Check if ID is valid
		printerr("Player Error: Invalid ENTRANCE_ITEM_ID obtained from Dungeon.")
		return false

	print("Player: Searching for entrance tile with ID %d..." % entrance_id)
	# Iterate through the cells used by the GridMap
	for cell_coords in grid_map.get_used_cells():
		# Check only ground level (Y=0) and if the item matches the entrance ID
		if cell_coords.y == 0 and grid_map.get_cell_item(cell_coords) == entrance_id:
			print("Player: Found entrance tile at grid coordinates: %s" % cell_coords)
			# Set both the logical target and the visual world position
			target_grid_position = cell_coords
			position = grid_map.map_to_local(cell_coords)
			# Let physics_process handle the final Y adjustment (e.g., position.y = 0.5)
			is_moving = false # Make sure the player isn't trying to move initially
			print("Player: Position set to %s" % position)
			return true # Successfully positioned the player

	# If the loop completes without finding the entrance
	printerr("Player Error: Entrance tile (ID: %d) not found in GridMap's used cells!" % entrance_id)
	return false
	
func _physics_process(delta):
	if is_moving:
		var target_world_position = grid_map.map_to_local(target_grid_position)
		if position.distance_to(target_world_position) < 0.1:
# Arrived at the target cell
			position = target_world_position # Snap exactly
			is_moving = false

			# Check if the cell we arrived at is the exit
			var current_cell_item = grid_map.get_cell_item(target_grid_position)
			var exit_id = -1
			var heal_id = -1
			if grid_map is Dungeon:
				exit_id = (grid_map as Dungeon).EXIT_ITEM_ID
				heal_id = (grid_map as Dungeon).HEAL_ITEM_ID
			else:
				printerr("Player Error: Cannot check for exit tile, GridMap is not Dungeon.")
			
			if exit_id != -1 and current_cell_item == exit_id:
				# Use call_deferred to avoid potential issues with modifying the world
				# or starting an async function directly within physics process.
				call_deferred("_handle_exit_reached")
				return # Stop further processing this frame after triggering exit logic
			elif heal_id != -1 and current_cell_item == heal_id:
				call_deferred("_handle_heal_reached")
		else:
			var direction = (target_world_position - position).normalized()
			position += direction * move_speed * delta
		return

	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	if input_dir.length_squared() > 0:
		var current_grid_coords = grid_map.local_to_map(position)
		var next_grid_coords = current_grid_coords + Vector3i(round(input_dir.x), 0, round(input_dir.z)) # Move one grid unit at a time
		if grid_map.get_cell_item(next_grid_coords) != -1: # Check for a valid tile
			#print(grid_map.get_cell_item(next_grid_coords))
			if next_grid_coords != target_grid_position:
				target_grid_position = next_grid_coords
				is_moving = true
	else:
		# Snap to the grid when WASD movement stops
		if not is_moving:
			snap_to_grid()
	position.y = .5

func snap_to_grid():
	if grid_map:
		target_grid_position = grid_map.local_to_map(position)
		position = grid_map.map_to_local(target_grid_position) 

func _handle_exit_reached() -> void:
	print("Player reached the exit!")

	if not (grid_map is Dungeon):
		printerr("Player Error: Cannot regenerate map, GridMap node is not the Dungeon script.")
		return

	# Cast grid_map to Dungeon to call its methods
	var dungeon_node: Dungeon = grid_map as Dungeon

	print("Regenerating dungeon...")
	# Ensure the player isn't trying to move while regenerating
	is_moving = false

	# Await the completion of the dungeon generation process
	await dungeon_node.generate_maze()

	print("Dungeon regeneration complete.")

	# Find the new entrance and move the player there
	if _find_and_set_start_position():
		print("Player moved to the new entrance.")
	else:
		printerr("Player Error: Failed to find the new entrance after regeneration!")
		# Handle this error case - maybe move player to 0,0 or retry?

func _handle_heal_reached():
	for member in player_party:
		member.current_hp = member.base_hp
	
func _enter_event(area) -> void:
	if area is Enemy:
		var enemy: Enemy = area as Enemy
		BattleScene.monster_party_data= area.monster_party.duplicate()
		BattleScene.player_party_data = self.player_party
		area.queue_free()
		pdata.party = player_party
		StateManager.save_player_data(pdata)
		get_tree().call_deferred("set_pause", true)
		BattleScene.set_state(BattleManager.BATTLE_STATE.ACTIVE)
	elif area is Item:
		var item: Item = area as Item
		#if self.player_party[item.is_for].weapon_gear[item.slot].damage >= item.weapon_gear.damage:
			#return
		#self.player_party[item.is_for].weapon_gear[item.slot] = item.weapon_gear
		print("got {0}".format([item.gear.display_name]))
		InvManager.add_item(item.gear)
		PopupInfo.setup(item.is_for, item.slot, item.gear)
		area.queue_free()
