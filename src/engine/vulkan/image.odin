package vulkan_context

import vk "vendor:vulkan"

VkImage :: struct {
	handle: vk.Image,
	view:   vk.ImageView,
	extent: vk.Extent2D,
	memory: vk.DeviceMemory,
    format: vk.Format,
}

createVkImageView :: proc(
	image: vk.Image,
	format: vk.Format,
	aspect_flags: vk.ImageAspectFlags,
	mip_levels: u32,
) -> vk.ImageView {
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image,
		viewType = .D2,
		format = format,
		subresourceRange = {aspectMask = aspect_flags, levelCount = mip_levels, layerCount = 1},
	}

	img_view: vk.ImageView
	vkCheck(
		vk.CreateImageView(
			g_vulkan_context.logic_device.handle,
			&view_info,
			g_vulkan_context.vk_allocator,
			&img_view,
		),
	)

	return img_view
}

createVkImage :: proc(
	image: ^VkImage,
	img_width: u32,
	img_height: u32,
	mip_levels: u32,
	format: vk.Format,
	tiling: vk.ImageTiling,
	usage: vk.ImageUsageFlags,
	properties: vk.MemoryPropertyFlags,
) {
    image.format = format

	img_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = format,
		extent = {width = img_width, height = img_height, depth = 1},
		mipLevels = mip_levels,
		arrayLayers = 1,
		tiling = tiling,
		initialLayout = .UNDEFINED,
		samples = {._1},
		usage = usage,
		sharingMode = .EXCLUSIVE,
	}

	vkCheck(
		vk.CreateImage(
			g_vulkan_context.logic_device.handle,
			&img_info,
			g_vulkan_context.vk_allocator,
			&image.handle,
		),
	)

	mem_req: vk.MemoryRequirements

	vk.GetImageMemoryRequirements(g_vulkan_context.logic_device.handle, image.handle, &mem_req)

	alloc_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = mem_req.size,
		memoryTypeIndex = vkFindMemoryType(mem_req.memoryTypeBits, properties),
	}

	vkCheck(
		vk.AllocateMemory(
			g_vulkan_context.logic_device.handle,
			&alloc_info,
			g_vulkan_context.vk_allocator,
			&image.memory,
		),
	)

	vkCheck(
		vk.BindImageMemory(g_vulkan_context.logic_device.handle, image.handle, image.memory, 0),
	)
}
