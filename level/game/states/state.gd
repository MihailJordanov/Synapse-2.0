class_name State extends Node

var fsm: GameDecisionEngine = null


func setup(engine: GameDecisionEngine) -> void:
	fsm = engine


func enter() -> void:
	pass


func re_enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func change_to(next_state: State) -> void:
	if fsm == null:
		push_error("%s: FSM reference is null." % name)
		return

	fsm.request_transition(next_state)
