package vulkan_context

import sdl "../../../vendor/sdl3"
import "core:log"
import vk "vendor:vulkan"

VkInstance :: struct {
	handle:          vk.Instance,
	debug_messenger: vk.DebugUtilsMessengerEXT,
	api_version:     u32,
}

initVkInstance :: proc() {
	log.infof("Vulkan: init Instance")

	vk.load_proc_addresses_global(rawptr(sdl.Vulkan_GetVkGetInstanceProcAddr()))
	assert(vk.CreateInstance != nil, "vulkan: function pointers not loaded")

	vkCheck(vk.EnumerateInstanceVersion(&g_vulkan_context.instance.api_version))

	assert(g_vulkan_context.instance.api_version >= vk.MAKE_VERSION(1, 3, 0)) // minimum version

	create_info := vk.InstanceCreateInfo {
		sType            = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &vk.ApplicationInfo {
			sType = .APPLICATION_INFO,
			pApplicationName = "App",
			applicationVersion = vk.MAKE_VERSION(1, 0, 0),
			pEngineName = "No Engine",
			engineVersion = vk.MAKE_VERSION(1, 0, 0),
			apiVersion = vk.API_VERSION_1_3,
		},
	}

	extensions := make([dynamic]cstring, context.temp_allocator)
	layers := make([dynamic]cstring, context.temp_allocator)

	sdl_count: u32
	sdl_extensions := sdl.Vulkan_GetInstanceExtensions(&sdl_count)
	for i in 0 ..< sdl_count {
		append(&extensions, sdl_extensions[i])
	}

	ext_count: u32
	vkCheck(vk.EnumerateInstanceExtensionProperties(nil, &ext_count, nil))

	available_ext := make([]vk.ExtensionProperties, ext_count, context.temp_allocator)

	vkCheck(vk.EnumerateInstanceExtensionProperties(nil, &ext_count, raw_data(available_ext)))

	if vkExtensionIsAvailable(vk.KHR_SURFACE_EXTENSION_NAME, available_ext[:]) {
		append(&extensions, vk.KHR_SURFACE_EXTENSION_NAME)
	}

	if vkExtensionIsAvailable(vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME, available_ext[:]) {
		append(&extensions, vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME)
	}

	if vkExtensionIsAvailable(vk.EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME, available_ext[:]) {
		append(&extensions, vk.EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME)
	}

	when ODIN_OS == .Darwin {
		create_info.flags |= {.ENUMERATE_PORTABILITY_KHR}
		if vkExtensionIsAvailable(vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME, available_ext[:]) {
			append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
		}
	}

	when ENABLE_VALIDATION_LAYERS {
		if vkExtensionIsAvailable(vk.EXT_DEBUG_UTILS_EXTENSION_NAME, available_ext[:]) {
			append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
		}

		append(&layers, "VK_LAYER_KHRONOS_validation")

		// Severity based on logger level.
		severity: vk.DebugUtilsMessageSeverityFlagsEXT
		if context.logger.lowest_level <= .Error {
			severity |= {.ERROR}
		}
		if context.logger.lowest_level <= .Warning {
			severity |= {.WARNING}
		}
		if context.logger.lowest_level <= .Info {
			severity |= {.INFO}
		}
		if context.logger.lowest_level <= .Debug {
			severity |= {.VERBOSE}
		}

		dbg_create_info := vk.DebugUtilsMessengerCreateInfoEXT {
			sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			messageSeverity = severity,
			messageType     = {
				.GENERAL,
				.VALIDATION,
				.PERFORMANCE,
				// .DEVICE_ADDRESS_BINDING,
			},
			pfnUserCallback = vkDebugCallback,
		}
		create_info.pNext = &dbg_create_info
	}

	create_info.ppEnabledLayerNames = raw_data(layers)
	create_info.enabledLayerCount = u32(len(layers))
	create_info.enabledExtensionCount = u32(len(extensions))
	create_info.ppEnabledExtensionNames = raw_data(extensions)

	vkCheck(
		vk.CreateInstance(
			&create_info,
			g_vulkan_context.vk_allocator,
			&g_vulkan_context.instance.handle,
		),
	)

	vk.load_proc_addresses_instance(g_vulkan_context.instance.handle)
	assert(vk.CreateDevice != nil, "vulkan: function pointers not loaded")

	when ENABLE_VALIDATION_LAYERS {
		vkCheck(
			vk.CreateDebugUtilsMessengerEXT(
				g_vulkan_context.instance.handle,
				&dbg_create_info,
				g_vulkan_context.vk_allocator,
				&g_vulkan_context.instance.debug_messenger,
			),
		)
	}
}

destroyVkInstance :: proc() {
	log.infof("Vulkan: destroy Instance")

	when ENABLE_VALIDATION_LAYERS {
		vk.DestroyDebugUtilsMessengerEXT(
			g_vulkan_context.instance.handle,
			g_vulkan_context.instance.debug_messenger,
			g_vulkan_context.vk_allocator,
		)
	}

	vk.DestroyInstance(g_vulkan_context.instance.handle, g_vulkan_context.vk_allocator)
}
