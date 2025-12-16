package vulkan_context

import vk "vendor:vulkan"

VkPipelineStageAccess :: struct {
	stage:  vk.PipelineStageFlags2,
	access: vk.AccessFlags2,
}
