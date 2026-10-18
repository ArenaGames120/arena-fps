## Регистрирует действия ввода в рантайме.
## Так проект работает даже если карта клавиш ещё не сохранена в project.godot.
class_name GameInput
extends RefCounted

const KEY_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"reload": [KEY_R],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_next": [KEY_Q],
	"scoreboard": [KEY_TAB],
	"pause": [KEY_ESCAPE],
}

const MOUSE_BINDINGS := {
	"fire": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],
}


static func ensure_actions() -> void:
	for action in KEY_BINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in KEY_BINDINGS[action]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			if not InputMap.action_has_event(action, key_event):
				InputMap.action_add_event(action, key_event)

	for action in MOUSE_BINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button in MOUSE_BINDINGS[action]:
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = button
			if not InputMap.action_has_event(action, mouse_event):
				InputMap.action_add_event(action, mouse_event)
