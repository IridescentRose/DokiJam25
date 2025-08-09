#version 450 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec2 tex_uv;
layout (location = 2) in vec3 inst_pos;
layout (location = 3) in vec2 inst_scale;
layout (location = 4) in vec4 inst_col;
layout (location = 5) in uint inst_tex;
layout (location = 6) in vec2 inst_uv_offset;
layout (location = 7) in vec2 inst_uv_scale;

out vec2 frag_uv;
out vec4 frag_col;
flat out uint frag_tex;

uniform mat4 proj;

void main() {
    vec3 pos = vert_pos * vec3(inst_scale, 1.0) + inst_pos;
    gl_Position = proj * vec4(pos, 1.0);
    frag_uv = tex_uv * inst_uv_scale + inst_uv_offset;
    frag_col = inst_col / 255.0;
    frag_tex = inst_tex;
}