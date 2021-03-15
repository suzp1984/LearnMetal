//
//  ShapeShader.metal
//  DrawTwoObjectsByOneEncoder
//
//  Created by Jacob Su on 3/15/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShapeShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoord;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
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
                               texture2d<half> texture [[texture(FragmentInputIndexTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    return float4(texture.sample(textureSampler, in.texCoord));
}
