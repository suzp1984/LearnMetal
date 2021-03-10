//
//  SquareRenderer.metal
//  IndexedElements
//
//  Created by Jacob Su on 3/4/21.
//

#include <metal_stdlib>
using namespace metal;

#include "SquareShaderType.h"

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
    
    float2 position = vertices[vertexID].position.xy;
    
    float4 pos = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vector_float4(position.xy, 0.0, 1.0);
    
    out.position = pos;
    out.texCoord = vertices[vertexID].texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> texture[[texture(FragmentInputIndexTexture)]],
                               texture2d<half> texture2[[texture(FragmentInputIndexTexture2)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoord);
    const half4 colorSample2 = texture2.sample(textureSampler, in.texCoord);
    
    return float4(mix(colorSample, colorSample2, 0.2));
}

