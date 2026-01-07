package vulkan_context

import "core:math/linalg"
import vk "vendor:vulkan"

VkScene :: struct {
	uniform:    VkSceneUniform,
	buffer:     VkBuffer,
	descriptor: VkDescriptor,
}

VkSceneUniform :: struct {
	projection:         linalg.Matrix4f32,
	view:               linalg.Matrix4f32,
	ambient_color:      linalg.Vector4f32,
	sunlight_direction: linalg.Vector4f32,
	sunlight_color:     linalg.Vector4f32,
}

initVkScene :: proc(scene: ^VkScene) {
	descriptor_pool_size := []vk.DescriptorPoolSize {
		vk.DescriptorPoolSize {
			type = .UNIFORM_BUFFER,
			descriptorCount = u32(len(g_vulkan_context.swapchain.images)),
		},
	}

	descriptor_layout_binding := []vk.DescriptorSetLayoutBinding {
		vk.DescriptorSetLayoutBinding {
			binding = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			stageFlags = {.VERTEX},
		},
	}

	initVkDescriptor(
		&scene.descriptor,
		u32(len(g_vulkan_context.swapchain.images)),
		descriptor_pool_size,
		descriptor_layout_binding,
	)

	initVkBuffer(
		&scene.buffer,
		vk.DeviceSize(size_of(scene.uniform)),
		{.UNIFORM_BUFFER, .TRANSFER_DST},
		{.DEVICE_LOCAL},
	)

	// scene.buffer = allocateVkBuffer(
	// 	vk.DeviceSize(size_of(scene.uniform)),
	// 	&scene.uniform,
	// 	{.UNIFORM_BUFFER, .TRANSFER_DST},
	// )
}

destroyVkScene :: proc(scene: ^VkScene) {
	destroyVkDescriptor(&scene.descriptor)
	destroyVkBuffer(&scene.buffer)
}
