## Manages the turn-based battle flow, combatant setup, state transitions,
## player input handling, and battle resolution.
##
## This node acts as the central orchestrator for combat encounters. It sets up
## player and enemy combatants based on provided data, handles the turn order,
## manages player action selection and targeting, executes actions, checks for
## win/loss conditions, and displays results. It uses a state machine
## (BATTLE_STATE) to control the battle progression.
extends CanvasLayer
class_name BattleManager

## Emitted when the battle ends (either win or loss). Can be connected to
## by other nodes to trigger actions like returning to a map or showing game over.
# signal battle_finished(result: BATTLE_STATE) # Example signal - add if needed


## Defines the possible states of the battle manager during combat.
enum BATTLE_STATE {
	INACTIVE,        ## Battle is not running, manager might be hidden.
	ACTIVE,          ## Battle is starting, setup process begins.
	IDLE,            ## Waiting for the next combatant's turn gauge to fill.
	TURN_START,      ## A combatant's turn has begun. Decide player/AI action.
	WAITING_FOR_ACTION, ## Waiting for the player to select an action from the menu.
	SELECTING_TARGET, ## Player has selected an action, now choosing a target.
	DO_ACTION,       ## (Currently unused directly, action logic is within states) The action is being executed.
	TURN_DONE,       ## The current combatant's action is complete. Clean up the turn.
	SHOW_RESULTS,    ## All enemies defeated, showing battle results/rewards UI.
	BATTLE_END,      ## Battle is over (win or loss), cleaning up combatants.
}

## Array holding all active combatant nodes (both players and enemies).
var _combatants: Array[Combatant] = []

## The combatant whose turn it currently is. Null if it's between turns.
var current_combatant: Combatant = null

## The current state of the battle state machine.
var current_state: BATTLE_STATE = BATTLE_STATE.INACTIVE

## The action (GearRes) selected by the player, waiting for target selection.
var selected_action: GearRes = null

## The index of the currently selected target within the enemy list.
var selected_target_index: int = 0

## The PackedScene for player combatants. Assign in the Inspector.
@export var player_combatant_scene: PackedScene

## The PackedScene for enemy combatants. Assign in the Inspector.
@export var enemy_combatant_scene: PackedScene

## Array of PartyMember resources defining the player party composition for this battle.
## Assign these resources in the Inspector before starting the battle.
@export var player_party_data: Array[PartyMember] = [] # Replace 'Resource' with your PartyMember resource type

## Array of PartyMember resources defining the enemy party composition for this battle.
## Assign these resources in the Inspector before starting the battle.
@export var monster_party_data: Array[MonsterPartyMember] = [] # Replace 'Resource' with your PartyMember resource type
func _ready() -> void:
	hide()
## Sets up the battle by instantiating and configuring combatants.
## Connects signals and starts their internal processing (e.g., turn gauge).
## This is typically called when transitioning to the ACTIVE state.
func setup_battle() -> void:
	# Clear any remnants from a previous battle
	_combatants.clear()
	# Ensure nodes referenced by % are available if not using @onready
	# (Can be removed if using @onready and setup happens after _ready)
	
	# Instantiate and configure enemy combatants
	for member_data in monster_party_data:
		if not enemy_combatant_scene:
			printerr("BattleManager: Enemy Combatant Scene not set!")
			return

		var c: Combatant = enemy_combatant_scene.instantiate()
		# Configure combatant stats and data from the PartyMember resource
		# TODO: Replace with actual property names from your PartyMember/Combatant classes
		c.member_data = member_data.duplicate()
		c.member_data.scale(get_tree().get_first_node_in_group('map').scaling)
		c.add_to_group("enemy")

		# Add the combatant node to the first available slot in the UI
		var slot_found = false
		for slot in %MonsterPartySlots.get_children():
			if slot.get_child_count() == 0:
				slot.add_child(c)
				slot_found = true
				break
		if not slot_found:
			printerr("BattleManager: No available monster party slot for ", c.display_name)
			c.queue_free() # Clean up instance if no slot
			continue # Skip adding to combatants list

		_combatants.append(c)

	# Instantiate and configure player combatants
	for member_data in player_party_data:
		if not player_combatant_scene:
			printerr("BattleManager: Player Combatant Scene not set!")
			return
		var c: Combatant = player_combatant_scene.instantiate()
		if member_data.current_hp == 0:
			continue
		# Configure combatant stats and data from the PartyMember resource
		# TODO: Replace with actual property names from your PartyMember/Combatant classes
		c.member_data = member_data
		c.add_to_group("player")

		# Add the combatant node to the first available slot in the UI
		var slot_found = false
		for slot in %PlayerPartySlots.get_children():
			if slot.get_child_count() == 0:
				slot.add_child(c)
				slot_found = true
				break
		if not slot_found:
			printerr("BattleManager: No available player party slot for ", c.display_name)
			c.queue_free() # Clean up instance if no slot
			continue # Skip adding to combatants list

		_combatants.append(c)

	# Connect signals and start processing for all instantiated combatants
	for c: Combatant in _combatants:
		if not c.is_connected("turn_ready", Callable(self, "_on_combatant_turn_ready")):
			c.turn_ready.connect(_on_combatant_turn_ready)
		if not c.is_connected("died", Callable(self, "_on_combatant_died")):
			c.died.connect(_on_combatant_died)
		c.start_processing() # Tell combatant to start its internal logic (e.g., turn timer)
## Callback triggered when a Combatant's turn gauge is full.
## Sets the current combatant, pauses others, and transitions the state machine.
## @param c: The Combatant whose turn is ready.
func _on_combatant_turn_ready(c: Combatant):
	# Prevent handling turn ready if battle isn't in a receptive state
	if current_state == BATTLE_STATE.INACTIVE or current_state == BATTLE_STATE.BATTLE_END or current_state == BATTLE_STATE.SHOW_RESULTS:
		return

	# Ensure only one turn happens at a time
	if current_combatant != null:
		printerr("BattleManager: Received turn_ready for ", c.name, " while ", current_combatant.name, " is active!")
		# Optionally, queue the turn or handle this overlap case
		return

	current_combatant = c

	# Pause processing for all other combatants during this turn
	for other_c: Combatant in _combatants:
		if c != other_c:
			other_c.disable_processing()

	# Transition state to start the turn logic
	set_state(BATTLE_STATE.TURN_START)
	# Immediately transition to waiting for action if it's a player
	# (Enemy AI action is handled within TURN_START state logic)
	if c.is_in_group("player"):
		set_state(BATTLE_STATE.WAITING_FOR_ACTION)

## Callback triggered when the current Combatant finishes their action.
## Resumes processing for other combatants, checks for battle end, and transitions to IDLE.
## @param c: The Combatant whose turn just ended.
func _on_combatant_turn_end(c: Combatant):
	# Ensure the combatant ending the turn is the one we expect
	if c != current_combatant:
		printerr("BattleManager: Received turn_end from unexpected combatant: ", c.name)
		return # Or handle appropriately

	current_combatant = null
	selected_action = null # Clear selected action
	selected_target_index = 0 # Reset target index

	# Resume processing for all other combatants
	for other_c: Combatant in _combatants:
		# Check if instance is valid, might have been removed (died)
		if is_instance_valid(other_c) and c != other_c:
			other_c.start_processing()

	# Tell the combatant its action is officially finished (for internal cleanup)
	# Check validity again in case it died during its own action/turn end effects
	if is_instance_valid(c):
		c.action_finished()

	# Check if the battle is over after the turn completes
	if not check_battle_over():
		# If battle is not over, return to idle state to wait for next turn
		set_state(BATTLE_STATE.IDLE)


## Callback triggered when a Combatant's health reaches zero or below.
## Removes the deceased combatant from the battle and frees the node.
## @param c: The Combatant that died.
func _on_combatant_died(c: Combatant):
	if not _combatants.has(c):
		# Already removed or wasn't properly added, ignore.
		return
	
	# Remove from the active list
	_combatants.erase(c)

	# Optional: Add visual/audio feedback for death here
	printt(c.member_data.display_name, "has been defeated!")
	if c.is_in_group("enemy"):
		%ResultUI.exp_gained += c.member_data.exp_value
	# Re-check battle over condition immediately after death
	check_battle_over()
	# Remove the node from the scene tree

	await get_tree().create_timer(1).timeout
	c.queue_free()




## Checks if the battle has reached a conclusion (all players defeated or all enemies defeated).
## Transitions to BATTLE_END or SHOW_RESULTS state if appropriate.
## @return bool: True if the battle is over, False otherwise.
func check_battle_over() -> bool:
	var enemies: Array[Combatant] = get_enemy_combatants()
	var players: Array[Combatant] = get_player_combatants()

	# Check for player defeat (All players have 0 or less HP)
	# Using `all()` requires Godot 4.x. For 3.x, use a loop.
	var all_players_defeated = true
	if players.is_empty(): # Handle case where player party data was empty?
		all_players_defeated = true # Or perhaps this is an error state
	else:
		for p in players:
			if p.current_hp > 0:
				all_players_defeated = false
				break

	if all_players_defeated:
		print("Battle Over - Players Defeated!")
		set_state(BATTLE_STATE.BATTLE_END)
		# Optionally emit a signal here: battle_finished.emit(BATTLE_STATE.BATTLE_END)
		# Reloading scene might be better handled by a parent node listening to a signal
		# get_tree().reload_current_scene() # Consider moving this out
		return true

	# Check for enemy defeat (All enemies have 0 or less HP)
	# Using `all()` requires Godot 4.x. For 3.x, use a loop.
	var all_enemies_defeated = true
	if enemies.is_empty(): # This is the win condition!
		all_enemies_defeated = true
	else:
		# Check if any remaining enemy is alive. If so, battle continues.
		# This handles the case where enemies might die mid-turn.
		all_enemies_defeated = true
		for e in enemies:
			if e.current_hp > 0:
				all_enemies_defeated = false
				break

	if all_enemies_defeated and not players.is_empty(): # Ensure player didn't lose on the same turn
		print("Battle Over - Enemies Defeated!")
		set_state(BATTLE_STATE.SHOW_RESULTS)
		# Optionally emit a signal here: battle_finished.emit(BATTLE_STATE.SHOW_RESULTS)
		return true

	return false # Battle continues


## Callback connected to the ActionMenu's signal when the player selects an action.
## Stores the selected action and transitions state to target selection.
## @param gear: The GearRes representing the chosen action.
func _on_action_selected(gear: GearRes):
	if current_state != BATTLE_STATE.WAITING_FOR_ACTION or not current_combatant.is_in_group("player"):
		# Only allow action selection during the player's turn when waiting.
		return

	selected_action = gear
	set_state(BATTLE_STATE.SELECTING_TARGET)

## Handles global input events, primarily for player target selection and confirmation.
func _input(event: InputEvent) -> void:

	# Handle Target Selection state input
	if current_state == BATTLE_STATE.SELECTING_TARGET:
		var targets: Array[Combatant] = get_enemy_combatants()
		if targets.is_empty():
			# No valid targets left, maybe cancel action or auto-end turn?
			# For now, just prevent input processing for targeting.
			return

		var navigated: bool = false
		# Navigate targets backward (e.g., Down arrow or S key)
		if event.is_action_pressed('move_backward'): # Use descriptive action names
			selected_target_index = (selected_target_index + 1) % targets.size()
			navigated = true
			get_viewport().set_input_as_handled() # Consume event

		# Navigate targets forward (e.g., Up arrow or W key)
		elif event.is_action_pressed('move_forward'): # Use descriptive action names
			# Modulo for positive wrapping, manual check for negative wrapping
			if selected_target_index == 0:
				selected_target_index = targets.size() - 1
			else:
				selected_target_index = (selected_target_index - 1) % targets.size()
			navigated = true
			get_viewport().set_input_as_handled() # Consume event

		# Update visual indicator for the selected target if navigation occurred
		if navigated:
			update_target_visuals()

		# Confirm target selection (e.g., Enter key or Space)
		if event.is_action_pressed("ui_accept"):
			if selected_action == null:
				printerr("BattleManager: Target confirmed but no action selected!")
				# Optionally return to WAITING_FOR_ACTION state
				return
			clear_target_visuals()
			set_state(BATTLE_STATE.DO_ACTION)
			var target_combatant: Combatant = targets[selected_target_index]
			$Targeter.create_path_and_spawn(current_combatant.get_node("TargetPoint").global_position, target_combatant.get_node("TargetPoint").global_position)
			# Check if the target has a take_damage method before calling
			await get_tree().create_timer(.5).timeout
			# Execute the selected action on the chosen target
			printt(current_combatant.member_data.display_name, " uses ", selected_action.display_name, " on ", target_combatant.member_data.display_name) # Assumes GearRes has a 'name'
			apply_action(current_combatant, target_combatant, selected_action)
		
			# Mark input as handled and transition state
			get_viewport().set_input_as_handled()
			set_state(BATTLE_STATE.TURN_DONE)

	# Handle advancing through results screen
	elif current_state == BATTLE_STATE.SHOW_RESULTS:
		if event.is_action_pressed("ui_accept"):
			%ResultUI.hide() # Assuming ResultUI is the node showing results
			set_state(BATTLE_STATE.BATTLE_END)
			get_viewport().set_input_as_handled() # Consume event


## Main processing loop, used here primarily for timed events or continuous checks
## if needed, though most logic is event-driven (signals, input) or state-driven.
## Currently used only to handle input during SHOW_RESULTS state after a delay.
func _process(delta: float) -> void:
	# The logic previously here for SHOW_RESULTS input handling was moved
	# to _input for better consistency. This function can be used for
	# animations or other time-dependent updates if necessary.
	# If not needed, you can disable it by calling set_process(false)
	# after setup and only enabling it when required by specific states.
	pass


## Updates the visual indicators (e.g., highlights, cursors) on combatants
## to show which enemy is currently targeted by the player.
func update_target_visuals() -> void:
	var targets: Array[Combatant] = get_enemy_combatants()
	if targets.is_empty():
		return # No targets to update

	for i in range(targets.size()):
		# Assuming Combatant has a boolean 'selected' property for visual state
		targets[i].selected = (i == selected_target_index)

func clear_target_visuals() -> void:
	var targets: Array[Combatant] = get_enemy_combatants()
	if targets.is_empty():
		return 
	for i in targets:
		i.selected = false

## Transitions the BattleManager to a new state, executing logic associated
## with entering that state.
## @param new_state: The BATTLE_STATE to transition to.
func set_state(new_state: BATTLE_STATE) -> void:
	if current_state == new_state:
		return # Avoid redundant state changes and logic execution

	# print("Battle State changing from ", BATTLE_STATE.keys()[current_state], " to ", BATTLE_STATE.keys()[new_state])
	current_state = new_state

	match current_state:
		BATTLE_STATE.INACTIVE:
			# Hide battle UI, disable processing if needed
			hide()
			set_process(false)
			set_physics_process(false)

		BATTLE_STATE.ACTIVE:
			# Setup combatants, show UI, enable processing
			setup_battle()
			%ResultUI.hide()
			show()
			set_process(true) # Enable _process if needed by other states
			set_physics_process(false) # Usually not needed for battle logic
			set_state(BATTLE_STATE.IDLE) # Move to IDLE immediately after setup

		BATTLE_STATE.IDLE:
			# Waiting state, combatant processing is active to fill turn gauges.
			# Potentially check for battle over again in case setup resulted in end condition
			check_battle_over()
			pass

		BATTLE_STATE.TURN_START:
			# Logic when a combatant's turn begins
			if not is_instance_valid(current_combatant):
				printerr("BattleManager: Invalid current_combatant at TURN_START!")
				set_state(BATTLE_STATE.IDLE) # Try to recover
				return

			printt("Turn Start: ", current_combatant.member_data.display_name)
			if current_combatant.is_in_group("player"):
				# Player turn: Show action menu
				%ActionMenu.on_turn_started(current_combatant) # Assumes ActionMenu node exists
			else:
				# Enemy turn: Basic AI - select random action, random player target
				var player_targets: Array[Combatant] = get_player_combatants()
				if player_targets.is_empty():
					# No players left? Should have been caught by check_battle_over
					print("Enemy turn: No player targets left.")
					set_state(BATTLE_STATE.TURN_DONE) # End turn immediately
					return

				if current_combatant.member_data.weapon_gear.is_empty():
					print("Enemy turn: ", current_combatant.member_data.display_name, " has no actions.")
					set_state(BATTLE_STATE.TURN_DONE) # End turn immediately
					return

				var enemy_action: GearRes = current_combatant.member_data.weapon_gear.pick_random()
				var target_player: Combatant = player_targets.pick_random()

				printt(current_combatant.member_data.display_name, " uses ", enemy_action.display_name, " on ", target_player.member_data.display_name)
				apply_action(current_combatant, target_player, enemy_action)

				# AI turn finishes immediately after acting
				set_state(BATTLE_STATE.TURN_DONE)

		BATTLE_STATE.WAITING_FOR_ACTION:
			# Player turn, waiting for input via ActionMenu signal (_on_action_selected)
			pass # No direct action needed here, logic driven by signal

		BATTLE_STATE.SELECTING_TARGET:
			# Player has chosen an action, now selecting target via _input()
			selected_target_index = 0 # Default to first target
			update_target_visuals() # Highlight the default target
			# Enable target UI elements if needed
			print("Select target for action: ", selected_action.display_name)

		BATTLE_STATE.TURN_DONE:
			# Current combatant's action is complete
			# Deselect any highlighted targets
			for combatant in get_enemy_combatants():
				combatant.selected = false
			for combatant in get_player_combatants():
				combatant.selected = false # Also deselect player if targeting players is possible

			if is_instance_valid(current_combatant):
				# If it's a player turn, inform the UI
				if current_combatant.is_in_group("player"):
					%ActionMenu.on_turn_ended(current_combatant) # Assumes ActionMenu node exists

			# Trigger the turn end logic (resumes others, checks battle over)
			_on_combatant_turn_end(current_combatant)
			# Note: _on_combatant_turn_end will set state to IDLE if battle not over

		BATTLE_STATE.SHOW_RESULTS:
			# All enemies defeated, display results UI
			print("Displaying Battle Results")
			for c: Combatant in _combatants: # Stop any remaining combatants (should only be players)
				c.disable_processing()

			%ResultUI.setup(player_party_data,) # Pass necessary data (e.g., party, exp, gold)
			%ResultUI.show()
			for member in player_party_data:
				member.exp_owned += %ResultUI.exp_gained
			set_process(false) # Pause _process temporarily
			await get_tree().create_timer(0.5).timeout # Short delay before allowing input
			set_process(true) # Re-enable _process ONLY if input is handled there
			# Input for this state is now handled in _input()

		BATTLE_STATE.BATTLE_END:
			# Battle is finished (win or loss), clean up everything
			print("Battle Ended. Cleaning up.")
			for c in _combatants:
				if is_instance_valid(c):
					c.queue_free() # Remove all remaining combatant nodes

			# Clear internal lists
			_combatants.clear()
			# It's often better NOT to clear the data arrays here,
			# as they might be needed if the player retries or moves on.
			# monster_party_data.clear()
			# player_party_data.clear()

			current_combatant = null
			selected_action = null

			%ResultUI.exp_gained = 0
			# Potentially emit a signal that the battle is fully over
			# battle_finished.emit(current_state) # Pass BATTLE_END or SHOW_RESULTS based on win/loss path?
			set_state(BATTLE_STATE.INACTIVE) # Go back to inactive state
			get_tree().paused = false # Ensure game is unpaused if it was paused for battle

		_:
			printerr("BattleManager: Reached unknown state: ", new_state)

# --- Helper Functions ---

## Retrieves a list of all active combatants belonging to the "player" group.
## @return Array[Combatant]: An array containing player combatants.
func get_player_combatants() -> Array[Combatant]:
	return _combatants.filter(func(c: Combatant): return is_instance_valid(c) and c.is_in_group("player"))


## Retrieves a list of all active combatants belonging to the "enemy" group.
## @return Array[Combatant]: An array containing enemy combatants.
func get_enemy_combatants() -> Array[Combatant]:
	return _combatants.filter(func(c: Combatant): return is_instance_valid(c) and c.is_in_group("enemy"))

## Applies the effect of a selected action from an attacker to a target.
## Handles different damage types (e.g., random range).
## @param attacker: The Combatant performing the action.
## @param target: The Combatant receiving the action.
## @param action: The GearRes representing the action taken.
func apply_action(attacker: Combatant, target: Combatant, action: GearRes):
	# Basic damage application example
	# TODO: Expand this to handle healing, buffs, different damage types (melee/magic), etc.
	# Assumes GearRes has 'damage' and 'dmg_type' properties.
	# Assumes Combatant has 'take_damage(amount: int)' method.
	if not is_instance_valid(target):
		printerr("BattleManager: apply_action target is invalid!")
		return
	if not action is WeaponGearRes:
		return
	$Targeter.stop_spawning()
	if action.atk_type == WeaponGearRes.AtkType.Melee or action.atk_type == WeaponGearRes.AtkType.Ranged:
		var damage_amount: int = 0
		# Example: Check for a specific damage type enum/constant if GearRes has it
		# Adjust this based on your GearRes structure
		const RANDOM_DMG_TYPE = 1 # Assuming GearRes.DmgType.Random corresponds to value 2
		if action.dmg_type == RANDOM_DMG_TYPE:
			# Ensure damage is at least 1 if using randi_range(1, ...)
			damage_amount = randi_range(max(1, action.damage / 2.0), action.damage) # Example random range
			# Or use your original: randi_range(1, action.damage) if max damage can be low
		else:
			damage_amount = action.damage

		
		if damage_amount > 0:
			target.take_damage(damage_amount)
			printt(target.member_data.display_name, " takes ", damage_amount, " damage.")
		else:
			printt("Action had no effect or dealt 0 damage.")
	elif action.atk_type == WeaponGearRes.AtkType.Magic:
		var damage_amount: int = 0
		# Example: Check for a specific damage type enum/constant if GearRes has it
		# Adjust this based on your GearRes structure
		const RANDOM_DMG_TYPE = 2 # Assuming GearRes.DmgType.Random corresponds to value 2
		if action.dmg_type == RANDOM_DMG_TYPE:
			# Ensure damage is at least 1 if using randi_range(1, ...)
			damage_amount = randi_range(max(1, action.damage / 2.0), action.damage) # Example random range
			# Or use your original: randi_range(1, action.damage) if max damage can be low
		else:
			damage_amount = action.damage

		
		if damage_amount > 0:
			target.take_magic_damage(damage_amount)
			printt(target.member_data.display_name, " takes ", damage_amount, " damage.")
		else:
			printt("Action had no effect or dealt 0 damage.")
	else:
		printerr("BattleManager: Target ", target.name, " does not have take_damage method.")
