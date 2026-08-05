class_name SpellCard
extends Card

const HORIZONTAL_EXPLOSION_PARTICLES = preload("uid://buc0bwow5trjh")

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
var requirement: SpellRequirement

func _ready() -> void:
	super._ready()
	card_type = CardType.SPELL
	_update_description_label()

func setup(new_target_mode: TargetMode,new_effect: SpellEffect,new_requirement: SpellRequirement) -> void:
	target_mode = new_target_mode
	effect = new_effect
	requirement = new_requirement

func execute(context: SpellContext) -> void:
	if effect == null:
		push_error(
			"SpellCard: Spell card %d has no effect."
			% card_id
		)
		return

	effect.execute(context)

func set_description(new_description: String) -> void:
	description = new_description
	_update_description_label()

func _update_description_label() -> void:
	if description_label == null:
		return

	description_label.bbcode_enabled = true
	description_label.text = description

func destroy() -> void:
	var explosion_pos: Vector2 = global_position

	if is_inside_tree():
		var tree := get_tree()

		if tree != null:
			var current_scene: Node = tree.current_scene

			if HORIZONTAL_EXPLOSION_PARTICLES != null and current_scene != null:
				var particles_instance := (HORIZONTAL_EXPLOSION_PARTICLES.instantiate() as Node2D)

				if particles_instance != null:
					current_scene.add_child(particles_instance)
					particles_instance.global_position = explosion_pos

					var colors: Array[Color] = [
						Color.RED,
						Color.AQUA,
						Color.LIME,
						Color.YELLOW,
						Color.WHITE
					]

					particles_instance.modulate = colors.pick_random()

					if particles_instance.has_method("restart"):
						particles_instance.call("restart")
					elif (particles_instance is CPUParticles2D or particles_instance is GPUParticles2D):
						particles_instance.emitting = true

	super.destroy()
	
func is_playable_now(context: CardPlayContext) -> bool:
	if context == null:
		return false

	if effect == null:
		return false

	if requirement != null:
		if not requirement.is_satisfied(context):
			return false

	if requires_target():
		return has_valid_target(context)

	return true

func has_valid_target(context: CardPlayContext) -> bool:
	for card: Card in context.board_cards:
		if is_valid_target(card, context.caster_side):
			return true

	return false

func get_valid_targets(context: CardPlayContext) -> Array[UnitCard]:
	var result: Array[UnitCard] = []

	for card: Card in context.board_cards:
		if is_valid_target(card, context.caster_side):
			result.append(card as UnitCard)

	return result

func requires_target() -> bool:
	return target_mode != TargetMode.NO_TARGET

func is_valid_target(card: Card,caster_side: int) -> bool:
	if not card is UnitCard:
		return false

	var unit := card as UnitCard

	match target_mode:
		TargetMode.ANY_UNIT:
			return true

		TargetMode.FRIENDLY_UNIT:
			return _is_friendly_unit(
				unit,
				caster_side
			)

		TargetMode.ENEMY_UNIT:
			return not _is_friendly_unit(
				unit,
				caster_side
			)

		TargetMode.NO_TARGET:
			return false

	return false
	
func _is_friendly_unit(unit: UnitCard,caster_side: int) -> bool:
	match caster_side:
		GameDecisionEngine.Side.PLAYER:
			return not unit.is_enemy_card

		GameDecisionEngine.Side.ENEMY:
			return unit.is_enemy_card

	return false
