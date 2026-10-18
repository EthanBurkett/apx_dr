// PHASEWIRE: barycentric UVs survive the game's skinned viewmodel draw path.
float4x4 viewProjectionMatrix : register(c0);
float4x4 worldMatrix : register(c4);
float4 fogConsts : register(c21);
float4 gameTime : register(c22);
struct Input { float4 position : POSITION; float4 packedUV : TEXCOORD0; };
struct Output { float4 position : POSITION; float4 baryTime : TEXCOORD0; float fog : TEXCOORD1; };
float randomTarget(float seed) { return frac(sin(seed*12.9898+7.233)*43758.5453); }
float2 unpackModelUV(float4 bytes) {
    float2 bits=bytes.zx+bytes.wy*256.0;
    float2 signValue=1.0-2.0*floor(bits/32768.0);
    float2 exponent=floor(fmod(bits/1024.0,32.0));
    float2 mantissa=fmod(bits,1024.0)/1024.0;
    return signValue*lerp(mantissa/16384.0,(1.0+mantissa)*exp2(exponent-15.0),step(0.5,exponent));
}
Output vs_main(Input input) {
    Output output;
    float clock=gameTime.w*0.72;
    float phase=frac(clock); phase=phase*phase*(3.0-2.0*phase);
    float scale=lerp(0.72,1.62,lerp(randomTarget(floor(clock)),randomTarget(floor(clock)+1.0),phase));
    float3 localPosition=input.position.xyz;
    // Pin the grip inside the hand. The blade and guard visibly expand/shrink.
    float blade=smoothstep(0.5,3.8,localPosition.x);
    localPosition*=lerp(1.0,scale,blade);
    float4 world=mul(float4(localPosition,1.0),worldMatrix);
    output.position=mul(world,viewProjectionMatrix);
    float2 uv=unpackModelUV(input.packedUV);
    output.baryTime=float4(uv,1.0-uv.x-uv.y,gameTime.w);
    output.fog=saturate(exp2((length(world.xyz)*fogConsts.z+fogConsts.w)*1.442695));
    return output;
}
