class_name UnitCard extends Card

signal connection_types_changed

const BASIC_EXPLOSION_PARTICLES: PackedScene = preload("uid://dyu16flnvpg7a")
const ADD_POINT_PARTICLES = preload("uid://d1vdn51cy30u8")

const MAX_TYPES_COUNT: int = 8     
const MAX_EQUIPPED_TYPES: int = 3   

@onready var a_sword: TextureRect = %A_Sword
@onready var a_shield: TextureRect = %A_Shield
@onready var a_axe: TextureRect = %A_Axe
@onready var a_shurikane: TextureRect = %A_Shurikane
@onready var a_wand: TextureRect = %A_Wand
@onready var a_magical_wand: TextureRect = %"A_Magical Wand"
@onready var a_mace: TextureRect = %A_Mace
@onready var a_teeth: TextureRect = %A_Teeth

@onready var d_sword: TextureRect = %D_Sword
@onready var d_shield: TextureRect = %D_Shield
@onready var d_axe: TextureRect = %D_Axe
@onready var d_shurikane: TextureRect = %D_Shurikane
@onready var d_wand: TextureRect = %D_Wand
@onready var d_magical_wand: TextureRect = %"D_Magical Wand"
@onready var d_mace: TextureRect = %D_Mace
@onready var d_teeth: TextureRect = %D_Teeth

@onready var points_label: Label = %PointsLabel

var target_types: Array[int] = []
var source_types: Array[int] = []
var points: int = 1


func _ready() -> void:
	super._ready()
	card_type = CardType.UNIT
	setup_card()


func _process(_delta: float) -> void:
	pass


func setup_card() -> void:
	update_all_type_visibilities()
	_update_points_label()

func _set_type_visible(type_index: int, is_target: bool, is_type_visible: bool) -> void:
	var icon: TextureRect = _get_icon_by_index(type_index, is_target)
	if icon:
		icon.visible = is_type_visible

func _get_icon_by_index(type_index: int, is_target: bool) -> TextureRect:
	match type_index:
		1: return a_sword if is_target else d_sword
		2: return a_shield if is_target else d_shield
		3: return a_axe if is_target else d_axe
		4: return a_shurikane if is_target else d_shurikane
		5: return a_wand if is_target else d_wand
		6: return a_magical_wand if is_target else d_magical_wand
		7: return a_mace if is_target else d_mace
		8: return a_teeth if is_target else d_teeth
		_: return null

func set_all_types(
	new_target_types: Array[int],
	new_source_types: Array[int]
) -> void:
	target_types.clear()

	for type_idx: int in new_target_types:
		if not _is_valid_type_number(type_idx):
			continue

		if target_types.has(type_idx):
			continue

		if target_types.size() >= MAX_EQUIPPED_TYPES:
			push_warning(
				"UnitCard: Too many target types."
			)
			break

		target_types.append(type_idx)

	source_types.clear()

	for type_idx: int in new_source_types:
		if not _is_valid_type_number(type_idx):
			continue

		if source_types.has(type_idx):
			continue

		if source_types.size() >= MAX_EQUIPPED_TYPES:
			push_warning(
				"UnitCard: Too many source types."
			)
			break

		source_types.append(type_idx)

	update_all_type_visibilities()
	connection_types_changed.emit()
	
func update_all_type_visibilities() -> void:
	for i in range(1, MAX_TYPES_COUNT + 1):
		_set_type_visible(i, true, target_types.has(i))
		_set_type_visible(i, false, source_types.has(i))

func _is_valid_type_number(type_number: int) -> bool:
	return type_number >= 1 and type_number <= MAX_TYPES_COUNT

func add_target_type(type_number: int) -> void:
	if not _is_valid_type_number(type_number):
		push_warning("UnitCard: Invalid target type.")
		return

	if target_types.size() >= MAX_EQUIPPED_TYPES:
		push_warning("UnitCard: Maximum target types reached.")
		return

	if target_types.has(type_number):
		push_warning("UnitCard: Target type already exists.")
		return

	target_types.append(type_number)
	_set_type_visible(type_number, true, true)
	connection_types_changed.emit()
	

func remove_target_type(type_number: int) -> void:
	if not _is_valid_type_number(type_number):
		push_warning("UnitCard: Invalid target type.")
		return

	if not target_types.has(type_number):
		push_warning("UnitCard: Target type is missing.")
		return

	target_types.erase(type_number)
	_set_type_visible(type_number, true, false)
	connection_types_changed.emit()
	
	
func add_source_type(type_number: int) -> void:
	if not _is_valid_type_number(type_number):
		push_warning("UnitCard: Invalid source type.")
		return

	if source_types.size() >= MAX_EQUIPPED_TYPES:
		push_warning("UnitCard: Maximum source types reached.")
		return

	if source_types.has(type_number):
		push_warning("UnitCard: Source type already exists.")
		return

	source_types.append(type_number)
	_set_type_visible(type_number, false, true)
	connection_types_changed.emit()


func remove_source_type(type_number: int) -> void:
	if not _is_valid_type_number(type_number):
		push_warning("UnitCard: Invalid source type.")
		return

	if not source_types.has(type_number):
		push_warning("UnitCard: Source type is missing.")
		return

	source_types.erase(type_number)
	_set_type_visible(type_number, false, false)
	connection_types_changed.emit()

func get_target_types_count() -> int:
	return target_types.size()

func get_source_types_count() -> int:
	return source_types.size()

func get_target_types_info() -> Dictionary:
	var missing: Array[int] = []
	for i in range(1, MAX_TYPES_COUNT + 1):
		if not target_types.has(i):
			missing.append(i)
	return {"present": target_types.duplicate(), "missing": missing}

func get_source_types_info() -> Dictionary:
	var missing: Array[int] = []
	for i in range(1, MAX_TYPES_COUNT + 1):
		if not source_types.has(i):
			missing.append(i)
	return {"present": source_types.duplicate(), "missing": missing}


func get_points() -> int:
	return points


func set_points(new_points: int) -> void:
	
	points = clampi(new_points, 0, 1024)
	_update_points_label()

	spawn_add_point_particles()


func add_points(amount: int) -> void:
	set_points(points + amount)


func remove_points(amount: int) -> void:
	set_points(points - amount)


func _update_points_label() -> void:
	if points_label:
		points_label.text = str(points)


func destroy() -> void:
	var explosion_pos: Vector2 = global_position
	var current_scene: Node = get_tree().current_scene
	
	if BASIC_EXPLOSION_PARTICLES and current_scene:
		var particles_instance = BASIC_EXPLOSION_PARTICLES.instantiate() as Node2D
		if particles_instance:
			particles_instance.global_position = explosion_pos
			var colors: Array[Color] = [
				Color.RED,
				Color.AQUA,
				Color.LIME,
				Color.YELLOW,
				Color.WHITE
			]
			particles_instance.modulate = colors.pick_random()
			current_scene.add_child(particles_instance)
			
			if particles_instance.has_method("restart"):
				particles_instance.call("restart")
			elif particles_instance is CPUParticles2D or particles_instance is GPUParticles2D:
				particles_instance.emitting = true

	super.destroy()


func spawn_add_point_particles() -> void:
	if ADD_POINT_PARTICLES == null or points_label == null:
		return

	var particles := ADD_POINT_PARTICLES.instantiate() as Node2D # или GPUParticles2D / CPUParticles2D
	if particles == null:
		return

	add_child(particles)
	

	var label_pos: Vector2 = points_label.global_position

	var center_x: float = label_pos.x + (points_label.size.x / 2.0)
	var center_y: float = label_pos.y + (points_label.size.y / 2.0)

	particles.global_position = Vector2(center_x, center_y)

	if particles is GPUParticles2D or particles is CPUParticles2D:
		particles.emitting = true

	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(particles.queue_free)
