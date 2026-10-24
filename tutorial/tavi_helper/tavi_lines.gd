class_name TaviLines
extends RefCounted

## ALL of Tavi's lines in one place - edit freely.
## BBCode works ([color=#ffe28a]...[/color], [b]...[/b]).
## %s is replaced by a name (enemy name / button text) - keep it where it is.
##
## Faces (TaviHelper.Face / TaviGuide.Face): WAVE, POINT, PRESENT, WORRIED, DETERMINED, SAD
## (the face for each line is chosen in the code that shows it).
##
## The start tutorial texts are separate: they are the Label texts inside
## tutorial/tutorial_overlay.tscn (one Panel per tutorial step).


#region /// Battle - level/tavi_guide/tavi_guide.gd

## First player turn, a card can be played.
const BATTLE_YOUR_TURN: String = "Your turn! Drag a card from your hand onto an empty slot on your side."
## First player turn, after choosing a spell that needs a target.
const BATTLE_PICK_TARGET_GUIDED: String = "Now pick a card on the board for your spell."
## The enemy starts the match (first enemy turn).
const BATTLE_ENEMY_FIRST: String = "The bad guy goes first this time. Let's wait and watch!"
## First enemy turn after the player's first turn.
const BATTLE_ENEMY_TURN: String = "Now it's the enemy's turn. Wait and see what they do!"

## Later turns, player idle while a card can be played.
const BATTLE_IDLE_PLAY_CARD: String = "Psst! Try playing one of your cards."
## Later turns, player idle while choosing a spell target.
const BATTLE_IDLE_PICK_TARGET: String = "Pick a card on the board for your spell."

## The control button must be pressed. Key = the button text.
const BATTLE_BUTTONS: Dictionary = {
	"End Turn": "Nicely done! Press [color=#ffe28a]End Turn[/color] to pass the turn.",
	"Resolve": "A cycle! Press [color=#ffe28a]Resolve[/color] to destroy the linked cards.",
	"Clear Board": "The board is full! Press [color=#ffe28a]Clear Board[/color].",
	"Skip Turn": "No moves left. Press [color=#ffe28a]Skip Turn[/color].",
}
## Any other button text. %s = button text.
const BATTLE_BUTTON_FALLBACK: String = "Press [color=#ffe28a]%s[/color]!"

#endregion


#region /// Main map (first zone tutorial) - map/scripts/map_zones.gd

const MAP_PICK_ZONE: String = "Welcome to the world map! Click on [color=#62ff90]Greenheart Vale[/color] to begin your journey."
const MAP_ZONE_OPENED: String = "Greenheart Vale is a peaceful valley - the perfect place for your first battles. Press [color=#ffe28a]Play[/color] to enter!"

#endregion


#region /// Zone (first zone tutorial) - zones/scripts/zone_controller.gd

## %s = enemy name of the first level.
const ZONE_PICK_LEVEL: String = "Choose your first opponent - click on [color=#ffe28a]%s[/color]!"
## %s = enemy name of the selected level.
const ZONE_LEVEL_SELECTED: String = "Beat [color=#ffe28a]%s[/color] to earn shillings and new cards. Press [color=#ffe28a]Play[/color] when you're ready!"

#endregion
