package main

import "../vendor/clay"
import eng_ctx "./engine"
import "./engine/base"
import math_ctx "./engine/math"
import "./engine/types"
import "./engine/ui"
import "./engine/utils"
import "./engine/vulkan"
import w_ctx "./engine/window"
import "core:crypto"
import "core:encoding/uuid"
import "core:log"
import "core:mem"
import "core:os"
import vk "vendor:vulkan"

main :: proc() {
	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator() // for uuid

	when ODIN_DEBUG {
		tracking_allocator := base.initTrackingAllocator(context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}

	eng_ctx.initEngine()
	defer eng_ctx.destroyEngine()

	// ----- Mesh -----
	mesh: types.Mesh

	gltf, err := utils.loadGltf("assets/models/BoxTextured.glb")
	assert(err == nil)

	mesh.name = gltf.surfaces[0].name
	mesh.vertices = gltf.surfaces[0].vertices
	mesh.indices = gltf.surfaces[0].indices
	mesh.translation = gltf.surfaces[0].translation
	mesh.scale = gltf.surfaces[0].scale
	mesh.rotation = gltf.surfaces[0].rotation
	mesh.model_matrix = math_ctx.MAT4IDENTITY

	// fmt.printfln("%#v", mesh)

	// cornflower blue
	vulkan.g_vulkan_context.background_color = {0.392, 0.584, 0.929, 1.0}

	vertex_shader, _ := os.read_entire_file_from_filename(
		"shaders/bin/mesh.vert.spv",
		// context.temp_allocator,
	)

	fragment_shader, _ := os.read_entire_file_from_filename(
		"shaders/bin/mesh.frag.spv",
		// context.temp_allocator,
	)
	shaders := []vulkan.VkShaderStageType {
		{shader = vertex_shader, stage = .VERTEX},
		{shader = fragment_shader, stage = .FRAGMENT},
	}

	vk_mesh: vulkan.VkMesh

	vk_mesh.vertex_buffer = vulkan.allocateVkBuffer(
	vk.DeviceSize(size_of(types.Vertex) * len(mesh.vertices)),
	raw_data(mesh.vertices[:]),
	{.VERTEX_BUFFER, .TRANSFER_DST, .TRANSFER_SRC},
	// {.STORAGE_BUFFER, .TRANSFER_DST, .SHADER_DEVICE_ADDRESS},
	// get_device_address = true,
	)
	vk_mesh.index_buffer = vulkan.allocateVkBuffer(
		vk.DeviceSize(size_of(u32) * len(mesh.indices)),
		raw_data(mesh.indices[:]),
		{.INDEX_BUFFER, .TRANSFER_DST},
	)
	vk_mesh.index_count = u32(len(mesh.indices))

	if len(gltf.textures) > 0 {
		texture_image := vulkan.createVkTextureImageFromStbImage(gltf.textures[0])
		texture_id, _ := uuid.to_string(texture_image.id)
		vk_mesh.texture.texture_images[texture_id] = texture_image
	}

	// needs to be created before the mesh
	vk_camera: vulkan.VkCamera
	vulkan.initVkCamera(&vk_camera)
	defer vulkan.destroyVkCamera(&vk_camera)

	vk_mesh.pipeline.wireframe = false
	vk_mesh.pipeline.blending = .none
	vulkan.initVkMesh(&vk_mesh, shaders)
	defer vulkan.destroyVkMesh(&vk_mesh)

	// ----- Camera -----

	camera: types.Camera
	camera.fov = 70
	camera.translation = {0, 0, 2}
	camera.projection = .perspective

	// ----- UI -----
	clay_ctx := ui.ClayContext{}
	ui.clayInit(&clay_ctx, f32(w_ctx.getWindowSize().x), f32(w_ctx.getWindowSize().y))
	defer ui.destroyClay(&clay_ctx)

	// ----- Main loop -----

	for eng_ctx.running() {
		defer free_all(context.temp_allocator)


		// ----- Camera -----
		{
			// fly camera
			velocity, pitch, yaw := eng_ctx.flyCameraController(
				camera.translation,
				eng_ctx.deltaTime(),
			)
			camera.velocity = velocity
			if w_ctx.isMouseButtonPressed(.RIGHT) {
				w_ctx.setMouseMode(.Captured)
				camera.pitch = pitch
				camera.yaw = yaw
			} else {
				w_ctx.setMouseMode(.Normal)
			}
		}

		types.updateCameraProjection(
			&camera,
			f32(w_ctx.getWindowSize().x),
			f32(w_ctx.getWindowSize().y),
		)

		vk_camera.uniform.projection = camera.projection_matrix
		vk_camera.uniform.view = camera.view_matrix

		// ----- Mesh -----
		{
			rotation, translation := eng_ctx.meshController(
				mesh.rotation,
				mesh.translation,
				eng_ctx.deltaTime(),
			)
			mesh.rotation = rotation
			mesh.translation = translation
		}

		vk_mesh.push_constant.model_matrix = mesh.model_matrix
		types.updateMeshProjection(&mesh)

		// ---- Render -----
		vulkan.beginVkRendering()

		// ----- ui ------

		{
			mouse_position := w_ctx.getMousePosition()
			mouse_scroll := w_ctx.getMouseScroll()

			clay.SetLayoutDimensions(
				{width = w_ctx.getWindowSize().x, height = w_ctx.getWindowSize().y},
			)
			clay.SetPointerState(
				{mouse_position.x, mouse_position.y},
				w_ctx.isMouseButtonPressed(.LEFT),
			)
			clay.UpdateScrollContainers(
				true,
				{mouse_scroll.position.x, mouse_scroll.position.y},
				eng_ctx.deltaTime(),
			)

			clay.BeginLayout()

			if clay.UI(clay.ID("OuterContainer"))(
			{
				layout = {
					sizing = {clay.SizingGrow(), clay.SizingGrow()},
					padding = clay.PaddingAll(16),
					childGap = 16,
				},
				backgroundColor = {250, 250, 255, 255},
			},
			) {
			}
			clay_render_cmds := clay.EndLayout()

			ui.clayRender(&clay_ctx, &clay_render_cmds)
		}

		// ----- draw -----
		vulkan.renderVkMesh(&vk_mesh, &vk_camera)

		vulkan.endVkRendering()

		when ODIN_DEBUG {
			base.checkDoubleFreeTrackingAllocator(tracking_allocator)
			base.resetTrackingAllocator(&tracking_allocator)
		}
	}

	when ODIN_DEBUG {
		mem.tracking_allocator_destroy(&tracking_allocator)
		// checks for leaks before on exit
		base.resetTrackingAllocator(&tracking_allocator)
	}
}
