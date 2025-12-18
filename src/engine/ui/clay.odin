package ui

import "../../../vendor/clay"
import "../base"
import "base:runtime"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"

@(private)
ctx: runtime.Context

ClayContext :: struct {
	handle:          ^clay.Context,
	mem_size:        u32,
	arena:           vmem.Arena,
	arena_allocator: mem.Allocator,
}

clayHandleErrors :: proc "system" (error_data: clay.ErrorData) {
	context = ctx
	log.errorf("%v", error_data.errorText.chars)
	// switch error_data.errorType {}
}

clayMeasureText :: proc "system" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	// TODO: check more dimensions, this only work with monospace
	return clay.Dimensions {
		width = f32(text.length) * f32(config.fontSize),
		height = f32(config.fontSize),
	}
}

clayInit :: proc(ctx: ^ClayContext, width, height: f32) {
	ctx.mem_size = clay.MinMemorySize()

	ctx.arena = base.initArenaAllocator(uint(ctx.mem_size))
	ctx.arena_allocator = vmem.arena_allocator(&ctx.arena)

	clay_mem := make([^]u8, ctx.mem_size, ctx.arena_allocator)

	clay_arena := clay.CreateArenaWithCapacityAndMemory(i32(ctx.mem_size), clay_mem)

	ctx.handle = clay.Initialize(
		clay_arena,
		{width = width, height = height},
		{errorHandlerFunction = clayHandleErrors},
	)

	clay.SetMeasureTextFunction(clayMeasureText, nil)
}

destroyClay :: proc(ctx: ^ClayContext) {
	vmem.arena_destroy(&ctx.arena)
}

clayRender :: proc(ctx: ^ClayContext, render_cmds: ^clay.RenderCommandArray) {
	// TODO: make renderer
	for i in 0 ..< render_cmds.length {
		cmd := clay.RenderCommandArray_Get(render_cmds, i)

		switch cmd.commandType {
		case .RENDER_COMMAND_TYPE_NONE:
		case .RENDER_COMMAND_TYPE_RECTANGLE:
		case .RENDER_COMMAND_TYPE_BORDER:
		case .RENDER_COMMAND_TYPE_TEXT:
		case .RENDER_COMMAND_TYPE_IMAGE:
		case .RENDER_COMMAND_TYPE_SCISSOR_START:
		case .RENDER_COMMAND_TYPE_SCISSOR_END:
		case .RENDER_COMMAND_TYPE_CUSTOM:
		}
	}
}
