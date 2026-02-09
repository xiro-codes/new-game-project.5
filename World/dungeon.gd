# Dungeon.gd
## Procedurally generates a dungeon layout on a GridMap using Prim's algorithm
## for the base maze structure, carves corridors, expands intersections into rooms,
## removes disconnected areas, and spawns enemies based on configured scenes and probabilities.
## Runs in the editor via a tool button for design-time generation.
@tool
extends GridMap
class_name Dungeon

# --- Constants ---

## The GridMap item ID representing an impassable wall tile. Should correspond to a wall tile in the MeshLibrary.
const WALL_ITEM_ID: int = -1
## The GridMap item ID representing a standard path/corridor tile.
const PATH_ITEM_ID: int = 0
## The GridMap item ID representing a tile that is part of a larger room (expanded intersection).
const ROOM_ITEM_ID: int = 1
## The GridMap item ID representing the dungeon entrance tile. Must match MeshLibrary.
const ENTRANCE_ITEM_ID: int = 2
## The GridMap item ID representing the dungeon exit tile. Must match MeshLibrary.
const EXIT_ITEM_ID: int = 3 
## The GridMap item ID representing the dungeon heal tile. Must match MeshLibrary.
const HEAL_ITEM_ID: int = 4
## The width (in GridMap cells) of the carved corridors.
const PATH_WIDTH: int = 1
## Predefined directions (orthogonal) used for neighbor checking in 2D grids (conceptual and GridMap).
const DIRS: Array[Vector2i] = [ Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP ]
## Vertical offset from the GridMap cell floor where enemies initially appear upon instantiation.
const ENEMY_SPAWN_Y_OFFSET: float = 0.5
## The final target Y position (local) for spawned enemies after placement.
const ENEMY_FINAL_Y_POS: float = 0.65

const ITEM_SPAWN_Y_OFFSET: float = 0.65

# --- Exports ---



@export_group("Maze Generation - Conceptual Layout")
## The width of the high-level conceptual grid used by Prim's algorithm.
@export var conceptual_width: int = 20
## The height of the high-level conceptual grid used by Prim's algorithm.
@export var conceptual_height: int = 20
## The minimum number of empty wall cells between the edge of a conceptual block and the start of its path node.
@export var min_spacing: int = 3
## The maximum number of empty wall cells between the edge of a conceptual block and the start of its path node.
@export var max_spacing: int = 5
@export var scaling:float = .75
@export_group("Intersection Rooms")
## The minimum size (width/height in cells) for rooms generated at intersections. Must be odd.
@export var min_intersection_room_size: int = 5
## The maximum size (width/height in cells) for rooms generated at intersections. Must be odd.
@export var max_intersection_room_size: int = 9
## The maximum number of intersection rooms to create. Set to -1 for no limit.
@export var max_intersection_rooms: int = 10
## The probability (0.0 to 1.0) that a valid intersection will be expanded into a room.
@export_range(0.0, 1.0) var intersection_to_room_chance: float = 0.8

@export_group("Enemy Spawning")
## Array of PackedScene resources representing the different types of enemies that can be spawned.
@export var enemy_scenes: Array[PackedScene]

## The probability (0.0 to 1.0) that an enemy will spawn on a tile identified as part of an intersection or room.
@export_range(0.0, 1.0) var intersection_spawn_chance: float = 0.6
## The probability (0.0 to 1.0) that an enemy will spawn on a standard path/corridor tile.
@export_range(0.0, 1.0) var path_spawn_chance: float = 0.1
## The absolute maximum number of enemies to spawn across the entire dungeon.
@export var max_enemies_to_spawn: int = 15

@export_group("Item Spawning")
## Array of PackedScene resources representing the different types of items that can be spawned.
@export var item_scenes: Array[PackedScene]
## The absolute maximum number of items to spawn across the entire dungeon. Set to -1 for no limit.
@export var max_items_to_spawn: int = 10
## The probability (0.0 to 1.0) that an item will spawn on a dead-end tile (path with only 1 connection).
@export_range(0.0, 1.0) var dead_end_item_chance: float = 0.7
## The probability (0.0 to 1.0) that an item will spawn on a tile identified as part of a room.
@export_range(0.0, 1.0) var room_item_chance: float = 0.4
## The probability (0.0 to 1.0) that an item will spawn on a standard path/corridor tile (not a dead end).
@export_range(0.0, 1.0) var path_item_chance: float = 0.05



# --- Maze Generation State ---
## Stores the Vector2i coordinates of visited cells in the conceptual grid during Prim's algorithm.
var visited_cells: Array[Vector2i] = []
## Stores the connections (as pairs of Vector2i conceptual coordinates) found by Prim's algorithm.
var connections: Array[Array] = [] # Array[ [Vector2i, Vector2i] ]
## Dictionary mapping conceptual cell coordinates (Vector2i) to their connection count (int). Used to find intersections.
var connection_counts: Dictionary = {} # { Vector2i: int }
## Dictionary mapping conceptual cell coordinates (Vector2i) to their primary placed GridMap position (Vector2i).
var cell_grid_pos: Dictionary = {} # { Vector2i: Vector2i }

# --- Internal Variables ---
## The calculated size (in GridMap cells) of one conceptual unit block (spacing + path width).
var unit_size: int
## The calculated total width of the GridMap in cells.
var grid_map_width: int = 0
## The calculated total height (depth along Z) of the GridMap in cells.
var grid_map_height: int = 0
## Counter for the number of enemies successfully spawned in the current session.
var _spawned_count: int = 0
## Counter for the number of items successfully spawned in the current session.
var _items_spawned_count: int = 0

# --- Godot Functions ---

## Called when the node is ready. Calculates dimensions, sets up RNG,
## and defers enemy spawning if not in the editor.
func _ready() -> void:
	_calculate_dimensions()
	# Use a fixed seed in editor for consistent generation previews (unless manually randomized)
	# Use a random seed at runtime for varied dungeons each play session.
	if Engine.is_editor_hint(): seed(hash("dungeon_editor_seed")) # Consider exposing seed or using a timestamp
	else: randomize()
	# Defer spawning until the next frame when running the game
	# Ensures the GridMap and layout are fully processed.
	generate_maze()

## Handles deferred enemy spawning called from _ready.
## Ensures dimensions are calculated and then calls the main spawn function.
## Uses call_deferred again for spawn_enemies to ensure it runs even later if needed.
func _deferred_ready_spawn():
	if grid_map_width == 0 or grid_map_height == 0: _calculate_dimensions()
	call_deferred("spawn_enemies") # Defer again just in case _calculate_dimensions needed setup time
	call_deferred("_spawn_items")
	
## Calculates the required GridMap dimensions based on the conceptual layout and spacing settings.
func _calculate_dimensions() -> void:
	# Ensure unit size is at least 1 + path width
	unit_size = max(1, max_spacing) + PATH_WIDTH
	grid_map_width = conceptual_width * unit_size
	grid_map_height = conceptual_height * unit_size


# --- Main Generation Function ---

## Orchestrates the entire dungeon generation process.
## Called by the editor tool button or potentially manually.
## Clears previous state, runs generation steps sequentially.
## Uses 'await' during some steps to allow visual updates in the editor.
func generate_maze() -> void:
	print("Generating dungeon...")
	_calculate_dimensions()
	if grid_map_width <= 0 or grid_map_height <= 0:
		printerr("GridMap dimensions invalid (width/height <= 0). Check conceptual size and spacing.")
		return

	# 1. Reset state from any previous generation
	_clear_generation_state()
	# 2. Initialize the GridMap with walls
	_fill_grid_with_walls()
	# 3. Generate the conceptual maze layout using Prim's algorithm
	_run_prims_algorithm()
	# 4. Count connections for each conceptual cell (identifies intersections)
	_calculate_connection_counts()
	# 5. Place initial path nodes on the GridMap based on conceptual layout and spacing
	_place_initial_path_nodes()
	# 6. Carve corridors between connected path nodes on the GridMap
	_carve_corridors()
	# 7. Clean up any single path tiles left isolated (minor visual artifact)
	_remove_isolated_path_tiles() # await allows editor refresh
	# 8. Expand intersections into larger rooms based on configuration
	_expand_intersections() # await allows editor refresh
	# 9. Perform flood fill to find the main reachable area and remove disconnected islands
	_remove_disconnected_islands() # await allows editor refresh
	
	_place_entrance_and_exit()
	_place_heals()
	call_deferred("_deferred_ready_spawn")
	scaling += .25
	print("Dungeon generation complete.")


# --- Maze Generation Steps (Private Helper Functions) ---

## Resets all state variables used during the generation process.
func _clear_generation_state() -> void:
	visited_cells.clear()
	connections.clear()
	connection_counts.clear()
	cell_grid_pos.clear()

## Clears the entire GridMap and fills every cell on the ground plane (Y=0) with the WALL_ITEM_ID.
func _fill_grid_with_walls() -> void:
	clear() # Clear existing GridMap contents
	for x in range(grid_map_width):
		for y in range(grid_map_height):
			set_cell_item(Vector3i(x, 0, y), WALL_ITEM_ID)

## Implements Randomized Prim's algorithm on the conceptual grid.
## Starts from the center, maintains a list of "walls" (potential connections) between visited and unvisited cells,
## randomly picks a wall, connects the cells if one is unvisited, adds the new cell's walls, and repeats.
## Populates `visited_cells` and `connections`.
func _run_prims_algorithm() -> void:
	var wall_list: Array = [] # List of potential connections [cell1, cell2]
	# Start Prim's from the center of the conceptual grid
	var start_mx: int = conceptual_width / 2
	var start_my: int = conceptual_height / 2
	var start_pos := Vector2i(start_mx, start_my)

	if not is_valid_maze_cell(start_pos):
		printerr("Start position outside conceptual bounds! Check conceptual_width/height.")
		return

	visited_cells.append(start_pos)
	add_conceptual_walls(start_pos, wall_list) # Add walls of the starting cell

	while not wall_list.is_empty():
		# Randomly select a wall from the list
		var wall_index: int = randi() % wall_list.size()
		var wall: Array = wall_list.pop_at(wall_index) # [Vector2i, Vector2i]
		var cell1: Vector2i = wall[0]
		var cell2: Vector2i = wall[1]

		var visited1: bool = visited_cells.has(cell1)
		var visited2: bool = visited_cells.has(cell2)

		# If exactly one of the cells connected by the wall is visited
		if visited1 != visited2:
			var unvisited_cell: Vector2i = cell2 if visited1 else cell1
			if is_valid_maze_cell(unvisited_cell): # Ensure it's within bounds
				# Mark the unvisited cell as visited
				visited_cells.append(unvisited_cell)
				# Add this connection (wall) to the list of actual maze connections
				connections.append(wall)
				# Add the walls of the newly visited cell to the wall list
				add_conceptual_walls(unvisited_cell, wall_list)

## Iterates through the `connections` list generated by Prim's and counts
## how many connections each conceptual cell has. Populates `connection_counts`.
func _calculate_connection_counts() -> void:
	for connection in connections:
		var cell1: Vector2i = connection[0]
		var cell2: Vector2i = connection[1]
		connection_counts[cell1] = connection_counts.get(cell1, 0) + 1
		connection_counts[cell2] = connection_counts.get(cell2, 0) + 1

## Places a single PATH_ITEM_ID tile on the GridMap for each visited conceptual cell.
## The position within the corresponding 'unit block' on the GridMap is randomized
## based on `min_spacing` and `max_spacing`. Populates `cell_grid_pos`.
func _place_initial_path_nodes() -> void:
	for mx in range(conceptual_width):
		for my in range(conceptual_height):
			var conceptual_cell := Vector2i(mx, my)
			if visited_cells.has(conceptual_cell):
				# Calculate the GridMap bounds for this conceptual cell's block
				var block_start_x: int = mx * unit_size
				var block_start_y: int = my * unit_size
				var block_end_x: int = block_start_x + unit_size
				var block_end_y: int = block_start_y + unit_size

				# Calculate the placement area within the block based on spacing
				var place_start_x: int = block_start_x + min_spacing
				var place_end_x: int = block_end_x - min_spacing
				var place_start_y: int = block_start_y + min_spacing
				var place_end_y: int = block_end_y - min_spacing

				# Choose a random grid position within the placement area
				var room_gx: int
				var room_gy: int
				# Handle cases where min/max spacing makes the placement area width/height 1 or less
				if place_start_x < place_end_x: room_gx = randi_range(place_start_x, place_end_x - 1)
				else: room_gx = (place_start_x + place_end_x - 1) / 2 # Center if range is invalid/zero

				if place_start_y < place_end_y: room_gy = randi_range(place_start_y, place_end_y - 1)
				else: room_gy = (place_start_y + place_end_y - 1) / 2 # Center if range is invalid/zero

				# Clamp values just in case calculations go slightly out of bounds
				room_gx = clamp(room_gx, 0, grid_map_width - 1)
				room_gy = clamp(room_gy, 0, grid_map_height - 1)

				# Place the initial path node
				set_cell_item(Vector3i(room_gx, 0, room_gy), PATH_ITEM_ID)
				# Store the mapping from conceptual cell to this GridMap position
				cell_grid_pos[conceptual_cell] = Vector2i(room_gx, room_gy)

## Draws lines (corridors) on the GridMap between the initial path nodes
## corresponding to connected conceptual cells found by Prim's algorithm (`connections`).
## Uses the `draw_line_on_gridmap` helper function.
func _carve_corridors() -> void:
	for connection in connections:
		var cell1: Vector2i = connection[0]
		var cell2: Vector2i = connection[1]
		# Ensure both connected conceptual cells have a placed GridMap position
		if cell_grid_pos.has(cell1) and cell_grid_pos.has(cell2):
			var gp1: Vector2i = cell_grid_pos[cell1] # GridMap position for cell1
			var gp2: Vector2i = cell_grid_pos[cell2] # GridMap position for cell2
			# Draw a line of path tiles between these two points
			draw_line_on_gridmap(gp1, gp2, PATH_ITEM_ID)

## Scans the GridMap for PATH_ITEM_ID tiles that have no adjacent PATH_ITEM_ID
## or ROOM_ITEM_ID neighbors. These are likely isolated artifacts from the carving process.
## Sets them back to WALL_ITEM_ID. Uses `await` to allow visual updates.
func _remove_isolated_path_tiles() -> void:
	var tiles_to_remove: Array[Vector2i] = []
	for gx in range(grid_map_width):
		for gy in range(grid_map_height):
			var cell_v3i := Vector3i(gx, 0, gy)
			if get_cell_item(cell_v3i) == PATH_ITEM_ID:
				# Check if this path tile has any path/room neighbors
				if not has_path_neighbor(gx, gy, grid_map_width, grid_map_height, PATH_ITEM_ID):
					tiles_to_remove.append(Vector2i(gx, gy))

	# Remove the identified isolated tiles
	for tile_pos in tiles_to_remove:
		set_cell_item(Vector3i(tile_pos.x, 0, tile_pos.y), WALL_ITEM_ID)
		# Allow the editor/game to process a frame to see the change gradually
		#await get_tree().process_frame

## Identifies conceptual cells with more than two connections (intersections).
## For a subset of these (based on `max_intersection_rooms` and `intersection_to_room_chance`),
## carves out a square room centered on the intersection's GridMap position.
## Room size is randomized between `min/max_intersection_room_size`. Uses `await`.
func _expand_intersections() -> void:
	var potential_room_centers: Array[Vector2i] = []
	var rooms_created_count: int = 0

	# 1. Identify potential centers for rooms (intersections with >2 connections)
	for mx in range(conceptual_width):
		for my in range(conceptual_height):
			var conceptual_cell := Vector2i(mx, my)
			# Check if it's a visited cell, has >2 connections, and has a grid position mapped
			if visited_cells.has(conceptual_cell) and \
			   connection_counts.get(conceptual_cell, 0) > 2 and \
			   cell_grid_pos.has(conceptual_cell):
				var main_grid_pos: Vector2i = cell_grid_pos[conceptual_cell]

				# Basic check to ensure room won't go out of bounds (needs buffer)
				# Ensure max size is odd for centering
				var effective_max_size = max(min_intersection_room_size, max_intersection_room_size)
				if effective_max_size % 2 == 0: effective_max_size -= 1 # Force odd
				effective_max_size = max(1, effective_max_size) # Ensure at least 1
				var buffer = (effective_max_size / 2) + 2 # Safety buffer

				if main_grid_pos.x >= buffer and main_grid_pos.x < grid_map_width - buffer and \
				   main_grid_pos.y >= buffer and main_grid_pos.y < grid_map_height - buffer:
					potential_room_centers.append(main_grid_pos)

	# 2. Shuffle and iterate through potential centers to create rooms
	potential_room_centers.shuffle()
	for main_grid_pos in potential_room_centers:
		# Stop if max room count is reached (and limit is >= 0)
		if max_intersection_rooms >= 0 and rooms_created_count >= max_intersection_rooms: break
		# Skip based on chance
		if randf() >= intersection_to_room_chance: continue

		# Determine room size for this specific room
		# Ensure min/max sizes are odd
		var effective_min_size = max(1, min_intersection_room_size)
		if effective_min_size % 2 == 0: effective_min_size += 1 # Force odd
		var effective_max_size_for_this_room = max(effective_min_size, max_intersection_room_size)
		if effective_max_size_for_this_room % 2 == 0: effective_max_size_for_this_room -= 1 # Force odd

		# Calculate number of possible odd sizes and pick one randomly
		var num_size_choices = (effective_max_size_for_this_room - effective_min_size) / 2 + 1
		if num_size_choices < 1: # Handle edge case where min=max
			num_size_choices = 1
			effective_min_size = effective_max_size_for_this_room

		var current_room_size = effective_min_size
		if num_size_choices > 1:
			var size_idx = randi() % num_size_choices
			current_room_size = effective_min_size + size_idx * 2 # Step by 2 to keep it odd

		var room_radius: int = current_room_size / 2 # Integer division is fine here

		# Calculate room bounds
		var room_start_x: int = main_grid_pos.x - room_radius
		var room_end_x: int = main_grid_pos.x + room_radius
		var room_start_y: int = main_grid_pos.y - room_radius
		var room_end_y: int = main_grid_pos.y + room_radius

		# 3. Carve the room
		var did_carve = false
		for gx in range(room_start_x, room_end_x + 1):
			for gy in range(room_start_y, room_end_y + 1):
				# Check bounds before setting item
				if gx >= 0 and gx < grid_map_width and gy >= 0 and gy < grid_map_height:
					set_cell_item(Vector3i(gx, 0, gy), ROOM_ITEM_ID)
					did_carve = true

		# If carving happened, increment count and yield frame
		if did_carve:
			rooms_created_count += 1
			#await get_tree().process_frame # Allow editor refresh

## Performs a Breadth-First Search (Flood Fill) starting from a known path/room tile
## (ideally near the center) to find all reachable path/room tiles. Any path/room tiles
## not reached by the flood fill are considered part of a disconnected "island" and
## are converted back to walls. Ensures the generated dungeon is fully connected. Uses `await`.
func _remove_disconnected_islands() -> void:
	print("Checking for and removing islands...")
	var reachable_tiles: Dictionary = {} # Using Dictionary as a Set: Vector2i -> bool
	var queue: Array[Vector2i] = []
	var start_node_found: bool = false

	# 1. Find a valid starting point for the flood fill
	# Try the conceptual center's mapped grid position first
	var start_conceptual_pos := Vector2i(conceptual_width / 2.0, conceptual_height / 2.0)
	var start_grid_pos: Vector2i = cell_grid_pos.get(start_conceptual_pos, Vector2i(-1,-1))

	if start_grid_pos != Vector2i(-1,-1): # Check if center exists in mapping
		var item_id = get_cell_item(Vector3i(start_grid_pos.x, 0, start_grid_pos.y))
		# Check if the tile at the center's mapped position is walkable
		if item_id == PATH_ITEM_ID or item_id == ROOM_ITEM_ID:
			queue.append(start_grid_pos)
			reachable_tiles[start_grid_pos] = true # Mark as reachable
			start_node_found = true
			# print("Flood fill starting from conceptual center grid pos: ", start_grid_pos)

	# Fallback: If center wasn't usable, find the first available path/room tile
	if not start_node_found:
		print("  Center start node not found or invalid, searching for fallback...")
		var used_cells = get_used_cells() # Gets Array[Vector3i] of all non-empty cells
		for cell_v3i in used_cells:
			var item_id = get_cell_item(cell_v3i)
			if item_id == PATH_ITEM_ID or item_id == ROOM_ITEM_ID:
				var cell_v2i := Vector2i(cell_v3i.x, cell_v3i.z) # Convert to 2D for queue/dict
				queue.append(cell_v2i)
				reachable_tiles[cell_v2i] = true
				start_node_found = true
				print("  Flood fill starting from fallback grid pos: ", cell_v2i)
				break # Found one, start the fill

	if not start_node_found:
		printerr("Could not find any valid path/room tile to start flood fill. Skipping island removal.")
		return

	# 2. Perform BFS (Flood Fill)
	var head = 0 # Current index in the queue
	while head < queue.size():
		var current_pos: Vector2i = queue[head]
		head += 1

		# Explore neighbors
		for dir in DIRS: # Check 4 orthogonal neighbors
			var neighbor_pos: Vector2i = current_pos + dir

			# Check bounds
			if neighbor_pos.x < 0 or neighbor_pos.x >= grid_map_width or \
			   neighbor_pos.y < 0 or neighbor_pos.y >= grid_map_height:
				continue

			# Check if already visited/marked as reachable
			if reachable_tiles.has(neighbor_pos):
				continue

			# Check if it's a navigable tile (path or room)
			var neighbor_item_id = get_cell_item(Vector3i(neighbor_pos.x, 0, neighbor_pos.y))
			if neighbor_item_id == PATH_ITEM_ID or neighbor_item_id == ROOM_ITEM_ID:
				reachable_tiles[neighbor_pos] = true # Mark as reachable
				queue.append(neighbor_pos) # Add to queue for exploration

	print("  Flood fill completed. Found %d reachable path/room tiles." % reachable_tiles.size())

	# 3. Identify and remove island tiles (those not in reachable_tiles)
	var islands_removed_count = 0
	var tiles_to_remove: Array[Vector2i] = []

	# Iterate through all cells to find unreachable path/room tiles
	# TODO: Optimization: Could iterate only through `get_used_cells()` again, but needs V3i->V2i conversion. Full scan is simpler.
	for gx in range(grid_map_width):
		for gy in range(grid_map_height):
			var current_pos_v2i := Vector2i(gx, gy)
			var current_pos_v3i := Vector3i(gx, 0, gy)
			var item_id = get_cell_item(current_pos_v3i)

			# If it's a floor tile but wasn't reached by the flood fill
			if (item_id == PATH_ITEM_ID or item_id == ROOM_ITEM_ID) and \
			   (not reachable_tiles.has(current_pos_v2i)):
				# This tile is part of an island
				tiles_to_remove.append(current_pos_v2i)

	# Actually remove the collected island tiles, yielding periodically
	if not tiles_to_remove.is_empty():
		print("  Removing %d island tiles..." % tiles_to_remove.size())
		var frame_yield_counter = 0
		for tile_pos in tiles_to_remove:
			set_cell_item(Vector3i(tile_pos.x, 0, tile_pos.y), WALL_ITEM_ID)
			islands_removed_count += 1
			frame_yield_counter += 1
			# Yield periodically to prevent editor freezing if removing many tiles
			if frame_yield_counter >= 100: # Adjust batch size as needed
				#await get_tree().process_frame
				frame_yield_counter = 0
		# Ensure one last frame yield if any removals happened < yield threshold
		if islands_removed_count > 0 and frame_yield_counter > 0:
			#await get_tree().process_frame
			pass
	print("Island removal complete. Removed %d tiles." % islands_removed_count)

## Finds all valid floor tiles (PATH or ROOM) after island removal,
## randomly selects two distinct tiles, and sets them to ENTRANCE_ITEM_ID and EXIT_ITEM_ID.
func _place_entrance_and_exit() -> void:
	print("Placing entrance and exit...")
	var valid_floor_tiles: Array[Vector3i] = []

	# 1. Collect all valid floor tile positions (Path or Room)
	# Iterate only through cells that are currently used (optimization)
	var used_cells = get_used_cells()
	for cell_pos_v3i in used_cells:
		var item_id = get_cell_item(cell_pos_v3i)
		# Ensure it's a standard floor tile, not a wall or already something else
		if item_id == PATH_ITEM_ID or item_id == ROOM_ITEM_ID:
			# Make sure we only consider tiles at y=0 (though get_used_cells should mostly give these)
			if cell_pos_v3i.y == 0:
				valid_floor_tiles.append(cell_pos_v3i)

	# 2. Check if we have enough valid tiles
	if valid_floor_tiles.size() < 2:
		printerr("Could not place entrance and exit: Fewer than 2 valid floor tiles found after generation.")
		return

	# 3. Shuffle the list and pick two distinct tiles
	valid_floor_tiles.shuffle()
	var entrance_pos: Vector3i = valid_floor_tiles[0]
	var exit_pos: Vector3i = valid_floor_tiles[1]

	# 4. Set the entrance and exit tiles on the GridMap
	set_cell_item(entrance_pos, ENTRANCE_ITEM_ID)
	set_cell_item(exit_pos, EXIT_ITEM_ID)

	print("  Placed Entrance at %s and Exit at %s" % [entrance_pos, exit_pos])

	# Optional: Yield a frame to ensure the visual update in the editor
	#await get_tree().process_frame
# --- Helper Functions ---
func _place_heals() -> void:
	print("Placing entrance and exit...")
	var valid_floor_tiles: Array[Vector3i] = []

	# 1. Collect all valid floor tile positions (Path or Room)
	# Iterate only through cells that are currently used (optimization)
	var used_cells = get_used_cells()
	for cell_pos_v3i in used_cells:
		var item_id = get_cell_item(cell_pos_v3i)
		# Ensure it's a standard floor tile, not a wall or already something else
		if item_id == PATH_ITEM_ID or item_id == ROOM_ITEM_ID or item_id == ENTRANCE_ITEM_ID or item_id == EXIT_ITEM_ID:
			# Make sure we only consider tiles at y=0 (though get_used_cells should mostly give these)
			if cell_pos_v3i.y == 0:
				valid_floor_tiles.append(cell_pos_v3i)

	# 2. Check if we have enough valid tiles
	if valid_floor_tiles.size() < 4:
		printerr("Could not place entrance and exit: Fewer than 2 valid floor tiles found after generation.")
		return

	# 3. Shuffle the list and pick two distinct tiles
	valid_floor_tiles.shuffle()
	var heal_posistions: Array[Vector3i] = [
		valid_floor_tiles[0],
		valid_floor_tiles[1],

	]
	

	# 4. Set the entrance and exit tiles on the GridMap
	for heal_pos in heal_posistions:
		set_cell_item(heal_pos, HEAL_ITEM_ID)
	# Optional: Yield a frame to ensure the visual update in the editor
	#await get_tree().process_frame
## Adds potential connections (walls) for a given conceptual cell to the wall list
## used by Prim's algorithm. Only adds walls leading to valid, unvisited neighbors.
## Ensures walls are stored consistently (sorted coordinates) to avoid duplicates.
func add_conceptual_walls(cell: Vector2i, wall_list_ref: Array) -> void:
	for dir in DIRS:
		var neighbor_cell: Vector2i = cell + dir
		# Check if the neighbor is within the conceptual grid bounds
		if is_valid_maze_cell(neighbor_cell) and not visited_cells.has(neighbor_cell):
			# Create a wall (pair of cells)
			var wall: Array = [cell, neighbor_cell]
			# Sort the wall consistently (e.g., by x then y) to ensure uniqueness regardless of direction added
			wall.sort_custom(func(a:Vector2i, b:Vector2i): if a.x != b.x: return a.x < b.x; return a.y < b.y)
			# Add the wall to the list if it's not already there
			if not wall_list_ref.has(wall):
				wall_list_ref.append(wall)

## Checks if a given Vector2i coordinate is within the bounds of the conceptual grid.
func is_valid_maze_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < conceptual_width and \
		   cell.y >= 0 and cell.y < conceptual_height

## Draws a line of `item_id` tiles on the GridMap between two Vector2i points (representing grid x, z).
## Uses a Bresenham-like line algorithm.
func draw_line_on_gridmap(start_pos: Vector2i, end_pos: Vector2i, item_id: int) -> void:
	var x0: int = start_pos.x; var y0: int = start_pos.y # Using y for grid Z
	var x1: int = end_pos.x;   var y1: int = end_pos.y
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1 # Step direction x
	var sy: int = 1 if y0 < y1 else -1 # Step direction y (z)
	var err: int = dx - dy # Error term
	var current_x: int = x0
	var current_y: int = y0

	while true:
		# Place tile at current position (ensure within bounds first)
		if current_x >= 0 and current_x < grid_map_width and \
		   current_y >= 0 and current_y < grid_map_height:
			set_cell_item(Vector3i(current_x, 0, current_y), item_id)
		else:
			# print("Draw line went out of bounds at: ", Vector2i(current_x, current_y))
			break # Stop if we go out of bounds

		# Check if we reached the end point
		if current_x == x1 and current_y == y1: break

		var e2: int = 2 * err # Double the error term
		# Adjust error and step x if needed
		if e2 > -dy:
			err -= dy
			current_x += sx
		# Adjust error and step y (z) if needed
		if e2 < dx:
			err += dx
			current_y += sy

## Checks if a GridMap cell at (gx, gy) has any orthogonal neighbors
## that are either `path_id` or `ROOM_ITEM_ID`. Used by `_remove_isolated_path_tiles`.
func has_path_neighbor(gx: int, gy: int, check_grid_width: int, check_grid_height: int, path_id: int) -> bool:
	# Define neighbors relative to (gx, gy)
	var neighbors: Array[Vector2i] = [
		Vector2i(gx + 1, gy), Vector2i(gx - 1, gy),
		Vector2i(gx, gy + 1), Vector2i(gx, gy - 1)
	]
	for neighbor_pos in neighbors:
		var nx: int = neighbor_pos.x
		var ny: int = neighbor_pos.y
		# Check bounds
		if nx >= 0 and nx < check_grid_width and ny >= 0 and ny < check_grid_height:
			var neighbor_item = get_cell_item(Vector3i(nx, 0, ny))
			# Check if neighbor is a path or a room tile
			if neighbor_item == path_id or neighbor_item == ROOM_ITEM_ID:
				return true # Found a path/room neighbor
	return false # No path/room neighbors found

# --- Enemy Spawning ---

## Spawns enemies on the generated dungeon floor based on probabilities.
## Distinguishes between intersection/room tiles and path tiles for different spawn chances.
## Only runs when the game is running (not in editor).
func spawn_enemies() -> void:
	# Ensure dimensions are valid before spawning
	if grid_map_width == 0 or grid_map_height == 0: _calculate_dimensions()
	if grid_map_width == 0 or grid_map_height == 0:
		printerr("Cannot spawn enemies, grid dimensions are zero.")
		return
		print("Dungeon: Clearing existing enemies...")
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	if not existing_enemies.is_empty():
		print("  Found %d node(s) in group 'enemies'. Removing..." % existing_enemies.size())
		for enemy in existing_enemies:
			# Check if the instance is still valid before trying to free it
			# (it might have been freed by other game logic)
			if is_instance_valid(enemy):
				enemy.queue_free()
		print("  Existing enemies removed.")
	else:
		print("  No nodes found in group 'enemies'.")
	# Ensure enemy scenes are configured
	if not enemy_scenes or enemy_scenes.is_empty():
		printerr("Dungeon: No enemy scenes configured in the 'enemy_scenes' export array!")
		return

	_spawned_count = 0 # Reset spawn counter for this run
	var potential_intersections: Array[Vector3] = [] # Spawn points on intersection/room tiles
	var potential_paths: Array[Vector3] = []       # Spawn points on path tiles

	# 1. Identify all potential spawn locations
	var used_cells_v3: Array[Vector3i] = get_used_cells()
	for cell_coords_v3 in used_cells_v3:
		var item_id: int = get_cell_item(cell_coords_v3)
		# Consider only path or room tiles as valid spawn locations
		if item_id == PATH_ITEM_ID:
			# Determine if it's an intersection/room by counting path neighbors
			# Note: This check might be simplified if ROOM_ITEM_ID inherently means intersection
			var neighbor_path_count: int = _count_connecting_neighbors(cell_coords_v3)
			# Convert cell coords to local world position, offset slightly upwards
			var spawn_position: Vector3 = map_to_local(cell_coords_v3) + Vector3.UP * ENEMY_SPAWN_Y_OFFSET

			# Categorize the spawn point
			if neighbor_path_count >= 3: # Treat rooms as intersections for spawning
				potential_intersections.append(spawn_position)
			else:
				potential_paths.append(spawn_position)

	# 2. Shuffle lists and attempt spawns based on probabilities
	potential_intersections.shuffle()
	potential_paths.shuffle()

	# Spawn on intersections/rooms first (often higher probability)
	for pos in potential_intersections:
		if _spawned_count >= max_enemies_to_spawn: break # Stop if max count reached
		if randf() < intersection_spawn_chance:
			_do_spawn(pos)
	
	# Then spawn on paths
	for pos in potential_paths:
		if _spawned_count >= max_enemies_to_spawn: break # Stop if max count reached
		if randf() < path_spawn_chance:
			_do_spawn(pos)

	if _spawned_count > 0: print("Spawned %d enemies." % _spawned_count)
func _spawn_items() -> void:
	# 1. Cleanup existing items
	print("Dungeon: Clearing existing items...")
	var existing_items = get_tree().get_nodes_in_group("items")
	if not existing_items.is_empty():
		print("  Found %d node(s) in group 'items'. Removing..." % existing_items.size())
		for item in existing_items:
			if is_instance_valid(item):
				item.queue_free()
		print("  Existing items removed.")
	else:
		print("  No nodes found in group 'items'.")

	# 2. Check prerequisites
	if not item_scenes or item_scenes.is_empty():
		print("Dungeon: No item scenes configured. Skipping item spawn.")
		return
	if max_items_to_spawn == 0:
		print("Dungeon: max_items_to_spawn is 0. Skipping item spawn.")
		return

	if grid_map_width == 0 or grid_map_height == 0:
		printerr("Dungeon: Cannot spawn items, grid dimensions are zero.")
		return

	# 3. Categorize potential spawn locations
	var potential_dead_ends: Array[Vector3] = []
	var potential_rooms: Array[Vector3] = []
	var potential_paths: Array[Vector3] = [] # Regular paths (not dead ends)
	_items_spawned_count = 0 # Reset counter

	var used_cells_v3 = get_used_cells()
	for cell_coords_v3 in used_cells_v3:
		if cell_coords_v3.y != 0: continue # Ground level only

		var item_id = get_cell_item(cell_coords_v3)
		var spawn_pos_world: Vector3 = map_to_local(cell_coords_v3) + Vector3.UP * ITEM_SPAWN_Y_OFFSET

		if item_id == ROOM_ITEM_ID:
			potential_rooms.append(spawn_pos_world)
		elif item_id == PATH_ITEM_ID:
			var neighbor_count = _count_connecting_neighbors(cell_coords_v3)
			if neighbor_count == 1:
				potential_dead_ends.append(spawn_pos_world)
			elif neighbor_count > 1: # Must be > 1 to not be a dead end
				potential_paths.append(spawn_pos_world)
			# else neighbor_count is 0 (isolated path - should have been removed) or < 0 (error)

	# 4. Shuffle lists
	potential_dead_ends.shuffle()
	potential_rooms.shuffle()
	potential_paths.shuffle()

	print("Dungeon: Potential item locations - DeadEnds: %d, Rooms: %d, Paths: %d" % [potential_dead_ends.size(), potential_rooms.size(), potential_paths.size()])

	var spawn_limit = max_items_to_spawn # Cache limit (-1 means no limit)
	var spawned_this_run = 0 # Track spawns within this function call

	# Use a helper function to avoid code duplication for spawning checks
	var try_spawn = func(pos_list: Array[Vector3], chance: float) -> void:
		if spawned_this_run >= spawn_limit and spawn_limit != -1: return # Check limit first
		if pos_list.is_empty(): return # No locations of this type

		var pos_to_try = pos_list.pop_back() # Take one location
		if randf() < chance:
			if _do_spawn_item(pos_to_try):
				spawned_this_run += 1
				_items_spawned_count += 1 # Use the class member counter if needed elsewhere

	# 5. Attempt spawning, prioritizing dead ends, then rooms, then paths
	# Iterate through ALL potential locations for each type, applying chance
	var initial_dead_end_count = potential_dead_ends.size()
	for _i in range(initial_dead_end_count):
		if spawn_limit != -1 and spawned_this_run >= spawn_limit: break
		try_spawn.call(potential_dead_ends, dead_end_item_chance)

	var initial_room_count = potential_rooms.size()
	for _i in range(initial_room_count):
		if spawn_limit != -1 and spawned_this_run >= spawn_limit: break
		try_spawn.call(potential_rooms, room_item_chance)

	var initial_path_count = potential_paths.size()
	for _i in range(initial_path_count):
		if spawn_limit != -1 and spawned_this_run >= spawn_limit: break
		try_spawn.call(potential_paths, path_item_chance)


	if spawned_this_run > 0:
		print("Dungeon: Spawned %d items." % spawned_this_run)
		# Allow visual updates in editor if spawning occurred
		if Engine.is_editor_hint():
			pass
			#await get_tree().process_frame
	else:
		print("Dungeon: Spawned 0 items.")


## Instantiates a random item from `item_scenes`, adds it as a child
## of the Dungeon's parent node, sets its position, and adds it to the 'items' group.
## Returns true if spawn was successful, false otherwise.
func _do_spawn_item(spawn_pos_world: Vector3) -> bool:
	if not item_scenes or item_scenes.is_empty(): return false # Should be checked earlier, but safety first

	var item_scene = item_scenes.pick_random()
	if not item_scene:
		printerr("Dungeon: Picked item scene was null.")
		return false

	var item_instance: Node = item_scene.instantiate()
	if not item_instance:
		printerr("Dungeon: Failed to instantiate item scene: ", item_scene.resource_path)
		return false

	# Add the item to the scene tree
	var parent_node = %Items
	if parent_node:
		parent_node.add_child(item_instance)
	else:
		printerr("Dungeon: Node has no parent! Cannot add item instance '%s' to scene tree." % item_instance.name)
		item_instance.queue_free()
		return false

	# Add to group for cleanup
	item_instance.add_to_group("items")

	# Set position
	if item_instance is Node3D:
		var final_pos = spawn_pos_world
		final_pos.y = ENEMY_FINAL_Y_POS # 
		# Using the pre-calculated world position passed in
		(item_instance as Node3D).global_position = final_pos
	else:
		printerr("Dungeon: Spawned item root node '%s' is not Node3D! Cannot set global_position." % item_instance.name)
		# Attempt fallback?
		if item_instance.has_method("set_position"):
			# Might need to convert world pos back to local if parent isn't origin
			item_instance.call("set_position", item_instance.to_local(spawn_pos_world))


	return true

## Counts how many direct orthogonal neighbors of a given cell are PATH_ITEM_ID.
## Used to help differentiate intersections from simple paths for spawning logic.
func _count_connecting_neighbors(cell_coords_v3: Vector3i) -> int:
	var count: int = 0
	# Define neighbor offsets in 3D GridMap space (only horizontal)
	var neighbor_offsets: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, # X axis
		Vector3i.FORWARD, Vector3i.BACK # Z axis
	]
	for offset in neighbor_offsets:
		var neighbor_coord_v3: Vector3i = cell_coords_v3 + offset
		# Note: No bounds check needed here, get_cell_item returns INVALID_CELL (-1) for out of bounds
		var neighbor_item_id = get_cell_item(neighbor_coord_v3)
		# Check if the neighbor is specifically a path tile
		# Might need adjustment if corridors adjacent to rooms should count differently.
		if neighbor_item_id == PATH_ITEM_ID : # or neighbor_item_id == ROOM_ITEM_ID ? Check design needs.
			count += 1
	return count

## Instantiates a random enemy from `enemy_scenes`, adds it as a child
## of the Dungeon's parent node, and sets its position. Increments `_spawned_count`.
func _do_spawn(spawn_pos: Vector3) -> void:
	if not enemy_scenes or enemy_scenes.is_empty(): return # Safety check
	# Pick a random enemy scene from the exported array
	var enemy_scene = enemy_scenes.pick_random()
	if not enemy_scene:
		printerr("Picked enemy scene was null.")
		return # Skip if pick_random returns null (e.g., empty array)

	# Instantiate the scene
	var enemy_instance: Enemy = enemy_scene.instantiate()
	if not enemy_instance:
		printerr("Failed to instantiate enemy scene: ", enemy_scene.resource_path)
		return
	enemy_instance.add_to_group("enemies")

	# Add the enemy to the scene tree, typically as a sibling of the Dungeon node
	# Assumes the Dungeon's parent is the appropriate container (e.g., the main level scene)
	%Enemies.add_child(enemy_instance)

	# Set the enemy's position
	if enemy_instance is Node3D:
		# If it's a 3D node, set its global position, adjusting Y to the final height
		var final_pos = spawn_pos
		final_pos.y = ENEMY_FINAL_Y_POS # Place feet near the floor
		(enemy_instance as Node3D).global_position = final_pos # Cast for type safety
	else:
		# Fallback if the enemy root isn't Node3D (less common for 3D games)
		printerr("Spawned enemy root node is not a Node3D! Cannot set global_position directly.")
		# Try a generic set_position if it exists (might be Node2D in a 3D world?)
		if enemy_instance.has_method("set_position"):
			enemy_instance.call("set_position", spawn_pos) # Use local position? Might need adjustment.

	_spawned_count += 1 # Increment spawn counter
