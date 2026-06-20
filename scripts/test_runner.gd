class_name TestRunner
extends Node

## Headless combat test harness. Runs named suites of matchups through a
## BattleManager in instant mode (no timer) and dumps each suite's log to
## res://debug/<suite>.txt in the same format as the debug arena.
## Run it as the main scene, or: godot --headless res://scenes/test_runner.tscn

const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")

const OUTPUT_DIR: String = "res://debug"

## Class key → archetype resource. Keys double as the labels in the report.
const CLASSES: Dictionary = {
	"FIGHTER": preload("res://data/fighter.tres"),
	"MAGE": preload("res://data/mage.tres"),
	"RANGER": preload("res://data/ranger.tres"),
	"CLERIC": preload("res://data/cleric.tres"),
	"MEDIC": preload("res://data/medic.tres"),
}

## Test suites, each written to res://debug/<name>.txt. A matchup is
## [friendly_keys, enemy_keys]; list order is front → rear, so the first key
## sits in slot 0 (the frontmost position). `start` numbers the first matchup
## so labels can continue a conceptual sequence across suites.
const SUITES: Array = [
	{
		"name": "combat_tests",
		"start": 1,
		"matchups": [
			# 1v1
			[["FIGHTER"], ["FIGHTER"]],
			[["FIGHTER"], ["MAGE"]],
			[["FIGHTER"], ["RANGER"]],
			[["FIGHTER"], ["CLERIC"]],
			[["MAGE"], ["MAGE"]],
			[["MAGE"], ["RANGER"]],
			[["RANGER"], ["RANGER"]],
			[["CLERIC"], ["FIGHTER"]],
			# 2v2
			[["FIGHTER", "FIGHTER"], ["FIGHTER", "FIGHTER"]],
			[["FIGHTER", "MAGE"], ["FIGHTER", "FIGHTER"]],
			[["FIGHTER", "MAGE"], ["MAGE", "MAGE"]],
			[["FIGHTER", "MAGE"], ["FIGHTER", "MAGE"]],
			[["FIGHTER", "CLERIC"], ["FIGHTER", "FIGHTER"]],
			[["FIGHTER", "CLERIC"], ["FIGHTER", "MAGE"]],
			[["FIGHTER", "RANGER"], ["FIGHTER", "FIGHTER"]],
			[["FIGHTER", "RANGER"], ["FIGHTER", "MAGE"]],
			# 3v3
			[["FIGHTER", "MAGE", "RANGER"], ["FIGHTER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "CLERIC", "MAGE"], ["FIGHTER", "FIGHTER", "MAGE"]],
			[["FIGHTER", "CLERIC", "RANGER"], ["MAGE", "MAGE", "FIGHTER"]],
			[["FIGHTER", "FIGHTER", "MAGE"], ["FIGHTER", "MAGE", "RANGER"]],
			# 4v4
			[["FIGHTER", "CLERIC", "MAGE", "RANGER"], ["FIGHTER", "FIGHTER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "CLERIC", "MAGE", "RANGER"], ["FIGHTER", "FIGHTER", "MAGE", "MAGE"]],
			[["FIGHTER", "CLERIC", "MAGE", "RANGER"], ["FIGHTER", "CLERIC", "MAGE", "RANGER"]],
			[["FIGHTER", "FIGHTER", "MAGE", "MAGE"], ["RANGER", "RANGER", "FIGHTER", "FIGHTER"]],
			# stress
			[["MAGE", "MAGE", "MAGE", "MAGE"], ["FIGHTER", "FIGHTER", "FIGHTER", "FIGHTER"]],
		],
	},
	{
		"name": "defense_tests",
		"start": 26,
		"matchups": [
			# Cleric in slot 2 — heals the (full-HP) Mage ahead of it.
			[["FIGHTER", "MAGE", "CLERIC", "FIGHTER"], ["FIGHTER", "FIGHTER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "MAGE", "CLERIC", "FIGHTER"], ["RANGER", "RANGER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "MAGE", "CLERIC", "FIGHTER"], ["FIGHTER", "FIGHTER", "MAGE", "MAGE"]],
			[["FIGHTER", "MAGE", "CLERIC", "FIGHTER"], ["FIGHTER", "CLERIC", "MAGE", "RANGER"]],
			# Cleric moved up to slot 1 — now heals the front Fighter taking hits.
			[["FIGHTER", "CLERIC", "MAGE", "FIGHTER"], ["FIGHTER", "FIGHTER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "CLERIC", "MAGE", "FIGHTER"], ["RANGER", "RANGER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "CLERIC", "MAGE", "FIGHTER"], ["FIGHTER", "FIGHTER", "MAGE", "MAGE"]],
			[["FIGHTER", "CLERIC", "MAGE", "FIGHTER"], ["FIGHTER", "CLERIC", "MAGE", "RANGER"]],
			# Triage Medic in slot 2 (same layout as 26-29) — heals whoever is
			# most wounded, so the front Fighter gets the heals, not the full Mage.
			[["FIGHTER", "MAGE", "MEDIC", "FIGHTER"], ["FIGHTER", "FIGHTER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "MAGE", "MEDIC", "FIGHTER"], ["RANGER", "RANGER", "FIGHTER", "FIGHTER"]],
			[["FIGHTER", "MAGE", "MEDIC", "FIGHTER"], ["FIGHTER", "FIGHTER", "MAGE", "MAGE"]],
			[["FIGHTER", "MAGE", "MEDIC", "FIGHTER"], ["FIGHTER", "CLERIC", "MAGE", "RANGER"]],
		],
	},
]

@onready var _manager: BattleManager = %BattleManager

## Log lines captured for the test currently running.
var _lines: PackedStringArray = []

func _ready() -> void:
	_manager.log_message.connect(_on_log)
	for suite in SUITES:
		_run_suite(suite)
	get_tree().quit()

func _run_suite(suite: Dictionary) -> void:
	var matchups: Array = suite["matchups"]
	var start: int = suite["start"]

	var blocks: PackedStringArray = []
	for i in matchups.size():
		var matchup: Array = matchups[i]
		blocks.append(_run_test(start + i, matchup[0], matchup[1]))

	# One blank line between tests; trailing newline at end of file.
	var report := "\n\n".join(blocks) + "\n"
	var path := "%s/%s.txt" % [OUTPUT_DIR, suite["name"]]
	_save(path, report)
	print("Wrote %d tests to %s" % [matchups.size(), path])

func _run_test(number: int, friendly_keys: Array, enemy_keys: Array) -> String:
	_lines = []
	var friendly := _spawn_side(friendly_keys, BattleEnums.Team.FRIENDLY)
	var enemy := _spawn_side(enemy_keys, BattleEnums.Team.ENEMY)

	_manager.start_battle(friendly, enemy) # instant mode → resolves synchronously

	_despawn(friendly)
	_despawn(enemy)

	var header := _format_label(number, friendly_keys, enemy_keys)
	return header + "\n" + "\n".join(_lines)

func _spawn_side(keys: Array, team: BattleEnums.Team) -> Array[Unit]:
	var units: Array[Unit] = []
	for i in keys.size():
		var unit: Unit = UNIT_SCENE.instantiate()
		add_child(unit) # in-tree so the unit's @onready labels resolve
		unit.setup(CLASSES[keys[i]], team, i)
		units.append(unit)
	return units

func _despawn(units: Array[Unit]) -> void:
	for unit in units:
		unit.queue_free()

func _on_log(text: String) -> void:
	_lines.append(text)

func _format_label(number: int, friendly_keys: Array, enemy_keys: Array) -> String:
	var left := "[%s]" % ", ".join(friendly_keys)
	var right := "[%s]" % ", ".join(enemy_keys)
	return "%02d. %s vs %s" % [number, left.rpad(34), right]

func _save(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("TestRunner: could not open %s" % path)
		return
	file.store_string(text)
	file.close()
