package types_context

import math_ctx "../math"
import "core:math/linalg"

Geometry :: struct {
	name:         string,
	rotation:     linalg.Quaternionf32,
	translation:  linalg.Vector3f32,
	scale:        linalg.Vector3f32,
	model_matrix: linalg.Matrix4f32,
}

updateGeometryProjection :: proc(geometry: ^Geometry) {
	rotation_matrix := math_ctx.quaternionToRotationMatrix(geometry.rotation, math_ctx.VEC3ZERO)

	translation := linalg.matrix4_translate(geometry.translation)

	geometry.model_matrix = translation * rotation_matrix * linalg.matrix4_scale(geometry.scale)
}
