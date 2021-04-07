//
//  shader.metal
//  hdr
//
//  Created by Jacob Su on 4/7/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
    float3 normal   [[attribute(ModelVertexAttributeNormal)]];
    float2 texCoord [[attribute(ModelVertexAttributeTexCoord)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float3 fragPos;
    float3 normal;
    float2 texCoord;
};

vertex RasterizerData lightVertexShader(Vertex in [[stage_in]],
                                        constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]]) {
    RasterizerData out;
    
    out.fragPos = (uniforms.modelMatrix * float4(in.position, 1.0)).xyz;
    out.texCoord = in.texCoord;
    out.normal = normalize(uniforms.normalMatrix * in.normal);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    
    return out;
}

fragment float4 lightFragmentShader(RasterizerData in [[stage_in]],
                                    texture2d<half> diffuseTexture [[texture(LightFragmentIndexDiffuseTexture)]],
                                    constant float3 &viewPos [[buffer(LightFragmentIndexViewPos)]],
                                    device Light *lights [[buffer(LightFragmentIndexLights)]],
                                    constant int &lightCount [[buffer(LightFragmentIndexLightCount)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    float3 color = float3(diffuseTexture.sample(textureSampler, in.texCoord).rgb);
    float3 normal = normalize(in.normal);
    // ambient
    float3 ambient = 0.0 * color;
    // lighting
    float3 lighting = float3(0.0);
    int count = lightCount;
    for (int i = 0; i < count; i++) {
        // diffuse
        float3 lightDir = normalize(lights[i].position - in.fragPos);
        float diff = max(dot(lightDir, normal), 0.0);
        float3 diffuse = lights[i].color * diff * color;
        float3 result = diffuse;
        
        // attenuation (use quadratic as we have gamma correction)
        float distance = length(in.fragPos - lights[i].position);
        result *= 1.0 / (distance * distance);
        lighting += result;
    }
    
    return float4(ambient + lighting, 1.0);
}

struct HDRRasterizerData
{
    float4 position [[position]];
    float2 texCoord;
};

vertex HDRRasterizerData HDRVertexShader(uint vertexID [[vertex_id]],
                                         constant HDRVertex *vertices [[buffer(HDRVertexInputPosition)]]) {
    HDRRasterizerData out;
    
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoords;
    
    return out;
}

fragment float4 HDRFragmentShader(HDRRasterizerData in [[stage_in]],
                                  texture2d<float> hdrTexture [[texture(HDRFragmentInputHDRTexture)]],
                                  constant int     &doHDR     [[buffer(HDRFragmentInputHDRSwitch)]],
                                  constant float   &exposure  [[buffer(HDRFragmentInputExposure)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    const float gamma = 2.2;
    float3 hdrColor = hdrTexture.sample(textureSampler, in.texCoord).rgb;
    if (doHDR >= 1) {
        // exposure
        float3 result = float3(1.0) - exp(-hdrColor * exposure);
        // also gamma correct while we're at it
        result = pow(result, float3(1.0 / gamma));
        return float4(result, 1.0);
    } else {
        float3 result = pow(hdrColor, float3(1.0/gamma));
        return float4(result, 1.0);
    }
}
