package base_context

import "core:log"
import "core:mem"
import vmem "core:mem/virtual"

initArenaAllocator :: proc(size: uint = 1 * mem.Megabyte) -> vmem.Arena {
	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena, size)

	assert(arena_err == nil)

	// return vmem.arena_allocator(&arena)
	return arena
}

initTrackingAllocator :: proc(allocator: mem.Allocator) -> mem.Tracking_Allocator {
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, allocator)
	// return mem.tracking_allocator(&tracking_allocator)
	return tracking_allocator
}

resetTrackingAllocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
	err := false

	for _, value in a.allocation_map {
		// fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
		log.errorf("%v: Leaked %v bytes\n", value.location, value.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}

checkDoubleFreeTrackingAllocator :: proc(tracking_allocator: mem.Tracking_Allocator) {
	if len(tracking_allocator.bad_free_array) > 0 {
		for b in tracking_allocator.bad_free_array {
			log.errorf("Bad free at: %v", b.location)
		}

		panic("Bad free detected")
	}
}
