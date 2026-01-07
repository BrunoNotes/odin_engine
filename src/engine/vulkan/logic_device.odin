package vulkan_context

import "core:log"
import vk "vendor:vulkan"

VkLogicDevice :: struct {
	handle:         vk.Device,
	queues:         []VkQueueInfo,
	graphics_queue: VkQueueInfo,
}

initVkLogicDevice :: proc() {
	queues := [?]VkQueueInfo{vkGetQueueInfo(g_vulkan_context.physical_device.handle, .GRAPHICS)}

	g_vulkan_context.logic_device.queues = queues[:]
	g_vulkan_context.logic_device.graphics_queue = queues[0]

	queue_create_info := vk.DeviceQueueCreateInfo {
		sType            = .DEVICE_QUEUE_CREATE_INFO,
		queueFamilyIndex = g_vulkan_context.logic_device.graphics_queue.family_idx,
		queueCount       = 1,
		pQueuePriorities = raw_data([]f32{1}),
	}

	features11 := vk.PhysicalDeviceVulkan11Features {
		sType = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
	}

	features12 := vk.PhysicalDeviceVulkan12Features {
		sType               = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		bufferDeviceAddress = true,
		descriptorIndexing  = true,
	}

	features13 := vk.PhysicalDeviceVulkan13Features {
		sType            = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
		dynamicRendering = true,
		synchronization2 = true,
	}

	vkpNextChainPushFront(&features11, &features12)
	vkpNextChainPushFront(&features11, &features13)

	available_device_extension_count: u32
	vkCheck(
		vk.EnumerateDeviceExtensionProperties(
			g_vulkan_context.physical_device.handle,
			nil,
			&available_device_extension_count,
			nil,
		),
	)

	device_extensions_available := make(
		[]vk.ExtensionProperties,
		available_device_extension_count,
		context.temp_allocator,
	)
	vkCheck(
		vk.EnumerateDeviceExtensionProperties(
			g_vulkan_context.physical_device.handle,
			nil,
			&available_device_extension_count,
			raw_data(device_extensions_available),
		),
	)

	device_extensions := make([dynamic]cstring, context.temp_allocator)

	append(&device_extensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME) // Needed for display on the screen

	if vkExtensionIsAvailable(vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME, device_extensions_available) {
		append(&device_extensions, vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME)
	}

	if vkExtensionIsAvailable(
		vk.EXT_EXTENDED_DYNAMIC_STATE_EXTENSION_NAME,
		device_extensions_available,
	) {
		dynamic_state_features := vk.PhysicalDeviceExtendedDynamicStateFeaturesEXT {
			sType = .PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT,
		}
		vkpNextChainPushFront(&features11, &dynamic_state_features)

		append(&device_extensions, vk.EXT_EXTENDED_DYNAMIC_STATE_EXTENSION_NAME)
	}

	if vkExtensionIsAvailable(
		vk.EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME,
		device_extensions_available,
	) {
		dynamic_state_3_features := vk.PhysicalDeviceExtendedDynamicState3FeaturesEXT {
			sType = .PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT,
		}
		vkpNextChainPushFront(&features11, &dynamic_state_3_features)

		append(&device_extensions, vk.EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME)
	}

	if vkExtensionIsAvailable(
		vk.EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME,
		device_extensions_available,
	) {
		swapchain_features := vk.PhysicalDeviceSwapchainMaintenance1FeaturesEXT {
			sType = .PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_EXT,
		}
		vkpNextChainPushFront(&features11, &swapchain_features)

		append(&device_extensions, vk.EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME)
	}

	when ODIN_DEBUG {
		for ext in device_extensions {
			log.debugf("Vulkan: device extension: %v", ext)
		}
	}

	device_features := vk.PhysicalDeviceFeatures2 {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = &features11,
	}
	vk.GetPhysicalDeviceFeatures2(g_vulkan_context.physical_device.handle, &device_features)

	push_descriptor_properties := vk.PhysicalDevicePushDescriptorPropertiesKHR {
		sType = .PHYSICAL_DEVICE_PUSH_DESCRIPTOR_PROPERTIES_KHR,
	}

	device_properties := vk.PhysicalDeviceProperties2 {
		sType = .PHYSICAL_DEVICE_PROPERTIES_2,
		pNext = &push_descriptor_properties,
	}

	vk.GetPhysicalDeviceProperties2(g_vulkan_context.physical_device.handle, &device_properties)

	device_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = &device_features,
		queueCreateInfoCount    = 1,
		pQueueCreateInfos       = &queue_create_info,
		enabledExtensionCount   = u32(len(device_extensions)),
		ppEnabledExtensionNames = raw_data(device_extensions),
	}

	vkCheck(
		vk.CreateDevice(
			g_vulkan_context.physical_device.handle,
			&device_info,
			g_vulkan_context.vk_allocator,
			&g_vulkan_context.logic_device.handle,
		),
	)

	// get the requested queues
	vk.GetDeviceQueue(
		g_vulkan_context.logic_device.handle,
		g_vulkan_context.logic_device.graphics_queue.family_idx,
		g_vulkan_context.logic_device.graphics_queue.queue_idx,
		&g_vulkan_context.logic_device.graphics_queue.queue,
	)
}

destroyVkLogicDevice :: proc() {
	vk.DestroyDevice(g_vulkan_context.logic_device.handle, g_vulkan_context.vk_allocator)
}
