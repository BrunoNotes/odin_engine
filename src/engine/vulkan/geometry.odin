package vulkan_context

import math_ctx "../math"
import "core:math/linalg"

VkGeometry :: struct {
	name:             string,
	rotation:         linalg.Quaternionf32,
	translation:      linalg.Vector3f32,
	scale:            linalg.Vector3f32,
	transform_matrix: linalg.Matrix4f32,
	render_objects:   []string,
}

VkGeometryPushConstant :: struct {
	transform_matrix: linalg.Matrix4f32,
}

destroyVkGeometry :: proc(geometry: ^VkGeometry) {
	for id in geometry.render_objects {
		destroyVkRenderObject(&g_render_objects[id])
	}
	// destroyVkPipeline(&geometry.pipeline)
}

destroyVkGeometrySlice :: proc(geometries: []VkGeometry) {
	for &geometry in geometries {
		destroyVkGeometry(&geometry)
	}
}

updateVkGeometryProjection :: proc(geometry: ^VkGeometry) {
	rotation_matrix := math_ctx.quaternionToRotationMatrix(geometry.rotation, math_ctx.VEC3ZERO)

	translation := linalg.matrix4_translate(geometry.translation)

	geometry.transform_matrix =
		translation * rotation_matrix * linalg.matrix4_scale(geometry.scale)
}
