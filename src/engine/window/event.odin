package window_context

import sdl "../../../vendor/sdl3"

processSdlEvents :: proc() {
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			g_window_context.close = true
		}
	}
}
