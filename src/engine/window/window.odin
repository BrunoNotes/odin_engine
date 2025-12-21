package window_context

import sdl "../../../vendor/sdl3"
import "base:runtime"
import "core:log"
import "core:math/linalg"
import "core:strings"

@(private)
default_ctx: runtime.Context

g_window_context: WindowContext

WindowContext :: struct {
	handle:        ^sdl.Window,
	title:         string,
	width, height: i32,
	close:         bool,
}

initWindow :: proc(title: string = "Window", width: i32 = 800, height: i32 = 600) {
	log.infof("Init window")

	// sdl.SetLogPriorities(ODIN_DEBUG ? .VERBOSE : .INFO)
	// sdl.SetLogOutputFunction(
	// 	proc "c" (
	// 		userdata: rawptr,
	// 		category: sdl.LogCategory,
	// 		priority: sdl.LogPriority,
	// 		message: cstring,
	// 	) {
	// 		context = default_ctx
	//
	// 		switch priority {
	// 		case .INVALID:
	// 			log.errorf("SDL: {} [{}]: {}", category, priority, message)
	// 		case .TRACE:
	// 			log.errorf("SDL: {} [{}]: {}", category, priority, message)
	// 		case .VERBOSE:
	// 			log.infof("SDL: {} [{}]: {}", category, priority, message)
	// 		case .DEBUG:
	// 			log.debugf("SDL: {} [{}]: {}", category, priority, message)
	// 		case .INFO:
	// 			log.infof("SDL: {} [{}]: {}", category, priority, message)
	// 		case .WARN:
	// 			log.warnf("SDL: {} [{}]: {}", category, priority, message)
	// 		case .ERROR:
	// 			log.errorf("SDL: {} [{}]: {}", category, priority, message)
	// 		case .CRITICAL:
	// 			log.errorf("SDL: {} [{}]: {}", category, priority, message)
	// 		}
	// 	},
	// 	nil,
	// )

	g_window_context.title = title
	g_window_context.width = width
	g_window_context.height = height

	g_window_context.handle = sdl.CreateWindow(
		strings.clone_to_cstring(title, context.temp_allocator),
		width,
		height,
		{.RESIZABLE, .VULKAN},
	)
	if g_window_context.handle == nil {
		log.fatalf("SDL: error initializing window")
	}

	g_window_context.close = false
}

destroyWindow :: proc() {
	log.infof("Destroy window")

	sdl.DestroyWindow(g_window_context.handle)
}

getWindowSize :: proc() -> linalg.Vector2f32 {
	return linalg.Vector2f32{f32(g_window_context.width), f32(g_window_context.height)}
}
