// ApX HUD pass: preserve the engine's vertex tint and alpha.
float4x4 worldViewProjectionMatrix : register(c0);
struct Input { float4 position : POSITION; float4 color : COLOR0; float2 uv : TEXCOORD0; };
struct Output { float4 position : POSITION; float4 color : COLOR0; float2 uv : TEXCOORD0; };
Output vs_main(Input input)
{
    Output output;
    output.position = mul(float4(input.position.xyz, 1.0), worldViewProjectionMatrix);
    output.color = input.color;
    output.uv = input.uv;
    return output;
}
