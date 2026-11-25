extends Node
## Analytics tests - open tests/analytics/analytics_test.tscn and press F6.
## Tests AnalyticsAggregator (pure data, no SDK, no save files touched) and measures the event
## volume of the aggregated system against the previous per-battle implementation on the same
## deterministic battles. Results are printed to the Output panel; the scene quits at the end.

const FLUSH_EVERY_BATTLES: int = 10

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	print("\n===== ANALYTICS TESTS =====")
	_test_single_win()
	_test_loss()
	_test_abandoned()
	_test_unchanged_deck()
	_test_changing_decks()
	_test_copies_and_repeated_plays()
	_test_units_and_spells()
	_test_legends()
	_test_persistence_roundtrip()
	_test_corrupted_data()
	_test_resources()
	_test_clear_after_flush()
	print("Checks: %d, failed: %d -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])

	print("\n===== EVENT VOLUME (same battles, previous vs aggregated) =====")
	for battles in [1, 6, 10, 20]:
		_measure_session(battles, false)
	_measure_session(10, true)

	get_tree().quit(1 if _failures > 0 else 0)


#region /// tests

func _test_single_win() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001, 11002], {11001: 1}, 1, 0, 31000, "win")
	_check(_value(a, "Card:Played:11001") == 1, "win: times played")
	_check(_value(a, "Card:BattlesPlayed:11001") == 1, "win: battles played")
	_check(_value(a, "Card:WinsPlayed:11001") == 1, "win: wins when played")
	_check(_value(a, "Card:InDeck:11002") == 1, "win: in deck")
	_check(_value(a, "Card:WinsInDeck:11002") == 1, "win: wins in deck")
	_check(_value(a, "Card:Played:11002") == -1, "win: unplayed card has no Played event")
	_check(_value(a, "Battle:Finished") == 1, "win: finished battles")


func _test_loss() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001], {11001: 2}, 2, 0, 31000, "loss")
	_check(_value(a, "Card:BattlesPlayed:11001") == 1, "loss: denominator kept")
	_check(_value(a, "Card:WinsPlayed:11001") == -1, "loss: no zero numerator event")
	_check(_value(a, "Card:InDeck:11001") == 1, "loss: in deck")
	_check(_value(a, "Card:WinsInDeck:11001") == -1, "loss: no zero wins event")
	_check(_value(a, "Legend:Battles:31000") == 1 and _value(a, "Legend:Wins:31000") == -1, "loss: legend")


func _test_abandoned() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001, 11002], {11001: 1}, 1, 0, 31000, "abandoned")
	_check(_value(a, "Card:Played:11001") == 1, "abandoned: usage still counted")
	_check(_value(a, "Card:BattlesPlayed:11001") == -1, "abandoned: not in win-rate denominators")
	_check(_value(a, "Card:InDeck:11002") == -1, "abandoned: not in deck stats")
	_check(_value(a, "Battle:Finished") == -1, "abandoned: not finished")
	_check(a.has_pending(), "abandoned: pending")


func _test_unchanged_deck() -> void:
	var a := AnalyticsAggregator.new()
	for i in range(5):
		a.record_battle([11001, 11002], {}, 0, 0, 0, "win" if i < 3 else "loss")
	_check(_value(a, "Card:InDeck:11001") == 5, "same deck x5: in deck = 5")
	_check(_value(a, "Card:WinsInDeck:11001") == 3, "same deck x5: wins = 3")
	_check(_events(a).size() == 2 * 2 + 2 + 1, "same deck x5: one event per counter, not per battle")


func _test_changing_decks() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001, 11002], {}, 0, 0, 0, "win")
	a.record_battle([11001, 11003], {}, 0, 0, 0, "loss")
	_check(_value(a, "Card:InDeck:11001") == 2, "changing decks: shared card")
	_check(_value(a, "Card:InDeck:11002") == 1 and _value(a, "Card:InDeck:11003") == 1, "changing decks: others")
	_check(_value(a, "Card:WinsInDeck:11003") == -1, "changing decks: lost deck has no wins")


func _test_copies_and_repeated_plays() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001, 11001, 11001, 11002], {11001: 3}, 3, 0, 0, "win")
	a.record_battle([11001, 11002], {11001: 1}, 1, 0, 0, "win")
	_check(_value(a, "Card:ExtraCopies:11001") == 2, "copies: 3 + 1 copies in 2 decks -> 2 extra")
	_check(_value(a, "Card:InDeck:11001") == 2, "copies: average = 1 + 2 / 2 = 2")
	_check(_value(a, "Card:ExtraCopies:11002") == -1, "copies: single copy -> no event")
	_check(_value(a, "Card:Played:11001") == 4, "repeated plays: total 4")
	_check(_value(a, "Card:BattlesPlayed:11001") == 2, "repeated plays: 2 battles")


func _test_units_and_spells() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001, 21001], {11001: 2, 21001: 1}, 2, 1, 0, "win")
	_check(_value(a, "Cards:UnitsPlayed") == 2 and _value(a, "Cards:SpellsPlayed") == 1, "units / spells")


func _test_legends() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001], {}, 0, 0, 31000, "win")
	a.record_battle([11001], {}, 0, 0, 31001, "loss")
	a.record_battle([11001], {}, 0, 0, 0, "win")
	_check(_value(a, "Legend:Battles:31000") == 1 and _value(a, "Legend:Wins:31000") == 1, "legend knight")
	_check(_value(a, "Legend:Battles:31001") == 1 and _value(a, "Legend:Wins:31001") == -1, "legend witch")
	_check(_value(a, "Legend:Battles:None") == 1 and _value(a, "Legend:Wins:None") == 1, "no legend is a category")


func _test_persistence_roundtrip() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001, 11001, 21001], {11001: 2}, 2, 0, 31000, "win")
	a.add_resource("sink", "Stamina", 5, "Battle", "Level")
	var b := AnalyticsAggregator.new()
	var ok: bool = b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	_check(ok and _events(a) == _events(b), "restart: counters survive save / load exactly")


func _test_corrupted_data() -> void:
	var a := AnalyticsAggregator.new()
	_check(not a.from_dict(null), "corrupted: null")
	_check(not a.from_dict({"schema": 999}), "corrupted: other schema")
	_check(not a.from_dict({"schema": 1, "cards": {"abc": {}}}), "corrupted: bad card id")
	_check(not a.from_dict({"schema": 1, "cards": [], "legends": {}}), "corrupted: wrong type")
	_check(not a.has_pending(), "corrupted: nothing pending after reset")


func _test_resources() -> void:
	var a := AnalyticsAggregator.new()
	a.add_resource("source", "Stamina", 1, "Regen", "Time")
	a.add_resource("source", "Stamina", 1, "Regen", "Time")
	a.add_resource("sink", "Stamina", 8, "Battle", "Level")
	var amounts: Dictionary = {}
	for event in _events(a):
		if event["type"] == "resource":
			amounts[event["flow"]] = event["amount"]
	_check(amounts.get("source") == 2 and amounts.get("sink") == 8, "stamina: exact totals, 2 events")


func _test_clear_after_flush() -> void:
	var a := AnalyticsAggregator.new()
	a.record_battle([11001], {11001: 1}, 1, 0, 0, "win")
	a.clear()
	_check(not a.has_pending() and _events(a).is_empty(), "flush: nothing sent twice")

#endregion


#region /// volume measurement

## Deterministic session: a 20-card deck (12 unique, some copies) with 6 spells, ~8 different cards played
## per battle, 2 decks alternating when change_decks = true. Wins 2 of 3.
func _measure_session(battles: int, change_decks: bool) -> void:
	var a := AnalyticsAggregator.new()
	var legacy: int = 0
	var optimized: int = 0
	var flushes: int = 0

	for i in range(battles):
		var deck: Array = _deck(1 if change_decks and i % 2 == 1 else 0)
		var played: Dictionary = {}
		for k in range(8):
			var card_id: int = deck[(i * 3 + k * 2) % deck.size()]
			played[card_id] = int(played.get(card_id, 0)) + 1
		var result: String = "win" if i % 3 != 2 else "loss"
		var unique: int = _unique(deck)

		legacy += 3 + unique + 4 + played.size() + 2 + 1 + unique  # see AnalyticsManager._legacy_event_cost
		optimized += 2 + 2  # progression start + end, Battle:Turns + Battle:ScoreDiff

		a.record_battle(deck, played, 7, 1, 31000, result)

		if a.battles_since_flush >= FLUSH_EVERY_BATTLES:
			optimized += _events(a).size()
			a.clear()
			flushes += 1

	if a.has_pending():  # session end / background: nothing is left unsent
		optimized += _events(a).size()
		a.clear()
		flushes += 1

	print("%2d battles%s: previous %4d (%.1f/battle) -> aggregated %4d (%.1f/battle), %d flushes, -%.0f%%" % [
		battles, " (2 decks)" if change_decks else "", legacy, legacy / float(battles),
		optimized, optimized / float(battles), flushes, 100.0 * (1.0 - optimized / float(legacy))
	])


func _deck(variant: int) -> Array:
	var units: Array = [11001, 11001, 11002, 11002, 11003, 11004, 11005, 11006, 11007, 11008, 11009, 11010, 11011, 11012]
	var spells: Array = [21001, 21001, 21000, 21002, 21100, 21101]
	if variant == 1:
		units = [11020, 11020, 11021, 11022, 11003, 11004, 11005, 11006, 11030, 11031, 11032, 11033, 11034, 11035]
	return units + spells


func _unique(ids: Array) -> int:
	var seen: Dictionary = {}
	for card_id in ids:
		seen[card_id] = true
	return seen.size()

#endregion


func _events(a: AnalyticsAggregator) -> Array[Dictionary]:
	return a.build_events()


## Value of a design event, -1 if it is not sent.
func _value(a: AnalyticsAggregator, event_id: String) -> int:
	for event in a.build_events():
		if event["type"] == "design" and event["id"] == event_id:
			return int(event["value"])
	return -1


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL: " + label)
