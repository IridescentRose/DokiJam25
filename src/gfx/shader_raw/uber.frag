#version 330 core
layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec3 NormalOut;

in vec4 vertexColor;
in vec2 uv;
in vec3 norm;

uniform sampler2D uTex;
uniform int hasTex;

void main()
{
    const vec3 lightDir = normalize(vec3(0, 0.5, 1));
    float lightStrength = max(dot(normalize(norm), -lightDir), 0.7);

    if (hasTex == 1) {
        FragColor = texture(uTex, uv) * vertexColor;
    } else {
        FragColor = vertexColor;
    }

    FragColor.rgb *= lightStrength;

    // TODO: USE LIGHTING WITH NORM

    if (FragColor.a < 1.0) {
        discard;
    }

    NormalOut = norm * 0.5 + 0.5;
}