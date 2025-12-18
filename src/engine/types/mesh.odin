package types_context

import math_ctx "../math"
import "core:math/linalg"

Mesh :: struct {
	name:         string,
	vertices:     []Vertex,
	indices:      []u32,
	rotation:     linalg.Quaternionf32,
	translation:  linalg.Vector3f32,
	scale:        linalg.Vector3f32,
	model_matrix: linalg.Matrix4f32,
}

updateMesh :: proc(mesh: ^Mesh) {
	rotation_matrix := math_ctx.quaternionToRotationMatrix(mesh.rotation, math_ctx.VEC3ZERO)

	translation := linalg.matrix4_translate(mesh.translation)

	mesh.model_matrix = translation * rotation_matrix * linalg.matrix4_scale(mesh.scale)
}
