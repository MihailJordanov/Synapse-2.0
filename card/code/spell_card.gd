class_name SpellCard
extends Card


enum TargetMode {
	NO_TARGET,
	ANY_UNIT,
	FRIENDLY_UNIT,
	ENEMY_UNIT
}

@onready var description_label: RichTextLabel = %DescriptionRichTextLabel

var description: String = ""
var target_mode: TargetMode = TargetMode.NO_TARGET
var effect: SpellEffect


func _ready() -> void:
	super._ready()
	card_type = CardType.SPELL
	_update_description_label()


func setup(
	new_target_mode: TargetMode,
	new_effect: SpellEffect
) -> void:
	target_mode = new_target_mode
	effect = new_effect


func execute(context: SpellContext) -> void:
	if effect == null:
		push_error(
			"SpellCard: Spell card %d has no effect."
			% card_id
		)
		return

	effect.execute(context)


func requires_target() -> bool:
	return target_mode != TargetMode.NO_TARGET


func is_valid_target(
	card: Card,
	caster_side: GameDecisionEngine.Side
) -> bool:
	if not card is UnitCard:
		return false

	var unit := card as UnitCard

	match target_mode:
		TargetMode.ANY_UNIT:
			return true

		TargetMode.FRIENDLY_UNIT:
			return _is_friendly_unit(unit, caster_side)

		TargetMode.ENEMY_UNIT:
			return not _is_friendly_unit(unit, caster_side)

		TargetMode.NO_TARGET:
			return false

	return false


func _is_friendly_unit(
	unit: UnitCard,
	caster_side: GameDecisionEngine.Side
) -> bool:
	match caster_side:
		GameDecisionEngine.Side.PLAYER:
			return not unit.is_enemy_card

		GameDecisionEngine.Side.ENEMY:
			return unit.is_enemy_card

	return false

func set_description(new_description: String) -> void:
	description = new_description
	_update_description_label()

func _update_description_label() -> void:
	if description_label == null:
		return

	description_label.bbcode_enabled = true
	description_label.text = description
