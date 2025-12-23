#version 460 core

layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec4 in_color;
layout(location = 2) in vec3 in_normal;

layout(location = 0) out vec4 out_color;

layout(set = 0, binding = 0) uniform uniform_object {
    mat4 projection;
    mat4 view;
    vec4 ambient_color;
    vec4 sunlight_direction;
    vec4 sunlight_color;
} u_scene;

layout(set = 1, binding = 0) uniform local_uniform_object {
    vec4 diffuse_color;
} u_obj;

layout(set = 1, binding = 1) uniform sampler2D diffuse_sampler;

void main() {
    float light_value = max(dot(in_normal, u_scene.sunlight_direction.xyz), 0.1f);

    vec4 color = in_color * (u_obj.diffuse_color * texture(diffuse_sampler, in_uv));
    vec4 ambient = color * u_scene.ambient_color;

    out_color = color * light_value * u_scene.sunlight_color.w + ambient;
    // out_color = in_color;
}
