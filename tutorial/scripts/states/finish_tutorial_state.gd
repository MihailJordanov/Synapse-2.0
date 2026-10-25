class_name TutorialFinishState
extends TutorialState


func enter() -> void:
	if not await wait_for_animation():
		return
	tutorial.overlay.adventure_button.disabled = false
	tutorial.overlay.adventure_button.show()
	tutorial.tutorial_completed.emit()
