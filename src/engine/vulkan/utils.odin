package vulkan_context

import "base:intrinsics"
import "core:log"
import vk "vendor:vulkan"

vkCheck :: proc(result: vk.Result, loc := #caller_location) {
	if result != .SUCCESS {
		log.panicf("Vulkan: error detected: %v", result, location = loc)
	}
}

vkExtensionIsAvailable :: proc(name: string, extensions: []vk.ExtensionProperties) -> bool {
	for ext in extensions {
		ext_name_clone := ext.extensionName
		ext_name := string(cstring(rawptr(&ext_name_clone[0])))
		if name == ext_name {
			return true
		}
	}
	return false
}

vkDebugCallback :: proc "system" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
	messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	context = runtime_ctx

	level: log.Level
	if .ERROR in messageSeverity {
		level = .Error
	} else if .WARNING in messageSeverity {
		level = .Warning
	} else if .INFO in messageSeverity {
		level = .Info
	} else {
		level = .Debug
	}

	log.logf(level, "vulkan[%v]: %s", messageTypes, pCallbackData.pMessage)
	return false
}

vkGetQueueInfo :: proc(physical_device: vk.PhysicalDevice, flags: vk.QueueFlag) -> VkQueueInfo {
	count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties2(physical_device, &count, nil)

	queue_families := make([]vk.QueueFamilyProperties2, count, context.temp_allocator)

	for &family in queue_families {
		family.sType = vk.StructureType.QUEUE_FAMILY_PROPERTIES_2
	}

	vk.GetPhysicalDeviceQueueFamilyProperties2(physical_device, &count, raw_data(queue_families))

	queue_info := VkQueueInfo{}

	for family, idx in queue_families {
		if flags in family.queueFamilyProperties.queueFlags {
			queue_info.family_idx = u32(idx)
			queue_info.queue_idx = 0
		}
	}

	return queue_info
}

vkpNextChainPushFront :: proc(
	main_struct: ^$MainT,
	new_struct: ^$NewT,
) where intrinsics.type_has_field(MainT, "pNext") &&
	intrinsics.type_has_field(NewT, "pNext") {
	new_struct.pNext = main_struct.pNext
	main_struct.pNext = new_struct
}

vkGetSwapChainSupport :: proc(
	physical_device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> VkSwapChainSupport {
	support := VkSwapChainSupport{}

	surface_info := vk.PhysicalDeviceSurfaceInfo2KHR {
		sType   = .PHYSICAL_DEVICE_SURFACE_INFO_2_KHR,
		surface = surface,
	}

	support.capabilities = vk.SurfaceCapabilities2KHR {
		sType = .SURFACE_CAPABILITIES_2_KHR,
	}

	vkCheck(
		vk.GetPhysicalDeviceSurfaceCapabilities2KHR(
			physical_device,
			&surface_info,
			&support.capabilities,
		),
	)

	format_count: u32
	vkCheck(
		vk.GetPhysicalDeviceSurfaceFormats2KHR(physical_device, &surface_info, &format_count, nil),
	)

	support.formats = make([]vk.SurfaceFormat2KHR, format_count, context.temp_allocator)

	for &format in support.formats {
		format.sType = .SURFACE_FORMAT_2_KHR
	}

	vkCheck(
		vk.GetPhysicalDeviceSurfaceFormats2KHR(
			physical_device,
			&surface_info,
			&format_count,
			raw_data(support.formats),
		),
	)

	present_mode_count: u32
	vkCheck(
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physical_device,
			surface,
			&present_mode_count,
			nil,
		),
	)

	support.present_modes = make([]vk.PresentModeKHR, present_mode_count, context.temp_allocator)

	vkCheck(
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physical_device,
			surface,
			&present_mode_count,
			raw_data(support.present_modes),
		),
	)

	return support
}

vkSelectSwapChainSurfaceFormat :: proc(
	available_formats: []vk.SurfaceFormat2KHR,
) -> vk.SurfaceFormat2KHR {
	preferred_formats := [?]vk.SurfaceFormat2KHR {
		vk.SurfaceFormat2KHR {
			sType = vk.StructureType.SURFACE_FORMAT_2_KHR,
			surfaceFormat = vk.SurfaceFormatKHR {
				format = vk.Format.B8G8R8A8_UNORM,
				colorSpace = vk.ColorSpaceKHR.SRGB_NONLINEAR,
			},
		},
	}

	// if there is only one return a default
	if len(available_formats) == 1 &&
	   available_formats[0].surfaceFormat.format == vk.Format.UNDEFINED {
		return preferred_formats[0]
	}

	for pref_format in preferred_formats {
		for avl_format in available_formats {
			if avl_format.surfaceFormat.format == pref_format.surfaceFormat.format &&
			   avl_format.surfaceFormat.colorSpace == pref_format.surfaceFormat.colorSpace {
				return avl_format // Return the first matching preferred format.
			}
		}
	}

	// If none of the preferred formats are available, return the first available format.
	return available_formats[0]
}

vkSelectSwapChainPresentMode :: proc(
	available_present_modes: []vk.PresentModeKHR,
	vSync: bool = false,
) -> vk.PresentModeKHR {
	if vSync {
		return vk.PresentModeKHR.FIFO
	}

	for mode in available_present_modes {
		if mode == vk.PresentModeKHR.MAILBOX {
			return vk.PresentModeKHR.MAILBOX
		} else if mode == vk.PresentModeKHR.IMMEDIATE {
			return vk.PresentModeKHR.IMMEDIATE
		}
	}

	return vk.PresentModeKHR.FIFO
}

vkFindMemoryType :: proc(type_filter: u32, properties: vk.MemoryPropertyFlags) -> u32 {
	mem_prop: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(g_vulkan_context.physical_device.handle, &mem_prop)

	for i: u32 = 0; i < mem_prop.memoryTypeCount; i += 1 {
		if (type_filter & (1 << i)) != 0 &&
		   (mem_prop.memoryTypes[i].propertyFlags & properties) == properties {
			return i
		}
	}

	panic("Vulkan: failed to find suitable memory type")
}

vkGetPipelineStageAccess :: proc(state: vk.ImageLayout) -> VkPipelineStageAccess {
	#partial switch state {
	case .UNDEFINED:
		return VkPipelineStageAccess{stage = {.TOP_OF_PIPE}, access = {}}
	case .COLOR_ATTACHMENT_OPTIMAL:
		return VkPipelineStageAccess {
			stage = {.COLOR_ATTACHMENT_OUTPUT},
			access = {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		return VkPipelineStageAccess {
			stage = {.FRAGMENT_SHADER, .COMPUTE_SHADER, .PRE_RASTERIZATION_SHADERS},
			access = {.SHADER_READ},
		}
	case .TRANSFER_DST_OPTIMAL:
		return VkPipelineStageAccess{stage = {.TRANSFER}, access = {.TRANSFER_WRITE}}
	case .GENERAL:
		return VkPipelineStageAccess {
			stage = {.COMPUTE_SHADER, .TRANSFER},
			access = {.MEMORY_READ, .MEMORY_WRITE, .TRANSFER_WRITE},
		}
	case .PRESENT_SRC_KHR:
		return VkPipelineStageAccess{stage = {.COLOR_ATTACHMENT_OUTPUT}, access = {}}
	case .DEPTH_STENCIL_ATTACHMENT_OPTIMAL:
		return VkPipelineStageAccess {
			stage = {.EARLY_FRAGMENT_TESTS},
			access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
		}
	case:
		return VkPipelineStageAccess {
			stage = {.ALL_COMMANDS},
			access = {.MEMORY_READ, .MEMORY_WRITE},
		}
	}
}

vkTransitionImage :: proc(
	cmd: vk.CommandBuffer,
	img: vk.Image,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
	format: vk.Format = vk.Format.UNDEFINED,
	mip_levels: u32 = vk.REMAINING_MIP_LEVELS,
) {
	src_stage_access := vkGetPipelineStageAccess(old_layout)
	dst_stage_access := vkGetPipelineStageAccess(new_layout)

	aspectMask: vk.ImageAspectFlags
	if new_layout == .DEPTH_STENCIL_ATTACHMENT_OPTIMAL {
		// TODO: check stencil
		if format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT {
			aspectMask = {.DEPTH, .STENCIL}
		} else {
			aspectMask = {.DEPTH}
		}
	} else {
		aspectMask = {.COLOR}
	}

	sub_resource_range := vk.ImageSubresourceRange {
		aspectMask     = aspectMask,
		baseMipLevel   = 0,
		baseArrayLayer = 0,
		levelCount     = mip_levels,
		layerCount     = vk.REMAINING_ARRAY_LAYERS,
	}

	barrier := vk.ImageMemoryBarrier2 {
		sType               = vk.StructureType.IMAGE_MEMORY_BARRIER_2,
		srcStageMask        = src_stage_access.stage,
		srcAccessMask       = src_stage_access.access,
		dstStageMask        = dst_stage_access.stage,
		dstAccessMask       = dst_stage_access.access,
		oldLayout           = old_layout,
		newLayout           = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image               = img,
		subresourceRange    = sub_resource_range,
	}

	dep_info := vk.DependencyInfo {
		sType                   = vk.StructureType.DEPENDENCY_INFO,
		imageMemoryBarrierCount = 1,
		pImageMemoryBarriers    = &barrier,
	}

	vk.CmdPipelineBarrier2(cmd, &dep_info)
}

findSupportedFormat :: proc(
	formats: []vk.Format,
	tiling: vk.ImageTiling,
	features: vk.FormatFeatureFlags,
) -> vk.Format {

	for format in formats {
		props: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(
			g_vulkan_context.physical_device.handle,
			format,
			&props,
		)

		if tiling == .LINEAR && (props.linearTilingFeatures & features) == features {
			return format
		} else if tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features {
			return format
		}

	}

	panic("vulkan: failed to find supported format")
}
