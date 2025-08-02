#version 330 core
out vec4 FragColor;

in vec4 vertexColor;
in vec2 uv;
in vec3 norm;

uniform sampler2D uTex;

void main()
{
    FragColor = texture(uTex, uv) * vertexColor;
    // TODO: USE LIGHTING WITH NORM
}