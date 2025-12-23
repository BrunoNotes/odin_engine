package utils_context

import "../../../vendor/cgltf"
import "../types"
import "core:fmt"
import "core:math/linalg"
import "core:path/filepath"
import "core:strings"

GltfData :: struct {
	scenes: []GltfScene,
	data:   ^cgltf.data,
}

GltfScene :: struct {
	nodes: []GltfNode,
}

GltfNode :: struct {
	name:        string,
	rotation:    linalg.Quaternionf32,
	translation: linalg.Vector3f32,
	scale:       linalg.Vector3f32,
	meshes:      []GltfMesh,
}

GltfMesh :: struct {
	primitives: []GltfPrimitive,
}

GltfPrimitive :: struct {
	vertices:           []types.Vertex,
	indices:            []u32,
	metallic_roughness: GltfMetallicRoughness,
}

GltfMetallicRoughness :: struct {
	has_attribute:      bool,
	base_color_texture: GltfTexture,
	base_color:         linalg.Vector4f32,
}

GltfTexture :: struct {
	image_path: string,
	byte:       []byte,
	type:       GltfTextureType,
}

GltfTextureType :: enum {
	file,
	byte,
}

loadGltf :: proc {
	loadGltfFile,
	loadGltfByte,
}

loadGltfFile :: proc(file_path: string, allocator := context.allocator) -> GltfData {

	options := cgltf.options{}
	data: ^cgltf.data
	result: cgltf.result
	file_path_cstring := strings.clone_to_cstring(file_path, context.temp_allocator)

	data, result = cgltf.parse_file(options, file_path_cstring)
	// defer cgltf.free(data)

	return proccessGltf(options, data, result, file_path, allocator = allocator)
}

loadGltfByte :: proc(byte: []byte, allocator := context.allocator) -> GltfData {
	// TODO: check why it does not work
	options := cgltf.options{}
	data: ^cgltf.data
	result: cgltf.result

	data, result = cgltf.parse(options, raw_data(byte), len(byte))
	// defer cgltf.free(data)

	return proccessGltf(options, data, result, allocator = allocator)
}

destroyGltf :: proc(gltf: GltfData) {
	cgltf.free(gltf.data)
}

proccessGltf :: proc(
	options: cgltf.options,
	data: ^cgltf.data,
	result: cgltf.result,
	file_path: string = "",
	allocator := context.allocator,
) -> GltfData {
	result := result
	file_path_cstring := strings.clone_to_cstring(file_path, context.temp_allocator)

	if result == .success {
		result = cgltf.load_buffers(options, data, file_path_cstring)
	}

	if result == .success {
		result = cgltf.validate(data)
	}

	assert(result == .success, "Gltf: invalid data")

	gltf_data: GltfData
	gltf_data.data = data

	gltf_data.scenes = make([]GltfScene, len(data.scenes), allocator)

	for &scene, scene_idx in data.scenes {
		tmp_nodes := make([dynamic]GltfNode, allocator)

		for &node in scene.nodes {
			tmp_gltf_node: GltfNode
			processGltfNode(node, &tmp_gltf_node, file_path, allocator)

			for &children in node.children {
				tmp_children_gltf_node: GltfNode
				processGltfNode(children, &tmp_children_gltf_node, file_path, allocator)
				append(&tmp_nodes, tmp_children_gltf_node)
			}

			append(&tmp_nodes, tmp_gltf_node)
		}

		gltf_data.scenes[scene_idx].nodes = tmp_nodes[:]
	}

	return gltf_data
}

processGltfNode :: proc(
	node: ^cgltf.node,
	out: ^GltfNode,
	file_path: string,
	allocator := context.allocator,
) {
	name, err := strings.clone_from_cstring(node.name)
	assert(err == nil, "Gltf: error getting node name")

	out.name = name

	out.translation = node.translation
	out.rotation.x = node.rotation.x
	out.rotation.y = node.rotation.y
	out.rotation.z = node.rotation.z
	out.rotation.w = node.rotation.w
	out.scale = node.scale

	tmp_gltf_meshes := make([dynamic]GltfMesh, allocator)

	if node.mesh != nil {
		tmp_gltf_mesh: GltfMesh
		processGltfMesh(node.mesh, &tmp_gltf_mesh, file_path, allocator)
		append(&tmp_gltf_meshes, tmp_gltf_mesh)
	}

	out.meshes = tmp_gltf_meshes[:]
}

processGltfMesh :: proc(
	mesh: ^cgltf.mesh,
	out: ^GltfMesh,
	file_path: string,
	allocator := context.allocator,
) {
	tmp_gltf_primitives := make([dynamic]GltfPrimitive, allocator)
	for &prim in mesh.primitives {
		tmp_gltf_primitive: GltfPrimitive
		// ----- index -----
		{
			index_accessor := prim.indices
			index_size := cgltf.accessor_unpack_indices(index_accessor, nil, 0, 0)

			tmp_gltf_primitive.indices = make([]u32, index_size, allocator)
			index_unpacked := cgltf.accessor_unpack_indices(
				index_accessor,
				raw_data(tmp_gltf_primitive.indices),
				uint(size_of(u32)),
				index_size,
			)

			assert(index_unpacked == index_size, "Gltf: error getting all indices")

			assert(
				len(tmp_gltf_primitive.indices) == int(index_size),
				"Gltf: error getting index buffer",
			)
		}

		// ----- position -----
		{
			position_accessor: ^cgltf.accessor
			for &attr in prim.attributes {
				if attr.type == .position {
					position_accessor = attr.data
					break
				}
			}

			assert(position_accessor != nil, "Gltf: error getting position accessor")
			assert(position_accessor.type == .vec3, "Gltf: position acessor is not a vec3")

			position_size := cgltf.accessor_unpack_floats(position_accessor, nil, 0)

			tmp_gltf_primitive.vertices = make([]types.Vertex, position_size / 3, allocator)

			positions := make([]f32, position_size, context.temp_allocator)
			position_unpacked := cgltf.accessor_unpack_floats(
				position_accessor,
				raw_data(positions),
				position_size,
			)

			assert(position_unpacked == position_size, "Gltf: error getting all positions")
			assert(
				len(tmp_gltf_primitive.vertices) * 3 == len(positions),
				"Gltf: error getting positions",
			)

			for i in 0 ..< len(tmp_gltf_primitive.vertices) {
				position_idx := i * 3
				tmp_gltf_primitive.vertices[i].position = {
					positions[position_idx],
					positions[position_idx + 1],
					positions[position_idx + 2],
				}

				tmp_gltf_primitive.vertices[i].normal = {1, 0, 0}
				tmp_gltf_primitive.vertices[i].color = 1
				tmp_gltf_primitive.vertices[i].uv = 0
			}
		}

		// ----- normals -----
		{
			normal_accessor: ^cgltf.accessor
			for &attr in prim.attributes {
				if attr.type == .position {
					normal_accessor = attr.data
					break
				}
			}

			if normal_accessor != nil {
				assert(normal_accessor.type == .vec3, "Gltf: normal acessor type is not a vec3")

				normals_size := cgltf.accessor_unpack_floats(normal_accessor, nil, 0)

				normals := make([]f32, normals_size)
				defer delete(normals)

				normals_unpacked := cgltf.accessor_unpack_floats(
					normal_accessor,
					raw_data(normals),
					normals_size,
				)

				assert(normals_unpacked == normals_size, "Gltf: error getting all normals")
				assert(
					len(tmp_gltf_primitive.vertices) * 3 == len(normals),
					"Gltf: error getting normals",
				)

				for i in 0 ..< len(tmp_gltf_primitive.vertices) {
					normal_idx := i * 3
					tmp_gltf_primitive.vertices[i].normal = {
						normals[normal_idx],
						normals[normal_idx + 1],
						normals[normal_idx + 2],
					}
				}
			}
		}

		// Uv
		{
			uv_accessor: ^cgltf.accessor
			for &attr in prim.attributes {
				if attr.type == .texcoord {
					uv_accessor = attr.data
					break
				}
			}


			if uv_accessor != nil {
				assert(uv_accessor.type == .vec2, "Gltf: uv acessor type is not a vec2")

				uv_size := cgltf.accessor_unpack_floats(uv_accessor, nil, 0)

				uvs := make([]f32, uv_size)
				defer delete(uvs)

				uv_unpacked := cgltf.accessor_unpack_floats(
					uv_accessor,
					raw_data(uvs),
					uint(uv_size),
				)

				assert(uv_unpacked == uv_size, "Gltf: error getting all uvs")
				assert(len(tmp_gltf_primitive.vertices) * 2 == len(uvs), "Gltf: error getting uvs")

				for i in 0 ..< len(tmp_gltf_primitive.vertices) {
					uv_idx := i * 2
					tmp_gltf_primitive.vertices[i].uv = {uvs[uv_idx], uvs[uv_idx + 1]}
				}
			}
		}

		// color
		{
			color_accessor: ^cgltf.accessor
			for &attr in prim.attributes {
				if attr.type == .color {
					color_accessor = attr.data
					break
				}
			}

			if color_accessor != nil {
				assert(color_accessor.type == .vec4, "Gltf: color acessor type is not a vec4")

				color_size := cgltf.accessor_unpack_floats(color_accessor, nil, 0)

				colors := make([]f32, color_size, context.temp_allocator)
				color_unpacked := cgltf.accessor_unpack_floats(
					color_accessor,
					raw_data(colors),
					color_size,
				)

				assert(color_unpacked == color_size, "Gltf: error getting all colors")
				assert(
					len(tmp_gltf_primitive.vertices) * 4 == len(colors),
					"Gltf: error getting colors",
				)

				for i in 0 ..< len(tmp_gltf_primitive.vertices) {
					color_idx := i * 4
					tmp_gltf_primitive.vertices[i].color = {
						colors[color_idx],
						colors[color_idx + 1],
						colors[color_idx + 2],
						colors[color_idx + 3],
					}
				}
			}

			if prim.material.has_pbr_metallic_roughness {
				tmp_gltf_primitive.metallic_roughness.has_attribute = true

				texture := prim.material.pbr_metallic_roughness.base_color_texture.texture

                fmt.println(prim.material.pbr_metallic_roughness)

				if texture.image_.buffer_view != nil {
					start := texture.image_.buffer_view.offset
					// end := start + texture.image_.buffer_view.size
					end := texture.image_.buffer_view.buffer.size

					texture_data := ([^]byte)(texture.image_.buffer_view.buffer.data)[start:end]

					tmp_gltf_primitive.metallic_roughness.base_color_texture.type = .byte
					tmp_gltf_primitive.metallic_roughness.base_color_texture.byte = texture_data
				} else {
					gltf_dir, _ := filepath.split(file_path)

					texture_path := filepath.join(
						{
							gltf_dir,
							strings.clone_from_cstring(texture.image_.uri, context.temp_allocator),
						},
						context.temp_allocator,
					)

					tmp_gltf_primitive.metallic_roughness.base_color_texture.type = .file
					tmp_gltf_primitive.metallic_roughness.base_color_texture.image_path =
						texture_path
				}

				tmp_gltf_primitive.metallic_roughness.base_color =
					prim.material.pbr_metallic_roughness.base_color_factor


			} else if prim.material.has_pbr_specular_glossiness {
				fmt.printfln("%#v", prim.material.pbr_specular_glossiness)
			}
		}

		append(&tmp_gltf_primitives, tmp_gltf_primitive)
	}

	out.primitives = tmp_gltf_primitives[:]
}
