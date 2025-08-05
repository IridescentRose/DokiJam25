#version 330 core
layout(location = 0) out vec4 FragColor;
in vec3 vertexColor;

void main()
{
    FragColor = vec4(vertexColor, 0.7);
}