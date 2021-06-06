//
//  Shader.metal
//  ModelUsdz
//
//  Created by Jacob Su on 5/19/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
    float2 texCoord [[attribute(ModelVertexAttributeTexcoord)]];
    float3 normal   [[attribute(ModelVertexAttributeNormal)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoords;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(ModelVertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(ModelVertexInputIndexUniforms)]]
                                   )
{
    RasterizerData out;
    
    Vertex vert = vertices[vertexID];
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vert.position, 1.0);
    out.texCoords = vert.texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    float3 colorSample = float3(diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    
    // gamma correct
    colorSample = pow(colorSample, float3(1.0/2.2));
    
    return float4(colorSample, 1.0);
}
