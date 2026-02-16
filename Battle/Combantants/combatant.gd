@tool
class_name Combatant
extends FlowContainer

#region Signals
# Signal emitted when the ATB gauge is full and it's this combatant's turn to act.
signal turn_ready(combatant)

# Signal emitted when this combatant's action is complete.  Useful for timing.
signal action_completed(combatant:Combatant)
signal died

#endregion

#region Exported Properties
@export var member_data: PartyMember
@export var selected: bool = false : set = _set_selected
#endregion

#region Public Properties
# Current HP of this combatant.  Use set_hp() to modify this.
var current_hp : int : set = set_hp
var current_melee_shield: int : set = set_melee_shield
var current_magic_shield: int : set = set_magic_shield
# Current ATB gauge value.  Goes from 0 to 100.
var atb_gauge : float = 0.0 : set = _set_atb_gauge
# Whether this combatant's turn is active.
var is_turn_active : bool = false
#endregion

#region Private Properties
# Timer used to fill the ATB gauge.
var _atb_timer : Timer
#endregion

#region Godot Overrides
func _ready():
	# Initialize HP.
	%Health.max_value = member_data.base_hp

	%MagicShield.max_value = member_data.base_magic_shield
	%MeleeShield.max_value = member_data.base_melee_shield
	current_hp = member_data.current_hp
	current_magic_shield = member_data.base_magic_shield
	current_melee_shield = member_data.base_melee_shield
	atb_gauge = randf_range(0, 50.)

	%LvlLabel.text = "Lvl. {0}".format([member_data.level])
	%NameLabel.text = member_data.display_name
	%HeadShot.texture = member_data.texture
	set_process(false)


func _process(delta):
	# Increment the ATB gauge based on the timer and delta.
	# IMPORTANT:  The timer's wait time is the *inverse* of speed, so we
	# multiply by delta here.
	if !is_turn_active: # Only fill if not already acting
		atb_gauge += ((member_data.speed * 100) * delta * 10) # Multiplying by 10 for better feel.  Adjust as needed.
		atb_gauge = min(atb_gauge, 100.0)  # Clamp to 100.
	if atb_gauge >= 100.0 and !is_turn_active:
		atb_gauge = 100.0
		is_turn_active = true
		turn_ready.emit(self)

#endregion


#region Public Methods

# Apply damage to the combatant.
func take_damage(damage : int):
	$AnimationPlayer.play("on_hit")
	DmgNumbers.display_number(damage, %TargetPoint.global_position)
	if current_melee_shield > 0:
		current_melee_shield -= damage
		current_melee_shield = max(current_melee_shield, 0)
	else:
		current_hp -= damage
		current_hp = max(current_hp, 0)  # Ensure HP doesn't go below 0.
	if current_hp <= 0:
		$AnimationPlayer.play("on_death")
		died.emit(self)
		await $AnimationPlayer.animation_finished

		pass
		#queue_free()  # basic death.  Replace with more complex death logic.

func take_magic_damage(damage: int):
	$AnimationPlayer.play("on_hit")

	DmgNumbers.display_number(damage, %TargetPoint.global_position)

	if current_magic_shield > 0:
		current_magic_shield -= damage
		current_magic_shield = max(current_magic_shield, 0)
	else:
		current_hp -= damage
		current_hp = max(current_hp, 0)  # Ensure HP doesn't go below 0.
	if current_hp <= 0:
		$AnimationPlayer.play("on_death")
		died.emit(self)
		await $AnimationPlayer.animation_finished
# Called by the TurnManager when this combatant's action is complete.
func action_finished():
	is_turn_active = false # Reset
	atb_gauge = 0.0 # Reset gauge
	#_atb_timer.start() #restart timer
	var action = self.member_data.get_action().pick_random()
	emit_signal("action_completed", self, action)

# Function to get the current ATB percentage (for UI display).
func get_atb_percent() -> float:
	return atb_gauge / 100.0

# Forcefully set the HP.  Useful for status effects or other abilities.
func set_hp(new_hp : int):
	current_hp = new_hp
	current_hp = clamp(current_hp, 0, member_data.base_hp)
	member_data.current_hp = current_hp
	%Health.value = current_hp
	%HealthLabel.text = "{0} / {1}".format([current_hp, member_data.base_hp])
	#emit_signal("hp_changed", self, current_hp, old_hp)

func set_melee_shield(new_value: int):
	current_melee_shield = new_value
	current_melee_shield = clamp(current_melee_shield, 0, member_data.base_melee_shield)
	%MeleeShield.value = current_melee_shield
	%MeleeShieldLabel.text = "{0} / {1}".format([current_melee_shield, member_data.base_melee_shield])
func set_magic_shield(new_value):
	current_magic_shield = new_value
	current_magic_shield = clamp(current_magic_shield, 0, member_data.base_magic_shield)
	%MagicShield.value = current_magic_shield
	%MagicShieldLabel.text = "{0} / {1}".format([current_magic_shield, member_data.base_magic_shield])

func start_processing():
	set_process(true)
func disable_processing():
	set_process(false)
#endregion

#region Private Methods
func _set_atb_gauge(value):
	atb_gauge = value
	%AtbGauge.value = value

func _set_selected(value):
	selected = value
	%SelectionMarker.visible = value

#endregion
