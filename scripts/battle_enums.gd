class_name BattleEnums
extends RefCounted

## Shared enums for the battle systems. Pure constants holder — never instanced.

## The archetype of a unit. Drives base stats and targeting behaviour.
enum ClassType {
	FIGHTER,
	MAGE,
	RANGER,
	CLERIC,
	MEDIC,
}

## How a healer chooses which ally to mend each tick.
enum HealTargetMode {
	ADJACENT_FORWARD, ## Ally in the slot ahead, else nearest living ally ahead.
	MOST_WOUNDED,     ## Living ally missing the most HP (anywhere on the team).
}

## How a unit picks its primary target within the enemy formation.
## Expressed by formation position so it stays correct for any slot count.
enum TargetMode {
	FRONTMOST, ## First living enemy counting from the front.
	MIDDLE,    ## Living enemy nearest the centre of the formation.
	REARMOST,  ## Last living enemy counting from the front.
}

## Which side of the arena a unit belongs to.
enum Team {
	FRIENDLY,
	ENEMY,
}
