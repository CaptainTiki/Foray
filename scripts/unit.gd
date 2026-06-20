class_name Unit
extends PanelContainer

## A single combatant on the board. Stats are seeded from a UnitClassData
## resource via setup(). All damage flows through take_hit().

signal died(unit: Unit)
signal hp_changed(unit: Unit)

var data: UnitClassData
var hp: int = 0
var max_hp: int = 0
var attack: int = 0
var speed: int = 0
var heal_amount: int = 0
var heal_target_mode: BattleEnums.HealTargetMode = BattleEnums.HealTargetMode.ADJACENT_FORWARD
var class_type: BattleEnums.ClassType = BattleEnums.ClassType.FIGHTER

var team: BattleEnums.Team = BattleEnums.Team.FRIENDLY
var slot_index: int = 0

@onready var _name_label: Label = %NameLabel
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _hp_label: Label = %HPLabel

## Seed this unit from a class definition and its place on the board.
func setup(p_data: UnitClassData, p_team: BattleEnums.Team, p_slot_index: int) -> void:
	data = p_data
	max_hp = data.max_hp
	hp = max_hp
	attack = data.attack
	speed = data.speed
	heal_amount = data.heal_amount
	heal_target_mode = data.heal_target_mode
	class_type = data.class_type
	team = p_team
	slot_index = p_slot_index
	if is_node_ready():
		_refresh()

func _ready() -> void:
	_refresh()

func is_alive() -> bool:
	return hp > 0

## The single entry point for dealing damage to a unit.
func take_hit(damage: int) -> void:
	if not is_alive():
		return
	hp = clampi(hp - damage, 0, max_hp)
	hp_changed.emit(self)
	_refresh()
	if hp == 0:
		died.emit(self)

## Restore hit points, capped at max_hp. Dead units cannot be revived.
func heal(amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	hp = clampi(hp + amount, 0, max_hp)
	hp_changed.emit(self)
	_refresh()

func _refresh() -> void:
	if data == null:
		return
	_name_label.text = data.display_name
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d/%d" % [hp, max_hp]
	modulate = Color.WHITE if is_alive() else Color(0.45, 0.45, 0.45)
	_name_label.add_theme_color_override("font_color", data.color)
