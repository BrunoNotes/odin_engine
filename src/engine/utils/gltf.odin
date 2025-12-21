package utils_context

import "../../../vendor/cgltf"
import "../types"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:path/filepath"
import "core:strings"

GltfReaderError :: enum {
	Indices,
	Vertices,
	Normals,
	TexCoords,
	Validate,
}

GltfError :: union #shared_nil {
	GltfReaderError,
}

GltfData :: struct {
	meshes: []GltfMesh,
	// textures: []StbImage,
}

GltfMesh :: struct {
	name:        string,
	rotation:    linalg.Quaternionf32,
	translation: linalg.Vector3f32,
	scale:       linalg.Vector3f32,
	primitives:  []GltfPrimitive,
}

GltfPrimitive :: struct {
	vertices:           []types.Vertex,
	indices:            []u32,
	base_color_texture: StbImage,
	base_color:         linalg.Vector4f32,
}

loadGltf :: proc {
	loadGltfFile,
	loadGltfByte,
}

loadGltfFile :: proc(file_path: string, allocator := context.allocator) -> (GltfData, GltfError) {

	options := cgltf.options{}
	data: ^cgltf.data
	result: cgltf.result
	file_path_cstring := strings.clone_to_cstring(file_path, context.temp_allocator)

	data, result = cgltf.parse_file(options, file_path_cstring)
	// defer cgltf.free(data)

	if (result == .success) {
		result = cgltf.load_buffers(options, data, file_path_cstring)
	}
	if (result == .success) {
		result = cgltf.validate(data)
	}

	if result != .success {
		return GltfData{}, .Validate
	}

	return proccessGltf(options, data, result, file_path, allocator = allocator)
}

loadGltfByte :: proc(byte: []byte, allocator := context.allocator) -> (GltfData, GltfError) {
	// TODO: check why it does not work
	options := cgltf.options{}
	data: ^cgltf.data
	result: cgltf.result

	data, result = cgltf.parse(options, raw_data(byte), len(byte))
	// defer cgltf.free(data)

	if result == .success {
		result = cgltf.validate(data)
	}

	if result != .success {
		return GltfData{}, .Validate
	}

	return proccessGltf(options, data, result, allocator = allocator)
}

proccessGltf :: proc(
	options: cgltf.options,
	data: ^cgltf.data,
	result: cgltf.result,
	file_path: string = "",
	allocator := context.allocator,
) -> (
	GltfData,
	GltfError,
) {
	gltf_data: GltfData
	// based on https://capati.github.io/odin-vk-guide/graphics-pipeline/mesh-loading

	gltf_data.meshes = make([]GltfMesh, len(data.meshes), allocator)

	for &mesh, mesh_idx in data.meshes {
		tmp_mesh: GltfMesh

		node: cgltf.node
		node_loop: for n in data.nodes {
			if n.mesh == &mesh {
				node = n
				break node_loop
			}
		}
		tmp_mesh.translation = node.translation
		tmp_mesh.rotation.x = node.rotation.x
		tmp_mesh.rotation.y = node.rotation.y
		tmp_mesh.rotation.z = node.rotation.z
		tmp_mesh.rotation.w = node.rotation.w
		tmp_mesh.scale = node.scale

		tmp_mesh.name = strings.clone_from_cstring(mesh.name, allocator)
		log.infof("Loading: %v", tmp_mesh.name)

		tmp_mesh.primitives = make([]GltfPrimitive, len(mesh.primitives), allocator)

		for &prim, prim_idx in mesh.primitives {
			tmp_primitive: GltfPrimitive
			tmp_vertices := make([dynamic]types.Vertex, allocator)
			tmp_indices := make([dynamic]u32, allocator)
			// Track starting vertex count for index offsetting
			initial_vtx := len(tmp_vertices)
			// fmt.printfln("%#v",prim)

			// Load index data
			{
				index_accessor := prim.indices

				resize(&tmp_indices, len(tmp_indices) + int(index_accessor.count))

				index_count := index_accessor.count
				index_buffer := make([]u32, index_count, context.temp_allocator)

				if indices_unpacked := cgltf.accessor_unpack_indices(
					index_accessor,
					raw_data(index_buffer),
					uint(size_of(u32)),
					index_count,
				); indices_unpacked < uint(index_count) {
					// Error if we didn't get all expected indices
					log.errorf(
						"[%s]: Only unpacked %d indices out of %d expected",
						tmp_mesh.name,
						indices_unpacked,
						index_count,
					)
					return gltf_data, GltfReaderError.Indices
				}

				for i in 0 ..< index_count {
					tmp_indices[i] = index_buffer[i] + u32(initial_vtx)
				}
			}

			// Load vertex position data
			{
				pos_accessor: ^cgltf.accessor
				for &attr in prim.attributes {
					if attr.type == .position {
						pos_accessor = attr.data
						break
					}
				}

				if pos_accessor == nil {
					log.warn("Mesh has no position attribute")
					continue
				}

				vertex_count := int(pos_accessor.count)

				old_len := len(tmp_vertices)
				resize(&tmp_vertices, old_len + vertex_count)

				for &vtx in tmp_vertices {
					vtx = {
						normal = {1, 0, 0}, // Default normal points along X
						color  = {1, 1, 1, 1}, // Default white
						uv     = {0, 0},
					}
				}

				positions := make([]f32, vertex_count * 3, context.temp_allocator)

				if vertices_unpacked := cgltf.accessor_unpack_floats(
					pos_accessor,
					raw_data(positions),
					uint(vertex_count * 3),
				); vertices_unpacked < uint(vertex_count) {
					log.errorf(
						"[%s]: Only unpacked %v vertices out of %v expected",
						tmp_mesh.name,
						vertices_unpacked,
						vertex_count,
					)
					return gltf_data, GltfReaderError.Vertices
				}

				for i in 0 ..< vertex_count {
					vert_idx := i * 3
					tmp_vertices[initial_vtx + i].position = {
						positions[vert_idx],
						positions[vert_idx + 1],
						positions[vert_idx + 2],
					}
				}
			}

			// Load vertex normals
			{
				normal_accessor: ^cgltf.accessor
				for &attr in prim.attributes {
					if attr.type == .normal {
						normal_accessor = attr.data
						break
					}
				}

				if normal_accessor != nil {
					vertex_count := int(normal_accessor.count)
					normals := make([]f32, vertex_count * 3)
					defer delete(normals)

					if normals_unpacked := cgltf.accessor_unpack_floats(
						normal_accessor,
						raw_data(normals),
						uint(vertex_count * 3),
					); normals_unpacked < uint(vertex_count) {
						log.errorf(
							"[%s]: Only unpacked %v normals out of %v expected",
							mesh.name,
							normals_unpacked,
							vertex_count,
						)

						return gltf_data, GltfReaderError.Normals
					}

					for i in 0 ..< vertex_count {
						vert_idx := i * 3
						tmp_vertices[initial_vtx + i].normal = {
							normals[vert_idx],
							normals[vert_idx + 1],
							normals[vert_idx + 2],
						}
					}
				}
			}

			// Load UV coordinates
			{
				uv_accessor: ^cgltf.accessor
				tex_idx: i32
				for &attr in prim.attributes {
					if attr.type == .texcoord && attr.index == 0 {
						uv_accessor = attr.data
						tex_idx = attr.index
						break
					}
				}

				if uv_accessor != nil {
					vertex_count := int(uv_accessor.count)
					uvs := make([]f32, vertex_count * 2)
					defer delete(uvs)

					if texcoords_unpacked := cgltf.accessor_unpack_floats(
						uv_accessor,
						raw_data(uvs),
						uint(vertex_count * 2),
					); texcoords_unpacked < uint(vertex_count) {
						log.errorf(
							"[%s]: Only unpacked %v texcoords out of %v expected",
							tmp_mesh.name,
							texcoords_unpacked,
							vertex_count,
						)

						return gltf_data, GltfReaderError.TexCoords
					}

					for i in 0 ..< vertex_count {
						vert_idx := i * 2
						tmp_vertices[initial_vtx + i].uv = {uvs[vert_idx], uvs[vert_idx + 1]}
					}
				}
			}

			// Load vertex colors
			{
				color_accessor: ^cgltf.accessor
				for &attr in prim.attributes {
					if attr.type == .color && attr.index == 0 {
						color_accessor = attr.data
						break
					}
				}

				if color_accessor != nil {
					vertex_count := int(color_accessor.count)
					colors := make([]f32, vertex_count * 4)
					defer delete(colors)

					if colors_unpacked := cgltf.accessor_unpack_floats(
						color_accessor,
						raw_data(colors),
						uint(vertex_count * 4),
					); colors_unpacked < uint(vertex_count) {
						log.warnf(
							"[%s]: Only unpacked %v colors out of %v expected",
							tmp_mesh.name,
							colors_unpacked,
							vertex_count,
						)
					}

					for i in 0 ..< vertex_count {
						vert_idx := i * 4
						tmp_vertices[initial_vtx + i].color = {
							colors[vert_idx],
							colors[vert_idx + 1],
							colors[vert_idx + 2],
							colors[vert_idx + 3],
						}
					}
				}
			}

			tmp_primitive.vertices = tmp_vertices[:]
			tmp_primitive.indices = tmp_indices[:]

			// fmt.printfln("%#v", prim.material)
			if prim.material.has_pbr_metallic_roughness {
				// fmt.printfln("%#v", prim.material.pbr_metallic_roughness)
				// fmt.printfln("%#v", prim.material.pbr_metallic_roughness.base_color_texture)
				tmp_primitive.base_color_texture = processGltfTexture(
					prim.material.pbr_metallic_roughness.base_color_texture.texture,
					file_path,
					allocator,
				)

				tmp_primitive.base_color = prim.material.pbr_metallic_roughness.base_color_factor
			} else if prim.material.has_pbr_specular_glossiness {
				fmt.printfln("%#v", prim.material.pbr_specular_glossiness)
			}

			tmp_mesh.primitives[prim_idx] = tmp_primitive
		}

		// fmt.printfln("%#v", tmp_surface)
		gltf_data.meshes[mesh_idx] = tmp_mesh
	}

	cgltf.free(data)

	return gltf_data, nil
}

processGltfTexture :: proc(
	texture: ^cgltf.texture,
	file_path: string = "",
	allocator := context.allocator,
) -> StbImage {
	image: StbImage
	if texture.image_.buffer_view != nil {
		// fmt.printfln("%#v", base_color_texture_view.texture.image_.buffer_view)
		start := texture.image_.buffer_view.offset
		// end := start + texture.image_.buffer_view.size
		end := texture.image_.buffer_view.buffer.size

		texture_data := ([^]byte)(texture.image_.buffer_view.buffer.data)[start:end]

		image = loadStbImage(texture_data, allocator)
	} else {
		// fmt.printfln("%#v", base_color_texture_view.texture.image_.buffer_view)
		gltf_dir, _ := filepath.split(file_path)

		image = loadStbImage(
			filepath.join(
				{
                    gltf_dir,
					strings.clone_from_cstring(texture.image_.uri, context.temp_allocator),
				},
				context.temp_allocator,
			),
			allocator,
		)
	}

	return image
}
