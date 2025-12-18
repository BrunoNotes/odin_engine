package math_ctx

import "core:math"
import "core:math/linalg"

VEC2ZERO := linalg.Vector2f32{0, 0}
VEC2UP := linalg.Vector2f32{0, 1}
VEC2DOWN := linalg.Vector2f32{0, -1}
VEC2LEFT := linalg.Vector2f32{-1, 0}
VEC2RIGHT := linalg.Vector2f32{1, 0}

vec2LengthSquared :: proc(vector: linalg.Vector2f32) -> f32 {
	return vector.x * vector.x + vector.y * vector.y
}

vec2Length :: proc(vector: linalg.Vector2f32) -> f32 {
	return math.sqrt(vec2LengthSquared(vector))
}

vec2Normalize :: proc(vector: ^linalg.Vector2f32) {
	vec_len := vec2Length(vector^)
	vector.x /= vec_len
	vector.y /= vec_len
}

// the distance between 2 vectors
vec2Distance :: proc(vector_0, vector_1: linalg.Vector2f32) -> f32 {
	diference := vector_0 - vector_1
	return vec2Length(diference)
}

VEC3ZERO := linalg.Vector3f32{0, 0, 0}
VEC3UP := linalg.Vector3f32{0, 1, 0}
VEC3DOWN := linalg.Vector3f32{0, -1, 0}
VEC3LEFT := linalg.Vector3f32{-1, 0, 0}
VEC3RIGHT := linalg.Vector3f32{1, 0, 0}
VEC3FORWARD := linalg.Vector3f32{0, 0, -1}
VEC3BACK := linalg.Vector3f32{0, 0, 1}

vec3LengthSqared :: proc(vector: linalg.Vector3f32) -> f32 {
	return vector.x * vector.x + vector.y * vector.y + vector.z * vector.z
}

vec3Length :: proc(vector: linalg.Vector3f32) -> f32 {
	return math.sqrt(vec3LengthSqared(vector))
}

vec3DotProduct :: proc(vector_0, vector_1: linalg.Vector3f32) -> f32 {
	product: f32 = 0
	product += vector_0.x * vector_1.x
	product += vector_0.y * vector_1.y
	product += vector_0.z * vector_1.z
	return product
}

vec3CrossMult :: proc(vector_0, vector_1: linalg.Vector3f32) -> linalg.Vector3f32 {
	return linalg.Vector3f32 {
		vector_0.y * vector_1.z - vector_0.z * vector_1.y,
		vector_0.z * vector_1.x - vector_0.x * vector_1.z,
		vector_0.x * vector_1.y - vector_0.y * vector_1.x,
	}
}

vec3Normalize :: proc(vector: ^linalg.Vector3f32) {
	vec_len := vec3Length(vector^)
	vector.x /= vec_len
	vector.y /= vec_len
	vector.z /= vec_len
}

vec4LengthSquared :: proc(vector: linalg.Vector4f32) -> f32 {
	return vector.x * vector.x + vector.y * vector.y + vector.z * vector.z + vector.w * vector.w
}

vec4Length :: proc(vector: linalg.Vector4f32) -> f32 {
	return math.sqrt(vec4LengthSquared(vector))
}

vec4Normalize :: proc(vector: ^linalg.Vector4f32) {
	vec_len := vec4Length(vector^)
	vector.x /= vec_len
	vector.y /= vec_len
	vector.z /= vec_len
	vector.w /= vec_len
}

vec4MultMatrix :: proc(m: linalg.Matrix4f32, v: linalg.Vector4f32) -> linalg.Vector4f32 {
	return linalg.Vector4f32 {
		m[0][0] * v.x + m[1][0] * v.y + m[2][0] * v.z + m[3][0] * v.w,
		m[0][1] * v.x + m[1][1] * v.y + m[2][1] * v.z + m[3][1] * v.w,
		m[0][2] * v.x + m[1][2] * v.y + m[2][2] * v.z + m[3][2] * v.w,
		m[0][3] * v.x + m[1][3] * v.y + m[2][3] * v.z + m[3][3] * v.w,
	}
}
