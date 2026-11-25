# Synapse - Analytics (GameAnalytics)

Everything goes through the autoload `AnalyticsManager` (`00_global/analytics_manager/`).
High-frequency statistics are counted locally in `AnalyticsAggregator` and sent as summed values.

## 1. Why

The first version sent one event per card per battle: on 24 Nov 2026 one player sent 424 events
in 6 battles (≈70 per battle, 371 design events). GameAnalytics lists **500 events per active user
per day** as a limit threshold (alert on the Integration page), so a normal play day would go over it.

The second version (aggregated, schema 1) still sent ~50 events in one flush. Schema 2 (now) sends
the "usually zero" side of every pair (losses instead of wins, extra plays / copies instead of totals)
and drops everything that can be derived, so a flush is roughly 30-40% smaller.

## 2. How it works

| Kind | Sent | Events |
|---|---|---|
| Automatic (SDK) | by GameAnalytics itself | installs, DAU/MAU, sessions + length, retention, version, OS |
| Immediate | when it happens | progression start/complete/fail, Battle:Turns, Battle:ScoreDiff, Battle:Abandoned, Shillings/Seals, tutorials, level/zone unlocks, second chance, ads, stamina depleted / not enough |
| Aggregated | summed, in a flush | card statistics, legends, stamina earned/spent |

**Flush** (sending the aggregated counters) happens when:
- `flush_every_battles` (15) battles were played since the last flush, or
- a battle ends and `flush_interval_minutes` (30) passed since the last flush, or
- the app goes to the background / is closed **and** at least `background_flush_min_battles` (5) battles wait,
- on launch, if at least 5 battles were left from the last run.

Fewer waiting battles are not sent: they stay in `user://analytics_buffer.json` (also across restarts)
and go with the next flush. A flush has a fixed cost (one event per counter that is not 0), so the more
battles share it, the cheaper each battle is.

**Persistence:** the buffer is saved after every battle, right after every flush (a restart never sends
the same counters twice) and on background / close. A broken or older-schema buffer is reset with a
warning; analytics can never stop the game. The SDK keeps its own offline queue for events it was given,
so there is no custom networking / retry. "Sent" = handed to the SDK, not confirmed exactly-once.

**Consent:** `AnalyticsManager.set_submission_enabled(false)` stops sending, stops collecting and deletes
the waiting counters.

## 3. Event catalog

### Immediate

| Event | Type | Value | When |
|---|---|---|---|
| `start / complete / fail : Zone<X> : <level>` | Progression | score on complete/fail | battle start / win / loss **or abandon** |
| `Battle:Turns:<level>` | Design | turns (both sides) | finished battle |
| `Battle:ScoreDiff:<level>` | Design | player score - enemy score | finished battle |
| `Battle:Abandoned:<level>` | Design | - | Pause→Exit, closed in a battle |
| `Progress:LevelUnlocked:<level>` | Design | - | first unlock only |
| `Progress:LevelCleared:<level>` | Design | - | **first** win of the level only |
| `Progress:ZoneUnlocked:<zone>` | Design | - | once |
| `Tutorial:Completed:<id>` / `Tutorial:Step:<id>:<step>` | Design | - | once |
| `Legend:Equipped:<id>` | Design | - | equipped legend changed |
| `SecondChance:<option>:<level>` | Design | - | seals paid for a second chance |
| `Stamina:Depleted` / `Stamina:NotEnough:<level>` | Design | - | stamina hit 0 / Play without stamina |
| Shillings, Seals | Resource | amount | every change (item type = reason) |
| Ads | Ad (Android/iOS) or `Ads:<placement>:<type>:<action>` | - | when ads exist |

### Aggregated (schema 2) — value = sum since the last flush, **not sent when 0** (missing = 0)

Only finished battles (win / loss) are counted here.

| Event | Value |
|---|---|
| `Card:BattlesPlayed:<id>` | finished battles in which the card was played at least once |
| `Card:ExtraPlays:<id>` | plays above 1 per battle (played 3× in a battle = 2) |
| `Card:LossesPlayed:<id>` | ... of the BattlesPlayed, lost |
| `Card:InDeck:<id>` | finished battles with the card in the deck |
| `Card:LossesInDeck:<id>` | ... of them lost |
| `Card:ExtraCopies:<id>` | copies above 1 (3 copies in one battle = 2) |
| `Legend:Battles:<id or None>` | finished battles with this legend (`None` = no legend) |
| `Legend:Losses:<id or None>` | ... of them lost |
| Stamina (Resource) | sink `Battle/Level` = spent, source `Regen/Time` = regenerated (summed) |

## 4. How to read the metrics

In GameAnalytics → Explore pick a design event and the **Sum** metric (Count = number of flushes, not battles).
Ratios are always **sum / sum**, never an average of percentages. GameAnalytics shows the sums;
the division is done by hand or in an exported sheet.

| Metric | Formula |
|---|---|
| Attempts per level | Progression **start** count of the level |
| Level win / completion rate | complete / (complete + fail) — fail includes abandoned |
| Abandon rate | COUNT(Battle:Abandoned:<level>) / start count |
| Finished battles (all) | SUM(Legend:Battles:*) |
| Average turns / score difference | MEAN(Battle:Turns:<level>) / MEAN(Battle:ScoreDiff:<level>) |
| Total card plays | SUM(Card:BattlesPlayed:<id>) + SUM(Card:ExtraPlays:<id>) |
| Deck inclusion rate | SUM(Card:InDeck:<id>) / SUM(Legend:Battles:*) |
| Deck inclusion win rate | 1 - SUM(Card:LossesInDeck:<id>) / SUM(Card:InDeck:<id>) |
| Played card win rate | 1 - SUM(Card:LossesPlayed:<id>) / SUM(Card:BattlesPlayed:<id>) |
| Average copies per deck | 1 + SUM(Card:ExtraCopies:<id>) / SUM(Card:InDeck:<id>) |
| Legend popularity | SUM(Legend:Battles:<id>) / SUM(Legend:Battles:*) |
| Legend win rate | 1 - SUM(Legend:Losses:<id>) / SUM(Legend:Battles:<id>) |
| Unit vs spell plays | total card plays of ids 1xxxx (units) vs 2xxxx (spells) |
| Currency sources / sinks | Resources page, split by item type |

## 5. What was removed / changed

| Before | Now | Why |
|---|---|---|
| `Battle:Started:<level>` | removed | = progression start |
| `Battle:Win/Loss:<level>` | removed | = progression complete / fail |
| `Battle:Abandoned:<level>` | kept | progression fail can't tell abandon from loss |
| `Deck:Copies:<id>` (every battle) | `Card:InDeck` + `Card:ExtraCopies` | summed |
| `Card:WinRate:<id>` (0/1 every battle) | `Card:InDeck` + `Card:LossesInDeck` | win rate = 1 - sum/sum |
| `CardPlayed:<level>:<id>` | `Card:BattlesPlayed` + `ExtraPlays` + `LossesPlayed` | **level dimension dropped**; played-card win rate is new |
| `CardType:Unit/Spell:<level>` | removed | derived from card ids; **level dimension dropped** |
| `Legend:Picked`, `Legend:WinRate` | `Legend:Battles`, `Legend:Losses` (+ `None`) | summed, no-legend counted |
| schema 1 (`Card:Played`, `WinsPlayed`, `WinsInDeck`, `Copies`, `Legend:Wins`, `Battle:Finished`, `Cards:UnitsPlayed/SpellsPlayed`) | schema 2 above | smaller flush; a schema-1 buffer on disk is reset |
| stamina | aggregated resource | was missing |

New identifiers were used wherever the meaning changed, so old and new data never mix.

## 6. Event volume

Same deterministic battles as `tests/analytics/analytics_test.tscn` (20-card deck with 6 spells,
8 plays per battle, 1 loss in 3; immediate battle events + all aggregated events incl. 2 stamina events,
nothing left unsent; Shillings / session events not counted on either side). Numbers from a Python copy
of the aggregator; the test scene prints the same table from the real GDScript:

| Battles in one flush | Before (per battle) | Now (per battle) |
|---|---|---|
| 1 | 52 | 35 |
| 3 | 52 | 25.7 |
| 5 | 52 | 17.2 |
| 10 | 52 | 11.3 |
| 15 | 52 | 8.9 |
| 10 with 2 decks | 53 | 13.5 |

Per battle: 4 immediate events (+ ~1 Shillings). A flush costs about 30 (1 battle) to 70 (10+ battles,
some losses) events, shared by all battles in it.
Example day: 20 battles in 3 sessions ≈ 20 × 5 + 3 flushes × ~65 ≈ 300 events.

Cardinality: about 110 cards × 6 + legends × 2 + per-level events ≈ 700–1,000 design ids
(limit 15,000); it grows with cards, not with players.

## 7. Known limits

- Card statistics have **no level dimension** (only global per card).
- Abandoned battles are only in the progression funnel (no card / legend statistics).
- Counters of a player who leaves for good with fewer than 5 unsent battles are never sent.
- A battle interrupted by Android killing the app in the background has a progression start without an end.
- Stamina regenerated while the game is closed is not counted (added on launch, before tracking starts).
- "Sent" in the debug report means handed to the SDK, not confirmed as received.

## 8. Testing

`tests/analytics/analytics_test.tscn` → F6. Prints PASS/FAIL for the aggregator (win, loss, abandoned,
same / changing decks, copies, repeated plays, legends incl. no legend, save/load, corrupted / old data,
stamina totals, no double send) and the volume table. It does not touch save files.

In a debug build `AnalyticsManager` prints a report after every flush (battles, flushes, SDK events per
category, events per battle, reduction versus the first implementation). `info_log` / `verbose_log`
turn on the SDK's own per-event log (very long - it overflows Godot's Output panel).
