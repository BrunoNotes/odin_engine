package engine_context

import "./types/color"
import "./vulkan"
import w_ctx "./window"
import "core:time"

g_engine_context: EngineContext

@(private = "file")
last_time := time.now()._nsec

EngineContext :: struct {
	running:    bool,
	delta_time: f32,
}

initEngine :: proc() {
	defer g_engine_context.running = true

	w_ctx.initWindow()
	vulkan.initVkContext()

	vulkan.setBackgroundColor(color.CORNFLOWER_BLUE)
}

destroyEngine :: proc() {
	vulkan.destroyVkContext()
	w_ctx.destroyWindow()
}

running :: proc() -> bool {
	current_time := time.now()._nsec
	g_engine_context.delta_time = f32(current_time - last_time) / f32(time.Second)
	last_time = current_time

	w_ctx.processEvents()
	w_ctx.updateInputState()

	if w_ctx.g_window_context.close {
		g_engine_context.running = false
	}

	if w_ctx.windowResized() {
		vulkan.g_vulkan_context.swapchain.needs_rebuild = true
	}

	return g_engine_context.running
}

deltaTime :: proc() -> f32 {
	return g_engine_context.delta_time
}
