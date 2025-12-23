package vulkan_context

import "../types"
import "core:log"
import vk "vendor:vulkan"

VkPipelineStageAccess :: struct {
	stage:  vk.PipelineStageFlags2,
	access: vk.AccessFlags2,
}

VkPipelineBlending :: enum {
	none,
	additive,
	alpha_blend,
}

VkPipeline :: struct {
	handle: vk.Pipeline,
	layout: vk.PipelineLayout,
}

initPipeline :: proc(
	pipeline: ^VkPipeline,
	shader_stages: VkShaderStages,
	push_constants_range: []vk.PushConstantRange = nil,
	descriptors_set_layout: []vk.DescriptorSetLayout = nil,
	attribute_descriptions: []vk.VertexInputAttributeDescription = nil,
	wireframe: bool = false,
	blending: VkPipelineBlending = .none,
	depth_write: b32 = true,
) {
	log.infof("Vulkan: init pipeline")

	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
	}

	if push_constants_range != nil {
		layout_info.pushConstantRangeCount = u32(len(push_constants_range))
		layout_info.pPushConstantRanges = raw_data(push_constants_range)
	}

	if descriptors_set_layout != nil {
		layout_info.setLayoutCount = u32(len(descriptors_set_layout))
		layout_info.pSetLayouts = raw_data(descriptors_set_layout)
	}

	vkCheck(
		vk.CreatePipelineLayout(
			g_vulkan_context.logic_device.handle,
			&layout_info,
			g_vulkan_context.vk_allocator,
			&pipeline.layout,
		),
	)

	binding_description := vk.VertexInputBindingDescription {
		binding   = 0,
		stride    = size_of(types.Vertex),
		inputRate = .VERTEX,
	}

	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType                         = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 1,
		pVertexBindingDescriptions    = &binding_description,
	}

	if attribute_descriptions != nil {
		vertex_input.vertexAttributeDescriptionCount = u32(len(attribute_descriptions))
		vertex_input.pVertexAttributeDescriptions = raw_data(attribute_descriptions)
	}

	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology               = .TRIANGLE_LIST,
		primitiveRestartEnable = false,
	}

	raster := vk.PipelineRasterizationStateCreateInfo {
		sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable        = false,
		rasterizerDiscardEnable = false,
		polygonMode             = wireframe ? .LINE : .FILL,
		depthBiasEnable         = false,
		lineWidth               = 1.0,
	}

	dynamic_states := []vk.DynamicState {
		vk.DynamicState.VIEWPORT,
		vk.DynamicState.SCISSOR,
		vk.DynamicState.CULL_MODE,
		vk.DynamicState.FRONT_FACE,
		vk.DynamicState.PRIMITIVE_TOPOLOGY,
	}

	blend_attachment: [dynamic]vk.PipelineColorBlendAttachmentState
	defer delete(blend_attachment)

	switch blending {
	case .none:
		append(
			&blend_attachment,
			vk.PipelineColorBlendAttachmentState{colorWriteMask = {.R, .G, .B, .A}},
		)
	case .additive:
		append(
			&blend_attachment,
			vk.PipelineColorBlendAttachmentState {
				colorWriteMask = {.R, .G, .B, .A},
				blendEnable = true,
				srcColorBlendFactor = .SRC_ALPHA,
				dstColorBlendFactor = .ONE,
				colorBlendOp = .ADD,
				srcAlphaBlendFactor = .ONE,
				dstAlphaBlendFactor = .ZERO,
				alphaBlendOp = .ADD,
			},
		)
	case .alpha_blend:
		append(
			&blend_attachment,
			vk.PipelineColorBlendAttachmentState {
				colorWriteMask = {.R, .G, .B, .A},
				blendEnable = true,
				srcColorBlendFactor = .SRC_ALPHA,
				dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
				colorBlendOp = .ADD,
				srcAlphaBlendFactor = .ONE,
				dstAlphaBlendFactor = .ZERO,
				alphaBlendOp = .ADD,
			},
		)
	}

	blend := vk.PipelineColorBlendStateCreateInfo {
		sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = u32(len(blend_attachment)),
		pAttachments    = raw_data(blend_attachment),
	}

	viewport := vk.PipelineViewportStateCreateInfo {
		sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount  = 1,
	}

	depth_stencil := vk.PipelineDepthStencilStateCreateInfo {
		sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		depthTestEnable       = true,
		depthWriteEnable      = depth_write,
		depthCompareOp        = .LESS,
		depthBoundsTestEnable = false,
		minDepthBounds        = 0,
		maxDepthBounds        = 1,
		stencilTestEnable     = false,
		front                 = {},
		back                  = {},
	}

	// No multisampling.
	multisample := vk.PipelineMultisampleStateCreateInfo {
		sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		rasterizationSamples = {._1},
	}

	dynamic_state_info := vk.PipelineDynamicStateCreateInfo {
		sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates    = raw_data(dynamic_states),
	}

	pipeline_rendering_info := vk.PipelineRenderingCreateInfo {
		sType                   = .PIPELINE_RENDERING_CREATE_INFO,
		colorAttachmentCount    = 1,
		pColorAttachmentFormats = &g_vulkan_context.swapchain.image_format,
		depthAttachmentFormat   = g_vulkan_context.swapchain.depth_images[0].format,
	}

	pipeline_info := vk.GraphicsPipelineCreateInfo {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = &pipeline_rendering_info,
		stageCount          = u32(len(shader_stages.stage_infos)),
		pStages             = raw_data(shader_stages.stage_infos),
		pVertexInputState   = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState      = &viewport,
		pRasterizationState = &raster,
		pMultisampleState   = &multisample,
		pDepthStencilState  = &depth_stencil,
		pColorBlendState    = &blend,
		pDynamicState       = &dynamic_state_info,
		layout              = pipeline.layout, // We need to specify the pipeline layout description up front as well.
		renderPass          = 0, // Since we are using dynamic rendering this will set as null
		subpass             = 0,
	}

	vkCheck(
		vk.CreateGraphicsPipelines(
			g_vulkan_context.logic_device.handle,
			0,
			1,
			&pipeline_info,
			g_vulkan_context.vk_allocator,
			&pipeline.handle,
		),
	)
}

destroyVkPipeline :: proc(pipeline: ^VkPipeline) {
	log.infof("Vulkan: destroy pipeline")

	vk.DestroyPipeline(
		g_vulkan_context.logic_device.handle,
		pipeline.handle,
		g_vulkan_context.vk_allocator,
	)

	vk.DestroyPipelineLayout(
		g_vulkan_context.logic_device.handle,
		pipeline.layout,
		g_vulkan_context.vk_allocator,
	)
}
