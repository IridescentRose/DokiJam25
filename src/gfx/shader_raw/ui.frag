#version 450 core
#extension GL_ARB_bindless_texture : require

layout(location = 0) out vec4 FragColor;

in vec2 frag_uv;
in vec4 frag_col;
flat in uint frag_tex;

layout(std430, binding = 3) buffer UIHandles {  // Changed to buffer, std430, binding=3
    sampler2D texture_handles[];
};

void main() {
    vec4 color = frag_col;

    if (frag_tex != 0u) {
        vec4 texColor = texture(texture_handles[frag_tex - 1u], frag_uv);
        color *= texColor;
    }

    FragColor = color;
}