#version 330 core
layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec4 outNormal;

in vec3 vertexColor;
in vec3 norm;

void main()
{
    FragColor = vec4(vertexColor, 1.0);
    outNormal = vec4(normalize(norm) * 0.5 + 0.5, 1);

    if (FragColor.a < 1.0) {
        discard;
    }
}