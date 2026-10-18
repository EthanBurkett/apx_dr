// 32 actual-model views, four seconds per revolution. Display one silhouette;
// crossfading different viewing angles produces ghost trails.
sampler2D colorMapSampler : register(s0);
struct Input { float4 color : COLOR0; float2 uv : TEXCOORD0; float phase : TEXCOORD1; };
float2 cell(float frame,float2 uv)
{
    float2 tile=float2(fmod(frame,4.0),floor(frame/4.0));
    return (tile+lerp(float2(0.004,0.004),float2(0.996,0.996),uv))/float2(4.0,8.0);
}
float4 ps_main(Input input) : COLOR0
{
    float selection=min(15.0,floor(input.color.r*16.0));
    float2 tile=float2(fmod(selection,4.0),floor(selection/4.0));
    float2 uv=(tile+cell(floor(input.phase+0.5),input.uv))/4.0;
    float4 view=tex2D(colorMapSampler,uv);
    return view*float4(1.0,input.color.g,input.color.b,input.color.a);
}
