#version 330
layout (location = 0) in vec3 aPos;
layout (location = 1) in uint encodedOffset;
layout (location = 2) in vec3 aCol;

out vec3 vertexColor;
out vec2 uv;
out vec3 norm;

uniform mat4 projView;
uniform mat4 model;

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
    const uint MASK = 511u;

    vec3 pos = aPos;
    int face = int((encodedOffset >> 27) & 7u);

    mat3 rot = getFaceRotation(face);
 
    vec3 rotated = rot * pos;
    norm = rot * vec3(0, 1, 0); //(projView * model * vec4(rot * vec3(0, 1, 0), 1.0)).xyz;

    norm = mat3(transpose(inverse(model))) * norm;

    float xoff = float((encodedOffset) & MASK);
    float yoff = float((encodedOffset >> 9) & MASK);
    float zoff = float((encodedOffset >> 18) & MASK);

    vec3 off = vec3(xoff, yoff, zoff);

    gl_Position = projView * model * vec4(rotated + off, 1.0);
    vertexColor = aCol.rgb / 255.0;
}
