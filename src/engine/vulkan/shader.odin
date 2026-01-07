package vulkan_context

import "core:slice"
import vk "vendor:vulkan"

VkShaderStages :: struct {
	modules:      []vk.ShaderModule,
	stage_infos:  []vk.PipelineShaderStageCreateInfo,
	module_infos: []vk.ShaderModuleCreateInfo,
}

VkShaderStageType :: struct {
	shader: []byte,
	stage:  vk.ShaderStageFlag,
}

initVkShaderStage :: proc(
	shader_stages: ^VkShaderStages,
	shader_stage_type: []VkShaderStageType,
	allocator := context.allocator,
) {
	shader_stages.modules = make([]vk.ShaderModule, len(shader_stage_type), allocator)
	shader_stages.stage_infos = make(
		[]vk.PipelineShaderStageCreateInfo,
		len(shader_stage_type),
		allocator,
	)
	shader_stages.module_infos = make(
		[]vk.ShaderModuleCreateInfo,
		len(shader_stage_type),
		allocator,
	)

	for stage, idx in shader_stage_type {
		byte_u32 := slice.reinterpret([]u32, stage.shader)

		module_info := vk.ShaderModuleCreateInfo {
			sType    = .SHADER_MODULE_CREATE_INFO,
			codeSize = len(stage.shader),
			pCode    = raw_data(byte_u32),
		}

		module: vk.ShaderModule
		vkCheck(
			vk.CreateShaderModule(
				g_vulkan_context.logic_device.handle,
				&module_info,
				g_vulkan_context.vk_allocator,
				&module,
			),
		)

		stage_info := vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {stage.stage},
			module = module,
			pName  = "main",
		}

		shader_stages.modules[idx] = module
		shader_stages.module_infos[idx] = module_info
		shader_stages.stage_infos[idx] = stage_info
	}
}

destroyVkShaderStage :: proc(shader_stages: VkShaderStages) {
	for module in shader_stages.modules {
		vk.DestroyShaderModule(
			g_vulkan_context.logic_device.handle,
			module,
			g_vulkan_context.vk_allocator,
		)
	}
}
