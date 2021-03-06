//
//  ModelShader.metal
//  ModelLoadingObj
//
//  Created by Jacob Su on 3/16/21.
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
    
    Vertex vert = vertices[vertexID];
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vert.position, 1.0);
    out.texCoords = vert.texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = diffuseTexture.sample(textureSampler, in.texCoords);
    
    return float4(colorSample);
}
