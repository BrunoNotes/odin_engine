package types_context

import "core:math/linalg"

Camera :: struct {
	velocity:          linalg.Vector3f32,
	translation:       linalg.Vector3f32,
	pitch:             f32,
	yaw:               f32,
	row:               f32,
	fov:               f32,
	projection:        CameraProjection,
	controller:        CameraController,
	projection_matrix: linalg.Matrix4f32,
	view_matrix:       linalg.Matrix4f32,
}

CameraProjection :: enum {
	perspective,
	orthographic,
}

CameraController :: enum {
	none,
	fly_camera,
}

getCameraRotationMatrix :: proc(cam: Camera) -> linalg.Matrix4f32 {
	return linalg.matrix4_from_quaternion(
		linalg.quaternion_from_pitch_yaw_roll(cam.pitch, cam.yaw, cam.row),
	)
}

getCameraViewMatrix :: proc(cam: Camera) -> linalg.Matrix4f32 {
	rotation := getCameraRotationMatrix(cam)
	translation := linalg.matrix4_translate(cam.translation)

	return linalg.inverse(translation * rotation)
}

updateCameraProjection :: proc(cam: ^Camera, width, height: f32) {
	if (cam.projection == .perspective) {
		v := linalg.Vector4f32{cam.velocity.x, cam.velocity.y, cam.velocity.z, 0}
		r := getCameraRotationMatrix(cam^)
		result := r * v
		cam.translation += linalg.Vector3f32{result.x, result.y, result.z}

		cam.view_matrix = getCameraViewMatrix(cam^)
		cam.projection_matrix = linalg.matrix4_perspective(cam.fov, width / height, 0.1, 1000.0)
	}
}
