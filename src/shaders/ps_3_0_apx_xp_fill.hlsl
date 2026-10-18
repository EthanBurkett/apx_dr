// A restrained metallic face for the thin XP fill. No flashing or scene effect.
sampler2D colorMapSampler : register(s0);
struct Input { float4 color : COLOR0; float2 uv : TEXCOORD0; };
float4 ps_main(Input input) : COLOR0
{
    float ridge = saturate(1.0 - abs(input.uv.y - 0.23) * 2.2);
    float face = lerp(0.64, 1.12, ridge);
    float4 color = tex2D(colorMapSampler, input.uv) * input.color;
    color.rgb *= face;
    return color;
}
