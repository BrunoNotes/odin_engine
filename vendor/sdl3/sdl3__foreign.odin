package sdl3

when ODIN_OS == .Windows {
	@(export)
	foreign import lib "./lib/SDL3.lib"
} else when ODIN_OS == .Linux {
	@(export)
	foreign import lib "./lib/libSDL3.a"
} else {
	@(export)
	foreign import lib "system:SDL3"
}

