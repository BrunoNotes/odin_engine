package window_context

import "core:math/linalg"
import sdl "../../../vendor/sdl3"
import "core:c"

MouseState :: struct {
    button_pressed: bool,
    double_click: bool,
}

MouseScrollState :: struct {
    position: linalg.Vector2f32,
    is_scrolling: bool,
}

g_keyboad_state: [^]bool

updateInputState :: proc() {
	numkeys: c.int
	g_keyboad_state = sdl.GetKeyboardState(&numkeys)
}

isKeyPressed :: proc(key: sdl.Scancode) -> bool {
	return g_keyboad_state[key]
}

isMouseButtonPressed :: proc(button: sdl.MouseButtonFlag) -> bool{
    return g_mouse_button_state[button].button_pressed
}

getMousePosition :: proc() -> linalg.Vector2f32 {
    return g_mouse_position
}

getMouseScroll :: proc() -> MouseScrollState {
    return g_mouse_scroll
}
