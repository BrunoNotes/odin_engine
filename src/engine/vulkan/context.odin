package vulkan_context

import sdl "../../../vendor/sdl3"
import "../base"
import w_ctx "../window"
import "core:log"
import "core:math/linalg"
import "core:mem"
import vmem "core:mem/virtual"
import vk "vendor:vulkan"

import "base:runtime"
@(private)
ENABLE_VALIDATION_LAYERS :: #config(ENABLE_VALIDATION_LAYERS, ODIN_DEBUG)
@(private)
DEVICE_EXTENSIONS := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}

@(private)
runtime_ctx: runtime.Context

g_vulkan_context: VkContext

VkContext :: struct {
	vSync:            bool,
	background_color: linalg.Vector4f32,
	arena:            vmem.Arena,
	arena_allocator:  mem.Allocator,
	vk_allocator:     ^vk.AllocationCallbacks,
	instance:         VkInstance,
	surface:          vk.SurfaceKHR,
	physical_device:  VkPhysicalDevice,
	logic_device:    VkLogicDevice,
	swapchain:       VkSwapChain,
}

initVkContext :: proc() {
	log.infof("Init VkContext")

	g_vulkan_context.arena = base.initArenaAllocator()
	g_vulkan_context.arena_allocator = vmem.arena_allocator(&g_vulkan_context.arena)

	// set global ctx to the current ctx
	runtime_ctx = context

	// TODO: make a custom allocator
	g_vulkan_context.vk_allocator = nil

	initVkInstance()

	if !sdl.Vulkan_CreateSurface(
		w_ctx.g_window_context.handle,
		g_vulkan_context.instance.handle,
		nil,
		&g_vulkan_context.surface,
	) {
		log.panicf("Vulkan: failed to create surface")
	}

    initVkPhysicalDevice()
    initVkLogicDevice()
    initVkSwapChain()
}

destroyVkContext :: proc() {
	log.infof("Destroy VkContext")

    vkCheck(vk.DeviceWaitIdle(g_vulkan_context.logic_device.handle))

    destroyVkSwapChain()
    destroyVkLogicDevice()
	vk.DestroySurfaceKHR(
		g_vulkan_context.instance.handle,
		g_vulkan_context.surface,
		g_vulkan_context.vk_allocator,
	)
	destroyVkInstance()
	vmem.arena_destroy(&g_vulkan_context.arena)
}
