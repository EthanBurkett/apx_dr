// RIFTHEART: obsidian clearcoat, layered dimensional plasma and live circuitry.
// All movement uses the engine clock. No GSC updates or client commands.
sampler2D colorMapSampler : register(s0);
samplerCUBE reflectionProbeSampler : register(s1);
sampler2D camoMapSampler : register(s2);
sampler3D modelLightingSampler : register(s4);
sampler2D specularMapSampler : register(s5);
float4 fogColor : register(c0);
float4 lightingLookupScale : register(c5);
float4 envMapParms : register(c6);
struct Input {
    float4 color : COLOR0;
    float2 uv : TEXCOORD0;
    float4 normalTime : TEXCOORD1;
    float4 viewFog : TEXCOORD2;
    float3 lightCoords : TEXCOORD3;
};

float3 energyPalette(float phase) {
    float blend = 0.5 + 0.5 * sin(phase);
    return lerp(float3(0.015, 0.78, 1.45), float3(0.93, 0.025, 1.25), blend);
}

float4 ps_main(Input input) : COLOR0 {
    float time = input.normalTime.w;
    float2 uv = input.uv;
    float3 N = normalize(input.normalTime.xyz);
    float3 V = normalize(input.viewFog.xyz);
    float facing = saturate(abs(dot(N, V)));
    float fresnel = pow(1.0 - facing, 3.4);
    // A derivative tangent frame makes the inner volume move beneath its UV
    // shell as the weapon turns, without extra mesh streams or bone changes.
    float3 dpdx = ddx(-input.viewFog.xyz);
    float3 dpdy = ddy(-input.viewFog.xyz);
    float2 duvdx = ddx(uv), duvdy = ddy(uv);
    float3 perpendicularX = cross(dpdy, N);
    float3 perpendicularY = cross(N, dpdx);
    float3 tangent = perpendicularX * duvdx.x + perpendicularY * duvdy.x;
    float3 bitangent = perpendicularX * duvdx.y + perpendicularY * duvdy.y;
    float inverseLength = rsqrt(max(max(dot(tangent,tangent), dot(bitangent,bitangent)), 0.000001));
    float2 parallax = float2(dot(V,tangent), dot(V,bitangent)) * inverseLength
                    / max(facing, 0.24) * 0.035;
    float4 field = tex2D(camoMapSampler, uv * 1.05);
    float4 drift = tex2D(camoMapSampler, uv * 1.7 + float2(time * 0.021, -time * 0.013));
    float2 warp = (drift.rg - 0.5) * 0.31;
    float3 volume = 0.0;
    // Separate depths, velocities and colors read as a moving interior rather
    // than a scrolling decal. Fixed sample count keeps SM3 cost predictable.
    float4 nearLayer = tex2D(camoMapSampler, uv*2.3 + warp + parallax
                               + float2(time*0.026, -time*0.019));
    float4 midLayer = tex2D(camoMapSampler, uv*3.8 - warp*0.6 + parallax*2.4
                               + float2(-time*0.015, time*0.028));
    float4 deepLayer = tex2D(camoMapSampler, uv*5.2 + warp*0.35 + parallax*4.5
                               + float2(time*0.012, time*0.009));
    float nearPlasma = pow(saturate(1.0-abs(nearLayer.r*2.0-1.0)), 5.0);
    float midPlasma = pow(saturate(1.0-abs(midLayer.g*2.0-1.0)), 7.0);
    float deepPlasma = pow(saturate(deepLayer.r*1.8-0.65), 3.0);
    volume += energyPalette(uv.x*8.0 + time*0.43) * nearPlasma * 0.75;
    volume += energyPalette(uv.y*9.0 - time*0.31 + 2.1) * midPlasma * 0.58;
    volume += float3(0.12,0.22,1.3) * deepPlasma * 0.45;
    float stars = pow(saturate(deepLayer.g*3.0-1.95), 12.0);
    volume += float3(0.60,0.87,1.0) * stars * 2.2;

    float4 stock = tex2D(colorMapSampler,uv);
    float3 specular = tex2D(specularMapSampler,uv).rgb;
    float luma = dot(stock.rgb,float3(0.299,0.587,0.114));
    float window = smoothstep(0.40,0.64,field.r);
    float cracks = pow(field.a, 1.8);
    float sweep = pow(saturate(0.5+0.5*sin(uv.x*27.0 + uv.y*14.0 - time*2.3)), 22.0);
    float circuit = field.b * (0.25 + 0.75*saturate(sin(time*1.7 + uv.y*34.0)));
    float3 edgeColor = energyPalette(uv.y*11.0 - time*0.55);
    float3 coatTint = lerp(float3(0.035,0.055,0.11), float3(0.18,0.025,0.24),field.g);
    float3 albedo = stock.rgb * (0.38+field.r*0.30) + coatTint*(0.25+luma);

    float3 lookupNormal = N / max(max(abs(N.x),abs(N.y)),abs(N.z));
    float3 ambient = tex3D(modelLightingSampler,
        input.lightCoords + lookupNormal*lightingLookupScale.xyz).rgb * 2.0;
    ambient = max(ambient, float3(0.18,0.20,0.28));
    float3 reflectionDirection = reflect(-V,N);
    float4 probe = texCUBE(reflectionProbeSampler,reflectionDirection);
    float3 reflection = probe.rgb * probe.a * specular
                      * (0.22 + fresnel*0.65) * max(envMapParms.x,0.25);
    float3 lightDirection = normalize(float3(0.35,-0.45,0.82));
    float coatHighlight = pow(saturate(dot(reflect(-lightDirection,N),V)),64.0);
    float3 surface = albedo * ambient * max(input.color.rgb,0.18) + reflection
                   + float3(0.35,0.65,1.0)*coatHighlight*0.55;
    float detail = 0.62 + luma*1.1;
    surface += volume * window * detail;
    surface += edgeColor * (cracks*(0.55+1.5*sweep) + circuit*0.36);
    surface += edgeColor * fresnel * (0.12 + 0.35*window);
    surface += float3(0.45,0.78,1.0)*sweep*window*0.28;
    return float4(lerp(fogColor.rgb,surface,input.viewFog.w),1.0);
}
