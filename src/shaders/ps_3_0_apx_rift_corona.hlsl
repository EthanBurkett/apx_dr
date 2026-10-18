// Transparent additive clearcoat: chromatic edges and a traveling energy crown.
sampler2D camoMapSampler : register(s2);
struct Input {
    float4 color : COLOR0;
    float2 uv : TEXCOORD0;
    float4 normalTime : TEXCOORD1;
    float4 viewFog : TEXCOORD2;
    float3 lightCoords : TEXCOORD3;
};
float4 ps_main(Input input) : COLOR0 {
    float3 N=normalize(input.normalTime.xyz), V=normalize(input.viewFog.xyz);
    float edge=pow(1.0-saturate(abs(dot(N,V))),4.2);
    float time=input.normalTime.w;
    float4 field=tex2D(camoMapSampler,input.uv*1.05);
    float wave=pow(saturate(0.5+0.5*sin(input.uv.y*25.0-time*1.6)),8.0);
    float3 spectrum=0.55+0.45*cos(6.2831853*(edge*0.7+input.uv.x*0.1-time*0.035
                                     +float3(0.02,0.34,0.66)));
    float intensity=edge*(0.22+0.42*wave) + field.a*wave*0.13;
    float tint = max(dot(input.color.rgb,float3(0.299,0.587,0.114)),0.25);
    float ambientResponse = 0.92 + 0.08*saturate(length(input.lightCoords));
    return float4(spectrum*intensity*input.viewFog.w*tint*ambientResponse,0.0);
}
