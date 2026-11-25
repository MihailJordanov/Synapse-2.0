# Synapse - Analytics (GameAnalytics)

Everything goes through the autoload `AnalyticsManager` (`00_global/analytics_manager/`).
High-frequency statistics are counted locally in `AnalyticsAggregator` and sent as summed values.

## 1. Why it changed

The first version sent one event per card per battle. On 24 Nov 2026 one player sent 424 events
in 6 battles (≈70 per battle, 371 of them design events). GameAnalytics lists
**500 events per active user per day** as a limit threshold (averaged over the players, it raises
an alert on the Integration page), so a normal play day would have gone far over it.

## 2. How it works now

| Kind | Sent | Events |
|---|---|---|
| Automatic (SDK) | by GameAnalytics itself | installs, DAU/MAU, sessions + length, retention, version, OS |
| Immediate | when it happens | progression start/complete/fail, Battle:Turns, Battle:ScoreDiff, Battle:Abandoned, Shillings/Seals, tutorials, level/zone unlocks, second chance, ads, stamina depleted / not enough |
| Aggregated | summed, in a flush | all card statistics, legends, unit/spell usage, stamina earned/spent |

**Flush (sending the aggregated counters)** happens when:
- `flush_every_battles` (10) battles were played since the last flush, or
- a battle ends and `flush_interval_minutes` (15) passed since the last flush, or
- the app goes to the background / is closed **and** at least `background_flush_min_battles` (3) battles are waiting,
- on launch, if at least 3 battles were left from the last run.

Fewer than 3 waiting battles are not sent alone (that would cost more than before, see section 6):
they stay in `user://analytics_buffer.json` and go with the next flush.

**Persistence:** the buffer is saved after every battle and right after every flush (so a restart never
sends the same counters twice), and on background / close. A broken or old buffer file is reset with a
warning; analytics can never stop the game. The SDK keeps its own offline queue for events it was given,
so no custom networking / retry exists here. Delivery is "handed to the SDK", not confirmed exactly-once.

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
| `Legend:Equipped:<id>` | Design | - | equipped legend changed (deck choice) |
| `SecondChance:<option>:<level>` | Design | - | seals paid for a second chance |
| `Stamina:Depleted` / `Stamina:NotEnough:<level>` | Design | - | stamina hit 0 / Play without stamina |
| Shillings, Seals | Resource | amount | every change (item type = reason) |
| Ads | Ad (Android/iOS) or `Ads:<placement>:<type>:<action>` | - | when ads exist |

### Aggregated (value = sum since the last flush, events with 0 are not sent)

| Event | Value |
|---|---|
| `Card:Played:<id>` | times the card was played (all battles, abandoned included) |
| `Card:BattlesPlayed:<id>` | finished battles in which it was played at least once |
| `Card:WinsPlayed:<id>` | ... of them won |
| `Card:InDeck:<id>` | finished battles with the card in the deck |
| `Card:WinsInDeck:<id>` | ... of them won |
| `Card:ExtraCopies:<id>` | copies above 1 (3 copies in one battle = 2) |
| `Legend:Battles:<id or None>` | finished battles with this legend (`None` = no legend) |
| `Legend:Wins:<id or None>` | ... of them won |
| `Battle:Finished` | finished battles (win + loss) |
| `Cards:UnitsPlayed` / `Cards:SpellsPlayed` | unit / spell cards played |
| Stamina (Resource) | sink `Battle/Level` = spent, source `Regen/Time` = regenerated (summed) |

## 4. How to read the metrics

In GameAnalytics → Explore, pick a design event and the **Sum** metric (Count = number of flushes, not battles).

| Metric | Formula |
|---|---|
| Attempts per level | Progression **start** count of the level |
| Level win rate / completion rate | complete / (complete + fail) — fail includes abandoned |
| Battle win rate (all levels) | complete / (complete + fail) on Zone level, or SUM(Legend:Wins:*) / SUM(Battle:Finished) |
| Abandon rate | COUNT(Battle:Abandoned:<level>) / start count |
| Average turns | MEAN(Battle:Turns:<level>) |
| Average score difference | MEAN(Battle:ScoreDiff:<level>) |
| Total card usage | SUM(Card:Played:<id>) |
| Deck inclusion rate | SUM(Card:InDeck:<id>) / SUM(Battle:Finished) |
| Deck inclusion win rate | SUM(Card:WinsInDeck:<id>) / SUM(Card:InDeck:<id>) |
| Played card win rate | SUM(Card:WinsPlayed:<id>) / SUM(Card:BattlesPlayed:<id>) |
| Average copies per deck | 1 + SUM(Card:ExtraCopies:<id>) / SUM(Card:InDeck:<id>) |
| Legend popularity | SUM(Legend:Battles:<id>) / SUM(Battle:Finished) |
| Legend win rate | SUM(Legend:Wins:<id>) / SUM(Legend:Battles:<id>) |
| Unit vs spell usage | SUM(Cards:UnitsPlayed) vs SUM(Cards:SpellsPlayed) |
| Currency sources / sinks | Resources page, split by item type |

Ratios are always **sum / sum** (never the average of percentages). GameAnalytics shows the two sums;
the division is done by hand or in an exported sheet.

## 5. What was removed / changed

| Before | Now | Why |
|---|---|---|
| `Battle:Started:<level>` | removed | = progression start |
| `Battle:Win:<level>` / `Battle:Loss:<level>` | removed | = progression complete / fail |
| `Battle:Abandoned:<level>` | kept | progression fail can't tell abandon from loss |
| `Deck:Copies:<id>` (every battle, value = copies) | `Card:InDeck` + `Card:ExtraCopies` (summed) | same numbers, 1 event per flush |
| `Card:WinRate:<id>` (0/1 every battle) | `Card:InDeck` + `Card:WinsInDeck` | win rate = sum/sum |
| `CardPlayed:<level>:<id>` | `Card:Played:<id>` + `Card:BattlesPlayed` + `Card:WinsPlayed` | **level dimension dropped** (cardinality: levels × cards); played-card win rate is new |
| `CardType:Unit/Spell:<level>` | `Cards:UnitsPlayed` / `Cards:SpellsPlayed` | **level dimension dropped** |
| `Legend:Picked:<id>`, `Legend:WinRate:<id>` | `Legend:Battles`, `Legend:Wins` (+ `None`) | summed, no-legend counted |
| stamina | now tracked (aggregated resource) | was missing |

New identifiers were used wherever the meaning changed, so old and new data never mix.

## 6. Event volume

Same deterministic battles as `tests/analytics/analytics_test.tscn` (20-card deck, 6 spells,
8 plays per battle; immediate battle events + all aggregated events, nothing left unsent;
Shillings / session events not counted on either side). The numbers below come from a Python copy
of the aggregator logic (Godot could not be run while writing this); the test scene prints the
same table from the real GDScript - check that it matches:

| Session | Before | After | Change |
|---|---|---|---|
| 1 battle, sent alone | 52 / battle | 70 / battle | **+35%** (why it is never sent alone) |
| 6 battles | 52 / battle | 19.5 / battle | -62% |
| 10 battles | 52 / battle | 13.3 / battle | -74% |
| 20 battles | 52 / battle | 13.3 / battle | -74% |
| 10 battles, 2 decks | 53 / battle | 15.8 / battle | -70% |

Break-even is about 2 battles per flush, hence `background_flush_min_battles = 3`.
Each battle costs 4 immediate events + about 1 Shillings event; everything else is shared per flush.

Cardinality: about 110 cards × 6 card events + ~10 legends × 2 + per-level events
≈ 700–1,000 design ids, far below the 15,000 limit, and it grows with cards, not with players.

## 7. Known limits

- Card statistics have **no level dimension** any more (only global per card).
- Counters of a player who leaves for good with fewer than 3 unsent battles are never sent.
- A battle interrupted by Android killing the app in the background has a progression start without an end
  (counts as an attempt only).
- Stamina regenerated while the game is closed is not counted (StaminaManager adds it on launch, before tracking starts).
- "Sent" in the debug report means handed to the SDK, not confirmed as received.

## 8. Testing

`tests/analytics/analytics_test.tscn` → F6. Prints PASS/FAIL for the aggregator (win, loss, abandoned,
same / changing decks, copies, repeated plays, units/spells, legends incl. no legend, save/load,
corrupted data, stamina totals, no double send) and the volume table above. It does not touch save files.

In a debug build `AnalyticsManager` prints a report after every flush:
battles, flushes, SDK events per category, events per battle, and the reduction versus the old system.
