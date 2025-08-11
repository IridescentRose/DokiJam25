#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 off;
layout (location = 2) in vec4 aCol;

uniform mat4 uModel;
uniform mat4 uProj;

mat3 rotateX(float a) {
    float s = sin(a), c = cos(a);
    return mat3(1, 0, 0,
                0, c, -s,
                0, s, c);
}

mat3 rotateY(float a) {
    float s = sin(a), c = cos(a);
    return mat3(c, 0, s,
                0, 1, 0,
               -s, 0, c);
}

mat3 rotateZ(float a) {
    float s = sin(a), c = cos(a);
    return mat3(c, -s, 0,
                s,  c, 0,
                0,  0, 1);
}

mat3 getFaceRotation(int face) {
    if (face == 0) return mat3(1); // top
    if (face == 1) return rotateX(radians(180.0)); // bottom
    if (face == 2) return rotateX(radians(-90.0)); // front
    if (face == 3) return rotateX(radians(90.0));  // back
    if (face == 4) return rotateZ(radians(-90.0)); // right
    if (face == 5) return rotateZ(radians(90.0));  // left
    return mat3(1); // default fallback
}


void main()
{
    vec3 pos = aPos;

    int face = int(aCol.a);
    mat3 rot = getFaceRotation(face);
 
    vec3 rotated = rot * pos;

    gl_Position = uProj * uModel * vec4(rotated + off, 1.0);
}
