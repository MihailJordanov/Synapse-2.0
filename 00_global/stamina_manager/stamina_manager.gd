extends Node

## Stamina (energy) system, Battle Cats style.
##
## Saved in player_data.json (through PlayerDataManager):
##   stamina, max_stamina, stamina_last_tick_unix
##
## - Regenerates 1 stamina every SECONDS_PER_STAMINA of REAL time (system clock),
##   also while the game is closed.
## - While full, the clock does not run. Spending from full starts the countdown at that moment.
## - refresh() runs on every scene that asks + every second while the game is open.
## - Clock moved backwards -> countdown restarts from now (no gain).

signal stamina_changed(current: int, maximum: int)

const SECONDS_PER_STAMINA: int = 60

var _timer: Timer


func _ready() -> void:
	refresh()

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_timer)
	_timer.timeout.connect(refresh)


#region /// public API

func get_stamina() -> int:
	return PlayerDataManager.stamina


func get_max_stamina() -> int:
	return PlayerDataManager.max_stamina


func is_full() -> bool:
	return get_stamina() >= get_max_stamina()


func can_afford(cost: int) -> bool:
	refresh()
	return get_stamina() >= maxi(cost, 0)


## Spends stamina if there is enough. Returns false (and spends nothing) otherwise.
func try_spend(cost: int) -> bool:
	cost = maxi(cost, 0)
	refresh()

	if get_stamina() < cost:
		return false

	if cost == 0:
		return true

	var was_full: bool = is_full()

	PlayerDataManager.stamina -= cost

	if was_full:
		# The regen countdown starts now (not from when it became full).
		PlayerDataManager.stamina_last_tick_unix = _now()

	PlayerDataManager.save_data()
	_emit_changed()
	return true


## Adds stamina (rewards, refills...). Can go above max, like a bonus.
func add_stamina(amount: int) -> void:
	if amount <= 0:
		return

	refresh()
	var was_full: bool = is_full()
	PlayerDataManager.stamina += amount

	if not was_full and is_full():
		PlayerDataManager.stamina_last_tick_unix = _now()

	PlayerDataManager.save_data()
	_emit_changed()


## Upgrades/changes the cap (e.g. player level up).
func set_max_stamina(value: int) -> void:
	value = maxi(value, 1)

	if value == get_max_stamina():
		return

	refresh()
	var was_full: bool = is_full()
	PlayerDataManager.max_stamina = value

	if was_full and not is_full():
		PlayerDataManager.stamina_last_tick_unix = _now()

	PlayerDataManager.save_data()
	_emit_changed()


## Seconds until the next +1 (0 when full).
func get_seconds_to_next() -> int:
	if is_full():
		return 0

	var elapsed: int = _now() - PlayerDataManager.stamina_last_tick_unix
	return clampi(SECONDS_PER_STAMINA - elapsed, 0, SECONDS_PER_STAMINA)


## Seconds until completely full (0 when full).
func get_seconds_to_full() -> int:
	if is_full():
		return 0

	var missing: int = get_max_stamina() - get_stamina()
	return get_seconds_to_next() + (missing - 1) * SECONDS_PER_STAMINA

#endregion


## Applies the regeneration for the real time that has passed.
func refresh() -> void:
	var now: int = _now()
	var last: int = PlayerDataManager.stamina_last_tick_unix

	# First run, or the system clock went backwards.
	if last <= 0 or now < last:
		PlayerDataManager.stamina_last_tick_unix = now
		PlayerDataManager.save_data()
		return

	if is_full():
		# Full: the countdown is paused. Kept in memory only (on load, full resets it anyway).
		PlayerDataManager.stamina_last_tick_unix = now
		return

	var gained: int = (now - last) / SECONDS_PER_STAMINA

	if gained <= 0:
		return

	PlayerDataManager.stamina = mini(get_stamina() + gained, get_max_stamina())

	if is_full():
		PlayerDataManager.stamina_last_tick_unix = now
	else:
		PlayerDataManager.stamina_last_tick_unix = last + gained * SECONDS_PER_STAMINA

	PlayerDataManager.save_data()
	_emit_changed()


func _emit_changed() -> void:
	stamina_changed.emit(get_stamina(), get_max_stamina())


func _now() -> int:
	return int(Time.get_unix_time_from_system())
