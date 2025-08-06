#version 430
layout(location = 0) out vec4 FragColor;

uniform vec2 uResolution; // viewport resolution (in pixels)
uniform sampler2D uScene; // Scene texture for FXAA

vec3 applyFXAA(sampler2D tex, vec2 uv, vec2 resolution) {
    vec2 texel = 1.0 / resolution;

    vec3 rgbNW = texture(tex, uv + texel * vec2(-1.0, -1.0)).rgb;
    vec3 rgbNE = texture(tex, uv + texel * vec2( 1.0, -1.0)).rgb;
    vec3 rgbSW = texture(tex, uv + texel * vec2(-1.0,  1.0)).rgb;
    vec3 rgbSE = texture(tex, uv + texel * vec2( 1.0,  1.0)).rgb;
    vec3 rgbM  = texture(tex, uv).rgb;

    vec3 lumaWeights = vec3(0.299, 0.587, 0.114);
    float lumaNW = dot(rgbNW, lumaWeights);
    float lumaNE = dot(rgbNE, lumaWeights);
    float lumaSW = dot(rgbSW, lumaWeights);
    float lumaSE = dot(rgbSE, lumaWeights);
    float lumaM  = dot(rgbM,  lumaWeights);

    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

    vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * 0.25 * 0.5, 1.0 / 128.0);
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = clamp(dir * rcpDirMin, -8.0, 8.0) * texel;

    vec3 rgbA = 0.5 * (
        texture(tex, uv + dir * (1.0 / 3.0 - 0.5)).rgb +
        texture(tex, uv + dir * (2.0 / 3.0 - 0.5)).rgb
    );
    vec3 rgbB = rgbA * 0.5 + 0.25 * (
        texture(tex, uv + dir * -0.5).rgb +
        texture(tex, uv + dir * 0.5).rgb
    );

    float lumaB = dot(rgbB, lumaWeights);
    return (lumaB < lumaMin || lumaB > lumaMax) ? rgbA : rgbB;
}

void main() {
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec3 fxaaColor = applyFXAA(uScene, uv, uResolution);
    FragColor = vec4(fxaaColor, 1.0);
}