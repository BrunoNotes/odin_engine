package vulkan_context

import "../types"
import w_ctx "../window"
import "core:log"
import "core:math/linalg"
import vk "vendor:vulkan"

VkMesh :: struct {
	// shaders:           []VkShaderStageType,
	shader_stages:     VkShaderStages,
	vertex_descriptor: VkDescriptor,
	vertex_buffer:     VkBuffer,
	index_buffer:      VkBuffer,
	index_count:       u32,
	push_constant:     VkMeshPushConstant,
	texture:           VkTexture,
	pipeline:          VkPipeline,
	// camera:            VkCamera,
	loaded:            bool,
}

VkMeshPushConstant :: struct {
	model_matrix: linalg.Matrix4f32,
}

initVkMesh :: proc(mesh: ^VkMesh, shaders: []VkShaderStageType, allocator := context.allocator) {
	defer mesh.loaded = true

	initVkShaderStage(&mesh.shader_stages, shaders, allocator)

	push_constant_range := []vk.PushConstantRange {
		vk.PushConstantRange {
			stageFlags = {.VERTEX},
			offset = size_of(linalg.Matrix4f32) * 0,
			size = size_of(linalg.Matrix4f32) * 2,
		},
	}

	vertex_descriptor_pool_size := []vk.DescriptorPoolSize {
		vk.DescriptorPoolSize {
			type = .UNIFORM_BUFFER,
			descriptorCount = u32(len(g_vulkan_context.swapchain.images)),
		},
	}

	vertex_descriptor_layout_binding := []vk.DescriptorSetLayoutBinding {
		vk.DescriptorSetLayoutBinding {
			binding = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			stageFlags = {.VERTEX},
		},
	}

	initVkDescriptor(
		&mesh.vertex_descriptor,
		u32(len(g_vulkan_context.swapchain.images)),
		vertex_descriptor_pool_size,
		vertex_descriptor_layout_binding,
	)

	initVkTexture(&mesh.texture, allocator)

	descritor_set_layouts := []vk.DescriptorSetLayout {
		mesh.vertex_descriptor.set_layout,
		mesh.texture.descriptor.set_layout,
	}

	attribute_descriptions := []vk.VertexInputAttributeDescription {
		{
			location = 0,
			binding = 0,
			format = .R32G32B32_SFLOAT,
			offset = u32(offset_of(types.Vertex, position)),
		},
		{
			location = 1,
			binding = 0,
			format = .R32G32_SFLOAT,
			offset = u32(offset_of(types.Vertex, uv)),
		},
		{
			location = 2,
			binding = 0,
			format = .R32G32B32A32_SFLOAT,
			offset = u32(offset_of(types.Vertex, color)),
		},
		{
			location = 3,
			binding = 0,
			format = .R32G32B32_SFLOAT,
			offset = u32(offset_of(types.Vertex, normal)),
		},
	}

	initPipeline(
		&mesh.pipeline,
		mesh.shader_stages,
		push_constant_range,
		descritor_set_layouts,
		attribute_descriptions,
	)
}

destroyVkMesh :: proc(mesh: ^VkMesh) {
	log.infof("Vulkan: destroy mesh")
	vkCheck(vk.QueueWaitIdle(g_vulkan_context.logic_device.graphics_queue.queue))

	destroyVkBuffer(&mesh.index_buffer)
	destroyVkBuffer(&mesh.vertex_buffer)
	destroyVkPipeline(&mesh.pipeline)
	destroyVkTexture(&mesh.texture)
	destroyVkDescriptor(&mesh.vertex_descriptor)
	destroyVkShaderStage(mesh.shader_stages)

	mesh.loaded = false
}

renderVkMesh :: proc(mesh: ^VkMesh, camera: ^VkCamera) {
	current_frame :=
		g_vulkan_context.swapchain.frame_data[g_vulkan_context.swapchain.current_frame]
	cmd := current_frame.cmd_buffer
	// cmd_pool := current_frame.cmd_pool

	viewport := vk.Viewport {
		x        = 0.0,
		y        = f32(w_ctx.getWindowSize().y),
		width    = f32(w_ctx.getWindowSize().x),
		height   = -f32(w_ctx.getWindowSize().y),
		minDepth = 0.0,
		maxDepth = 1.0,
	}

	vk.CmdSetViewport(cmd, 0, 1, &viewport)

	scissor := vk.Rect2D {
		extent = vk.Extent2D {
			width = u32(w_ctx.getWindowSize().x),
			height = u32(w_ctx.getWindowSize().y),
		},
	}

	vk.CmdSetScissor(cmd, 0, 1, &scissor)

	vk.CmdSetCullMode(cmd, {.FRONT})
	vk.CmdSetFrontFace(cmd, .CLOCKWISE)
	vk.CmdSetPrimitiveTopology(cmd, .TRIANGLE_LIST)

	vk.CmdBindPipeline(cmd, .GRAPHICS, mesh.pipeline.handle)

	{
		size := camera.buffer.info.size
		staging_buffer := vkInitStagingBuffer(size)
		defer destroyVkBuffer(&staging_buffer)

		vkMapBufferMemory(&staging_buffer, &camera.uniform, size)

		copyVkBuffer(staging_buffer.handle, camera.buffer.handle, 0, 0, size)
	}

	{
		// TODO: check if this needs to be updated every frame
		size := mesh.texture.buffer.info.size
		staging_buffer := vkInitStagingBuffer(size)
		defer destroyVkBuffer(&staging_buffer)

		vkMapBufferMemory(&staging_buffer, &mesh.texture.uniform, size)

		copyVkBuffer(staging_buffer.handle, mesh.texture.buffer.handle, 0, 0, size)
	}

	vertex_buffer_info := vk.DescriptorBufferInfo {
		buffer = camera.buffer.handle,
		offset = 0,
		range  = size_of(camera.uniform),
	}

	texture_buffer_info := vk.DescriptorBufferInfo {
		buffer = mesh.texture.buffer.handle,
		offset = 0,
		range  = size_of(mesh.texture.uniform),
	}

	if len(mesh.texture.current_image) <= 0 {
		for key, _ in mesh.texture.texture_images {
			mesh.texture.current_image = key
			break
		}
	}

	img_info := vk.DescriptorImageInfo {
		imageLayout = .READ_ONLY_OPTIMAL,
		imageView   = mesh.texture.texture_images[mesh.texture.current_image].image.view,
		sampler     = mesh.texture.texture_images[mesh.texture.current_image].sampler,
	}

	descriptor_write := []vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = mesh.vertex_descriptor.set,
			dstBinding = 0,
			dstArrayElement = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &vertex_buffer_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = mesh.texture.descriptor.set,
			dstBinding = 0,
			dstArrayElement = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &texture_buffer_info,
		},
		{
			sType           = .WRITE_DESCRIPTOR_SET,
			dstSet          = mesh.texture.descriptor.set,
			// dstBinding      = model.texture.texture_images[current_image_name].descriptor_binding,
			dstBinding      = 1,
			descriptorType  = .COMBINED_IMAGE_SAMPLER,
			descriptorCount = 1,
			pImageInfo      = &img_info,
		},
	}

	descriptors_sets := []vk.DescriptorSet{mesh.vertex_descriptor.set, mesh.texture.descriptor.set}

	vk.UpdateDescriptorSets(
		g_vulkan_context.logic_device.handle,
		u32(len(descriptor_write)),
		raw_data(descriptor_write),
		0,
		{},
	)

	vk.CmdBindDescriptorSets(
		cmd,
		.GRAPHICS,
		mesh.pipeline.layout,
		0,
		u32(len(descriptors_sets)),
		raw_data(descriptors_sets),
		0,
		{},
	)

	offset: vk.DeviceSize = 0
	vk.CmdBindVertexBuffers(cmd, 0, 1, &mesh.vertex_buffer.handle, &offset)
	vk.CmdBindIndexBuffer(cmd, mesh.index_buffer.handle, offset, .UINT32)

	vk.CmdPushConstants(
		cmd,
		mesh.pipeline.layout,
		{.VERTEX},
		0,
		size_of(type_of(mesh.push_constant)),
		&mesh.push_constant,
	)

	vk.CmdDrawIndexed(cmd, mesh.index_count, 1, 0, 0, 0)
	// vk.CmdDraw(cmd, u32(len(model.vertices)), 1, 0, 0)
}
