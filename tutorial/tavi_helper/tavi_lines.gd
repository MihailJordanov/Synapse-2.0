class_name TaviLines
extends RefCounted

## ALL of Tavi's lines in one place - edit freely.
## BBCode works ([color=#ffe28a]...[/color], [b]...[/b]).
## %s is replaced by a name (enemy name / button text) - keep it where it is.
##
## Faces (TaviHelper.Face / TaviGuide.Face):
## WAVE, POINT, PRESENT, WORRIED, DETERMINED, SAD
##
## The start tutorial texts are separate: they are the Label texts inside
## tutorial/tutorial_overlay.tscn (one Panel per tutorial step).


#region /// Battle - level/tavi_guide/tavi_guide.gd

## First player turn, a card can be played.
const BATTLE_YOUR_TURN: String = "Your turn, adventurer! Drag a card from your hand onto an empty slot."

## First player turn, after choosing a spell that needs a target.
const BATTLE_PICK_TARGET_GUIDED: String = "The spell is ready! Choose a card on the board as its target."

## The enemy starts the match (first enemy turn).
const BATTLE_ENEMY_FIRST: String = "Our foe has the first move. Stay sharp and watch their play!"

## First enemy turn after the player's first turn.
const BATTLE_ENEMY_TURN: String = "The turn passes to our foe. Let's see what they have planned!"


## Later turns, player idle while a card can be played.
const BATTLE_IDLE_PLAY_CARD: String = "The board awaits, adventurer. Play one of your cards!"

## Later turns, player idle while choosing a spell target.
const BATTLE_IDLE_PICK_TARGET: String = "Your spell awaits a target. Choose a card on the board."


## The control button must be pressed. Key = the button text.
const BATTLE_BUTTONS: Dictionary = {
	"End Turn": "A fine move! Press [color=#ffe28a]End Turn[/color] to pass the turn.",
	"Resolve": "A cycle is complete! Press [color=#ffe28a]Resolve[/color] to claim its power.",
	"Clear Board": "No space remains! Press [color=#ffe28a]Clear Board[/color] to begin anew.",
	"Skip Turn": "No moves remain. Press [color=#ffe28a]Skip Turn[/color] and prepare for the next.",
}

## Any other button text. %s = button text.
const BATTLE_BUTTON_FALLBACK: String = "The next step awaits! Press [color=#ffe28a]%s[/color]."


## A cycle was made (every time, in levels with Play with Tavi). Random line.
## Tavi stays until Resolve is pressed; the arrow points at the button.
const BATTLE_PLAYER_CYCLE: Array[String] = [
	"Yesss! You made a cycle! Press [color=#ffe28a]Resolve[/color] and grab those points!",
	"Wow, look at that cycle! You're a natural!",
	"Perfect link! Now [color=#ffe28a]Resolve[/color] it - those points are yours!",
]
const BATTLE_ENEMY_CYCLE: Array[String] = [
	"Grr! The bad guy made a cycle... We'll get them back!",
	"Hey, no fair! Press [color=#ffe28a]Resolve[/color] - and let's pay them back next turn!",
	"Ugh, a cycle for them. Watch where they link cards and block them next time!",
]

## End screens (only in levels with Play with Tavi).
## One line is picked at random.
## {money} = shillings earned in this battle.
const BATTLE_VICTORY: Array[String] = [
	"Victory! You earned [color=#ffe28a]{money}[/color] shillings. The spoils are yours!",
	"A glorious victory! Go on, adventurer-claim your well-earned rewards!",
	"Our foe is defeated! I knew you had the heart of a true champion!",
]

const BATTLE_DEFEAT: Array[String] = [
	"We may have lost this battle, but our journey is far from over. Let's try again!",
	"Our foe prevailed today-but next time, victory will be ours!",
	"That was a fierce battle... Rest for a moment, adventurer. I still believe in you!",
]

#endregion


#region /// Name entry (after the start tutorial) - tutorial/name_entry/name_entry.gd

const NAME_ASK: String = "You did great! I'm [color=#ffe28a]Tavi[/color], by the way. What should I call you, adventurer?"
## {name} = the name the player typed.
const NAME_CONFIRMED: String = "Nice to meet you, [color=#ffe28a]{name}[/color]! Here's a little gift - your very first icon!"

#endregion


#region /// Main map (first zone tutorial) - map/scripts/map_zones.gd

const MAP_PICK_ZONE: String = "Welcome to Nexara, adventurer! Select [color=#62ff90]Greenheart Vale[/color] to begin your journey."

const MAP_ZONE_OPENED: String = "Greenheart Vale awaits-a peaceful land for your first battles. Press [color=#ffe28a]Play[/color] to enter!"

#endregion


#region /// Zone (first zone tutorial) - zones/scripts/zone_controller.gd

## %s = enemy name of the first level.
const ZONE_PICK_LEVEL: String = "Your first challenge awaits! Select [color=#ffe28a]%s[/color] to face them."

## Back in the zone after LOSING the first level (shown until it is beaten). %s = enemy name.
const ZONE_RETRY_PICK_LEVEL: String = "Don't worry, everyone loses sometimes! [color=#ffe28a]%s[/color] won't be so lucky twice - click and try again!"
const ZONE_RETRY_LEVEL_SELECTED: String = "That's the spirit! Show [color=#ffe28a]%s[/color] what you've learned. Press [color=#ffe28a]Play[/color]!"

## %s = enemy name of the selected level.
const ZONE_LEVEL_SELECTED: String = "Defeat [color=#ffe28a]%s[/color] to earn shillings and discover new cards. Press [color=#ffe28a]Play[/color] when you're ready!"

#endregion


#region /// Collection tutorial - collection/script/collection_tutorial.gd + zones/scripts/zone_controller.gd

## Zone A, after the Collection is unlocked (until the collection tutorial is done).
const ZONE_COLLECTION_UNLOCKED: String = "Ooh, you unlocked the [color=#ffe28a]Collection[/color]! That's where all your cards live. Click it - I'll show you around!"

const COLLECTION_SELECT_CARD: String = "Welcome to your Collection! These are all the cards you own. Click on this card to take a closer look."
const COLLECTION_ADD_REMOVE_INFO: String = "Here's the card you picked. [color=#7CFC00]Add[/color] puts a copy into your deck, [color=#ff7a7a]Remove[/color] takes one out."
const COLLECTION_PRESS_ADD: String = "Let's try it! Press [color=#7CFC00]Add[/color] once."
const COLLECTION_PRESS_REMOVE: String = "Great! Now press [color=#ff7a7a]Remove[/color] to take it back out."
const COLLECTION_OPEN_DECK: String = "You've got it! Now open your [color=#ffe28a]Deck[/color]."
const COLLECTION_DECK_UNITS: String = "This is your deck! Your [color=#8fd3ff]units[/color] are on the left - those are the cards you fight with."
const COLLECTION_DECK_SPELLS: String = "And the right side is for [color=#d58fff]spells[/color]... Spells? Hehe, that's a story for later. I told you the world of Nexara is full of surprises!"
const COLLECTION_EXIT: String = "That's everything! Press [color=#ffe28a]Exit[/color] when you're ready to get back to the adventure."

#endregion


#region /// New zone - tutorial/zone_complete + map/scripts/map_zones.gd + zones/scripts/zone_controller.gd

## Black screen after the first clear of a zone's last level.
const ZONE_COMPLETE: String = "You did it - the whole zone is cleared! I'm so proud of you! But this is only the beginning... a big world full of new rivals is waiting for us. Ready for the next adventure?"
## Main map: point at the newly unlocked zone. %s = zone name.
const MAP_NEW_ZONE_PICK: String = "Look, the clouds have cleared! A new land is waiting: %s. Click on it!"
## Main map: the zone scroll is open. %s = zone name.
const MAP_NEW_ZONE_OPENED: String = "%s - new rivals and new cards are waiting there. Press [color=#ffe28a]Play[/color] and let's go!"
## First visit of the new zone (shown once, then Tavi leaves).
const ZONE_ARRIVED: String = "Here we are! Your adventure continues from here. I'll always be close by - good luck, champion!"

#endregion


#region /// Spell tutorial - tutorial/spell_tutorial/spell_tutorial.gd

const SPELL_TUT_INTRO: String = "Great win! Now I'll show you something powerful - [color=#d58fff]spells[/color]! I picked the cards for this battle, just follow me."
const SPELL_TUT_PLAY_FIRST: String = "You go first. Drag the [color=#ffe28a]glowing card[/color] onto one of your slots."
const SPELL_TUT_END_TURN_FIRST: String = "Nice! Press [color=#ffe28a]End Turn[/color] - now it's the enemy's move."
const SPELL_TUT_ENEMY_TURN: String = "The enemy is thinking..."
const SPELL_TUT_CLOSE_FIRST_CYCLE: String = "The enemy's card links to yours! Play the [color=#ffe28a]glowing card[/color] and close the cycle."
const SPELL_TUT_RESOLVE: String = "A cycle! Press [color=#ffe28a]Resolve[/color] and watch closely what happens!"
const SPELL_TUT_MANA: String = "Did you see that? Your [color=#89CFF0]mana[/color] went up! In a cycle you get mana = [color=#7CFC00]your destroyed cards[/color] - [color=#ff5555]enemy destroyed cards[/color]. Here: 2 - 1 = 1 mana!"
const SPELL_TUT_SPELL_CARD: String = "And every cycle draws you a [color=#d58fff]spell card[/color]! Play as many spells as you like (and your mana allows) [color=#ffe28a]before[/color] your unit card - after the unit card your turn ends."
const SPELL_TUT_SPELL_COST: String = "The number above the picture is the spell's [color=#89CFF0]mana cost[/color]. Your mana is here, on the right. 1 mana - just enough for it!"
const SPELL_TUT_END_TURN: String = "Press [color=#ffe28a]End Turn[/color]."
const SPELL_TUT_PLAY_THIRD: String = "The enemy started a new chain. Play the [color=#ffe28a]glowing card[/color] to link to it."
const SPELL_TUT_NOT_ENOUGH: String = "The enemy's last card has nothing to do with our cards. But look: you have [color=#7CFC00]3 / 7[/color] points and closing this cycle gives only 3 - that's 6. One point short!"
const SPELL_TUT_PLAY_SPELL: String = "Time for magic! Drag your [color=#d58fff]spell[/color] onto an empty slot of yours."
const SPELL_TUT_PICK_TARGET: String = "Now click [color=#ffe28a]your unit[/color] on the board - it gets [color=#7CFC00]+1 point[/color]."
const SPELL_TUT_CLOSE_SECOND_CYCLE: String = "Your unit is stronger now! Play the [color=#ffe28a]glowing card[/color] and close the cycle!"
const SPELL_TUT_VICTORY: String = "6 points would not be enough - but with one spell you made 7! That's the power of [color=#d58fff]spells[/color]. And this spell is now yours - keep it!"
## Zone A after the spell tutorial: points at the Collection button (until the Collection is opened).
const ZONE_SPELLS_IN_COLLECTION: String = "Your new [color=#d58fff]spell[/color] is waiting in the [color=#ffe28a]Collection[/color]! There you can add spells to your deck. Let's take a look!"

#endregion
