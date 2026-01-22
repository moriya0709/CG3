#include "object3d.hlsli"

struct Material
{
    float32_t4 color;
    int32_t enableLighting;
    float32_t4x4 uvTransform;
    float32_t shininess;
};

struct DirectionalLight
{
    float32_t4 color; // ライトの色
    float32_t3 direction; // ライトの向き
    float intensity; // 輝度
    bool isActive; // ライトの有効無効
};

struct PointLight
{
    float32_t4 color; // ライトの色
    float32_t3 position; // ライトの位置
    float intensity; // 輝度
    bool isActive; // ライトの有効無効
};

struct Camera
{
    float32_t3 worldPosition;
};

ConstantBuffer<Material> gMaterial : register(b0);
ConstantBuffer<DirectionalLight> gDirectionalLight : register(b1);
ConstantBuffer<Camera> gCamera : register(b2);
ConstantBuffer<PointLight> gPointLight : register(b3);

struct PixelShaderOutput
{
    float32_t4 color : SV_TARGET0;
};

Texture2D<float32_t4> gTexture : register(t0);
SamplerState gSampler : register(s0);

PixelShaderOutput main(VertexShaderOutput input)
{
    PixelShaderOutput output;
    float4 transformedUV = mul(float32_t4(input.texcoord, 0.0f, 1.0f), gMaterial.uvTransform);
    float32_t4 textureColor = gTexture.Sample(gSampler, transformedUV.xy);
    float32_t3 toEye = normalize(gCamera.worldPosition - input.worldPosition);
    
    float32_t3 pointLightDirection = normalize(input.worldPosition - gPointLight.position);

    if (gMaterial.enableLighting != 0)
    {
        float3 result = float3(0.0f, 0.0f, 0.0f);
        
        
        // *Directional* //
        if (gDirectionalLight.isActive)
        {
            // 拡散反射計算
            float NdotL = saturate(dot(normalize(input.normal), -gDirectionalLight.direction));
            float cos = pow(NdotL * 1.0f + 0.1f, 2.0f);
        
            // 鏡面反射計算
            float32_t3 halfVector = normalize(-gDirectionalLight.direction + toEye);
            float NDotH = dot(normalize(input.normal), halfVector);
            float specularPow = pow(saturate(NDotH), gMaterial.shininess); // 反射強度
         
            // 拡散反射
            float32_t3 diffuse = gMaterial.color.rgb * textureColor.rgb * gDirectionalLight.color.rgb * cos * gDirectionalLight.intensity;
            // 鏡面反射
            float32_t3 specular = gDirectionalLight.color.rgb * gDirectionalLight.intensity * specularPow * float32_t3(1.0f, 1.0f, 1.0f);
        
            result += diffuse + specular;    
        }
        
        
        // *Point* //
        if (gPointLight.isActive)
        {
            // 拡散反射計算
            float NdotL = saturate(dot(normalize(input.normal), -pointLightDirection));
            float cos = pow(NdotL * 1.0f + 0.1f, 2.0f);
        
            // 鏡面反射計算
            float32_t3 halfVector = normalize(-pointLightDirection + toEye);
            float NDotH = dot(normalize(input.normal), halfVector);
            float specularPow = pow(saturate(NDotH), gMaterial.shininess); // 反射強度
         
            // 拡散反射
            float32_t3 diffuse = gMaterial.color.rgb * textureColor.rgb * gPointLight.color.rgb * cos * gPointLight.intensity;
            // 鏡面反射
            float32_t3 specular = gPointLight.color.rgb * gPointLight.intensity * specularPow * float32_t3(1.0f, 1.0f, 1.0f);
        
            result += diffuse + specular;
        }
        
        // 拡散反射+鏡面反射
        output.color.rgb = result;
        output.color.a = gMaterial.color.a * textureColor.a;
    }
    else
    {
        output.color = gMaterial.color * textureColor;
    }
    
    // textureのa値が0の時にPixelを棄却する
    if (textureColor.a == 0.0f)
    {
        discard;
    }
    // output.colorのa値が0の時にPixelを棄却する
    if (output.color.a == 0.0f)
    {
        discard;
    }
    
    return output;
}
