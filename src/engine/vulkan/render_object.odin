package vulkan_context

import "../types"
import "../utils"
import "core:encoding/uuid"
import "core:math/linalg"
import vk "vendor:vulkan"

g_render_objects: map[string]VkRenderObject

VkRenderObject :: struct {
	id:            uuid.Identifier,
	index_count:   u32,
	vertex_buffer: VkBuffer,
	index_buffer:  VkBuffer,
	texture:       VkTexture,
	pipeline:      VkPipeline,
}

initVkRenderObjectsFromGltfFile :: proc(
	file_path: string,
	scene: VkScene,
	allocator := context.allocator,
) -> []VkGeometry {
	gltf := utils.loadGltf(file_path)
	defer utils.destroyGltf(gltf)

	return initVkRenderObjectsFromGltf(gltf, scene, allocator)
}

initVkRenderObjectsFromGltf :: proc(
	gltf: utils.GltfData,
	vk_scene: VkScene,
	allocator := context.allocator,
) -> []VkGeometry {
	tmp_geometries := make([dynamic]VkGeometry, allocator)

	for scene in gltf.scenes {
		for node in scene.nodes {
			geometry := VkGeometry {
				name        = node.name,
				translation = node.translation,
				scale       = node.scale,
				rotation    = node.rotation,
			}

			tmp_render_objects_ids := make([dynamic]string, allocator)

			for mesh in node.meshes {
				for prim in mesh.primitives {
					render_object: VkRenderObject
					render_object.id = uuid.generate_v7()

					append(&tmp_render_objects_ids, uuid.to_string(render_object.id))

					render_object.vertex_buffer = allocateVkBuffer(
						vk.DeviceSize(size_of(types.Vertex) * len(prim.vertices)),
						raw_data(prim.vertices[:]),
						{.VERTEX_BUFFER, .TRANSFER_DST, .TRANSFER_SRC},
					)

					render_object.index_buffer = allocateVkBuffer(
						vk.DeviceSize(size_of(u32) * len(prim.indices)),
						raw_data(prim.indices[:]),
						{.INDEX_BUFFER, .TRANSFER_DST},
					)

					render_object.index_count = u32(len(prim.indices))

					texture_image: VkTextureImage
					diffuse_color: linalg.Vector4f32
					if prim.metallic_roughness.has_attribute {
						switch prim.metallic_roughness.base_color_texture.type {
						case .file:
							texture_image = createVkTextureImageFromImage(
								prim.metallic_roughness.base_color_texture.image_path,
							)
						case .byte:
							texture_image = createVkTextureImageFromImage(
								prim.metallic_roughness.base_color_texture.byte,
							)
						}

						diffuse_color = prim.metallic_roughness.base_color
					} else {
						initVkTextureImage(&texture_image, type = .blank)
						diffuse_color = 1
					}

					render_object.texture = initVkTexture(
						texture_image,
						VkTextureUniform{diffuse_color = diffuse_color},
					)

					initVkMeshRenderObjectPipeline(&render_object, vk_scene, allocator)

					g_render_objects[uuid.to_string(render_object.id)] = render_object
				}
			}

			geometry.render_objects = tmp_render_objects_ids[:]

			if len(geometry.render_objects) > 0 {
				append(&tmp_geometries, geometry)
			}
		}
	}

	return tmp_geometries[:]
}

destroyVkRenderObject :: proc(render_object: ^VkRenderObject) {
	vkCheck(vk.QueueWaitIdle(g_vulkan_context.logic_device.graphics_queue.queue))

	destroyVkBuffer(&render_object.index_buffer)
	destroyVkBuffer(&render_object.vertex_buffer)
	destroyVkTexture(&render_object.texture)
	destroyVkPipeline(&render_object.pipeline)
}
