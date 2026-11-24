extends Node
## Autoload "AnalyticsManager": everything that goes to GameAnalytics passes through here.
##
## Automatic in GameAnalytics (nothing to call): unique installs, DAU/MAU, session count and
## length, Day 1/7/30 retention, game version (configureBuild), OS, device.
##
## Automatic here (signals of other autoloads, nothing to call):
##   levels unlocked / first clears, zones unlocked, tutorials completed, equipped legend,
##   Shillings / Seals earned and spent, stamina running out.
##
## Called from the game (see battle_* functions):
##   battle start / card played / battle end (win, loss, abandoned), second chance, ads,
##   not enough stamina, tutorial steps.
##
## Keys: analytics_secrets.gd (git-ignored). Missing file / empty keys -> analytics off, game runs normally.

const SECRETS_PATH: String = "res://00_global/analytics_manager/analytics_secrets.gd"
const DEFAULT_BUILD: String = "0.1.0"

## Must be registered before init. Currencies: letters only. Item types: alphanumeric. Max 20 each.
const CURRENCY_MONEY: String = "Shillings"
const CURRENCY_SEALS: String = "Seals"
const ITEM_TYPES: Array[String] = ["Battle", "Defeat", "SecondChance", "Shop", "Reward", "Tutorial", "Other"]

## Editor / debug runs also send events (handy while integrating). Turn off when the real players come,
## or use a separate "dev" game in GameAnalytics for testing.
@export var submit_in_debug_builds: bool = true
## Prints every event the SDK sends (debug builds only).
@export var verbose_log: bool = false

var _ga: Object = null
var _enabled: bool = false

# Currency tracking: last known totals + the reason for the next change.
var _last_money: int = 0
var _last_seals: int = 0
var _currency_item_type: String = "Other"
var _currency_item_id: String = "unknown"

var _last_stamina: int = -1

## The running battle (empty when none). Aggregated, sent at the end -> few events per battle.
var _battle: Dictionary = {}


func _ready() -> void:
	_init_game_analytics()
	_connect_game_signals()


#region /// setup

func _init_game_analytics() -> void:
	if not Engine.has_singleton("GameAnalytics"):
		push_warning("AnalyticsManager: GameAnalytics plugin not found (not supported on this platform?).")
		return

	var keys: Dictionary = _load_keys()

	if keys.is_empty():
		push_warning("AnalyticsManager: no keys in %s - analytics is off." % SECRETS_PATH)
		return

	_ga = Engine.get_singleton("GameAnalytics")

	if OS.is_debug_build():
		_ga.setEnabledInfoLog(true)
		_ga.setEnabledVerboseLog(verbose_log)

	_ga.configureBuild(str(ProjectSettings.get_setting("application/config/version", DEFAULT_BUILD)))
	_ga.configureAvailableResourceCurrencies([CURRENCY_MONEY, CURRENCY_SEALS])
	_ga.configureAvailableResourceItemTypes(ITEM_TYPES)
	_ga.init(keys["game_key"], keys["secret_key"])

	_enabled = true
	set_submission_enabled(submit_in_debug_builds or not OS.is_debug_build())


func _load_keys() -> Dictionary:
	if not ResourceLoader.exists(SECRETS_PATH):
		return {}

	var script := load(SECRETS_PATH) as Script

	if script == null:
		return {}

	var constants: Dictionary = script.get_script_constant_map()
	var game_key: String = str(constants.get("GAME_KEY", ""))
	var secret_key: String = str(constants.get("SECRET_KEY", ""))

	if game_key.is_empty() or secret_key.is_empty():
		return {}

	return {"game_key": game_key, "secret_key": secret_key}


## For a privacy / consent option: false = nothing is sent (events are dropped).
func set_submission_enabled(value: bool) -> void:
	if _ga != null:
		_ga.setEnabledEventSubmission(value)


func is_active() -> bool:
	return _enabled and _ga != null


func _connect_game_signals() -> void:
	_last_money = PlayerDataManager.get_money()
	_last_seals = PlayerDataManager.get_seals()
	_last_stamina = StaminaManager.get_stamina()

	PlayerDataManager.money_changed.connect(_on_money_changed)
	PlayerDataManager.seals_changed.connect(_on_seals_changed)
	StaminaManager.stamina_changed.connect(_on_stamina_changed)
	LevelManager.level_unlocked.connect(func(level_id: String) -> void: design("Progress:LevelUnlocked:" + level_id))
	LevelManager.level_defeated.connect(func(level_id: String) -> void: design("Progress:LevelCleared:" + level_id))
	ZoneManager.zone_unlocked.connect(func(zone: String) -> void: design("Progress:ZoneUnlocked:" + zone))
	TutorialManager.tutorial_completed.connect(func(tutorial_id: String) -> void: design("Tutorial:Completed:" + tutorial_id))
	LegendManager.equipped_legend_changed.connect(func(legend_id: int) -> void: design("Legend:Equipped:%d" % legend_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _battle.is_empty():
			battle_ended("abandoned")  # closed the game in the middle of a battle

		if _ga != null:
			_ga.onQuit()

#endregion


#region /// low level (use these for anything new)

## Design event: 1-5 parts split by ":" (each max 64 chars), e.g. "Shop:Opened". value -> sum/mean in GA.
func design(event_id: String, value: Variant = null) -> void:
	if not is_active():
		return

	if value == null:
		_ga.addDesignEvent(event_id, {})
	else:
		_ga.addDesignEventWithValue(event_id, float(value))


## status: "start" / "complete" / "fail". zone + level, e.g. ("ZoneA", "A02").
func progression(status: String, zone: String, level: String, score: int = -1) -> void:
	if not is_active():
		return

	if score >= 0:
		_ga.addProgressionEventWithScore(status, zone, level, "", score)
	else:
		_ga.addProgressionEvent(status, zone, level, "", {})


## flow: "source" (earned) / "sink" (spent).
func resource(flow: String, currency: String, amount: int, item_type: String, item_id: String) -> void:
	if not is_active() or amount <= 0:
		return

	if not ITEM_TYPES.has(item_type):
		item_type = "Other"

	_ga.addResourceEvent(flow, currency, amount, item_type, item_id.left(32), {})


## severity: "debug" / "info" / "warning" / "error" / "critical".
func error(severity: String, message: String) -> void:
	if is_active():
		_ga.addErrorEvent(severity, message, {})

#endregion


#region /// battles

## Call once when a battle starts, with the FULL decks (duplicates included) before anything is drawn.
## level_id e.g. "A02" ("" = test run / tutorial -> pass a name like "SpellTutorial").
func battle_started(level_id: String, unit_ids: Array, spell_ids: Array, legend_id: int) -> void:
	if not _battle.is_empty():
		battle_ended("abandoned")

	var level: String = level_id if not level_id.is_empty() else "Test"
	var copies: Dictionary = {}  # card id -> copies in the deck

	for card_id in unit_ids + spell_ids:
		copies[int(card_id)] = int(copies.get(int(card_id), 0)) + 1

	_battle = {
		"level": level,
		"zone": _zone_of(level),
		"legend": legend_id,
		"copies": copies,
		"played": {},  # card id -> times played
		"units_played": 0,
		"spells_played": 0,
	}

	progression("start", _battle["zone"], level)
	design("Battle:Started:" + level)
	design("Legend:Picked:%d" % legend_id)

	# Popularity of each card in decks (count) + copies per deck (mean of the value).
	for card_id in copies:
		design("Deck:Copies:%d" % card_id, copies[card_id])


## Call after a successful play (not on drag). Only the player's cards are counted.
func battle_card_played(card_id: int, is_spell: bool) -> void:
	if _battle.is_empty():
		return

	var played: Dictionary = _battle["played"]
	played[card_id] = int(played.get(card_id, 0)) + 1

	if is_spell:
		_battle["spells_played"] += 1
	else:
		_battle["units_played"] += 1


## result: "win" / "loss" / "abandoned". Call once, at the FINAL result (after the second-chance choice).
func battle_ended(result: String, player_score: int = 0, enemy_score: int = 0, turns: int = 0) -> void:
	if _battle.is_empty() or result not in ["win", "loss", "abandoned"]:
		return

	var battle: Dictionary = _battle
	_battle = {}
	var level: String = battle["level"]
	var won: bool = result == "win"

	if won:
		progression("complete", battle["zone"], level, player_score)
	else:
		progression("fail", battle["zone"], level, player_score)

	design("Battle:%s:%s" % [result.capitalize(), level])
	design("Battle:Turns:" + level, turns)
	design("Battle:ScoreDiff:" + level, player_score - enemy_score)

	# Cards played, by id and by level (value = times in this battle -> sum = total plays).
	for card_id in battle["played"]:
		design("CardPlayed:%s:%d" % [level, card_id], battle["played"][card_id])

	design("CardType:Unit:" + level, battle["units_played"])
	design("CardType:Spell:" + level, battle["spells_played"])

	if result == "abandoned":
		return  # no win rate for unfinished battles

	# Win rate = mean of the value (1 = win, 0 = loss).
	var win_value: int = 1 if won else 0
	design("Legend:WinRate:%d" % battle["legend"], win_value)

	for card_id in battle["copies"]:
		design("Card:WinRate:%d" % card_id, win_value)


func is_in_battle() -> bool:
	return not _battle.is_empty()

#endregion


#region /// other game events

## option: "rewind" / "enemy_minus_3"... Call when the player buys the second chance.
func second_chance_used(option: String) -> void:
	var level: String = _battle.get("level", "Unknown")
	design("SecondChance:%s:%s" % [option, level])


## action: "show" / "clicked" / "failed_show" / "reward_received". type: "rewarded_video" / "interstitial" / "banner".
## Real ad events only exist on Android / iOS; a design event is always sent too.
func ad_event(action: String, ad_type: String, placement: String, ad_sdk: String = "admob") -> void:
	design("Ads:%s:%s:%s" % [placement, ad_type, action])

	if is_active() and OS.get_name() in ["Android", "iOS"]:
		_ga.addAdEvent(action, ad_type, ad_sdk, placement, {})


## The player pressed Play without enough stamina.
func stamina_not_enough(level_id: String) -> void:
	design("Stamina:NotEnough:" + level_id)


## Optional finer tutorial progress, e.g. tutorial_step("start_tutorial", "first_cycle").
func tutorial_step(tutorial_id: String, step: String) -> void:
	design("Tutorial:Step:%s:%s" % [tutorial_id, step])


## Optional: say WHY the next Shillings / Seals change happens (otherwise "Battle" in a battle, else "Other").
## Example: AnalyticsManager.currency_reason("SecondChance", "rewind") right before try_spend_seals(30).
func currency_reason(item_type: String, item_id: String) -> void:
	_currency_item_type = item_type
	_currency_item_id = item_id

#endregion


#region /// automatic tracking

func _on_money_changed(money: int) -> void:
	_track_currency_change(CURRENCY_MONEY, money - _last_money)
	_last_money = money


func _on_seals_changed(seals: int) -> void:
	_track_currency_change(CURRENCY_SEALS, seals - _last_seals)
	_last_seals = seals


func _track_currency_change(currency: String, delta: int) -> void:
	if delta == 0:
		return

	var item_type: String = _currency_item_type
	var item_id: String = _currency_item_id

	if item_type == "Other" and not _battle.is_empty():
		item_type = "Battle"
		item_id = _battle["level"]

	resource("source" if delta > 0 else "sink", currency, absi(delta), item_type, item_id)

	_currency_item_type = "Other"
	_currency_item_id = "unknown"


func _on_stamina_changed(current: int, _maximum: int) -> void:
	if current <= 0 and _last_stamina > 0:
		design("Stamina:Depleted")

	_last_stamina = current


## "A02" -> "ZoneA". Anything else (tests, tutorials) -> "Special".
func _zone_of(level: String) -> String:
	if level.length() >= 3 and level.substr(1).is_valid_int():
		return "Zone" + level.left(1).to_upper()

	return "Special"

#endregion
