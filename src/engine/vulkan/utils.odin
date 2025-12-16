package vulkan_context

import "core:log"
import vk "vendor:vulkan"
import "base:intrinsics"

vkCheck :: proc(result: vk.Result, loc := #caller_location) {
	if result != .SUCCESS {
		log.panicf("Vulkan: error detected: %v", result, location = loc)
	}
}

vkExtensionIsAvailable :: proc(
    name: string,
    extensions: []vk.ExtensionProperties,
) -> bool {
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

vkGetQueueInfo :: proc(
    physical_device: vk.PhysicalDevice,
    flags: vk.QueueFlag,
) -> VkQueueInfo {
    count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties2(physical_device, &count, nil)

    queue_families := make(
        []vk.QueueFamilyProperties2,
        count,
        context.temp_allocator,
    )

    for &family in queue_families {
        family.sType = vk.StructureType.QUEUE_FAMILY_PROPERTIES_2
    }

    vk.GetPhysicalDeviceQueueFamilyProperties2(
        physical_device,
        &count,
        raw_data(queue_families),
    )

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
        vk.GetPhysicalDeviceSurfaceFormats2KHR(
            physical_device,
            &surface_info,
            &format_count,
            nil,
        ),
    )

    support.formats = make(
        []vk.SurfaceFormat2KHR,
        format_count,
        context.temp_allocator,
    )

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

    support.present_modes = make(
        []vk.PresentModeKHR,
        present_mode_count,
        context.temp_allocator,
    )

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
            if avl_format.surfaceFormat.format ==
                   pref_format.surfaceFormat.format &&
               avl_format.surfaceFormat.colorSpace ==
                   pref_format.surfaceFormat.colorSpace {
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

vkFindMemoryType :: proc(
    type_filter: u32,
    properties: vk.MemoryPropertyFlags,
) -> u32 {
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
