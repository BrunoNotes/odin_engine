package vulkan_context

import "core:math/linalg"
import vk "vendor:vulkan"

VkCamera :: struct {
	uniform: VkCameraUniform,
	buffer:  VkBuffer,
}

VkCameraUniform :: struct {
	projection: linalg.Matrix4f32,
	view:       linalg.Matrix4f32,
}

initVkCamera :: proc(camera: ^VkCamera) {
	initVkBuffer(
		&camera.buffer,
		vk.DeviceSize(size_of(camera.uniform)),
		{.UNIFORM_BUFFER, .TRANSFER_DST},
		{.DEVICE_LOCAL},
	)
}
destroyVkCamera :: proc(camera: ^VkCamera) {
	destroyVkBuffer(&camera.buffer)
}
