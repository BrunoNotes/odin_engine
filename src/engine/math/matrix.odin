package math_ctx

import "core:math/linalg"

MAT4IDENTITY := linalg.Matrix4f32 {
	1.0,
	0.0,
	0.0,
	0.0,
	0.0,
	1.0,
	0.0,
	0.0,
	0.0,
	0.0,
	1.0,
	0.0,
	0.0,
	0.0,
	0.0,
	1.0,
}

ortographicProjectionMatrix :: proc(
	left_dir, right_dir, bottom_dir, top_dir, near_clip, far_clip: f32,
) -> linalg.Matrix4f32 {
	result: linalg.Matrix4f32

	lr := 1.0 / (left_dir - right_dir)
	bt := 1.0 / (bottom_dir - top_dir)
	nf := 1.0 / (near_clip - far_clip)

	result[0][0] = -2.0 * lr
	result[1][1] = -2.0 * bt
	result[2][2] = -2.0 * nf

	result[3][0] = (left_dir + right_dir) * lr
	result[3][1] = (top_dir + bottom_dir) * bt
	result[3][2] = (far_clip + near_clip) * nf

	return result
}
