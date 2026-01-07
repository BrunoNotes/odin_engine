package vulkan_context

import vk "vendor:vulkan"

vkDrawScene :: proc(scene: ^VkScene) {
	{
		size := scene.buffer.info.size
		staging_buffer := vkInitStagingBuffer(size)
		defer destroyVkBuffer(&staging_buffer)

		vkMapBufferMemory(&staging_buffer, &scene.uniform, size)

		copyVkBuffer(staging_buffer.handle, scene.buffer.handle, 0, 0, size)
	}

	scene_buffer_info := vk.DescriptorBufferInfo {
		buffer = scene.buffer.handle,
		offset = 0,
		range  = size_of(scene.uniform),
	}

	scene_descriptor_write := []vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = scene.descriptor.set,
			dstBinding = 0,
			dstArrayElement = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &scene_buffer_info,
		},
	}

	vk.UpdateDescriptorSets(
		g_vulkan_context.logic_device.handle,
		u32(len(scene_descriptor_write)),
		raw_data(scene_descriptor_write),
		0,
		{},
	)
}

vkDrawGeometry :: proc(geometry: VkGeometry, scene: ^VkScene) {
	current_frame := vkGetCurrentFrame()
	cmd := current_frame.cmd_buffer

	for id in geometry.render_objects {
		render_object := g_render_objects[id]

		vk.CmdBindPipeline(cmd, .GRAPHICS, render_object.pipeline.handle)

		texture_buffer_info := vk.DescriptorBufferInfo {
			buffer = render_object.texture.buffer.handle,
			offset = 0,
			range  = size_of(render_object.texture.uniform),
		}

		img_info := vk.DescriptorImageInfo {
			imageLayout = .READ_ONLY_OPTIMAL,
			imageView   = render_object.texture.texture_image.image.view,
			sampler     = render_object.texture.texture_image.sampler,
		}

		descriptor_write := []vk.WriteDescriptorSet {
			{
				sType = .WRITE_DESCRIPTOR_SET,
				dstSet = render_object.texture.descriptor.set,
				dstBinding = 0,
				dstArrayElement = 0,
				descriptorType = .UNIFORM_BUFFER,
				descriptorCount = 1,
				pBufferInfo = &texture_buffer_info,
			},
			{
				sType           = .WRITE_DESCRIPTOR_SET,
				dstSet          = render_object.texture.descriptor.set,
				// dstBinding      = model.texture.texture_images[current_image_name].descriptor_binding,
				dstBinding      = 1,
				descriptorType  = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				pImageInfo      = &img_info,
			},
		}

		vk.UpdateDescriptorSets(
			g_vulkan_context.logic_device.handle,
			u32(len(descriptor_write)),
			raw_data(descriptor_write),
			0,
			{},
		)

		descriptors_sets := []vk.DescriptorSet {
			scene.descriptor.set,
			render_object.texture.descriptor.set,
		}
		vk.CmdBindDescriptorSets(
			cmd,
			.GRAPHICS,
			render_object.pipeline.layout,
			0,
			u32(len(descriptors_sets)),
			raw_data(descriptors_sets),
			0,
			{},
		)

		offset: vk.DeviceSize = 0
		vk.CmdBindVertexBuffers(cmd, 0, 1, &render_object.vertex_buffer.handle, &offset)
		vk.CmdBindIndexBuffer(cmd, render_object.index_buffer.handle, offset, .UINT32)

		push_constant := VkGeometryPushConstant {
			transform_matrix = geometry.transform_matrix,
		}
		vk.CmdPushConstants(
			cmd,
			render_object.pipeline.layout,
			{.VERTEX},
			0,
			size_of(type_of(push_constant)),
			&push_constant,
		)

		vk.CmdDrawIndexed(cmd, render_object.index_count, 1, 0, 0, 0)
	}
}
