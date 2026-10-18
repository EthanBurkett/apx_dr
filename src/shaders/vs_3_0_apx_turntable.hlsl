// Engine gameTime is bound by the SDK's named vertex-constant mapping.
float4x4 worldViewProjectionMatrix : register(c0);
float4 gameTime : register(c22);
struct Input { float4 position : POSITION; float4 color : COLOR0; float2 uv : TEXCOORD0; };
struct Output { float4 position : POSITION; float4 color : COLOR0; float2 uv : TEXCOORD0; float phase : TEXCOORD1; };
Output vs_main(Input input)
{
    Output output;
    output.position=mul(float4(input.position.xyz,1),worldViewProjectionMatrix);
    output.color=input.color;
    output.uv=input.uv;
    // One discrete view every 125 ms, in forward atlas order. Quantize before
    // interpolation so the entire preview changes on the same frame.
    output.phase=fmod(floor(gameTime.w*8.0),32.0);
    return output;
}
