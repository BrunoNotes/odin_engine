package engine_context

import math_ctx "./math"
import w_ctx "./window"
import "core:math/linalg"

flyCameraController :: proc(
	camera_position: linalg.Vector3f32,
	delta_time: f32,
) -> (
	linalg.Vector3f32,
	f32,
	f32,
) {
	sprint_mult: f32 = 4
	direction: linalg.Vector3f32
	if w_ctx.isKeyPressed(.W) {
		direction += math_ctx.VEC3FORWARD
	}
	if w_ctx.isKeyPressed(.S) {
		direction += math_ctx.VEC3BACK
	}
	if w_ctx.isKeyPressed(.D) {
		direction += math_ctx.VEC3RIGHT
	}
	if w_ctx.isKeyPressed(.A) {
		direction += math_ctx.VEC3LEFT
	}
	if w_ctx.isKeyPressed(.SPACE) {
		direction += math_ctx.VEC3UP
	}
	if w_ctx.isKeyPressed(.LCTRL) {
		direction += math_ctx.VEC3DOWN
	}

	direction = direction == 0 ? direction : linalg.normalize(direction) // normalize
	velocity := direction * delta_time

	if w_ctx.isKeyPressed(.LSHIFT) {
		velocity *= sprint_mult
	}

	pitch, yaw: f32

	if w_ctx.isMouseButtonPressed(.RIGHT) {
		look_sensitivity: f32 = 0.002

		mouse_position := w_ctx.getMousePosition()
		mouse_delta := look_sensitivity * -mouse_position

		pitch = linalg.clamp(mouse_delta.y, -1.54, 1.54)
		yaw = mouse_delta.x
	}

	return velocity, pitch, yaw
}

// TODO: temp
geometryController :: proc(
	geometry_rotation: linalg.Quaternionf32,
	geometry_translation: linalg.Vector3f32,
	delta_time: f32,
) -> (
	linalg.Quaternionf32,
	linalg.Vector3f32,
) {
	rotation_direction: linalg.Vector2f32
	if w_ctx.isKeyPressed(.P) {
		rotation_direction += math_ctx.VEC2UP
	}
	if w_ctx.isKeyPressed(.I) {
		rotation_direction += math_ctx.VEC2DOWN
	}
	if w_ctx.isKeyPressed(.E) {
		rotation_direction += math_ctx.VEC2RIGHT
	}
	if w_ctx.isKeyPressed(.Q) {
		rotation_direction += math_ctx.VEC2LEFT
	}

	rotation_direction =
		rotation_direction == 0 ? rotation_direction : linalg.normalize(rotation_direction) // normalize
	rotation_vector := rotation_direction * delta_time

	rotation := geometry_rotation
	rotation *= math_ctx.quaternionFromAxisAngle(math_ctx.VEC3UP, rotation_vector.x)
	rotation *= math_ctx.quaternionFromAxisAngle(math_ctx.VEC3LEFT, rotation_vector.y)


	direction: linalg.Vector3f32
	if w_ctx.isKeyPressed(.UP) {
		direction += math_ctx.VEC3FORWARD
	}
	if w_ctx.isKeyPressed(.DOWN) {
		direction += math_ctx.VEC3BACK
	}
	if w_ctx.isKeyPressed(.RIGHT) {
		direction += math_ctx.VEC3RIGHT
	}
	if w_ctx.isKeyPressed(.LEFT) {
		direction += math_ctx.VEC3LEFT
	}

	direction = direction == 0 ? direction : linalg.normalize(direction) // normalize
	translation := geometry_translation + (direction * delta_time)

	return rotation, translation
}
