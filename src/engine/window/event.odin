package window_context

import sdl "../../../vendor/sdl3"
import "core:math/linalg"

g_mouse_position: linalg.Vector2f32
g_mouse_button_state: [5]MouseState
g_mouse_scroll: MouseScrollState

processEvents :: proc() {
    is_scrolling:= false
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			g_window_context.close = true
		case .MOUSE_MOTION:
			g_mouse_position.x = event.motion.x
			g_mouse_position.y = event.motion.y
		case .MOUSE_BUTTON_DOWN:
			g_mouse_button_state[event.button.button - 1].button_pressed = true
			g_mouse_button_state[event.button.button - 1].double_click = event.button.clicks >= 2
		case .MOUSE_BUTTON_UP:
			g_mouse_button_state[event.button.button - 1].button_pressed = false
			g_mouse_button_state[event.button.button - 1].double_click = event.button.clicks < 2
        case .MOUSE_WHEEL:
            is_scrolling = true
			g_mouse_scroll.position.x = event.wheel.x
			g_mouse_scroll.position.y = event.wheel.y
		}
	}

    g_mouse_scroll.is_scrolling = is_scrolling
}
