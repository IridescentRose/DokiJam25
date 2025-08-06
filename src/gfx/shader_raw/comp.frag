#version 330 core
layout(location = 0) out vec4 FragColor;

uniform sampler2D gAlbedo;
uniform sampler2D gNormal;
uniform sampler2D gDepth;

uniform vec2 uResolution;

uniform mat4 uInvProj;     // Inverse projection matrix
uniform mat4 uInvView;     // Inverse view matrix

uniform vec3 uSunDir;      // Normalized (e.g., vec3(-0.5, -1, -0.5))
uniform vec3 uSunColor;    // e.g., vec3(1.0)
uniform vec3 uAmbientColor;  // e.g., vec3(0.1)

uniform vec3 cameraPos; // Camera position in world space

uniform vec3 uFogColor;    // e.g., vec3(0.5, 0.6, 0.7)
uniform float uFogDensity; // e.g., 0.1

vec3 reconstructWorldPos(vec2 uv, float depth) {
    // Convert from [0,1] UV + depth to NDC
    float z = depth * 2.0 - 1.0;
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, z, 1.0);

    // View space
    vec4 viewSpace = uInvProj * clipSpace;
    viewSpace /= viewSpace.w;

    // World space
    vec4 worldPos = uInvView * viewSpace;
    return worldPos.xyz;
}

vec3 acesTonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0, 1.0);
}

vec3 applyBrightnessContrast(vec3 color, float brightness, float contrast) {
    color = color + brightness;
    color = (color - 0.5) * contrast + 0.5;
    return color;
}


void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;

    vec3 albedo = texture(gAlbedo, uv).rgb;

    // Extract from [0,1]
    vec3 normal = normalize(texture(gNormal, uv).xyz * 2.0 - 1.0);
    float depth = texture(gDepth, uv).r;

    // Skip background
    if (depth >= 1.0) {
        FragColor = vec4(0.0);
        return;
    }

    vec3 worldPos = reconstructWorldPos(uv, depth);

    // Lighting
    float diff = max(dot(normal, uSunDir), 0.0);

    // vec3 viewDir = normalize(cameraPos - worldPos);
    // vec3 halfDir = normalize(uSunDir + viewDir);
    // float spec = pow(max(dot(normal, halfDir), 0.0), 64.0); // shininess
    vec3 lit = albedo * (diff * uSunColor * 0.6 + uAmbientColor);// + spec * uSunColor;

    // Distance-based exponential fog
    float fogDistance = length(worldPos - cameraPos);

    // sqrt(2) / 2 * 48 
    float fogStart = 34.0;
    float fogAmount = 1.0 - exp(-(max(fogDistance - fogStart, 0.0)) * uFogDensity);
    fogAmount = clamp(fogAmount, 0.0, 1.0);

    vec3 toneMapped = acesTonemap(lit);
    toneMapped = mix(toneMapped, uFogColor, fogAmount);

    // Post processing
    toneMapped = mix(vec3(dot(toneMapped, vec3(0.2126, 0.7152, 0.0722))), toneMapped, 1.61); // saturation > 1.0
    toneMapped = applyBrightnessContrast(toneMapped, -0.05, 1.0); // Adjust brightness and contrast
    FragColor = vec4(toneMapped, 1.0);
}