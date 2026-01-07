#version 460 core

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec2 in_uv; // texture coordinates
layout(location = 2) in vec4 in_color;
layout(location = 3) in vec3 in_normal;

layout(set = 0, binding = 0) uniform uniform_object {
    mat4 projection;
    mat4 view;
    vec4 ambient_color;
    vec4 sunlight_direction;
    vec4 sunlight_color;
} u_scene;

layout(set = 1, binding = 0) uniform gltf_material_data{   

	vec4 color_factors;
	vec4 metal_rough_factors;
	
} material_data;

layout(push_constant) uniform push_constants {
    mat4 transform_matrix;
} p_constants;



layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec4 out_color;
layout(location = 2) out vec3 out_normal;

void main()
{
    gl_Position = u_scene.projection * u_scene.view * p_constants.transform_matrix * vec4(in_position, 1.0);
    out_uv = in_uv;
    out_color = in_color * material_data.color_factors;
    out_normal = (p_constants.transform_matrix * vec4(in_normal, 0.f)).xyz;
}
