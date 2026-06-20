class_name Slot
extends VBoxContainer

## One position on the board: a host area that holds at most one Unit, plus a
## dropdown that selects which class (or Empty) spawns here on Fight.

@export var team: BattleEnums.Team = BattleEnums.Team.FRIENDLY
@export var index: int = 0

var unit: Unit = null

var _types: Array[UnitClassData] = []

@onready var _host: PanelContainer = %Host
@onready var _placeholder: Label = %Placeholder
@onready var _dropdown: OptionButton = %Dropdown

## Populate the dropdown: item 0 is Empty, then one entry per class type.
func setup(types: Array[UnitClassData]) -> void:
	_types = types
	_dropdown.clear()
	_dropdown.add_item("Empty")
	for type_data in _types:
		_dropdown.add_item(type_data.display_name)
	_dropdown.select(0)

## The class chosen in the dropdown, or null for an empty slot.
func selected_data() -> UnitClassData:
	var idx := _dropdown.selected
	if idx <= 0:
		return null
	return _types[idx - 1]

## Spawn the selected unit into the host. Returns the Unit, or null if Empty.
func spawn(unit_scene: PackedScene) -> Unit:
	clear_unit()
	var selected := selected_data()
	if selected == null:
		return null
	var new_unit: Unit = unit_scene.instantiate()
	unit = new_unit
	_host.add_child(new_unit)
	_placeholder.visible = false
	new_unit.setup(selected, team, index)
	return new_unit

func clear_unit() -> void:
	if unit != null and is_instance_valid(unit):
		unit.queue_free()
	unit = null
	_placeholder.visible = true

func set_interactable(value: bool) -> void:
	_dropdown.disabled = not value
