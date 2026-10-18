// CoD4 menu expressions expose alpha only. Encode health in alpha 0.5..1;
// decode here, with fixed output opacity. SM2 retains a readable flat mint fill.
sampler2D colorMapSampler : register(s0);
struct Input { float4 color : COLOR0; float2 uv : TEXCOORD0; };
float4 ps_main(Input input) : COLOR0
{
    float health = saturate((input.color.a - 0.5) * 2.0);
    float3 critical = float3(0.94, 0.27, 0.20);
    float3 caution = float3(0.94, 0.72, 0.32);
    float3 healthy = float3(0.49, 0.81, 0.67);
    float3 color = lerp(critical, caution, saturate(health * 2.0));
    color = lerp(color, healthy, saturate((health - 0.5) * 2.0));
    float face = lerp(0.78, 1.05, saturate(1.0 - abs(input.uv.y - 0.25) * 2.0));
    float4 texel = tex2D(colorMapSampler, input.uv);
    return float4(color * face * texel.rgb, texel.a * 0.95);
}
