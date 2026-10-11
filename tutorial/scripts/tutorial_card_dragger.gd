class_name TutorialCardDragger
extends CardDragger

## Selection is by INSTANCE, not just ID: only one duplicate can be dragged.
var allowed_card: UnitCard = null


func set_allowed_card(card: UnitCard, slots: Array[CardSlot]) -> void:
	set_play_context(false, [])
	_clear_hover()
	allowed_card = card
	if is_instance_valid(card):
		set_play_context(true, slots)


func clear_allowed_card() -> void:
	set_play_context(false, [])
	_clear_hover()
	allowed_card = null


func start_drag(card: Card) -> void:
	if not enabled or not is_instance_valid(allowed_card) or card != allowed_card:
		return
	super.start_drag(card)


func raycast_check_for_card() -> Card:
	if not enabled or not is_instance_valid(allowed_card):
		return null
	var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(params)
	for hit: Dictionary in results:
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.get_parent() == allowed_card:
			return allowed_card
	return null


func raycast_check_for_card_slot() -> CardSlot:
	var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD_SLOT
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(params)
	for hit: Dictionary in results:
		var collider: Node = hit.get("collider") as Node
		if collider == null:
			continue
		var slot: CardSlot = collider.get_parent() as CardSlot
		if slot != null and allowed_slots.has(slot) and not slot.card_in_slot:
			return slot
	return null
