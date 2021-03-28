//
//  ModelShader.metal
//  Asteroids
//
//  Created by Jacob Su on 3/28/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ModelShaderType.h"

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
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vertices[vertexID].position, 1.0);
    out.texCoords = vertices[vertexID].texCoord;
    
    return out;
}

vertex RasterizerData rockVertexShader(uint vertexID [[vertex_id]],
                                   uint instanceID [[instance_id]],
                                   constant Vertex *vertices   [[buffer(ModelVertexInputIndexPosition)]],
                                   constant RockUniforms &uniforms [[buffer(ModelVertexInputIndexUniforms)]],
                                   constant RockModel *models  [[buffer(ModelVertexInputIndexModels)]]
                                   )
{
    RasterizerData out;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *models[instanceID].modelMatrix * float4(vertices[vertexID].position, 1.0);
    out.texCoords = vertices[vertexID].texCoord;
    
    return out;
}


fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = diffuseTexture.sample(textureSampler, in.texCoords);
    
    return float4(colorSample);
}
