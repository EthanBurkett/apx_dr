// Thick antialiased triangle edges; all interior fragments are discarded.
struct Input { float4 baryTime : TEXCOORD0; float fog : TEXCOORD1; };
float4 ps_main(Input input) : COLOR0 {
    float3 bary=input.baryTime.xyz;
    float3 distance=bary/max(fwidth(bary),0.00001);
    float nearest=min(distance.x,min(distance.y,distance.z));
    float coverage=1.0-smoothstep(2.5,4.0,nearest);
    clip(coverage-0.025);
    float time=input.baryTime.w;
    float3 spectrum=0.55+0.45*cos(6.2831853*(time*0.19+float3(0.0,0.33333,0.66667)));
    spectrum=pow(spectrum,0.65);
    float shimmer=0.88+0.12*sin(time*2.7);
    return float4(spectrum*0.85*coverage*input.fog*shimmer,coverage);
}
