class_name UnitClassData
extends Resource

## Data-driven definition of a unit archetype. One .tres per class.
## Stats and targeting rules live here so combat logic stays generic.

@export var display_name: String = "Unit"
@export var class_type: BattleEnums.ClassType = BattleEnums.ClassType.FIGHTER

@export_group("Stats")
@export var max_hp: int = 10
@export var attack: int = 3
@export var speed: int = 5
## Hit points restored to an ally each tick. Non-zero marks a healer, which
## heals instead of attacking. 0 = this class deals damage normally.
@export var heal_amount: int = 0
## How a healer picks its target. Only consulted when heal_amount > 0.
@export var heal_target_mode: BattleEnums.HealTargetMode = BattleEnums.HealTargetMode.ADJACENT_FORWARD

@export_group("Targeting")
## Where this class aims its primary hit within the enemy formation.
@export var target_mode: BattleEnums.TargetMode = BattleEnums.TargetMode.FRONTMOST
## How many slots to either side of the primary target also get hit.
@export_range(0, 3) var splash_radius: int = 0
## Fraction of attack dealt to splashed neighbours (e.g. 0.6 = 60%).
@export_range(0.0, 1.0, 0.05) var splash_multiplier: float = 0.0

@export_group("Display")
@export var color: Color = Color.WHITE
