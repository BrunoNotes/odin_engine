package main

import eng_ctx "./engine"
import "./engine/base"
import "./engine/vulkan"
import "core:log"
import "core:mem"

main :: proc() {
	context.logger = log.create_console_logger()

	when ODIN_DEBUG {
		tracking_allocator := base.initTrackingAllocator(context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}

	eng_ctx.initEngine()
	defer eng_ctx.destroyEngine()

    // cornflower blue
	vulkan.g_vulkan_context.background_color = {0.392, 0.584, 0.929, 1.0}

	// main loop
	for eng_ctx.running() {
		defer free_all(context.temp_allocator)

		eng_ctx.updateEngine()

		// render
		vulkan.beginVkRendering()

		vulkan.endVkRendering()

		when ODIN_DEBUG {
			base.checkDoubleFreeTrackingAllocator(tracking_allocator)
			base.resetTrackingAllocator(&tracking_allocator)
		}
	}

	when ODIN_DEBUG {
		mem.tracking_allocator_destroy(&tracking_allocator)
		// checks for leaks before on exit
		base.resetTrackingAllocator(&tracking_allocator)
	}
}
