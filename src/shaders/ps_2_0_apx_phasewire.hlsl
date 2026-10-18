// SM2 fallback: relative-width triangle wires without derivative instructions.
struct Input { float4 baryTime : TEXCOORD0; float fog : TEXCOORD1; };
float4 ps_main(Input input) : COLOR0 {
    float nearest=min(input.baryTime.x,min(input.baryTime.y,input.baryTime.z));
    float coverage=1.0-smoothstep(0.045,0.08,nearest);
    clip(coverage-0.025);
    float3 spectrum=0.55+0.45*cos(6.2831853*(input.baryTime.w*0.19+float3(0.0,0.33333,0.66667)));
    return float4(spectrum*0.85*coverage*input.fog,coverage);
}
