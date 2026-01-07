package vulkan_context

import vk "vendor:vulkan"

VkDescriptor :: struct {
	pool:       vk.DescriptorPool,
	set_layout: vk.DescriptorSetLayout,
	set:        vk.DescriptorSet,
}

initVkDescriptor :: proc(
	descriptor: ^VkDescriptor,
	max_descriptor_set: u32,
	pool_size: []vk.DescriptorPoolSize,
	layout_binding: []vk.DescriptorSetLayoutBinding,
) {
	pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		flags         = {
			.UPDATE_AFTER_BIND, //  allows descriptor sets to be updated after they have been bound to a command buffer
			.FREE_DESCRIPTOR_SET, // individual descriptor sets can be freed from the descriptor pool
		},
		maxSets       = max_descriptor_set,
		poolSizeCount = u32(len(pool_size)),
		pPoolSizes    = raw_data(pool_size),
	}

	vkCheck(
		vk.CreateDescriptorPool(
			g_vulkan_context.logic_device.handle,
			&pool_info,
			g_vulkan_context.vk_allocator,
			&descriptor.pool,
		),
	)

	layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		flags        = {
			.UPDATE_AFTER_BIND_POOL, // Allows to update the descriptor set after it has been bound
		},
		bindingCount = u32(len(layout_binding)),
		pBindings    = raw_data(layout_binding),
	}

	vkCheck(
		vk.CreateDescriptorSetLayout(
			g_vulkan_context.logic_device.handle,
			&layout_info,
			g_vulkan_context.vk_allocator,
			&descriptor.set_layout,
		),
	)

	set_layouts := []vk.DescriptorSetLayout{descriptor.set_layout}

	set_alloc_info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = descriptor.pool,
		descriptorSetCount = u32(len(set_layouts)),
		pSetLayouts        = raw_data(set_layouts),
	}

	vkCheck(
		vk.AllocateDescriptorSets(
			g_vulkan_context.logic_device.handle,
			&set_alloc_info,
			&descriptor.set,
		),
	)
}

destroyVkDescriptor :: proc(descriptor: ^VkDescriptor) {
	vk.DestroyDescriptorSetLayout(
		g_vulkan_context.logic_device.handle,
		descriptor.set_layout,
		g_vulkan_context.vk_allocator,
	)

	vk.DestroyDescriptorPool(
		g_vulkan_context.logic_device.handle,
		descriptor.pool,
		g_vulkan_context.vk_allocator,
	)
}
