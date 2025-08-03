#version 330 core
layout(location = 0) out vec4 FragColor;

in vec2 uv;

uniform sampler2D uTex;
uniform sampler2D uNorm;

#define LINE_WEIGHT 1.5

void main()
{
   float dx = (1.0 / 1280.0) * LINE_WEIGHT;
   float dy = (1.0 / 720.0) * LINE_WEIGHT;

   vec2 uvCenter   = uv;
   vec2 uvRight    = vec2(uvCenter.x + dx, uvCenter.y);
   vec2 uvTop      = vec2(uvCenter.x,      uvCenter.y - dx);
   vec2 uvTopRight = vec2(uvCenter.x + dx, uvCenter.y - dx);

   vec3 mCenter   = texture(uNorm, uvCenter).rgb;
   vec3 mTop      = texture(uNorm, uvTop).rgb;
   vec3 mRight    = texture(uNorm, uvRight).rgb;
   vec3 mTopRight = texture(uNorm, uvTopRight).rgb;

   vec3 dT  = abs(mCenter - mTop);
   vec3 dR  = abs(mCenter - mRight);
   vec3 dTR = abs(mCenter - mTopRight);

   float dTmax  = max(dT.x, max(dT.y, dT.z));
   float dRmax  = max(dR.x, max(dR.y, dR.z));
   float dTRmax = max(dTR.x, max(dTR.y, dTR.z));
   
   float deltaRaw = 0.0;
   deltaRaw = max(deltaRaw, dTmax);
   deltaRaw = max(deltaRaw, dRmax);
   deltaRaw = max(deltaRaw, dTRmax);

   // Lower threshold values will discard fewer samples
   // and give darker/thicker lines.
   float threshold    = 0.5;
   float deltaClipped = clamp((deltaRaw * 2.0) - threshold, 0.0, 1.0);

   float oI = deltaClipped;
   vec4 outline = vec4(oI, oI, oI, 1.0);
   vec4 albedo  = texture(uTex, uv);
   FragColor = albedo; // - outline;
}