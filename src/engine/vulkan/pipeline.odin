package vulkan_context

import "../types"
import "core:math/linalg"
import vk "vendor:vulkan"

@(private = "file")
vertex_shader := #load("../../../shaders/bin/mesh.vert.spv")
@(private = "file")
fragment_shader := #load("../../../shaders/bin/mesh.frag.spv")

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
	push_constants_range: []vk.PushConstantRange = {},
	descriptors_set_layout: []vk.DescriptorSetLayout = {},
	attribute_descriptions: []vk.VertexInputAttributeDescription = {},
	wireframe: bool = false,
	blending: VkPipelineBlending = .none,
	depth_write: b32 = true,
) {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
	}

	if len(push_constants_range) > 0 {
		layout_info.pushConstantRangeCount = u32(len(push_constants_range))
		layout_info.pPushConstantRanges = raw_data(push_constants_range)
	}

	if len(descriptors_set_layout) > 0 {
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

	if len(attribute_descriptions) > 0 {
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

initVkMeshRenderObjectPipeline :: proc(
	render_object: ^VkRenderObject,
	scene: VkScene,
	allocator := context.allocator,
) {
	shaders := []VkShaderStageType {
		{shader = vertex_shader, stage = .VERTEX},
		{shader = fragment_shader, stage = .FRAGMENT},
	}

	shader_stages: VkShaderStages
	initVkShaderStage(&shader_stages, shaders, allocator)
	defer destroyVkShaderStage(shader_stages)

	push_constant_range := []vk.PushConstantRange {
		vk.PushConstantRange {
			stageFlags = {.VERTEX},
			offset = size_of(linalg.Matrix4f32) * 0,
			size = size_of(linalg.Matrix4f32) * 2,
		},
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

	descriptors_set_layouts := []vk.DescriptorSetLayout {
		scene.descriptor.set_layout,
		render_object.texture.descriptor.set_layout,
	}

	initPipeline(
		&render_object.pipeline,
		shader_stages,
		push_constant_range,
		descriptors_set_layouts[:],
		attribute_descriptions,
		// wireframe = true,
	)
}
