package vulkan_context

import w_ctx "../window"
import vk "vendor:vulkan"

beginVkRendering :: proc() {
	// rebuilds the swapchain if needed
	if g_vulkan_context.swapchain.needs_rebuild {
		vkCheck(vk.QueueWaitIdle(g_vulkan_context.logic_device.graphics_queue.queue))

		destroyVkSwapChain()
		initVkSwapChain()

		g_vulkan_context.swapchain.current_frame = 0
		g_vulkan_context.swapchain.needs_rebuild = false
	}

	current_frame :=
		g_vulkan_context.swapchain.frame_data[g_vulkan_context.swapchain.current_frame]

	// Wait until GPU has finished processing the frame that was using these resources previously
	vkCheck(
		vk.WaitForFences(
			g_vulkan_context.logic_device.handle,
			1,
			&current_frame.render_finished_fence,
			true,
			max(u64),
		),
	)

	vkCheck(
		vk.ResetFences(
			g_vulkan_context.logic_device.handle,
			1,
			&current_frame.render_finished_fence,
		),
	)

	// Reset the command pool to reuse the command buffer for recording
	vkCheck(vk.ResetCommandPool(g_vulkan_context.logic_device.handle, current_frame.cmd_pool, {}))

	cmd := current_frame.cmd_buffer

	begin_info := vk.CommandBufferBeginInfo {
		sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}

	vkCheck(vk.BeginCommandBuffer(cmd, &begin_info))

	next_img := vk.AcquireNextImageKHR(
		g_vulkan_context.logic_device.handle,
		g_vulkan_context.swapchain.handle,
		max(u64),
		current_frame.img_available_semaphore,
		0,
		&g_vulkan_context.swapchain.next_img_idx,
	)

	if next_img == vk.Result.ERROR_OUT_OF_DATE_KHR {
		g_vulkan_context.swapchain.needs_rebuild = true
	} else if next_img == vk.Result.SUBOPTIMAL_KHR {
		g_vulkan_context.swapchain.needs_rebuild = true
	}

	current_img := g_vulkan_context.swapchain.images[g_vulkan_context.swapchain.current_frame]
	current_depth_img :=
		g_vulkan_context.swapchain.depth_images[g_vulkan_context.swapchain.current_frame]

	vkTransitionImage(
		cmd,
		current_img.handle,
		vk.ImageLayout.UNDEFINED,
		vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
	)

	vkTransitionImage(
		cmd,
		current_depth_img.handle,
		vk.ImageLayout.UNDEFINED,
		vk.ImageLayout.DEPTH_ATTACHMENT_OPTIMAL,
	)

	color_attachment := [?]vk.RenderingAttachmentInfo {
		{
			sType = vk.StructureType.RENDERING_ATTACHMENT_INFO,
			imageView = current_img.view,
			imageLayout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
			loadOp = vk.AttachmentLoadOp.CLEAR,
			storeOp = vk.AttachmentStoreOp.STORE,
			clearValue = vk.ClearValue {
				color = vk.ClearColorValue{float32 = g_vulkan_context.background_color},
			},
		},
	}

	depth_attachment := vk.RenderingAttachmentInfo {
		sType = .RENDERING_ATTACHMENT_INFO,
		imageView = current_depth_img.view,
		imageLayout = .DEPTH_ATTACHMENT_OPTIMAL,
		loadOp = .CLEAR,
		storeOp = .STORE,
		clearValue = {depthStencil = {depth = 0}},
	}

	rendering_info := vk.RenderingInfo {
		sType = vk.StructureType.RENDERING_INFO_KHR,
		renderArea = vk.Rect2D {
			offset = vk.Offset2D{x = 0, y = 0},
			extent = vk.Extent2D {
				width = u32(w_ctx.g_window_context.width),
				height = u32(w_ctx.g_window_context.height),
			},
		},
		layerCount = 1,
		colorAttachmentCount = len(color_attachment),
		pColorAttachments = raw_data(&color_attachment),
		pDepthAttachment = &depth_attachment,
	}

	vk.CmdBeginRendering(cmd, &rendering_info)
}

endVkRendering :: proc() {
	current_frame :=
		g_vulkan_context.swapchain.frame_data[g_vulkan_context.swapchain.current_frame]
	cmd := current_frame.cmd_buffer
	current_img := g_vulkan_context.swapchain.images[g_vulkan_context.swapchain.current_frame]

	vk.CmdEndRendering(cmd)

	vkTransitionImage(
		cmd,
		current_img.handle,
		vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
		vk.ImageLayout.PRESENT_SRC_KHR,
	)

	vkCheck(vk.EndCommandBuffer(cmd))

	wait_semaphore := [?]vk.SemaphoreSubmitInfo {
		{
			sType = vk.StructureType.SEMAPHORE_SUBMIT_INFO,
			semaphore = current_frame.img_available_semaphore,
			stageMask = {.COLOR_ATTACHMENT_OUTPUT},
		},
	}

	signal_semaphore := [?]vk.SemaphoreSubmitInfo {
		{
			sType = vk.StructureType.SEMAPHORE_SUBMIT_INFO,
			semaphore = current_frame.render_finished_semaphore,
			stageMask = {.COLOR_ATTACHMENT_OUTPUT},
		},
	}

	cmd_buffer_info := [?]vk.CommandBufferSubmitInfo {
		{sType = vk.StructureType.COMMAND_BUFFER_SUBMIT_INFO, commandBuffer = cmd},
	}

	submit_info := [?]vk.SubmitInfo2 {
		{
			sType = vk.StructureType.SUBMIT_INFO_2,
			waitSemaphoreInfoCount = len(wait_semaphore),
			pWaitSemaphoreInfos = raw_data(&wait_semaphore),
			commandBufferInfoCount = len(cmd_buffer_info),
			pCommandBufferInfos = raw_data(&cmd_buffer_info),
			signalSemaphoreInfoCount = len(signal_semaphore),
			pSignalSemaphoreInfos = raw_data(&signal_semaphore),
		},
	}

	// Submit the command buffer to the GPU and signal when it's done
	vkCheck(
		vk.QueueSubmit2(
			g_vulkan_context.logic_device.graphics_queue.queue,
			len(submit_info),
			raw_data(&submit_info),
			current_frame.render_finished_fence,
		),
	)

	present_info := vk.PresentInfoKHR {
		sType              = vk.StructureType.PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &current_frame.render_finished_semaphore,
		swapchainCount     = 1,
		pSwapchains        = &g_vulkan_context.swapchain.handle,
		pImageIndices      = &g_vulkan_context.swapchain.next_img_idx,
	}

	present_result := vk.QueuePresentKHR(
		g_vulkan_context.logic_device.graphics_queue.queue,
		&present_info,
	)

	if present_result == .ERROR_OUT_OF_DATE_KHR {
		g_vulkan_context.swapchain.needs_rebuild = true
	} else {
		assert(present_result == .SUCCESS || present_result == .SUBOPTIMAL_KHR)
	}

	g_vulkan_context.swapchain.current_frame =
		(g_vulkan_context.swapchain.current_frame + 1) %
		g_vulkan_context.swapchain.max_frames_inflight
}
