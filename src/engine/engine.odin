package engine_context

import "./vulkan"
import w_ctx "./window"
import "core:log"
import "core:time"

g_engine_context: EngineContext

@(private = "file")
last_time := time.now()._nsec

EngineContext :: struct {
	running:    bool,
	delta_time: f32,
}

initEngine :: proc() {
	log.infof("Init engine")

	defer g_engine_context.running = true

	w_ctx.initWindow()
	vulkan.initVkContext()
}

destroyEngine :: proc() {
	log.infof("Destroy engine")

	vulkan.destroyVkContext()
	w_ctx.destroyWindow()
}

running :: proc() -> bool {
	return g_engine_context.running
}

deltaTime :: proc() -> f32 {
	return g_engine_context.delta_time
}

updateEngine :: proc() {
	current_time := time.now()._nsec
	g_engine_context.delta_time = f32(current_time - last_time) / f32(time.Second)
	last_time = current_time

    w_ctx.processSdlEvents()

    if w_ctx.g_window_context.close {
        g_engine_context.running = false
    }
}
