# PathSpawnerDynamic.gd
extends Path2D

# The arrow scene to instance. Assign this in the Inspector.
@export var arrow_scene: PackedScene

# Total number of arrows to spawn per activation.
@export var total_arrows: int = 10

# Time in seconds between each arrow spawn.
@export var spawn_interval: float = 0.5 

# Speed at which arrows travel along the path (in units per second).
@export var travel_speed: float = 150.0 

# --- Private Variables ---
var _active_arrows: Array[PathFollow2D] = [] 
var _spawn_timer: Timer
var _spawned_count: int = 0
var _is_spawning: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure there's a Curve2D resource assigned or create one
	if not curve:
		curve = Curve2D.new()
		print("Created new Curve2D resource for Path2D.")
		
	# Create the Timer node programmatically
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false # Keep firing until stopped or queue runs out
	# Connect the timer's timeout signal to our spawning function
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout) 
	add_child(_spawn_timer) # Add the timer as a child so it processes

# --- Public Function to Create Path and Start Spawning ---
# Call this function to define the path and begin the arrow sequence.
# start_pos and end_pos should be in the local coordinate space of this Path2D node.
func create_path_and_spawn(start_pos: Vector2, end_pos: Vector2):
	# 1. Define the Path
	if not curve: # Should have been created in _ready, but double-check
		curve = Curve2D.new()
		
	# Clear any previous points to define a new path
	curve.clear_points() 
	
	# Add the start and end points for a straight line path
	# Note: Points are relative to the Path2D node's origin.
	curve.add_point(start_pos)
	curve.add_point(end_pos)
	
	print("Path created from %s to %s (local coords)." % [start_pos, end_pos])

	# 2. Start the Spawning Process
	_start_spawning_internal()


# Internal function to begin the spawning process (called after path is set)
func _start_spawning_internal():
	# Check if an arrow scene is assigned
	if not arrow_scene:
		printerr("No arrow_scene assigned to PathSpawner!")
		return
		
	# Ensure the path is valid before starting
	if not curve or curve.get_point_count() < 2:
		printerr("Cannot start spawning, path curve is not valid (needs at least 2 points).")
		return

	# Reset state if starting again (clears old arrows, stops timer)
	stop_spawning() 
	_spawned_count = 0
	_is_spawning = true
	
	# Set the timer's wait time
	_spawn_timer.wait_time = spawn_interval
	
	# Start the timer to trigger the first spawn after spawn_interval
	# Or spawn immediately and then start timer (see previous version's comments)
	_spawn_timer.start()
	
	print("Spawning started. Total arrows: %d, Interval: %.2f s" % [total_arrows, spawn_interval])

# Public function to stop spawning and clear existing arrows.
func stop_spawning():
	_is_spawning = false
	if _spawn_timer: # Check if timer exists before stopping
		_spawn_timer.stop()
	
	# Clear out any existing arrows
	# Iterate backwards when removing
	for i in range(_active_arrows.size() - 1, -1, -1):
		var arrow_follow_node = _active_arrows[i]
		if is_instance_valid(arrow_follow_node):
			arrow_follow_node.queue_free()
	_active_arrows.clear()
	# print("Spawning stopped and arrows cleared.") # Optional print

# Called every frame. Delta is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Don't process if the curve is invalid or no arrows exist
	if not curve or curve.get_point_count() < 2 or _active_arrows.is_empty():
		return
		
	var path_length = curve.get_baked_length()
	if path_length <= 0: # Avoid division by zero or issues with zero-length paths
		# Clear remaining arrows immediately if path length is zero
		stop_spawning() 
		return

	# Iterate backwards because we might remove items from the array
	for i in range(_active_arrows.size() - 1, -1, -1):
		var path_follow: PathFollow2D = _active_arrows[i]
		
		if not is_instance_valid(path_follow):
			_active_arrows.remove_at(i)
			continue 

		# Move the arrow along the path based on speed
		path_follow.progress += travel_speed * delta
		
		# Check if the arrow has reached or passed the end of the path
		if path_follow.progress >= path_length:
			_active_arrows.remove_at(i)
			path_follow.queue_free()


# Function called when the spawn timer finishes its countdown.
func _on_spawn_timer_timeout() -> void:
	if not _is_spawning:
		return 

	if _spawned_count < total_arrows:
		_spawn_arrow()
		_spawned_count += 1
	
	# If we've spawned all the required arrows, stop the timer.
	if _spawned_count >= total_arrows:
		_spawn_timer.stop()
		_is_spawning = false 
		print("Finished spawning all arrows for this path.")

# Helper function to create and setup a single arrow instance.
func _spawn_arrow() -> void:
	if not arrow_scene: 
		printerr("Cannot spawn arrow, arrow_scene is null.")
		_spawn_timer.stop() # Stop spawning if scene is missing
		_is_spawning = false
		return
		
	var path_follow = PathFollow2D.new()
	path_follow.progress = 0 
	path_follow.rotates = true 
	# path_follow.loop = false # Default
	
	var arrow_instance = arrow_scene.instantiate()
	path_follow.add_child(arrow_instance)
	
	# Add to this Path2D node so it follows the curve
	add_child(path_follow) 
	
	_active_arrows.append(path_follow)
