#version 460 core

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec2 in_uv; // texture coordinates
layout(location = 2) in vec4 in_color;
layout(location = 3) in vec2 in_normal;

layout(set = 0, binding = 0) uniform uniform_object {
    mat4 projection;
    mat4 view;
} u_camera;

layout(push_constant) uniform push_constants {
    mat4 model_matrix;
} p_constants;

layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec4 out_color;

void main()
{
    gl_Position = u_camera.projection * u_camera.view * p_constants.model_matrix * vec4(in_position, 1.0);
    out_uv = in_uv;
    out_color = in_color;
}
