#version 330 core
layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec3 NormalOut;

in vec3 vertexColor;
in vec3 norm;

void main()
{
    const vec3 lightDir = normalize(vec3(0, -0.6, 0.5));
    float lightStrength = max(dot(normalize(norm), -lightDir), 0.46);

    vec3 color = vertexColor * lightStrength;
    FragColor = vec4(color, 1.0);
    NormalOut = norm * 0.5 + 0.5;

    if (FragColor.a < 1.0) {
        discard;
    }
}