// Eight independent stills per atlas; no temporal blending or resolution loss.
sampler2D colorMapSampler : register(s0);
struct Input { float4 color : COLOR0; float2 uv : TEXCOORD0; };
float4 ps_main(Input input) : COLOR0
{
    float frame=min(7.0,floor(input.color.r*8.0));
    float2 tile=float2(frame-2.0*floor(frame/2.0),floor(frame/2.0));
    float2 uv=(tile+lerp(float2(0.002,0.002),float2(0.998,0.998),input.uv))/float2(2.0,4.0);
    float4 view=tex2D(colorMapSampler,uv);
    return view*float4(1.0,input.color.g,input.color.b,input.color.a);
}
