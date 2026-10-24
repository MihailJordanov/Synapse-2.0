class_name TutorialFinishState
extends TutorialState


func enter() -> void:
	if not await wait_for_animation():
		return
	tutorial.overlay.adventure_button.disabled = false
	tutorial.overlay.adventure_button.show()
	PlayerDataManager.complete_start_tutorial()
	tutorial.tutorial_completed.emit()
