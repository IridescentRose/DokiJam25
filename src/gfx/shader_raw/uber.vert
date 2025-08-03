#version 330
layout (location = 0) in uint encodedPos;
layout (location = 1) in vec3 aCol;

out vec3 vertexColor;
out vec2 uv;
out vec3 norm;

uniform mat4 viewProj;
uniform mat4 model;

void main()
{
    const uint MASK = 511u;
    float x = float((encodedPos) & MASK);
    float y = float((encodedPos >> 9) & MASK);
    float z = float((encodedPos >> 18) & MASK);

    gl_Position = vec4(x, y, z, 1.0) * model * viewProj;
    vertexColor = aCol.rgb / 255.0;

    int face = int((encodedPos >> 27) & 7u);
    if (face == 0) {
        norm = vec3(0, 1, 0);
    } else if (face == 1) {
        norm = vec3(0, -1, 0);
    } else if (face == 2) {
        norm = vec3(0, 0, 1);
    } else if (face == 3) {
        norm = vec3(0, 0, -1);
    } else if (face == 4) {
        norm = vec3(1, 0, 0);
    } else if (face == 5) {
        norm = vec3(-1, 0, 0);
    }
}
