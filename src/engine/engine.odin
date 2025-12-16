package engine_context

import sdl "../../vendor/sdl3"
import "./vulkan"
import "./window"
import "core:log"

g_engine_context: EngineContext

EngineContext :: struct {
	running:        bool,
}

initEngine :: proc() {
	log.infof("Init engine")

	defer g_engine_context.running = true

	window.initWindow()
	vulkan.initVkContext()
}

destroyEngine :: proc() {
	log.infof("Destroy engine")

	vulkan.destroyVkContext()
	window.destroyWindow()
}

running :: proc() -> bool {
	return g_engine_context.running
}

updateEngine :: proc() {
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			g_engine_context.running = false
		}
	}
}
