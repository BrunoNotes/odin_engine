package utils_context

import "../../../vendor/cgltf"
import "../types"
import "core:log"
import "core:math/linalg"
import "core:path/filepath"
import "core:strings"

GltfReaderError :: enum {
	Indices,
	Vertices,
	Normals,
	TexCoords,
}

GltfError :: union #shared_nil {
	GltfReaderError,
}

GltfData :: struct {
	surfaces: []GltfSurface,
	textures: []StbImage,
}

GltfSurface :: struct {
	name:        string,
	vertices:    []types.Vertex,
	indices:     []u32,
	rotation:    linalg.Quaternionf32,
	translation: linalg.Vector3f32,
	scale:       linalg.Vector3f32,
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

	return proccessGltf(options, data, result, file_path, allocator = allocator)
}

loadGltfByte :: proc(byte: []byte, allocator := context.allocator) -> (GltfData, GltfError) {
	// TODO: check why it does not work
	options := cgltf.options{}
	data: ^cgltf.data
	result: cgltf.result

	data, result = cgltf.parse(options, raw_data(byte), len(byte))
	// defer cgltf.free(data)

	if (result == .success) {
		result = cgltf.validate(data)
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
	if (result == .success) {

		gltf_data.surfaces = make([]GltfSurface, len(data.meshes), allocator)
		gltf_data.textures = make([]StbImage, len(data.textures), allocator)

		for &mesh, idx in data.meshes {
			tmp_surface: GltfSurface

			node := data.nodes[idx]
			tmp_surface.translation = node.translation
			tmp_surface.rotation.x = node.rotation.x
			tmp_surface.rotation.y = node.rotation.y
			tmp_surface.rotation.z = node.rotation.z
			tmp_surface.rotation.w = node.rotation.w
			tmp_surface.scale = node.scale

			tmp_surface.name = strings.clone_from_cstring(mesh.name, allocator)
			log.infof("Loading: %v", tmp_surface.name)

			tmp_vertices := make([dynamic]types.Vertex, allocator)
			tmp_indices := make([dynamic]u32, allocator)

			for &prim in mesh.primitives {
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
							tmp_surface.name,
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
							tmp_surface.name,
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
								tmp_surface.name,
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
								tmp_surface.name,
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

				tmp_surface.vertices = tmp_vertices[:]
				tmp_surface.indices = tmp_indices[:]
			}

			gltf_data.surfaces[idx] = tmp_surface
		}

		for &texture, idx in data.textures {
			loaded_image: StbImage
			if texture.image_.buffer_view != nil {
				start := texture.image_.buffer_view.offset
				// end := start + texture.image_.buffer_view.size
				end := texture.image_.buffer_view.buffer.size

				texture_data := ([^]byte)(texture.image_.buffer_view.buffer.data)[start:end]

				loaded_image = loadStbImage(texture_data, allocator)
			} else {
				split_string := strings.split(
					file_path,
					ODIN_OS == .Windows ? "\\" : "/",
					context.temp_allocator,
				)

				loaded_image = loadStbImage(
					filepath.join(
						{
							filepath.join(
								split_string[:len(split_string) - 1],
								context.temp_allocator,
							),
							strings.clone_from_cstring(texture.image_.uri, context.temp_allocator),
						},
						context.temp_allocator,
					),
					allocator,
				)
			}

			gltf_data.textures[idx] = loaded_image
		}

		cgltf.free(data)
	}

	return gltf_data, nil
}
