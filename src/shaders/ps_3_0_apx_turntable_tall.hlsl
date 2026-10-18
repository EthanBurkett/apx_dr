// 32 actual-model views, four seconds per revolution. Display one silhouette;
// crossfading different viewing angles produces double limbs and ghost trails.
sampler2D colorMapSampler : register(s0);
sampler2D page1Sampler : register(s1);
sampler2D page2Sampler : register(s2);
sampler2D page3Sampler : register(s3);
struct Input { float4 color : COLOR0; float2 uv : TEXCOORD0; float phase : TEXCOORD1; };
float2 cell(float frame,float2 uv)
{
    float2 tile=float2(fmod(frame,8.0),floor(frame/8.0));
    return (tile+lerp(float2(0.004,0.004),float2(0.996,0.996),uv))/float2(8.0,4.0);
}
float4 ps_main(Input input) : COLOR0
{
    float selection=min(15.0,floor(input.color.r*16.0));
    float2 tile=float2(fmod(selection,4.0),floor(selection/4.0));
    float page=floor(tile.x/2.0)+2.0*floor(tile.y/2.0);
    float2 uv=(fmod(tile,2.0)+cell(floor(input.phase+0.5),input.uv))/2.0;
    float4 view;
    if(page<0.5) view=tex2D(colorMapSampler,uv);
    else if(page<1.5) view=tex2D(page1Sampler,uv);
    else if(page<2.5) view=tex2D(page2Sampler,uv);
    else view=tex2D(page3Sampler,uv);
    return view*float4(1.0,input.color.g,input.color.b,input.color.a);
}
