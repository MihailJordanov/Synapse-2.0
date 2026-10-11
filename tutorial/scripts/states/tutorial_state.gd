class_name TutorialState
extends Node

@export var animation_name: StringName = &""
@export var loop_animation: bool = true
@export var hint_panel: Control

var tutorial: TutorialController
var visit: int = 0


func setup(controller: TutorialController) -> void:
	tutorial = controller


func enter() -> void:
	pass


func exit() -> void:
	if is_instance_valid(hint_panel):
		hint_panel.hide()


func update(_delta: float) -> void:
	pass


func is_active() -> bool:
	return is_instance_valid(tutorial) and tutorial.is_state_active(self)


func change_to(next_state: TutorialState) -> void:
	if is_active():
		tutorial.request_transition(next_state)


func wait_seconds(seconds: float) -> bool:
	return await tutorial.wait_seconds(seconds, self, visit)


func wait_for_animation() -> bool:
	return await tutorial.wait_for_animation(self, visit)
