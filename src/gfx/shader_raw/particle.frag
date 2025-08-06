#version 330 core
layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec4 outNormal;

in vec3 norm;
in vec3 vertexColor;

void main()
{
    FragColor = vec4(vertexColor, 0.7);
    outNormal = vec4(normalize(norm) * 0.5 + 0.5, 1.0);
}