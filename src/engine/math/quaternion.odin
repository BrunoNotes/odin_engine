package math_ctx

import "core:math"
import "core:math/linalg"

normalizeQuaternion :: proc(q: quaternion128) -> quaternion128 {
	normal := math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)

	result: quaternion128

	result.x = q.x / normal
	result.y = q.y / normal
	result.z = q.z / normal
	result.w = q.w / normal

	return result
}

quaternionFromAxisAngle :: proc(axis: linalg.Vector3f32, angle: f32) -> quaternion128 {
	half_angle := 0.5 * angle

	sin := math.sin(half_angle)
	cos := math.cos(half_angle)

	return quaternion(x = sin * axis.x, y = sin * axis.y, z = sin * axis.z, w = cos)
}

quaternionToRotationMatrix :: proc(
	q: quaternion128,
	center: linalg.Vector3f32,
) -> linalg.Matrix4f32 {
	result: linalg.Matrix4f32

	result[0][0] = (q.x * q.x) - (q.y * q.y) - (q.z * q.z) + (q.w * q.w)
	result[1][0] = 2.0 * ((q.x * q.y) + (q.z * q.w))
	result[2][0] = 2.0 * ((q.x * q.z) - (q.y * q.w))
	result[3][0] =
		center.x - center.x * result[0][0] - center.y * result[1][0] - center.z * result[2][0]

	result[0][1] = 2.0 * ((q.x * q.y) - (q.z * q.w))
	result[1][1] = -(q.x * q.x) + (q.y * q.y) - (q.z * q.z) + (q.w * q.w)
	result[2][1] = 2.0 * ((q.y * q.z) + (q.x * q.w))
	result[3][1] =
		center.y - center.x * result[0][1] - center.y * result[1][1] - center.z * result[2][1]

	result[0][2] = 2.0 * ((q.x * q.z) + (q.y * q.w))
	result[1][2] = 2.0 * ((q.y * q.z) - (q.x * q.w))
	result[2][2] = -(q.x * q.x) - (q.y * q.y) + (q.z * q.z) + (q.w * q.w)
	result[3][2] =
		center.z - center.x * result[0][2] - center.y * result[1][2] - center.z * result[2][2]

	result[0][3] = 0.0
	result[1][3] = 0.0
	result[2][3] = 0.0
	result[3][3] = 1.0

	return result
}

quaternionToMatrix4 :: proc(q: quaternion128) -> linalg.Matrix4f32 {
	result := MAT4IDENTITY
	n := normalizeQuaternion(q)

	result[0][0] = 1.0 - 2.0 * n.y * n.y - 2.0 * n.z * n.z
	result[1][0] = 2.0 * n.x * n.y - 2.0 * n.z * n.w
	result[2][0] = 2.0 * n.x * n.z + 2.0 * n.y * n.w

	result[0][1] = 2.0 * n.x * n.y + 2.0 * n.z * n.w
	result[1][1] = 1.0 - 2.0 * n.x * n.x - 2.0 * n.z * n.z
	result[2][1] = 2.0 * n.y * n.z - 2.0 * n.x * n.w

	result[0][3] = 2.0 * n.x * n.z - 2.0 * n.y * n.w
	result[1][3] = 2.0 * n.y * n.z + 2.0 * n.x * n.w
	result[2][3] = 1.0 - 2.0 * n.x * n.x - 2.0 * n.y * n.y

	return result
}
