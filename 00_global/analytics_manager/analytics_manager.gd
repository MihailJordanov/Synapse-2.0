extends Node
## Autoload "AnalyticsManager": everything that goes to GameAnalytics passes through here.
## Full event list and how to read it: docs/analytics/ANALYTICS.md
##
## Automatic in GameAnalytics (nothing to call): installs, DAU/MAU, sessions and their length,
## Day 1/7/30 retention, game version (configureBuild), OS, device.
##
## Two kinds of events:
##   Immediate  - progression (start / complete / fail), battle result details, tutorials,
##                level / zone unlocks, currencies, second chance, ads. One per occurrence.
##   Aggregated - cards, legends, stamina. Counted locally in AnalyticsAggregator
##                (saved in user://analytics_buffer.json) and sent as summed values:
##                every flush_every_battles battles, after flush_interval_minutes, when the app goes
##                to the background / closes (from background_flush_min_battles battles on),
##                and on the next launch if something was left.
##
## Keys: analytics_secrets.gd (git-ignored). Missing file / empty keys -> analytics off, game runs normally.

const SECRETS_PATH: String = "res://00_global/analytics_manager/analytics_secrets.gd"
const BUFFER_PATH: String = "user://analytics_buffer.json"
const DEFAULT_BUILD: String = "0.1.0"

## Must be registered before init. Currencies: letters only. Item types: alphanumeric. Max 20 each.
const CURRENCY_MONEY: String = "Shillings"
const CURRENCY_SEALS: String = "Seals"
const CURRENCY_STAMINA: String = "Stamina"
const ITEM_TYPES: Array[String] = ["Battle", "Defeat", "SecondChance", "Shop", "Reward", "Tutorial", "Regen", "Other"]

## Editor / debug runs also send events (handy while integrating). Turn off when the real players come,
## or use a separate "dev" game in GameAnalytics for testing.
@export var submit_in_debug_builds: bool = true
## SDK log in the Output panel (debug builds only). Off by default: it prints a long JSON block
## for EVERY event, which overflows Godot's Output panel when the aggregated statistics are sent.
@export var info_log: bool = false
## Even more SDK log (debug builds only).
@export var verbose_log: bool = false
## Aggregated statistics are sent after this many battles...
@export_range(1, 100, 1) var flush_every_battles: int = 15
## ...or when a battle ends and this much time passed since the last send.
@export_range(1.0, 240.0, 1.0) var flush_interval_minutes: float = 30.0
## Going to the background / closing sends the aggregated statistics only from this many battles on
## (fewer stay saved and go with the next send - sending 1 battle alone costs more than before).
@export_range(1, 100, 1) var background_flush_min_battles: int = 5
## Debug builds: print the analytics report after every send (never sent to GameAnalytics).
@export var print_debug_report: bool = true

var _ga: Object = null
var _enabled: bool = false
var _submission_enabled: bool = true

var _aggregator: AnalyticsAggregator = AnalyticsAggregator.new()
var _last_flush_ms: int = 0
var _buffer_dirty: bool = false

# Currency tracking: last known totals + the reason for the next change.
var _last_money: int = 0
var _last_seals: int = 0
var _last_stamina: int = -1
var _currency_item_type: String = "Other"
var _currency_item_id: String = "unknown"

## The running battle (empty when none).
var _battle: Dictionary = {}

## Development numbers only (get_debug_report()). Counts what is handed to the SDK,
## which is not the same as "received by GameAnalytics".
var _diag: Dictionary = {
	"battles": 0,
	"flushes": 0,
	"sent": {"design": 0, "progression": 0, "resource": 0, "error": 0, "ad": 0},
	"battle_events_sent": 0,  # progression + battle + aggregated events
	"legacy_battle_events": 0,  # what the previous (per-battle) implementation would have sent
}


func _ready() -> void:
	_init_game_analytics()
	_connect_game_signals()
	_last_flush_ms = Time.get_ticks_msec()
	_load_buffer()

	# Left over from the last run (killed before it was sent). Small leftovers just keep
	# accumulating with this session's battles.
	if _aggregator.battles_since_flush >= background_flush_min_battles:
		flush()


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

	_ga.setEnabledInfoLog(OS.is_debug_build() and info_log)
	_ga.setEnabledVerboseLog(OS.is_debug_build() and verbose_log)

	_ga.configureBuild(str(ProjectSettings.get_setting("application/config/version", DEFAULT_BUILD)))
	_ga.configureAvailableResourceCurrencies([CURRENCY_MONEY, CURRENCY_SEALS, CURRENCY_STAMINA])
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


## For a privacy / consent option: false = nothing is sent and nothing is collected
## (pending aggregated statistics are deleted).
func set_submission_enabled(value: bool) -> void:
	_submission_enabled = value

	if _ga != null:
		_ga.setEnabledEventSubmission(value)

	if not value:
		_battle = {}
		_aggregator.clear()
		_buffer_dirty = true
		_save_buffer()


func is_active() -> bool:
	return _enabled and _ga != null and _submission_enabled


func _connect_game_signals() -> void:
	_last_money = PlayerDataManager.get_money()
	_last_seals = PlayerDataManager.get_seals()
	_last_stamina = StaminaManager.get_stamina()

	PlayerDataManager.money_changed.connect(_on_money_changed)
	PlayerDataManager.seals_changed.connect(_on_seals_changed)
	StaminaManager.stamina_changed.connect(_on_stamina_changed)
	# One-time milestones (first unlock / first clear only).
	LevelManager.level_unlocked.connect(func(level_id: String) -> void: design("Progress:LevelUnlocked:" + level_id))
	LevelManager.level_defeated.connect(func(level_id: String) -> void: design("Progress:LevelCleared:" + level_id))
	ZoneManager.zone_unlocked.connect(func(zone: String) -> void: design("Progress:ZoneUnlocked:" + zone))
	TutorialManager.tutorial_completed.connect(func(tutorial_id: String) -> void: design("Tutorial:Completed:" + tutorial_id))
	# Deck-building choice (only when it changes), not battles - those are Legend:Battles.
	LegendManager.equipped_legend_changed.connect(func(legend_id: int) -> void: design("Legend:Equipped:%d" % legend_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _battle.is_empty():
			battle_ended("abandoned")  # closed the game in the middle of a battle

		_background_flush()

		if _ga != null:
			_ga.onQuit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# Android: the app may be killed in the background without any other callback.
		_background_flush()

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

	_count_sent("design")


## status: "start" / "complete" / "fail". zone + level, e.g. ("ZoneA", "A02").
func progression(status: String, zone: String, level: String, score: int = -1) -> void:
	if not is_active():
		return

	if score >= 0:
		_ga.addProgressionEventWithScore(status, zone, level, "", score)
	else:
		_ga.addProgressionEvent(status, zone, level, "", {})

	_count_sent("progression")


## flow: "source" (earned) / "sink" (spent).
func resource(flow: String, currency: String, amount: int, item_type: String, item_id: String) -> void:
	if not is_active() or amount <= 0:
		return

	if not ITEM_TYPES.has(item_type):
		item_type = "Other"

	_ga.addResourceEvent(flow, currency, amount, item_type, item_id.left(32), {})
	_count_sent("resource")


## severity: "debug" / "info" / "warning" / "error" / "critical".
func error(severity: String, message: String) -> void:
	if is_active():
		_ga.addErrorEvent(severity, message, {})
		_count_sent("error")

#endregion


#region /// battles

## Call once when a battle starts, with the FULL decks (duplicates included) before anything is drawn.
## level_id e.g. "A02" ("" = test run / tutorial -> pass a name like "SpellTutorial").
func battle_started(level_id: String, unit_ids: Array, spell_ids: Array, legend_id: int) -> void:
	if not is_active():
		return

	if not _battle.is_empty():
		battle_ended("abandoned")

	var level: String = level_id if not level_id.is_empty() else "Test"

	_battle = {
		"level": level,
		"zone": _zone_of(level),
		"legend": legend_id,
		"deck": unit_ids + spell_ids,
		"played": {},  # card id -> times played
	}

	progression("start", _battle["zone"], level)
	_diag["battle_events_sent"] += 1


## Call after a successful play (not on drag). Only the player's cards are counted.
## Unit / spell totals come from the card ids (1xxxx = unit, 2xxxx = spell), so is_spell is not stored.
func battle_card_played(card_id: int, _is_spell: bool = false) -> void:
	if _battle.is_empty():
		return

	var played: Dictionary = _battle["played"]
	played[card_id] = int(played.get(card_id, 0)) + 1


## result: "win" / "loss" / "abandoned". Call once, at the FINAL result (after the second-chance choice).
func battle_ended(result: String, player_score: int = 0, enemy_score: int = 0, turns: int = 0) -> void:
	if _battle.is_empty() or result not in ["win", "loss", "abandoned"]:
		return

	var battle: Dictionary = _battle
	_battle = {}

	if not is_active():
		return

	var level: String = battle["level"]
	var finished: bool = result != "abandoned"
	var sent_before: int = _total_sent()

	# Immediate: the progression funnel (attempts, wins, fails per level).
	if result == "win":
		progression("complete", battle["zone"], level, player_score)
	else:
		progression("fail", battle["zone"], level, player_score)

	if finished:
		design("Battle:Turns:" + level, turns)
		design("Battle:ScoreDiff:" + level, player_score - enemy_score)
	else:
		design("Battle:Abandoned:" + level)

	_diag["battle_events_sent"] += _total_sent() - sent_before
	_diag["battles"] += 1
	_diag["legacy_battle_events"] += _legacy_event_cost(battle, finished)

	# Aggregated: cards, legend.
	_aggregator.record_battle(battle["deck"], battle["played"], battle["legend"], result)
	_buffer_dirty = true
	_save_buffer()
	_flush_if_due()


func is_in_battle() -> bool:
	return not _battle.is_empty()

#endregion


#region /// aggregation

## Sends everything that was aggregated and empties the buffer. Safe to call any time.
func flush() -> void:
	if not is_active():
		_save_buffer()
		return

	if not _aggregator.has_pending():
		return

	var sent_before: int = _total_sent()

	for event: Dictionary in _aggregator.build_events():
		if event["type"] == "design":
			design(event["id"], event["value"])
		else:
			resource(event["flow"], event["currency"], event["amount"], event["item_type"], event["item_id"])

	_diag["battle_events_sent"] += _total_sent() - sent_before
	_diag["flushes"] += 1

	_aggregator.clear()
	_last_flush_ms = Time.get_ticks_msec()
	_buffer_dirty = true
	_save_buffer()  # right after sending: a restart must not send the same counters again

	if OS.is_debug_build() and print_debug_report:
		print(get_debug_report())


## Background / close: send only if it is worth it, always save the rest (sent on the next launch).
func _background_flush() -> void:
	if _aggregator.battles_since_flush >= background_flush_min_battles:
		flush()
	else:
		_save_buffer()


func _flush_if_due() -> void:
	var minutes: float = (Time.get_ticks_msec() - _last_flush_ms) / 60000.0

	if _aggregator.battles_since_flush >= flush_every_battles or minutes >= flush_interval_minutes:
		flush()


func _save_buffer() -> void:
	if not _buffer_dirty:
		return

	var file := FileAccess.open(BUFFER_PATH, FileAccess.WRITE)

	if file == null:
		return  # analytics must never break the game

	file.store_string(JSON.stringify(_aggregator.to_dict()))
	_buffer_dirty = false


func _load_buffer() -> void:
	if not FileAccess.file_exists(BUFFER_PATH):
		return

	var file := FileAccess.open(BUFFER_PATH, FileAccess.READ)

	if file == null:
		return

	if not _aggregator.from_dict(JSON.parse_string(file.get_as_text())):
		push_warning("AnalyticsManager: analytics buffer was unreadable and was reset.")
		_buffer_dirty = true
		_save_buffer()

#endregion


#region /// other game events

## option: "rewind" / "enemy_minus_points"... Call when the player buys the second chance.
func second_chance_used(option: String) -> void:
	var level: String = _battle.get("level", "Unknown")
	design("SecondChance:%s:%s" % [option, level])


## action: "show" / "clicked" / "failed_show" / "reward_received". type: "rewarded_video" / "interstitial" / "banner".
## Native ad events only exist on Android / iOS; on other platforms a design event is sent instead.
func ad_event(action: String, ad_type: String, placement: String, ad_sdk: String = "admob") -> void:
	if not is_active():
		return

	if OS.get_name() in ["Android", "iOS"]:
		_ga.addAdEvent(action, ad_type, ad_sdk, placement, {})
		_count_sent("ad")
	else:
		design("Ads:%s:%s:%s" % [placement, ad_type, action])


## The player pressed Play without enough stamina.
func stamina_not_enough(level_id: String) -> void:
	design("Stamina:NotEnough:" + level_id)


## Optional finer tutorial progress, e.g. tutorial_step("start_tutorial", "first_cycle").
func tutorial_step(tutorial_id: String, step: String) -> void:
	design("Tutorial:Step:%s:%s" % [tutorial_id, step])


## Optional: say WHY the next Shillings / Seals / Stamina change happens
## (otherwise "Battle" in a battle, else "Other"; stamina: spent = "Battle", gained = "Regen").
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


## Shillings / Seals: immediate (few per battle, important for the economy).
func _track_currency_change(currency: String, delta: int) -> void:
	if delta == 0:
		return

	var reason: Array = _take_currency_reason()

	if reason[0] == "Other" and not _battle.is_empty():
		reason = ["Battle", _battle["level"]]

	resource("source" if delta > 0 else "sink", currency, absi(delta), reason[0], reason[1])


## Stamina: aggregated (regen ticks would be far too many events). Totals stay exact.
func _on_stamina_changed(current: int, _maximum: int) -> void:
	var delta: int = current - _last_stamina

	if current <= 0 and _last_stamina > 0:
		design("Stamina:Depleted")

	_last_stamina = current

	if delta == 0 or not is_active():
		return

	var reason: Array = _take_currency_reason()

	if reason[0] == "Other":
		reason = ["Battle", "Level"] if delta < 0 else ["Regen", "Time"]

	_aggregator.add_resource("sink" if delta < 0 else "source", CURRENCY_STAMINA, absi(delta), reason[0], reason[1])
	_buffer_dirty = true  # written with the next battle / flush, not on every tick


func _take_currency_reason() -> Array:
	var reason: Array = [_currency_item_type, _currency_item_id]
	_currency_item_type = "Other"
	_currency_item_id = "unknown"
	return reason


## "A02" -> "ZoneA". Anything else (tests, tutorials) -> "Special".
func _zone_of(level: String) -> String:
	if level.length() >= 3 and level.substr(1).is_valid_int():
		return "Zone" + level.left(1).to_upper()

	return "Special"

#endregion


#region /// diagnostics (development only, never sent)

func get_debug_report() -> String:
	var sent: Dictionary = _diag["sent"]
	var battles: int = _diag["battles"]
	var pending: int = _aggregator.build_events().size()
	var battle_events: int = _diag["battle_events_sent"] + pending
	var legacy: int = _diag["legacy_battle_events"]
	var per_battle: float = float(battle_events) / float(maxi(battles, 1))
	var reduction: float = 100.0 * (1.0 - float(battle_events) / float(maxi(legacy, 1)))

	return "\n".join(PackedStringArray([
		"SYNAPSE ANALYTICS REPORT (handed to the SDK, not confirmed as received)",
		"Battles: %d   Flushes: %d" % [battles, _diag["flushes"]],
		"SDK events: design %d, progression %d, resource %d, ad %d, error %d (total %d)" % [
			sent["design"], sent["progression"], sent["resource"], sent["ad"], sent["error"], _total_sent()
		],
		"Battle-related events (incl. %d still pending): %d = %.1f per battle" % [pending, battle_events, per_battle],
		"Previous implementation would have sent: %d -> reduction %.0f%%" % [legacy, reduction],
	]))


func _count_sent(category: String) -> void:
	_diag["sent"][category] += 1


func _total_sent() -> int:
	var total: int = 0

	for count in _diag["sent"].values():
		total += int(count)

	return total


## Events the per-battle implementation (before the aggregation) sent for one battle.
func _legacy_event_cost(battle: Dictionary, finished: bool) -> int:
	var unique_in_deck: int = 0
	var seen: Dictionary = {}

	for card_id in battle["deck"]:
		if not seen.has(card_id):
			seen[card_id] = true
			unique_in_deck += 1

	# start: progression + Battle:Started + Legend:Picked + Deck:Copies per card
	# end: progression + Battle:<result> + Turns + ScoreDiff + CardPlayed per card + 2 CardType
	#      (+ Legend:WinRate + Card:WinRate per card when finished)
	var cost: int = 3 + unique_in_deck + 4 + battle["played"].size() + 2

	if finished:
		cost += 1 + unique_in_deck

	return cost

#endregion
