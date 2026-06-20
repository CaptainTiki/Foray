class_name Arena
extends Control

## Test-arena view. Wires the 8 slots, the Fight/Reset buttons and the combat
## log to a BattleManager. Owns no combat rules itself — it only spawns units
## from the per-slot dropdowns and hands the formations to the manager.

const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")

## Folder where per-battle combat logs are written for debugging.
const DEBUG_DIR: String = "res://debug"

## Available unit classes offered in every slot's dropdown.
const UNIT_TYPES: Array[UnitClassData] = [
	preload("res://data/fighter.tres"),
	preload("res://data/mage.tres"),
	preload("res://data/ranger.tres"),
	preload("res://data/cleric.tres"),
]

@onready var _manager: BattleManager = %BattleManager
@onready var _log: RichTextLabel = %Log
@onready var _fight_button: Button = %FightButton
@onready var _reset_button: Button = %ResetButton

var _friendly_slots: Array[Slot] = []
var _enemy_slots: Array[Slot] = []

## Open file handle for the current battle's combat log, or null when idle.
var _log_file: FileAccess = null

func _ready() -> void:
	_friendly_slots = [%F0, %F1, %F2, %F3]
	_enemy_slots = [%E0, %E1, %E2, %E3]
	for slot in _all_slots():
		slot.setup(UNIT_TYPES)

	_fight_button.pressed.connect(_on_fight_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_manager.log_message.connect(_append_log)
	_manager.battle_ended.connect(_on_battle_ended)

	_append_log("Pick units, then press Fight.")

func _on_fight_pressed() -> void:
	if _manager.is_running():
		return
	_log.clear()

	var friendly := _spawn_formation(_friendly_slots)
	var enemy := _spawn_formation(_enemy_slots)
	if not _has_living(friendly) or not _has_living(enemy):
		_append_log("Need at least one unit on each side to fight.")
		return

	_open_log_file()
	_set_slots_interactable(false)
	_fight_button.disabled = true
	_manager.start_battle(friendly, enemy)

func _on_reset_pressed() -> void:
	_manager.stop_battle()
	_close_log_file()
	for slot in _all_slots():
		slot.clear_unit()
	_log.clear()
	_set_slots_interactable(true)
	_fight_button.disabled = false
	_append_log("Reset. Pick units, then press Fight.")

func _on_battle_ended(_winner: BattleEnums.Team) -> void:
	# Leave the board frozen on the result; Reset clears it for another round.
	_append_log("Press Reset to set up another battle.")
	_close_log_file()

func _spawn_formation(slots: Array[Slot]) -> Array[Unit]:
	var formation: Array[Unit] = []
	for slot in slots:
		formation.append(slot.spawn(UNIT_SCENE))
	return formation

func _has_living(formation: Array[Unit]) -> bool:
	for u in formation:
		if u != null and u.is_alive():
			return true
	return false

func _all_slots() -> Array[Slot]:
	return _friendly_slots + _enemy_slots

func _set_slots_interactable(value: bool) -> void:
	for slot in _all_slots():
		slot.set_interactable(value)

func _append_log(text: String) -> void:
	_log.add_text(text + "\n")
	if _log_file != null:
		_log_file.store_line(text)

## Create the debug folder (if needed) and open a fresh timestamped log file.
func _open_log_file() -> void:
	_close_log_file()
	DirAccess.make_dir_recursive_absolute(DEBUG_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/combat_%s.txt" % [DEBUG_DIR, stamp]
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	if _log_file == null:
		push_warning("Could not open combat log file: %s" % path)

func _close_log_file() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
