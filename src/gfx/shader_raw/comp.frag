#version 330 core
layout(location = 0) out vec4 FragColor;

uniform sampler2D gAlbedo;
uniform sampler2D gNormal;
uniform sampler2D gDepth;

uniform vec2 uResolution;

uniform mat4 uInvProj;     // inverse projection
uniform mat4 uInvView;     // inverse view
uniform mat4 uView;
uniform mat4 uProj;

uniform vec3 cameraPos;    // camera position (world)

uniform float uTime;       // 0..1 day cycle
uniform int uFrame;       // 0..1 day cycle

uniform vec3  uFogColor;   // not used (procedural sky fog)
uniform float uFogDensity; // base density (used via helper)

// --- reconstruction / tone helpers ---
vec3 reconstructWorldPos(vec2 uv, float depth) {
    float z = depth * 2.0 - 1.0;
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, z, 1.0);
    vec4 viewSpace = uInvProj * clipSpace;
    viewSpace /= viewSpace.w;
    vec4 worldPos = uInvView * viewSpace;
    return worldPos.xyz;
}

vec2 worldToScreen(vec3 p) {
    vec4 clip = uProj * uView * vec4(p, 1.0);
    vec2 ndc  = clip.xy / max(clip.w, 1e-6);
    return ndc * 0.5 + 0.5;
}

vec3 acesTonemap(vec3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 applyBrightnessContrast(vec3 color, float brightness, float contrast) {
    color += brightness;
    color = (color - 0.5) * contrast + 0.5;
    return color;
}

// --- sky math ---
vec3 rotateYaw(vec3 v, float deg) {
    float a = radians(deg);
    float c = cos(a), s = sin(a);
    mat3 R = mat3(
        c,   0.0,  s,
        0.0, 1.0,  0.0,
       -s,   0.0,  c
    );
    return normalize(R * v);
}

const float PI = 3.1415926535;

vec3 sunDirSimple(float t) {
    t = fract(t);
    float maxAlt = radians(75.0);
    float alt = sin(2.0 * PI * (t - 0.25)) * maxAlt;
    float az  = (PI * 0.5) + 2.0 * PI * t;
    return normalize(vec3(sin(az) * cos(alt), sin(alt), cos(az) * cos(alt)));
}

float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
}
float remap(float x, float a, float b) { return clamp((x - a) / (b - a), 0.0, 1.0); }

vec3 viewRay(vec2 uv) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, 1.0, 1.0);
    vec4 eye = uInvProj * ndc;
    vec3 vEye = normalize(eye.xyz / eye.w);
    return normalize((uInvView * vec4(vEye, 0.0)).xyz);
}

float softDiskCos(float cosTheta, float angRadius, float softnessMul) {
    float inner = cos(angRadius);
    float outer = cos(angRadius * softnessMul);
    return smoothstep(outer, inner, cosTheta);
}

// --- stars ---
float hash13(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float hash12(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec2 dirToOct(vec3 n) {
    n = normalize(n);
    n /= (abs(n.x) + abs(n.y) + abs(n.z) + 1e-6);
    vec2 uv = n.xz;
    if (n.y < 0.0) uv = (1.0 - abs(uv.yx)) * sign(uv);
    return uv * 0.5 + 0.5;
}

vec3 starfield(vec3 dir, float time, vec3 moonDir) {
    dir = normalize(dir);
    dir = rotateYaw(dir, time * 90.0); // slow drift

    vec2 uv = dirToOct(dir);
    const float TILE = 560.0;
    vec2 gid = floor(uv * TILE);
    vec2 f   = fract(uv * TILE);

    float h0  = hash12(gid);
    float h1  = hash12(gid + 101.0);
    float hx0 = hash12(gid + 13.0);
    float hx1 = hash12(gid + 37.0);

    float sel0 = step(0.9935, h0);
    float sel1 = step(0.9965, h1);

    vec2  p0   = vec2(hash12(gid + 17.0), hash12(gid + 29.0));
    float r0   = 0.22;
    float d0   = distance(f, p0);
    float core0= smoothstep(r0, r0 - 0.12, d0);
    float mag0 = mix(0.6, 1.0, pow(h0, 8.0));
    vec3  col0 = mix(vec3(0.86, 0.89, 1.0), vec3(1.0, 0.97, 0.93), hx0);

    vec2  p1   = vec2(hash12(gid + 53.0), hash12(gid + 71.0));
    float r1   = 0.18;
    float d1   = distance(f, p1);
    float core1= smoothstep(r1, r1 - 0.10, d1);
    float mag1 = mix(0.6, 1.0, pow(h1, 10.0));
    vec3  col1 = mix(vec3(0.86, 0.89, 1.0), vec3(1.0, 0.97, 0.93), hx1);

    float tw0 = 0.6 + 0.4 * sin(time * 6.0 + h0 * 6.2831853);
    float tw1 = 0.6 + 0.4 * sin(time * 6.3 + h1 * 6.2831853);

    float horizon = smoothstep(-0.05, 0.15, dir.y);

    float cosAng = dot(dir, normalize(moonDir));
    float ang    = acos(clamp(cosAng, -1.0, 1.0));
    float coreKill = smoothstep(radians(1.0),  radians(3.0),  ang);
    float wideFade = smoothstep(radians(6.0),  radians(15.0), ang);
    float altBoost = mix(0.6, 1.0, smoothstep(0.0, 0.35, moonDir.y));
    float moonFade = coreKill * wideFade * altBoost;

    vec3 stars0 = col0 * mag0 * tw0 * core0 * sel0;
    vec3 stars1 = col1 * mag1 * tw1 * core1 * sel1;
    return (stars0 + stars1) * horizon * moonFade;
}

// --- sky shader (HDR) ---
vec3 skyColor_HDR(vec3 V, vec3 sunDir, vec3 moonDir, float turbidity, float starMask) {
    float mu = dot(V, sunDir);
    float up = clamp(V.y, -0.1, 1.0);

    float sunVis = smoothstep(0.00, 0.04, sunDir.y);
    sunVis *= sunVis;
    sunVis *= step(0.0, sunDir.y);

    float day   = smoothstep(0.02, 0.20, sunDir.y);
    float night = 1.0 - day;

    vec3 zenithCol     = vec3(0.015, 0.055, 0.18);
    vec3 horizonDay    = vec3(0.50, 0.58, 0.70);
    vec3 horizonSunset = vec3(0.95, 0.40, 0.10);
    vec3 nightZenith   = vec3(0.0025, 0.005, 0.016);
    vec3 nightHorizon  = vec3(0.015, 0.025, 0.045);

    float sunAlt = clamp(sunDir.y, -0.2, 1.0);
    float warm = pow(smoothstep(-0.05, 0.30, sunAlt), 0.8);
    vec3 horizonCol = mix(horizonSunset, horizonDay, warm);

    vec3 sunLow  = vec3(1.0, 0.60, 0.28);
    vec3 sunHigh = vec3(1.0, 0.90, 0.65);
    float warmFactor = pow(smoothstep(-0.05, 0.30, sunAlt), 0.65);
    vec3 sunCol = mix(sunLow, sunHigh, warmFactor);

    float t = pow(clamp(up, 0.0, 1.0), 0.5 + 0.25 * warm);
    vec3 baseDay   = mix(horizonCol, zenithCol, t);
    vec3 baseNight = mix(nightHorizon, nightZenith, t);
    vec3 base = mix(baseNight, baseDay, day);

    float rayleigh = pow(1.0 - abs(mu), 2.0);
    float blueBoost = mix(0.8, 1.5, day);
    vec3 rayleighCol = vec3(0.12, 0.22, 0.85) * rayleigh * (blueBoost / max(1.0, turbidity)) * day;

    float mie = hgPhase(mu, 0.8) * 0.012 * (turbidity * 0.6 + 0.4) * sunVis;

    float sunAngular = 0.025;
    float sunDisk = smoothstep(cos(sunAngular * 4.0), cos(sunAngular), mu) * sunVis;

    float cosToMoon = dot(V, moonDir);
    float moonAltVis = smoothstep(0.00, 0.05, moonDir.y) * step(0.0, moonDir.y);
    float moonVis = moonAltVis * night;
    float moonAngular = 0.018;
    float moonDisk = softDiskCos(cosToMoon, moonAngular, 1.6) * moonVis;
    moonDisk = pow(moonDisk, 0.9);
    vec3  moonCol = vec3(0.85, 0.88, 1.0);
    float moonHalo = pow(max(cosToMoon, 0.0), 140.0) * 0.06 * moonVis;

    vec3 col = base + rayleighCol;
    vec3 mieCol = mix(sunCol, vec3(1.0, 0.85, 0.55), 0.4);
    col += mie * mieCol * 4.0;
    col += sunDisk * sunCol * 14.0;
    col += moonDisk * moonCol * 4.0;
    col += moonHalo * moonCol;

    float haze = clamp(turbidity * 0.18, 0.0, 0.6) * (1.0 - t);
    haze *= mix(0.8, 0.55, day);
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(col, vec3(lum), haze);

    vec3 stars = starfield(V, uTime, moonDir) * night * starMask;
    col += stars;

    return col;
}

// --- ambient from sky ---
vec3 skyAmbient(vec3 N, vec3 sunDir, vec3 moonDir, float turbidity) {
    float u = clamp(N.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 upCol   = skyColor_HDR(normalize(max(N, 0.0001)), sunDir, moonDir, turbidity, 0.0);
    vec3 downDir = normalize(vec3(N.x, -abs(N.y), N.z));
    vec3 dnCol   = skyColor_HDR(downDir, sunDir, moonDir, turbidity, 0.0) * 0.15;
    return mix(dnCol, upCol, u);
}

// --- fog helpers ---
float fogDensityAtY(float baseDensity, float y, float baseHeight, float heightFalloff) {
    return baseDensity * exp(-(y - baseHeight) * heightFalloff);
}

float fogFactorExp(float d, float baseDensity, float y0, float y1, float baseHeight, float heightFalloff) {
    float yMid = mix(y0, y1, 0.5);
    float sigma = fogDensityAtY(baseDensity, yMid, baseHeight, heightFalloff);
    return 1.0 - exp(-sigma * max(d, 0.0));
}

// --- dither ---
float ign(vec2 p) { return fract(52.9829189*fract(dot(p, vec2(0.06711056, 0.00583715)))); }

// -- godrays --
// Radial samples toward the sun position; depth masks occluders
vec3 godRays(vec2 uv, vec2 sunSS, float sunVis, vec3 sunCol) {
    const int   SAMPLES = 28;          // a hair fewer
    const float DENSITY = 0.85;        // shorter march per sample
    const float DECAY   = 0.94;        // more falloff
    const float WEIGHT  = 0.18;        // weaker per-tap
    const float EXPOSE  = 1.0;         // no extra boost

    // Move a bit each frame to reduce banding
    float jitter = fract(sin(float(uFrame)*12.9898)*43758.5453);
    vec2 dir = (sunSS - uv);
    vec2 stepUV = dir * (DENSITY / float(SAMPLES));
    vec2 coord  = uv + stepUV * jitter;
    float illum = 1.0;
    float sum   = 0.0;
    for (int i = 0; i < SAMPLES; ++i) {
        coord += stepUV;
        vec2 tc = clamp(coord, vec2(0.0), vec2(1.0));
        float z = texture(gDepth, tc).r;
        float sky = smoothstep(0.995, 1.0, z);   // 0=geometry, 1=sky
        sum += sky * illum;
        illum *= DECAY;
    }

    float pixZ    = texture(gDepth, uv).r;
    float pixSky  = smoothstep(0.995, 1.0, pixZ);
    float surfMix = mix(0.06, 1.0, pixSky);
    float rays = sum * WEIGHT * EXPOSE * sunVis * surfMix;

    return sunCol * rays;
}

// --- main ---
void main() {
    vec2 uv = gl_FragCoord.xy / uResolution;

    vec3 albedo = texture(gAlbedo, uv).rgb;

    vec3 sunDir = sunDirSimple(uTime);
    sunDir = rotateYaw(sunDir, 30.0);
    vec3 moonDir = normalize(-sunDir);

    float depth = texture(gDepth, uv).r;

    vec3 lit_color = vec3(0.0);
    if (depth >= 0.999) {
        vec3 V = viewRay(uv);
        lit_color = skyColor_HDR(V, sunDir, moonDir, 3.0, 1.0);
    } else {
        vec3 worldPos = reconstructWorldPos(uv, depth);
        vec3 N = normalize(texture(gNormal, uv).xyz * 2.0 - 1.0);
        vec3 V = normalize(cameraPos - worldPos);

        float day   = smoothstep(0.02, 0.20, sunDir.y);
        float night = 1.0 - day;

        float sunVis = smoothstep(0.00, 0.04, sunDir.y);
        sunVis *= sunVis;
        sunVis *= step(0.0, sunDir.y);
        float sunAlt = clamp(sunDir.y, -0.2, 1.0);

        vec3 sunLow  = vec3(1.0, 0.60, 0.28);
        vec3 sunHigh = vec3(1.0, 0.90, 0.65);
        float warmFactor = pow(smoothstep(-0.05, 0.30, sunAlt), 0.65);
        vec3 sunCol = mix(sunLow, sunHigh, warmFactor);
        vec3 sunColForFog = sunCol;

        float I_sun  = sunVis * 0.5;
        float I_moon = night * smoothstep(0.0, 0.12, moonDir.y) * 0.07;
        vec3  moonCol = vec3(0.85, 0.88, 1.0);

        float NdotLs = max(dot(N, normalize(sunDir)), 0.0);
        float NdotLm = max(dot(N, normalize(moonDir)), 0.0);

        vec3 direct = NdotLs * sunCol * I_sun + NdotLm * moonCol * I_moon;

        vec3 ambient = skyAmbient(N, sunDir, moonDir, 3.0);
        float dayAmt   = smoothstep(0.02, 0.20, sunDir.y);
        float nightAmt = 1.0 - dayAmt;
        float ambLum = dot(ambient, vec3(0.2126, 0.7152, 0.0722));
        ambient = mix(vec3(ambLum), ambient, mix(0.7, 0.5, dayAmt));
        float ambScale = mix(0.55, 0.35, dayAmt);
        ambient *= ambScale;
        vec3 nightFloor = vec3(0.02, 0.025, 0.035);
        ambient += nightFloor * nightAmt;

        lit_color = albedo * (direct + ambient);

        // --- screen-space god rays ---
        // Sun world point far away along direction (Directional light proxy)
        vec3 sunWorld = cameraPos + sunDir * 5000.0;
        vec2 sunSSRaw = worldToScreen(sunWorld);
        // allow sampling slightly offscreen, but fade with distance outside
        vec2 sunSS = clamp(sunSSRaw, vec2(-0.25), vec2(1.25));
        vec2 outside = max(vec2(0.0) - sunSSRaw, sunSSRaw - vec2(1.0));
        float offDist = length(max(outside, vec2(0.0)));
        float screenFade = smoothstep(0.35, 0.0, offDist); // 1 inside, 0 by ~35% offscreen

        // Sun visibility reused from your sky (approx)
        float sunVisForRays = smoothstep(0.00, 0.04, sunDir.y) * step(0.0, sunDir.y);

        // Day fade and horizon fade keep it subtle
        float horizonFade = smoothstep(0.0, 0.15, abs(sunSS.y - 0.5) + 0.1);


        float vis = sunVisForRays * dayAmt * screenFade * horizonFade;
        vis = smoothstep(0.0, 1.0, vis);
        vec3 rays = godRays(uv, sunSS, vis, sunCol);
        lit_color += rays;

        // fog
        vec3 viewDir = normalize(worldPos - cameraPos);
        float d = length(worldPos - cameraPos);
        float dEff = max(d - 33.0, 0.0);
        float f = fogFactorExp(dEff, 0.1, cameraPos.y, worldPos.y, 32.0, 0.008);
        f = clamp(f, 0.0, 1.0);

        vec3 fogCol = skyColor_HDR(viewDir, sunDir, moonDir, 3.0, 0.0);
        float muFog = dot(viewDir, sunDir);
        float mieFog = hgPhase(muFog, 0.8) * 0.15;
        fogCol += sunColForFog * mieFog * f * sunVis * 0.25;

        lit_color = mix(lit_color, fogCol, f);
    }

    vec3 toneMapped = acesTonemap(lit_color);

    float n = ign(gl_FragCoord.xy + float(uFrame)*13.0);
    vec3 dither = vec3(n - 0.5) / 255.0;
    toneMapped += dither;

    toneMapped = mix(vec3(dot(toneMapped, vec3(0.2126, 0.7152, 0.0722))), toneMapped, 1.31);
    FragColor = vec4(toneMapped, 1.0);
}
