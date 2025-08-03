#version 330
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec4 aCol;
layout (location = 2) in vec2 aTex;
layout (location = 3) in vec3 aNorm;

out vec4 vertexColor;
out vec2 uv;
out vec3 norm;

uniform mat4 viewProj;
uniform mat4 model;

void main()
{
    gl_Position = vec4(aPos, 1.0) * model * viewProj;
    vertexColor = aCol;
    uv = aTex;
    norm = aNorm;
}
