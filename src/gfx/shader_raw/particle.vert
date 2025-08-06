#version 330
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 offset;
layout (location = 2) in vec4 aCol;

out vec3 vertexColor;
out vec3 norm;

uniform mat4 projView;
uniform mat4 model;
uniform float yaw;
uniform float pitch;


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
    float cosYaw = cos(yaw);
    float sinYaw = sin(yaw);
    float cosPitch = cos(pitch);
    float sinPitch = sin(pitch);

    mat3 billboard_rot = mat3(
        vec3( cosYaw, 0.0, -sinYaw ),
        vec3( sinYaw * sinPitch, cosPitch, cosYaw * sinPitch ),
        vec3( sinYaw * cosPitch, -sinPitch, cosPitch * cosYaw )
    );

    int face = int(aCol.a);
    mat3 rot = getFaceRotation(face);
    vec3 pre_rotated = rot * aPos;

    vec3 modeled = (model * vec4(pre_rotated, 1.0)).xyz;
    vec3 rotated = billboard_rot * modeled;
    vec3 world_pos = offset + rotated;

    gl_Position = projView * vec4(world_pos, 1.0);
    vertexColor = aCol.rgb / 255.0;
    norm = rot * vec3(0, 1, 0);
}
