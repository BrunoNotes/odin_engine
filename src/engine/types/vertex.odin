package types_context

import "core:math/linalg"

Vertex :: struct {
	position: linalg.Vector3f32,
	uv:       linalg.Vector2f32,
	color:    linalg.Vector4f32,
	normal:   linalg.Vector3f32,
}
