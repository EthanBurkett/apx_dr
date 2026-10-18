// CoD4 model streams use byte-packed half UVs and packed normals, unlike HUDs.
// Packing verified against the installed SDK's model vertex shader bytecode.
float4x4 viewProjectionMatrix : register(c0);
float4x4 worldMatrix : register(c4);
float4 baseLightingCoords : register(c8);
float4 fogConsts : register(c21);
float4 gameTime : register(c22);

struct Input {
    float4 position : POSITION;
    float4 color : COLOR0;
    float4 packedUV : TEXCOORD0;
    float4 packedNormal : NORMAL;
};
struct Output {
    float4 position : POSITION;
    float4 color : COLOR0;
    float2 uv : TEXCOORD0;
    float4 normalTime : TEXCOORD1;
    float4 viewFog : TEXCOORD2;
    float3 lightCoords : TEXCOORD3;
};

float2 unpackModelUV(float4 bytes) {
    float2 bits = bytes.zx + bytes.wy * 256.0;
    float2 signValue = 1.0 - 2.0 * floor(bits / 32768.0);
    float2 exponent = floor(fmod(bits / 1024.0, 32.0));
    float2 mantissa = fmod(bits, 1024.0) / 1024.0;
    float2 normal = (1.0 + mantissa) * exp2(exponent - 15.0);
    float2 subnormal = mantissa / 16384.0;
    return signValue * lerp(subnormal, normal, step(0.5, exponent));
}

Output vs_main(Input input) {
    Output output;
    float4 world = mul(float4(input.position.xyz, 1.0), worldMatrix);
    float3 objectNormal = (input.packedNormal.xyz / 127.0 - 1.0)
                        * (input.packedNormal.w / 255.0 + 0.752941176);
    float3 normal = mul(float4(objectNormal, 0.0), worldMatrix).xyz;
    output.position = mul(world, viewProjectionMatrix);
    output.color = input.color;
    output.uv = unpackModelUV(input.packedUV);
    output.normalTime = float4(normal, gameTime.w);
    // CoD4's model world matrix is camera-relative; this remains valid for
    // animated viewmodels, player-held worldmodels and dropped weapons.
    output.viewFog = float4(-world.xyz,
        saturate(exp2((length(world.xyz) * fogConsts.z + fogConsts.w) * 1.442695)));
    output.lightCoords = baseLightingCoords.xyz;
    return output;
}
