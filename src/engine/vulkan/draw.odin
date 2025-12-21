package vulkan_context

import "../types"
import "../utils"
import "core:encoding/uuid"
// import "core:encoding/uuid"
import vk "vendor:vulkan"

VkRenderObject :: struct {
	geometry:    types.Geometry,
	vk_geometry: []VkGeometry,
}

initVkRenderObjectsFromGltfFile :: proc(
	file_path: string,
	camera: VkCamera,
	allocator := context.allocator,
) -> []VkRenderObject {
	gltf := utils.loadGltf(file_path)
    defer utils.destroyGltf(gltf)

	return initVkRenderObjectsFromGltf(gltf, camera, allocator)
}

@(private = "file")
vertex_shader := #load("../../../shaders/bin/mesh.vert.spv")
@(private = "file")
fragment_shader := #load("../../../shaders/bin/mesh.frag.spv")

initVkRenderObjectsFromGltf :: proc(
	gltf: utils.GltfData,
	camera: VkCamera,
	allocator := context.allocator,
) -> []VkRenderObject {
	vk_render_objects := make([dynamic]VkRenderObject, allocator)

	// vertex_shader, _ := os.read_entire_file_from_filename("shaders/bin/mesh.vert.spv")
	// fragment_shader, _ := os.read_entire_file_from_filename("shaders/bin/mesh.frag.spv")
	shaders := []VkShaderStageType {
		{shader = vertex_shader, stage = .VERTEX},
		{shader = fragment_shader, stage = .FRAGMENT},
	}

	for scene in gltf.scenes {
		for node in scene.nodes {
			geometry := types.Geometry {
				name        = node.name,
				translation = node.translation,
				scale       = node.scale,
				rotation    = node.rotation,
			}

			for mesh in node.meshes {
				tmp_vk_geometries := make([dynamic]VkGeometry, allocator)

				for prim in mesh.primitives {
					vk_geometry: VkGeometry

					vk_geometry.vertex_buffer = allocateVkBuffer(
						vk.DeviceSize(size_of(types.Vertex) * len(prim.vertices)),
						raw_data(prim.vertices[:]),
						{.VERTEX_BUFFER, .TRANSFER_DST, .TRANSFER_SRC},
					)

					vk_geometry.index_buffer = allocateVkBuffer(
						vk.DeviceSize(size_of(u32) * len(prim.indices)),
						raw_data(prim.indices[:]),
						{.INDEX_BUFFER, .TRANSFER_DST},
					)
					vk_geometry.index_count = u32(len(prim.indices))

					if prim.metallic_roughness.has_attribute {
						texture_image: VkTextureImage

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
						texture_id, _ := uuid.to_string(texture_image.id)
						vk_geometry.texture.texture_images[texture_id] = texture_image

						vk_geometry.texture.uniform.diffuse_color = prim.metallic_roughness.base_color
					}

					// TODO: move this
					vk_geometry.pipeline.wireframe = false
					vk_geometry.pipeline.blending = .none

					initVkGeometry(&vk_geometry, shaders)

					append(&tmp_vk_geometries, vk_geometry)
				}

				append(
					&vk_render_objects,
					VkRenderObject{geometry = geometry, vk_geometry = tmp_vk_geometries[:]},
				)

			}
		}
	}

	return vk_render_objects[:]
}

destroyVkRenderObjectsSlice :: proc(render_objects: ^[]VkRenderObject) {
	for &ro in render_objects {
		for &vk_ro in ro.vk_geometry {
			destroyVkGeometry(&vk_ro)
		}
	}
}
