class_name ResourceHud
extends PanelContainer

## Compact panel with player resources (money, stamina).
## Add a new resource: duplicate a row (e.g. MoneyBox) in the scene and update it here.

@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_box: Control = %StaminaBox
@onready var money_label: Label = %MoneyLabel


func _ready() -> void:
	StaminaManager.refresh()
	_update_stamina(StaminaManager.get_stamina(), StaminaManager.get_max_stamina())
	StaminaManager.stamina_changed.connect(_update_stamina)

	_update_money(PlayerDataManager.get_money())
	PlayerDataManager.money_changed.connect(_update_money)

	# Tooltip countdown, refreshed once per second.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_update_tooltip)
	_update_tooltip()


func _update_stamina(current: int, maximum: int) -> void:
	stamina_label.text = "%d/%d" % [current, maximum]


func _update_money(amount: int) -> void:
	money_label.text = str(amount)


func _update_tooltip() -> void:
	if StaminaManager.is_full():
		stamina_box.tooltip_text = "Stamina is full"
		return

	var seconds: int = StaminaManager.get_seconds_to_next()
	stamina_box.tooltip_text = "+1 stamina in %d:%02d" % [seconds / 60, seconds % 60]
