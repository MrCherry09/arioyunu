class_name GameInput
## Tüm tuş ve oyun kolu (gamepad) eşlemeleri tek yerde.
## Kol düzeni Xbox adlarıyla: A = alt düğme, X = sol düğme (PlayStation'da ✕ ve □).
##
##   Hareket   : sol çubuk / D-pad
##   Zıpla     : A        (basılı tut: süzül)
##   Dash      : X, RT
##   Aşağı     : sol çubuk aşağı / D-pad aşağı (yerde kay, havada çakıl)
##   Etkileşim: Y (şalter)
##   Oda değiş : LB / RB
##   Sıfırla   : Select (Back / Share)
##   Duraklat  : Esc / Start (Options)

const DEADZONE := {
	"move_left": 0.2,
	"move_right": 0.2,
	"down": 0.6,  ## Çapraz yürürken yanlışlıkla kaymasın diye çubuğu iyice bastırmak gerekir
}


static func setup() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT, _btn(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [KEY_D, KEY_RIGHT, _btn(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"jump": [KEY_SPACE, KEY_W, KEY_UP, _btn(JOY_BUTTON_A)],
		"down": [KEY_S, KEY_DOWN, _btn(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"dash": [KEY_SHIFT, KEY_K, _btn(JOY_BUTTON_X), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"interact": [KEY_F, KEY_ENTER, _btn(JOY_BUTTON_Y)],
		"restart": [KEY_R, _btn(JOY_BUTTON_BACK)],
		"pause": [KEY_ESCAPE, _btn(JOY_BUTTON_START)],
		"next_room": [KEY_E, KEY_PAGEDOWN, _btn(JOY_BUTTON_RIGHT_SHOULDER)],
		"prev_room": [KEY_Q, KEY_PAGEUP, _btn(JOY_BUTTON_LEFT_SHOULDER)],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE.get(action, 0.5))
		for item in map[action]:
			var ev: InputEvent
			if item is InputEvent:
				ev = item
			else:
				var key := InputEventKey.new()
				key.physical_keycode = item
				ev = key
			InputMap.action_add_event(action, ev)


static func _btn(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = -1  # tüm kollar
	ev.button_index = button
	return ev


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = axis
	ev.axis_value = value
	return ev
