class_name TutorialWatchCycleState
extends TutorialState

var _resolving: bool = false


func enter() -> void:
	_resolving = false
	if not tutorial.show_tutorial_cycle():
		return
	tutorial.overlay.resolve_button.pressed.connect(_on_resolve_pressed)
	tutorial.overlay.resolve_button.disabled = false
	tutorial.overlay.resolve_button.show()


func exit() -> void:
	if tutorial.overlay.resolve_button.pressed.is_connected(_on_resolve_pressed):
		tutorial.overlay.resolve_button.pressed.disconnect(_on_resolve_pressed)
	tutorial.overlay.resolve_button.disabled = true
	tutorial.overlay.resolve_button.hide()
	super.exit()


func _on_resolve_pressed() -> void:
	if not is_active() or _resolving:
		return
	_resolving = true
	tutorial.overlay.resolve_button.disabled = true
	tutorial.overlay.resolve_button.hide()
	if not await tutorial.resolve_tutorial_cycle(self, visit):
		return
	if not await wait_seconds(tutorial.tutorial_setup.after_destroy_wait):
		return
	change_to(tutorial.finish_tutorial_state)
