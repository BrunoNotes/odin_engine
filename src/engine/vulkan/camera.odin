package vulkan_context

import "core:math/linalg"
import vk "vendor:vulkan"

VkScene :: struct {
	uniform: kkSceneUniform,
	buffer:  VkBuffer,
}

kkSceneUniform :: struct {
	projection:         linalg.Matrix4f32,
	view:               linalg.Matrix4f32,
	ambient_color:      linalg.Vector4f32,
	sunlight_direction: linalg.Vector4f32,
	sunlight_color:     linalg.Vector4f32,
}

initVkScene :: proc(camera: ^VkScene) {
	initVkBuffer(
		&camera.buffer,
		vk.DeviceSize(size_of(camera.uniform)),
		{.UNIFORM_BUFFER, .TRANSFER_DST},
		{.DEVICE_LOCAL},
	)
}

destroyVkScene :: proc(camera: ^VkScene) {
	destroyVkBuffer(&camera.buffer)
}
