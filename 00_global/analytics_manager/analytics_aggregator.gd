class_name AnalyticsAggregator
extends RefCounted
## Local counters for high-frequency statistics (cards, legends, stamina), sent to GameAnalytics
## as a few summed events instead of one event per occurrence. Pure data: no SDK, no autoloads,
## so it can be tested on its own (tests/analytics/analytics_test.gd).
##
## Only FINISHED battles (win / loss) are counted; abandoned battles are only in the progression funnel.
## To send as few events as possible, values that are usually 0 are sent instead of the usual
## "big" value: LOSSES instead of wins, EXTRA plays / copies instead of totals. Events with 0 are
## not sent (a missing event = 0). See docs/analytics/ANALYTICS.md for the formulas.

const SCHEMA_VERSION: int = 2
const NO_LEGEND: String = "None"

const CARD_COUNTERS: Array[String] = ["played", "battles_played", "losses_played", "in_deck", "losses_in_deck", "copies"]

var cards: Dictionary = {}  # card id (int) -> counter name -> int
var legends: Dictionary = {}  # "31000" / "None" -> {"battles": int, "losses": int}
var battles_since_flush: int = 0
## "flow|currency|item_type|item_id" -> amount (summed resource events, e.g. stamina).
var resources: Dictionary = {}


## One battle is over. deck_ids: every card in the deck (duplicates = copies).
## played: card id -> times played in this battle. legend_id 0 = no legend.
func record_battle(deck_ids: Array, played: Dictionary, legend_id: int, result: String) -> void:
	battles_since_flush += 1

	if result != "win" and result != "loss":
		return

	var lost: int = 1 if result == "loss" else 0

	for card_id in played:
		var counters: Dictionary = _card(int(card_id))
		counters["played"] += int(played[card_id])
		counters["battles_played"] += 1
		counters["losses_played"] += lost

	var copies: Dictionary = {}

	for card_id in deck_ids:
		copies[int(card_id)] = int(copies.get(int(card_id), 0)) + 1

	for card_id in copies:
		var counters: Dictionary = _card(card_id)
		counters["in_deck"] += 1
		counters["copies"] += copies[card_id]
		counters["losses_in_deck"] += lost

	var legend_key: String = str(legend_id) if legend_id != 0 else NO_LEGEND
	var legend: Dictionary = legends.get(legend_key, {"battles": 0, "losses": 0})
	legend["battles"] += 1
	legend["losses"] += lost
	legends[legend_key] = legend


func add_resource(flow: String, currency: String, amount: int, item_type: String, item_id: String) -> void:
	if amount <= 0:
		return

	var key: String = "%s|%s|%s|%s" % [flow, currency, item_type, item_id]
	resources[key] = int(resources.get(key, 0)) + amount


func has_pending() -> bool:
	return battles_since_flush > 0 or not resources.is_empty()


## Everything waiting, as a list of events (only values > 0).
## {"type": "design", "id": String, "value": int} / {"type": "resource", "flow", "currency", "amount", "item_type", "item_id"}
func build_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var card_ids: Array = cards.keys()
	card_ids.sort()

	for card_id in card_ids:
		var c: Dictionary = cards[card_id]
		_add(events, "Card:BattlesPlayed:%d" % card_id, c["battles_played"])
		_add(events, "Card:ExtraPlays:%d" % card_id, c["played"] - c["battles_played"])
		_add(events, "Card:LossesPlayed:%d" % card_id, c["losses_played"])
		_add(events, "Card:InDeck:%d" % card_id, c["in_deck"])
		_add(events, "Card:LossesInDeck:%d" % card_id, c["losses_in_deck"])
		_add(events, "Card:ExtraCopies:%d" % card_id, c["copies"] - c["in_deck"])

	var legend_keys: Array = legends.keys()
	legend_keys.sort()

	for legend_key in legend_keys:
		_add(events, "Legend:Battles:" + legend_key, legends[legend_key]["battles"])
		_add(events, "Legend:Losses:" + legend_key, legends[legend_key]["losses"])

	for key in resources:
		var parts: PackedStringArray = String(key).split("|")
		events.append({"type": "resource", "flow": parts[0], "currency": parts[1], "amount": int(resources[key]), "item_type": parts[2], "item_id": parts[3]})

	return events


func clear() -> void:
	cards.clear()
	legends.clear()
	battles_since_flush = 0
	resources.clear()


#region /// persistence (plain data, JSON friendly)

func to_dict() -> Dictionary:
	var card_data: Dictionary = {}

	for card_id in cards:
		card_data[str(card_id)] = cards[card_id].duplicate()

	return {
		"schema": SCHEMA_VERSION,
		"cards": card_data,
		"legends": legends.duplicate(true),
		"battles_since_flush": battles_since_flush,
		"resources": resources.duplicate(),
	}


## Loads saved counters. Anything malformed (or an older schema) is dropped - returns false, never crashes.
func from_dict(data: Variant) -> bool:
	clear()

	if not data is Dictionary or int(data.get("schema", -1)) != SCHEMA_VERSION:
		return false

	var card_data: Variant = data.get("cards", {})
	var legend_data: Variant = data.get("legends", {})
	var resource_data: Variant = data.get("resources", {})

	if not card_data is Dictionary or not legend_data is Dictionary or not resource_data is Dictionary:
		return false

	for key in card_data:
		if not String(key).is_valid_int() or not card_data[key] is Dictionary:
			clear()
			return false

		var counters: Dictionary = _card(int(key))

		for counter in CARD_COUNTERS:
			counters[counter] = maxi(int(card_data[key].get(counter, 0)), 0)

	for key in legend_data:
		if not legend_data[key] is Dictionary:
			clear()
			return false

		legends[String(key)] = {
			"battles": maxi(int(legend_data[key].get("battles", 0)), 0),
			"losses": maxi(int(legend_data[key].get("losses", 0)), 0),
		}

	for key in resource_data:
		if String(key).split("|").size() != 4:
			clear()
			return false

		resources[String(key)] = maxi(int(resource_data[key]), 0)

	battles_since_flush = maxi(int(data.get("battles_since_flush", 0)), 0)
	return true

#endregion


func _card(card_id: int) -> Dictionary:
	if not cards.has(card_id):
		var counters: Dictionary = {}

		for counter in CARD_COUNTERS:
			counters[counter] = 0

		cards[card_id] = counters

	return cards[card_id]


func _add(events: Array[Dictionary], event_id: String, value: int) -> void:
	if value > 0:
		events.append({"type": "design", "id": event_id, "value": value})
