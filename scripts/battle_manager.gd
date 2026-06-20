class_name BattleManager
extends Node

## Drives combat. On each timer tick every living unit acts once in speed
## order. Targeting is resolved by formation position so the same rules work
## for any number of slots. Reports progress purely through the log signal.

signal log_message(text: String)
signal battle_ended(winner: BattleEnums.Team)

@export var tick_seconds: float = 1.0
## When true, start_battle() resolves the whole fight synchronously in a loop
## instead of one tick per timer tick. Used by the headless test runner; the
## timer-driven arena UI leaves this false and is unaffected.
@export var instant: bool = false

## Safety cap for instant mode so a non-terminating fight can't loop forever.
const MAX_INSTANT_TICKS: int = 100

## Slot-indexed formations. Entries may be null (empty slot) and stay in place
## when a unit dies, so positional targeting and splash remain correct.
var _friendly: Array[Unit] = []
var _enemy: Array[Unit] = []
var _running: bool = false
var _tick: int = 0

@onready var _timer: Timer = %Timer

func _ready() -> void:
	_timer.one_shot = false
	_timer.wait_time = tick_seconds
	_timer.timeout.connect(_on_tick)

func is_running() -> bool:
	return _running

func start_battle(friendly: Array[Unit], enemy: Array[Unit]) -> void:
	_friendly = friendly
	_enemy = enemy
	_tick = 0
	_running = true
	log_message.emit("⚔  Battle start!")
	if instant:
		_run_instant()
	else:
		_timer.start()

## Drive the fight to completion immediately. Stops when a side wins or the
## tick cap is reached, reporting a draw in the latter case.
func _run_instant() -> void:
	while _running and _tick < MAX_INSTANT_TICKS:
		_on_tick()
	if _running:
		# Cap hit with both sides still standing — no decisive result.
		_running = false
		log_message.emit("DRAW — tick limit reached")

func stop_battle() -> void:
	_running = false
	_timer.stop()

# --- Tick loop -------------------------------------------------------------

func _on_tick() -> void:
	if not _running:
		return
	_tick += 1
	log_message.emit("── Tick %d ──" % _tick)
	var order := _living_units()
	order.sort_custom(_compare_initiative)
	# Units act in descending speed; everyone sharing a speed forms one tier.
	# A tier resolves simultaneously: we snapshot who is alive when the tier
	# begins and let all of them act, so equal-speed foes still land their
	# blow even if a tier-mate kills them first (mutual kills are possible).
	# A faster tier acting earlier can still cancel a slower unit's action.
	var i := 0
	while i < order.size():
		if not _running:
			return
		var j := i
		while j < order.size() and order[j].speed == order[i].speed:
			j += 1
		var actors: Array[Unit] = []
		for k in range(i, j):
			if order[k].is_alive():
				actors.append(order[k])
		for u in actors:
			_act(u)
		if _check_end():
			return
		i = j

func _act(unit: Unit) -> void:
	var attacker := unit
	var damage := attacker.attack
	if attacker.heal_amount > 0:
		if _heal_action(attacker):
			return
		# No ally to mend — lash out for half the heal power instead.
		damage = roundi(attacker.heal_amount / 2.0)

	var foes := _enemy if attacker.team == BattleEnums.Team.FRIENDLY else _friendly
	var target_index := _resolve_target(attacker, foes)
	if target_index < 0:
		return

	_hit(attacker, foes[target_index], damage)

	var radius := attacker.data.splash_radius
	if radius > 0 and attacker.data.splash_multiplier > 0.0:
		var splash := roundi(damage * attacker.data.splash_multiplier)
		for d in range(1, radius + 1):
			for j in [target_index - d, target_index + d]:
				if j >= 0 and j < foes.size():
					var neighbour := foes[j]
					if neighbour != null and neighbour.is_alive():
						_hit(attacker, neighbour, splash)

func _hit(attacker: Unit, target: Unit, damage: int) -> void:
	var before := target.hp
	target.take_hit(damage)
	log_message.emit("%s hits %s for %d  (%d→%d)" % [
		_label(attacker), _label(target), damage, before, target.hp,
	])
	if not target.is_alive():
		log_message.emit("   %s is defeated." % _label(target))

# --- Healing ---------------------------------------------------------------

## Heal the chosen ally and report true; returns false when there is no living
## ally ahead to mend, leaving the healer free to attack instead.
func _heal_action(healer: Unit) -> bool:
	var allies := _friendly if healer.team == BattleEnums.Team.FRIENDLY else _enemy
	var target := _resolve_heal_target(healer, allies)
	if target == null:
		return false
	var before := target.hp
	target.heal(healer.heal_amount)
	log_message.emit("%s heals %s for %d  (%d→%d)" % [
		_label(healer), _label(target), healer.heal_amount, before, target.hp,
	])
	return true

## The ally a healer mends, per its heal_target_mode. May be null, in which
## case the healer attacks instead.
func _resolve_heal_target(healer: Unit, allies: Array[Unit]) -> Unit:
	match healer.heal_target_mode:
		BattleEnums.HealTargetMode.MOST_WOUNDED:
			return _most_wounded_ally(allies)
		_:
			return _ally_ahead(healer, allies)

## Adjacent forward slot (own_index - 1) if it holds a living ally, otherwise
## the nearest living ally ahead of the healer.
func _ally_ahead(healer: Unit, allies: Array[Unit]) -> Unit:
	for i in range(healer.slot_index - 1, -1, -1):
		var ally := allies[i]
		if ally != null and ally.is_alive():
			return ally
	return null

## Living ally missing the most HP. Null if every ally is at full health, so a
## triage healer with nothing to mend falls through to attacking instead.
func _most_wounded_ally(allies: Array[Unit]) -> Unit:
	var best: Unit = null
	var most_missing := 0
	for ally in allies:
		if ally == null or not ally.is_alive():
			continue
		var missing := ally.max_hp - ally.hp
		if missing > most_missing:
			most_missing = missing
			best = ally
	return best

# --- Targeting -------------------------------------------------------------

## Returns the slot index of the primary target, or -1 if no living foe.
func _resolve_target(attacker: Unit, foes: Array[Unit]) -> int:
	var living: Array[int] = []
	for i in foes.size():
		var f := foes[i]
		if f != null and f.is_alive():
			living.append(i)
	if living.is_empty():
		return -1

	match attacker.data.target_mode:
		BattleEnums.TargetMode.FRONTMOST:
			return living[0]
		BattleEnums.TargetMode.REARMOST:
			return living[living.size() - 1]
		BattleEnums.TargetMode.MIDDLE:
			# Middle of the living foes: alive[alive.size() / 2] (int division).
			return living[living.size() / 2]
	return living[0]

# --- Helpers ---------------------------------------------------------------

func _living_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in _friendly + _enemy:
		if u != null and u.is_alive():
			out.append(u)
	return out

func _has_living(formation: Array[Unit]) -> bool:
	for u in formation:
		if u != null and u.is_alive():
			return true
	return false

## Faster units act first; ties break by slot position (front slots first).
## Equal-speed units across teams resolve simultaneously (see _on_tick); this
## ordering only affects log/readout order within a speed tier.
func _compare_initiative(a: Unit, b: Unit) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	if a.slot_index != b.slot_index:
		return a.slot_index < b.slot_index
	return a.team < b.team

func _check_end() -> bool:
	# A wipe of the friendly side is a loss outright — checked first, so even a
	# mutual wipe in the same tick counts as a defeat, enemy state irrelevant.
	if not _has_living(_friendly):
		_end_battle(BattleEnums.Team.ENEMY)
		return true
	if not _has_living(_enemy):
		_end_battle(BattleEnums.Team.FRIENDLY)
		return true
	return false

func _end_battle(winner: BattleEnums.Team) -> void:
	_running = false
	_timer.stop()
	var winner_name := "Your party" if winner == BattleEnums.Team.FRIENDLY else "Enemy"
	log_message.emit("🏁  %s wins after %d tick(s)!" % [winner_name, _tick])
	battle_ended.emit(winner)

func _label(u: Unit) -> String:
	var side := "F" if u.team == BattleEnums.Team.FRIENDLY else "E"
	return "%s%d %s" % [side, u.slot_index + 1, u.data.display_name]
