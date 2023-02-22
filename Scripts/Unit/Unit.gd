# Represents a unit in the game board
# The board manages the Unit's position inside the game grid.
# The unit itself is only a visual representation that moves smoothly in the game world.
# We use the tool mode so the `skin` and `skin_offset` below update in the editor.
tool 
class_name Unit
extends Path2D


signal action_selected(action)


# Preload the `Grid.tres` resource you created in the previous part.
var CONSTANTS: Resource = preload("res://Resources/CONSTANTS.tres")
export(Resource) var grid = preload("res://Resources/Grid.tres")

var _pilot: Resource
var _mech: Resource

var pilot_name: String = 'PILOT'
var mech_name: String = 'MECH'

# Type of the unit
export(String, 'ally', 'enemy') var team

# Texture representing the unit.
export var skin: Texture setget set_skin
export var skin_offset := Vector2.ZERO setget set_skin_offset

# Distance to which the unit can walk in cells.
export var move_range: int setget ,_get_move_range
# The unit's move speed in pixels, when it's moving along a path.
export var move_speed := 600.0
# Through its setter function, the `_is_walking` property toggles processing for this unit.
# See `_set_is_walking()` at the bottom of this code snippet.
var _is_walking := false setget _set_is_walking

# Cell where the unit is located
var cell := Vector2.ZERO setget set_cell
var is_selected := false setget set_is_selected
var is_selecting_action := false setget set_is_selecting_action
var used_move_range := 0

var status: Dictionary = {} # Keys will be the status, as given by CONSTANT.STATUS, and values bool. Except engaged will be an Array of the engaged units
var conditions: Dictionary = {} # Keys will be the condition, as given by CONSTANT.CONDITIONS, and key the number of remaining turns

# Preload all components
onready var _sprite: Sprite = $PathFollow2D/Sprite
onready var _anim_player: AnimationPlayer = $AnimationPlayer
onready var _path_follow: PathFollow2D = $PathFollow2D
onready var _unit_hud = $PathFollow2D/UnitHUD
onready var _stats = $UnitStats
onready var _side_menu = $SideMenu

signal walk_finished


func _ready():
	# _process will only run if the unit needs to move
	set_process(false)
	if not Engine.editor_hint:
		# We create the curve resource here because creating it in the editor prevents us from
		# moving the unit.
		curve = Curve2D.new()


func initialize(unit_data: Dictionary):
	# Parameters
	# ----------
	# unit_data: Dictionary
	# {
	#	pilot: String. Path to the resource of the pilot
	#	mech: String. Path to the resource of the mech
	#	position: Vector2. Postion in the map in cells
	#	team: String. Team the unit is part of
	# }
	
	_pilot = load(unit_data['pilot'])
	_mech = load(unit_data['mech'])
	set_cell(unit_data['cell'])
	team = unit_data['team']
	
	pilot_name = _pilot.pilot_name
	mech_name = _mech.frame_name
	_stats.initialize(_pilot, _mech)
	_unit_hud.initialize(_stats.max_hp, _stats.heat_cap)
	_side_menu.initialize(_get_menu_layout())
	move_range = _stats.speed
	
	# Reset status and conditions
	for i in CONSTANTS.STATUS:
		status[i] = false
	status[CONSTANTS.STATUS.ENGAGED] = []
	
	for i in CONSTANTS.CONDITIONS:
		conditions[i] = 0
	
	#In the future this should also set the skin
	
	# The following lines initialize the `cell` property and snap the unit to the cell's center on the map.
	position = grid.map_to_world(cell)


func _process(delta):
	_path_follow.offset += move_speed * delta
	
	if _path_follow.unit_offset >= 1.0:
		_set_is_walking(false) # This also sets _process as false due to the setter bellow
		
		position = grid.map_to_world(self.cell)
		_path_follow.offset = 0.0
		curve.clear_points()
		# Finally, we emit a signal. We'll use this one with the game board.
		emit_signal("walk_finished")


func walk_along(path: PoolVector2Array) -> void:
	# path is a set of points given as relative from the current position
	if path.empty():
		return
	
	curve.add_point(Vector2.ZERO)
	for point in path:
		curve.add_point(grid.map_to_world(point) - position)
	
	# Inmediately set the position to the last point
	_set_is_walking(true)
	used_move_range = min(used_move_range + path.size() - 1, move_range)
	set_cell(path[-1])
	


func _get_menu_layout() -> Dictionary:
	var layout := {
		'FULL ACTIONS': {},
		'QUICK ACTIONS': {}
	}
	
	layout['FULL ACTIONS'] = _mech.weapons
	layout['QUICK ACTIONS'] = _mech.weapons
	return layout 


func finish_turn() -> void:
	used_move_range = 0


func take_damage(damage: int, damage_type: int) -> void:
	if damage_type == CONSTANTS.DAMAGE_TYPES.HEAT:
		take_heat(damage)
		return
	_stats.hp -= damage
	_unit_hud.hp = _stats.hp


func take_heat(heat: int) -> void:
	_stats.heat -= heat
	_unit_hud.heat = _stats.heat


func take_structure(struct: int) -> void:
	_stats.structure -= struct
	_unit_hud.structure = _stats.structure


func take_stress(stress: int) -> void:
	_stats.stress -= stress
	_unit_hud.stress = _stats.stress


# Maybe unnecesary, too verbose
func set_status(status_key: int, value) -> void:
	if not CONSTANTS.STATUS.has(status_key):
		print("Status not recognized")
		return
	
	status[status_key] = value


# Maybe unnecesary, too verbose
func set_condition_time(condition_key: int, value: int) -> void:
	if not CONSTANTS.CONDITIONS.has(condition_key):
		print("Status not recognized")
		return
	
	conditions[condition_key] = value


func set_skin(value: Texture) -> void:
	skin = value
	
	# Due to the onready preloading the sprite node might not be ready, wait using yield until the 
	# ready signal is recieved
	if not _sprite:
		yield(self, "ready")
	_sprite.texture = value

func set_skin_offset(value: Vector2) -> void:
	skin_offset = value
	# See above
	if not _sprite:
		yield(self, "ready")
	_sprite.position = value

func set_cell(val: Vector2) -> void:
	cell = grid.clamp_position(val) # We don't want to have out-of-grid cells

func set_is_selected(val: bool) -> void:
	if is_selected == val:
		return
		
	is_selected = val
	if is_selected:
		_anim_player.play("selected")
	else:
		_anim_player.play("idle") # idle animations reset the 'selected' animation

func set_is_selecting_action(val: bool) -> void:
	if is_selecting_action == val:
		return
		
	is_selecting_action = val
	if is_selecting_action:
		z_index = 1
		_side_menu.show_menu()
	else:
		z_index = 0
		_side_menu.hide_menu()

func _set_is_walking(val: bool) -> void:
	_is_walking = val
	set_process(_is_walking)

func _get_move_range() -> int:
	return move_range - used_move_range

func show_hud() -> void:
	_unit_hud.show()
	
func hide_hud() -> void:
	_unit_hud.hide()


func _on_SideMenu_action_selected(action):
	# Here should be all the action preprocessing
	emit_signal("action_selected", action)


func _on_UnitStats_structure_reduced(new_structure):
	_unit_hud.structure = new_structure


func _on_UnitStats_stress_raised(new_stress):
	_unit_hud.stress = new_stress

