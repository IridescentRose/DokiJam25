#version 330
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 offset;
layout (location = 2) in vec3 aCol;

out vec3 vertexColor;

uniform mat4 projView;
uniform mat4 model;
uniform float yaw;
uniform float pitch;

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


    vec3 rotated = billboard_rot * aPos;
    vec3 world_pos = offset + rotated;


    gl_Position = projView * model * vec4(world_pos, 1.0);
    vertexColor = aCol.rgb / 255.0;
}
