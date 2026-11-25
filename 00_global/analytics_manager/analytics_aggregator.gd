class_name AnalyticsAggregator
extends RefCounted
## Local counters for high-frequency statistics (cards, legends, stamina), sent to GameAnalytics
## as a few summed events instead of one event per occurrence. Pure data: no SDK, no autoloads,
## so it can be tested on its own (tests/analytics/analytics_test.gd).
##
## Only FINISHED battles (win / loss) count for win-rate numerators and denominators.
## Abandoned battles still count for usage (Card:Played, Cards:UnitsPlayed / SpellsPlayed).
## See docs/analytics/ANALYTICS.md for every event and how to read it.

const SCHEMA_VERSION: int = 1
const NO_LEGEND: String = "None"

# card id (int) -> counter name -> int
const CARD_COUNTERS: Array[String] = ["played", "battles_played", "wins_played", "in_deck", "wins_in_deck", "copies"]
## Design event per counter. "copies" is not sent as is: Card:ExtraCopies = copies - in_deck
## (copies above 1), so single-copy cards cost no event. Average copies = 1 + ExtraCopies / InDeck.
const CARD_EVENT_IDS: Dictionary = {
	"played": "Card:Played",
	"battles_played": "Card:BattlesPlayed",
	"wins_played": "Card:WinsPlayed",
	"in_deck": "Card:InDeck",
	"wins_in_deck": "Card:WinsInDeck",
}

var cards: Dictionary = {}
var legends: Dictionary = {}  # "31000" / "None" -> {"battles": int, "wins": int}
var units_played: int = 0
var spells_played: int = 0
var battles_finished: int = 0
var battles_since_flush: int = 0
## "flow|currency|item_type|item_id" -> amount (summed resource events, e.g. stamina).
var resources: Dictionary = {}


## One battle is over. deck_ids: every card in the deck (duplicates = copies).
## played: card id -> times played in this battle. legend_id 0 = no legend.
func record_battle(deck_ids: Array, played: Dictionary, units: int, spells: int, legend_id: int, result: String) -> void:
	var finished: bool = result == "win" or result == "loss"
	var won: bool = result == "win"

	units_played += units
	spells_played += spells
	battles_since_flush += 1

	for card_id in played:
		var counters: Dictionary = _card(int(card_id))
		counters["played"] += int(played[card_id])

		if finished:
			counters["battles_played"] += 1

			if won:
				counters["wins_played"] += 1

	if not finished:
		return

	battles_finished += 1

	var copies: Dictionary = {}

	for card_id in deck_ids:
		copies[int(card_id)] = int(copies.get(int(card_id), 0)) + 1

	for card_id in copies:
		var counters: Dictionary = _card(card_id)
		counters["in_deck"] += 1
		counters["copies"] += copies[card_id]

		if won:
			counters["wins_in_deck"] += 1

	var legend_key: String = str(legend_id) if legend_id != 0 else NO_LEGEND
	var legend: Dictionary = legends.get(legend_key, {"battles": 0, "wins": 0})
	legend["battles"] += 1

	if won:
		legend["wins"] += 1

	legends[legend_key] = legend


func add_resource(flow: String, currency: String, amount: int, item_type: String, item_id: String) -> void:
	if amount <= 0:
		return

	var key: String = "%s|%s|%s|%s" % [flow, currency, item_type, item_id]
	resources[key] = int(resources.get(key, 0)) + amount


func has_pending() -> bool:
	return battles_since_flush > 0 or not resources.is_empty()


## Everything waiting, as a list of events. Counters that are 0 are not sent
## (their denominators are, so a missing numerator simply means 0).
## {"type": "design", "id": String, "value": int} / {"type": "resource", "flow", "currency", "amount", "item_type", "item_id"}
func build_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var card_ids: Array = cards.keys()
	card_ids.sort()

	for card_id in card_ids:
		var counters: Dictionary = cards[card_id]

		for counter in CARD_EVENT_IDS:
			if int(counters[counter]) > 0:
				events.append(_design("%s:%d" % [CARD_EVENT_IDS[counter], card_id], counters[counter]))

		var extra_copies: int = int(counters["copies"]) - int(counters["in_deck"])

		if extra_copies > 0:
			events.append(_design("Card:ExtraCopies:%d" % card_id, extra_copies))

	var legend_keys: Array = legends.keys()
	legend_keys.sort()

	for legend_key in legend_keys:
		events.append(_design("Legend:Battles:" + legend_key, legends[legend_key]["battles"]))

		if int(legends[legend_key]["wins"]) > 0:
			events.append(_design("Legend:Wins:" + legend_key, legends[legend_key]["wins"]))

	if battles_finished > 0:
		events.append(_design("Battle:Finished", battles_finished))

	if units_played > 0:
		events.append(_design("Cards:UnitsPlayed", units_played))

	if spells_played > 0:
		events.append(_design("Cards:SpellsPlayed", spells_played))

	for key in resources:
		var parts: PackedStringArray = String(key).split("|")
		events.append({"type": "resource", "flow": parts[0], "currency": parts[1], "amount": int(resources[key]), "item_type": parts[2], "item_id": parts[3]})

	return events


func clear() -> void:
	cards.clear()
	legends.clear()
	units_played = 0
	spells_played = 0
	battles_finished = 0
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
		"units_played": units_played,
		"spells_played": spells_played,
		"battles_finished": battles_finished,
		"battles_since_flush": battles_since_flush,
		"resources": resources.duplicate(),
	}


## Loads saved counters. Anything malformed is dropped (returns false) - never crashes the game.
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
			"wins": maxi(int(legend_data[key].get("wins", 0)), 0),
		}

	for key in resource_data:
		if String(key).split("|").size() != 4:
			clear()
			return false

		resources[String(key)] = maxi(int(resource_data[key]), 0)

	units_played = maxi(int(data.get("units_played", 0)), 0)
	spells_played = maxi(int(data.get("spells_played", 0)), 0)
	battles_finished = maxi(int(data.get("battles_finished", 0)), 0)
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


func _design(event_id: String, value: int) -> Dictionary:
	return {"type": "design", "id": event_id, "value": value}
