package vulkan_context

import w_ctx "../window"
import "core:log"
import vk "vendor:vulkan"

VkSwapChain :: struct {
	max_frames_inflight: u32,
	image_format:        vk.Format,
	handle:              vk.SwapchainKHR,
	images:              []VkImage,
	depth_images:        []VkImage,
	frame_data:          []VkFrameData,
	current_frame:       u32,
	next_img_idx:        u32,
	needs_rebuild:       bool,
}

VkSwapChainSupport :: struct {
	capabilities:  vk.SurfaceCapabilities2KHR,
	formats:       []vk.SurfaceFormat2KHR,
	present_modes: []vk.PresentModeKHR,
}

VkQueueFamilyIdx :: struct {
	graphics: Maybe(u32),
	present:  Maybe(u32),
}

VkQueueInfo :: struct {
	family_idx: u32,
	queue_idx:  u32,
	queue:      vk.Queue,
}

VkFrameData :: struct {
	cmd_pool:                  vk.CommandPool,
	cmd_buffer:                vk.CommandBuffer,
	frame_number:              u64,
	img_available_semaphore:   vk.Semaphore,
	render_finished_semaphore: vk.Semaphore,
	render_finished_fence:     vk.Fence,
}


initVkSwapChain :: proc() {
	log.infof("Vulkan: init SwapChain")

	swapchain_support := vkGetSwapChainSupport(
		g_vulkan_context.physical_device.handle,
		g_vulkan_context.surface,
	)

	surface_format := vkSelectSwapChainSurfaceFormat(swapchain_support.formats)
	present_mode := vkSelectSwapChainPresentMode(
		swapchain_support.present_modes,
		g_vulkan_context.vSync,
	)

	assert(
		u32(w_ctx.getWindowSize().y) <=
		swapchain_support.capabilities.surfaceCapabilities.maxImageExtent.height,
	)
	assert(
		u32(w_ctx.getWindowSize().x) <=
		swapchain_support.capabilities.surfaceCapabilities.maxImageExtent.width,
	)

	// min_img_count :=
	//     swapchain_support.capabilities.surfaceCapabilities.minImageCount
	//
	// preferred_img_count := max(3, min_img_count)
	//
	// max_img_count :=
	//     swapchain_support.capabilities.surfaceCapabilities.maxImageCount == 0 ? preferred_img_count : swapchain_support.capabilities.surfaceCapabilities.maxImageCount

	// g_vulkan_context.swapchain.max_frames_inflight = math.clamp(
	//     preferred_img_count,
	//     min_img_count,
	//     max_img_count,
	// )

	g_vulkan_context.swapchain.max_frames_inflight =
		swapchain_support.capabilities.surfaceCapabilities.minImageCount + 1

	if swapchain_support.capabilities.surfaceCapabilities.maxImageCount > 0 &&
	   g_vulkan_context.swapchain.max_frames_inflight >
		   swapchain_support.capabilities.surfaceCapabilities.maxImageCount {
		g_vulkan_context.swapchain.max_frames_inflight =
			swapchain_support.capabilities.surfaceCapabilities.maxImageCount
	}

	g_vulkan_context.swapchain.image_format = surface_format.surfaceFormat.format

	swapchain_info := vk.SwapchainCreateInfoKHR {
		sType = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR,
		surface = g_vulkan_context.surface,
		minImageCount = g_vulkan_context.swapchain.max_frames_inflight,
		imageFormat = surface_format.surfaceFormat.format,
		imageColorSpace = surface_format.surfaceFormat.colorSpace,
		imageExtent = vk.Extent2D {
			width = u32(w_ctx.getWindowSize().x),
			height = u32(w_ctx.getWindowSize().y),
		},
		imageArrayLayers = 1,
		imageUsage = {.COLOR_ATTACHMENT, .TRANSFER_DST},
		imageSharingMode = vk.SharingMode.EXCLUSIVE,
		preTransform = swapchain_support.capabilities.surfaceCapabilities.currentTransform,
		compositeAlpha = {.OPAQUE},
		presentMode = present_mode,
		clipped = true,
	}

	vkCheck(
		vk.CreateSwapchainKHR(
			g_vulkan_context.logic_device.handle,
			&swapchain_info,
			g_vulkan_context.vk_allocator,
			&g_vulkan_context.swapchain.handle,
		),
	)

	g_vulkan_context.swapchain.frame_data = make(
		[]VkFrameData,
		g_vulkan_context.swapchain.max_frames_inflight,
		g_vulkan_context.arena_allocator,
	)

	cmd_poll_info := vk.CommandPoolCreateInfo {
		sType            = vk.StructureType.COMMAND_POOL_CREATE_INFO,
		queueFamilyIndex = g_vulkan_context.logic_device.graphics_queue.family_idx,
	}

	img_count: u32

	vkCheck(
		vk.GetSwapchainImagesKHR(
			g_vulkan_context.logic_device.handle,
			g_vulkan_context.swapchain.handle,
			&img_count,
			nil,
		),
	)

	assert(g_vulkan_context.swapchain.max_frames_inflight >= img_count)

	swapchain_images := make([]vk.Image, img_count, context.temp_allocator)
	vkCheck(
		vk.GetSwapchainImagesKHR(
			g_vulkan_context.logic_device.handle,
			g_vulkan_context.swapchain.handle,
			&img_count,
			raw_data(swapchain_images),
		),
	)

	g_vulkan_context.swapchain.images = make(
		[]VkImage,
		img_count,
		g_vulkan_context.arena_allocator,
	)

	g_vulkan_context.swapchain.depth_images = make(
		[]VkImage,
		img_count,
		g_vulkan_context.arena_allocator,
	)

	fence_info := vk.FenceCreateInfo {
		sType = vk.StructureType.FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}

	semaphore_info := vk.SemaphoreCreateInfo {
		sType = vk.StructureType.SEMAPHORE_CREATE_INFO,
	}

	for i: u32 = 0; i < g_vulkan_context.swapchain.max_frames_inflight; i += 1 {
		g_vulkan_context.swapchain.images[i].handle = swapchain_images[i]

		g_vulkan_context.swapchain.images[i].view = createVkImageView(
			g_vulkan_context.swapchain.images[i].handle,
			g_vulkan_context.swapchain.image_format,
			{.COLOR},
			1,
		)

		{
			g_vulkan_context.swapchain.depth_images[i].extent =
				g_vulkan_context.swapchain.images[i].extent

			depth_format := findSupportedFormat(
				{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
				.OPTIMAL,
				{.DEPTH_STENCIL_ATTACHMENT},
			)

			createVkImage(
				&g_vulkan_context.swapchain.depth_images[i],
				u32(w_ctx.getWindowSize().x),
				u32(w_ctx.getWindowSize().y),
				1,
				depth_format,
				.OPTIMAL,
				{.DEPTH_STENCIL_ATTACHMENT},
				{.DEVICE_LOCAL},
			)

			g_vulkan_context.swapchain.depth_images[i].view = createVkImageView(
				g_vulkan_context.swapchain.depth_images[i].handle,
				g_vulkan_context.swapchain.depth_images[i].format,
				{.DEPTH},
				1,
			)
		}

		vkCheck(
			vk.CreateFence(
				g_vulkan_context.logic_device.handle,
				&fence_info,
				g_vulkan_context.vk_allocator,
				&g_vulkan_context.swapchain.frame_data[i].render_finished_fence,
			),
		)

		vkCheck(
			vk.CreateSemaphore(
				g_vulkan_context.logic_device.handle,
				&semaphore_info,
				g_vulkan_context.vk_allocator,
				&g_vulkan_context.swapchain.frame_data[i].render_finished_semaphore,
			),
		)

		vkCheck(
			vk.CreateSemaphore(
				g_vulkan_context.logic_device.handle,
				&semaphore_info,
				g_vulkan_context.vk_allocator,
				&g_vulkan_context.swapchain.frame_data[i].img_available_semaphore,
			),
		)

		vkCheck(
			vk.CreateCommandPool(
				g_vulkan_context.logic_device.handle,
				&cmd_poll_info,
				g_vulkan_context.vk_allocator,
				&g_vulkan_context.swapchain.frame_data[i].cmd_pool,
			),
		)

		cmd_buffer_alloc_info := vk.CommandBufferAllocateInfo {
			sType              = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool        = g_vulkan_context.swapchain.frame_data[i].cmd_pool,
			level              = vk.CommandBufferLevel.PRIMARY,
			commandBufferCount = 1,
		}

		vkCheck(
			vk.AllocateCommandBuffers(
				g_vulkan_context.logic_device.handle,
				&cmd_buffer_alloc_info,
				&g_vulkan_context.swapchain.frame_data[i].cmd_buffer,
			),
		)

	}
}

destroyVkSwapChain :: proc() {
	log.infof("Vulkan: destroy SwapChain")

	for &frame in g_vulkan_context.swapchain.frame_data {
		vk.FreeCommandBuffers(
			g_vulkan_context.logic_device.handle,
			frame.cmd_pool,
			1,
			&frame.cmd_buffer,
		)

		vk.DestroyCommandPool(
			g_vulkan_context.logic_device.handle,
			frame.cmd_pool,
			g_vulkan_context.vk_allocator,
		)

		vk.DestroyFence(
			g_vulkan_context.logic_device.handle,
			frame.render_finished_fence,
			g_vulkan_context.vk_allocator,
		)

		vk.DestroySemaphore(
			g_vulkan_context.logic_device.handle,
			frame.img_available_semaphore,
			g_vulkan_context.vk_allocator,
		)

		vk.DestroySemaphore(
			g_vulkan_context.logic_device.handle,
			frame.render_finished_semaphore,
			g_vulkan_context.vk_allocator,
		)
	}

	for img in g_vulkan_context.swapchain.images {
		vk.DestroyImageView(
			g_vulkan_context.logic_device.handle,
			img.view,
			g_vulkan_context.vk_allocator,
		)
	}

	for img in g_vulkan_context.swapchain.depth_images {
		vk.DestroyImageView(
			g_vulkan_context.logic_device.handle,
			img.view,
			g_vulkan_context.vk_allocator,
		)
		vk.DestroyImage(
			g_vulkan_context.logic_device.handle,
			img.handle,
			g_vulkan_context.vk_allocator,
		)
		vk.FreeMemory(
			g_vulkan_context.logic_device.handle,
			img.memory,
			g_vulkan_context.vk_allocator,
		)
	}

	vk.DestroySwapchainKHR(
		g_vulkan_context.logic_device.handle,
		g_vulkan_context.swapchain.handle,
		g_vulkan_context.vk_allocator,
	)
}
