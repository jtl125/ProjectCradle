class_name GameBoard
extends YSort

export var _grid: Resource = preload("res://Resources/Grid.tres")
var CONSTANTS: Resource = preload("res://Resources/CONSTANTS.tres")

var _directions = _grid.directions()
var _units := {}

# Array to store the different identifiers for the sides the unit belong in the map
var allegiances := ['ally', 'enemy']
var allegiance_turn_index = 0

var RAY_CAST_SPEED := 10 # Speed of the ray casting in pixels
enum STATE {FREE, MOVEMENT, SELECTING, ACTING}
var _board_state: int = STATE.FREE setget change_state

var _active_unit: Unit
var _performing_action
var _walkable_cells := []
var _marked_cells := []

onready var _unit_overlay: UnitOverlay = $UnitOverlay
onready var _unit_path: UnitPath = $UnitPath 
onready var _cursor = $Cursor
onready var _action_processor = $ActionProcessor

func _ready() -> void:
	_reinitialize()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # It handles well all states
		change_state(STATE.FREE)


func _reinitialize() -> void:
	_units.clear()
	change_state(STATE.FREE)
	
	for child in get_children():
		
		# We can cast cast anything into a Unit, if it doesnt work it returns null
		var unit := child as Unit
		if not unit:
			continue
		
		_units[unit.cell] = unit
		
		if not unit.allegiance in allegiances:
			allegiances.push_back(unit.allegiance)
		
		unit.connect("action_selected", self, "_on_Unit_action_selected")


func is_occupied(cell: Vector2) -> bool:
	return true if _units.has(cell) else false


func get_walkable_cells(unit: Unit) -> Array:
	var blocked_spaces = _units.keys()
	return _grid.flood_fill(unit.cell, unit.move_range, blocked_spaces)


func get_visible_cells(unit: Unit, vision_range: int) -> Array:
	var blocked_spaces = _units.keys()
	return _grid.flood_fill(unit.cell, vision_range, blocked_spaces, false) # This shuld be updated


func _select_unit(cell: Vector2) -> void:
	
	if not _units.has(cell):
		return
	
	if not _units[cell].allegiance == allegiances[allegiance_turn_index]:
		return
	
	_active_unit = _units[cell]
	
	print(_active_unit.move_range)
	if _active_unit.move_range == 0:
		change_state(STATE.SELECTING)
		return
	
	change_state(STATE.MOVEMENT)


func _move_active_unit(new_cell: Vector2) -> void:
	
	if new_cell == _active_unit.cell:
		change_state(STATE.SELECTING)
		return
	
	if is_occupied(new_cell) or not new_cell in _walkable_cells:
		return
	
	_units.erase(_active_unit.cell)
	_units[new_cell] = _active_unit
	
	_active_unit.walk_along(_unit_path._current_path)
	yield(_active_unit, "walk_finished")
	
	change_state(STATE.SELECTING)


# Maybe I could implement a state machine since I have already separated the code...
func change_state(new_state: int) -> void:
	match new_state:
		STATE.FREE:
			_cursor.is_active = true
			_unit_overlay.clear()
			_unit_path.stop()
			
			if _active_unit:
				_active_unit.is_selecting_action = false
				_active_unit.is_selected = false
				_active_unit = null
			
		STATE.MOVEMENT:
			_cursor.is_active = true
			_walkable_cells = get_walkable_cells(_active_unit)
			_unit_overlay.draw(_walkable_cells)
			_unit_path.initialize(_walkable_cells)
			
			_active_unit.is_selected = true
			_active_unit.is_selecting_action = false # Toggles the menu and animations
			
		STATE.SELECTING:
			_cursor.is_active = false
			_unit_overlay.clear()
			_unit_path.stop()
			
			_active_unit.is_selected = false
			_active_unit.is_selecting_action = true 
			
		STATE.ACTING:
			_cursor.is_active = true
			_unit_overlay.clear()
			_unit_path.stop()
			
			_active_unit.is_selected = false
			_active_unit.is_selecting_action = false 
			
		_:
			print('The state you are entering does not exist, the program will probably crash soon')
	
	$DEBUG_LABEL.text = allegiances[allegiance_turn_index]
	_board_state = new_state


func finish_unit_turn() -> void:
	_active_unit.finish_turn()
	change_state(STATE.FREE)
	allegiance_turn_index = (allegiance_turn_index+1) % allegiances.size()

func _on_Cursor_moved(new_cell: Vector2) -> void:
	if _board_state == STATE.MOVEMENT:
		_unit_path.draw(_active_unit.cell, new_cell)
	elif _board_state == STATE.ACTING:
		var relative_angle: float = _active_unit.cell.angle_to_point(_cursor.cell)
		_unit_overlay.update_overlay(_cursor.cell, relative_angle)
	
	for cell in _units:
		if _units[cell] == _active_unit:
			continue
		_units[cell].hide_hud()
	
	if _units.has(new_cell):
		_units[new_cell].show_hud()

func _on_Cursor_accept_pressed(cell: Vector2) -> void:
	if _board_state == STATE.FREE:
		_select_unit(cell)
	elif _board_state == STATE.MOVEMENT:
		_move_active_unit(cell)
	elif _board_state == STATE.ACTING:
		
		var was_action_performed: bool = _action_processor.process_action_targeted(cell)
			# Finish the unit action
		if was_action_performed:
			finish_unit_turn()

func _on_Unit_action_selected(action) -> void:
	change_state(STATE.ACTING)
	_action_processor.initialize(_units, action, _active_unit)
	_unit_overlay.initialize(_units, action, _active_unit)
	_on_Cursor_moved(_cursor.cell)
