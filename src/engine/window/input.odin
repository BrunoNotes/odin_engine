package window_context

import "core:log"
import sdl "../../../vendor/sdl3"
import "core:c"
import "core:math/linalg"

MouseState :: struct {
	button_pressed: bool,
	double_click:   bool,
}

MouseScrollState :: struct {
	position:     linalg.Vector2f32,
	is_scrolling: bool,
}

MouseMode :: enum {
	Normal,
	Captured,
}

g_keyboad_state: [^]bool
g_mouse_mode := MouseMode.Normal

updateInputState :: proc() {
	numkeys: c.int
	g_keyboad_state = sdl.GetKeyboardState(&numkeys)
}

isKeyPressed :: proc(key: sdl.Scancode) -> bool {
	return g_keyboad_state[key]
}

isMouseButtonPressed :: proc(button: sdl.MouseButtonFlag) -> bool {
	return g_mouse_button_state[button].button_pressed
}

getMousePosition :: proc() -> linalg.Vector2f32 {
	return g_mouse_position
}

getMouseScroll :: proc() -> MouseScrollState {
	return g_mouse_scroll
}

setMouseMode :: proc(mode: MouseMode) {
	switch mode {
	case .Normal:
        if g_mouse_mode != mode {
            g_mouse_mode = .Normal
            if !sdl.SetWindowRelativeMouseMode(g_window_context.handle, false){
                log.errorf("SDL: error setting window relative mode, %v", sdl.GetError())
            }
        }
	case .Captured:
        if g_mouse_mode != mode {
            g_mouse_mode = .Captured
            if !sdl.SetWindowRelativeMouseMode(g_window_context.handle, true){
                log.errorf("SDL: error setting window relative mode, %v", sdl.GetError())
            }
        }
	}
}
