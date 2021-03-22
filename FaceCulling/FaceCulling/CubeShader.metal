//
//  CubeShader.metal
//  FaceCulling
//
//  Created by Jacob Su on 3/22/21.
//

#include <metal_stdlib>
using namespace metal;

#include "CubeShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(VertexAttributeIndexPosition)]];
    float2 texCoord [[attribute(VertexAttributeIndexTexcoord)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoord;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    float3 position = vertices[vertexID].position;
    
    float4 pos = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vector_float4(position.xyz, 1.0);
    
    out.position = pos;
    out.texCoord = vertices[vertexID].texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> texture[[texture(FragmentInputIndexTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoord);
    
    return float4(colorSample);
}
