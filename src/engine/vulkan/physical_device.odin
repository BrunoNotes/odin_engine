package vulkan_context

import "core:log"
import "core:strings"
import vk "vendor:vulkan"

VkPhysicalDevice :: struct {
	handle:      vk.PhysicalDevice,
	properties2: vk.PhysicalDeviceProperties2,
}


initVkPhysicalDevice :: proc() {
	log.infof("Vulkan: init PhysicalDevice")

	scorePhysicalDevice :: proc(
		device: vk.PhysicalDevice,
		surface: vk.SurfaceKHR,
	) -> (
		score: int,
	) {
		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(device, &props)

		name := strings.truncate_to_byte(string(props.deviceName[:]), 0)
		log.infof("Vulkan: evaluating device %q", name)
		defer log.infof("Vulkan: device %q scored %v", name, score)

		features: vk.PhysicalDeviceFeatures
		vk.GetPhysicalDeviceFeatures(device, &features)

		// Need certain extensions supported.
		{
			count: u32
			vkCheck(vk.EnumerateDeviceExtensionProperties(device, nil, &count, nil))

			extensions := make([]vk.ExtensionProperties, count, context.temp_allocator)
			vkCheck(
				vk.EnumerateDeviceExtensionProperties(device, nil, &count, raw_data(extensions)),
			)

			required_loop: for required in DEVICE_EXTENSIONS {
				for &extension in extensions {
					extension_name := strings.truncate_to_byte(
						string(extension.extensionName[:]),
						0,
					)
					if extension_name == string(required) {
						continue required_loop
					}
				}

				log.infof("Vulkan: device does not support required extension %q", required)
				return 0
			}
		}

		// Check if swapchain is adequately supported.
		{
			support := vkGetSwapChainSupport(device, surface)

			// Need at least a format and present mode.
			if len(support.formats) == 0 || len(support.present_modes) == 0 {
				log.infof("Vulkan: device does not support swapchain")
				return 0
			}
		}

		families_idx := VkQueueFamilyIdx{}
		count: u32
		vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)

		families_properties := make([]vk.QueueFamilyProperties, count, context.temp_allocator)
		vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(families_properties))

		for propertie, i in families_properties {
			if .GRAPHICS in propertie.queueFlags {
				families_idx.graphics = u32(i)
			}

			supported: b32
			vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), surface, &supported)
			if supported {
				families_idx.present = u32(i)
			}

			// Found all needed queues?
			_, has_graphics := families_idx.graphics.?
			_, has_present := families_idx.present.?
			if has_graphics && has_present {
				break
			}
		}

		if _, has_graphics := families_idx.graphics.?; !has_graphics {
			log.infof("Vulkan: device does not have a graphics queue")
			return 0
		}
		if _, has_present := families_idx.present.?; !has_present {
			log.infof("Vulkan: device does not have a presentation queue")
			return 0
		}

		// Favor GPUs.
		switch props.deviceType {
		case .DISCRETE_GPU:
			score += 300_000
		case .INTEGRATED_GPU:
			score += 200_000
		case .VIRTUAL_GPU:
			score += 100_000
		case .CPU, .OTHER:
		}

		when ODIN_DEBUG {
			log.infof("Vulkan: scored %i based on device type %v", score, props.deviceType)
		}

		// Maximum texture size.
		score += int(props.limits.maxImageDimension2D)
		when ODIN_DEBUG {
			log.infof(
				"Vulkan: added the max 2D image dimensions (texture size) of %v to the score",
				props.limits.maxImageDimension2D,
			)
		}
		return
	}

	device_count: u32
	vkCheck(vk.EnumeratePhysicalDevices(g_vulkan_context.instance.handle, &device_count, nil))

	assert(device_count > 0)

	physical_devices := make([]vk.PhysicalDevice, device_count, context.temp_allocator)

	vkCheck(
		vk.EnumeratePhysicalDevices(
			g_vulkan_context.instance.handle,
			&device_count,
			raw_data(physical_devices),
		),
	)

	best_device_score := -1
	for device in physical_devices {
		if score := scorePhysicalDevice(device, g_vulkan_context.surface); score > best_device_score {
			g_vulkan_context.physical_device.handle = device
			best_device_score = score
		}
	}

	if best_device_score <= 0 {
		log.panic("Vulkan: no suitable GPU found")
	}

	g_vulkan_context.physical_device.properties2 = vk.PhysicalDeviceProperties2 {
		sType = vk.StructureType.PHYSICAL_DEVICE_PROPERTIES_2,
	}
	vk.GetPhysicalDeviceProperties2(
		g_vulkan_context.physical_device.handle,
		&g_vulkan_context.physical_device.properties2,
	)

	device_name := strings.truncate_to_byte(
		string(g_vulkan_context.physical_device.properties2.properties.deviceName[:]),
		0,
	)
	log.infof("Vulkan: selected gpu: %v", device_name)
}
