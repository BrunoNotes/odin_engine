#version 460 core

layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec4 in_color;

layout(location = 0) out vec4 out_color;

layout(set = 1, binding = 0) uniform local_uniform_object {
    vec4 diffuse_color;
} u_obj;

layout(set = 1, binding = 1) uniform sampler2D diffuse_sampler;

void main() {
    out_color = in_color * (u_obj.diffuse_color * texture(diffuse_sampler, in_uv));
    // out_color = in_color;
}
