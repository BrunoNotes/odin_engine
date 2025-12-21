package main

import "../vendor/clay"
import eng_ctx "./engine"
import "./engine/base"
import "./engine/types"
import "./engine/ui"
import "./engine/vulkan"
import w_ctx "./engine/window"
import "core:crypto"
import "core:log"
import "core:mem"

main :: proc() {
	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator() // for uuid

	when ODIN_DEBUG {
		tracking_allocator := base.initTrackingAllocator(context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}

	eng_ctx.initEngine()
	defer eng_ctx.destroyEngine()

	// cornflower blue
	vulkan.g_vulkan_context.background_color = {0.392, 0.584, 0.929, 1.0}


	// needs to be created before the mesh
	vk_camera: vulkan.VkCamera
	vulkan.initVkCamera(&vk_camera)
	defer vulkan.destroyVkCamera(&vk_camera)

	vk_render_objects := vulkan.initVkRenderObjectsFromGltfFile(
		// "assets/models/BoxTextured.glb",
        // "/home/bruno/tmp/glTF-Sample-Models/2.0/Sponza/glTF/Sponza.gltf",
        // "/home/bruno/tmp/glTF-Sample-Models/2.0/Lantern/glTF-Binary/Lantern.glb",
        "/home/bruno/tmp/glTF-Sample-Models/2.0/Suzanne/glTF/Suzanne.gltf",
		vk_camera,
	)
	defer vulkan.destroyVkRenderObjectsSlice(&vk_render_objects)

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
		for &render_object in vk_render_objects {
			{
				rotation, translation := eng_ctx.geometryController(
					render_object.geometry.rotation,
					render_object.geometry.translation,
					eng_ctx.deltaTime(),
				)
				render_object.geometry.rotation = rotation
				render_object.geometry.translation = translation
			}

			for &vk_geometry in render_object.vk_geometry {
				vk_geometry.push_constant.model_matrix = render_object.geometry.model_matrix
				types.updateGeometryProjection(&render_object.geometry)
				vulkan.renderVkGeometry(&vk_geometry, &vk_camera)
			}
		}

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
