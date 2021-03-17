//
//  CubeShader.metal
//  RotatingCube
//
//  Created by Jacob Su on 3/17/21.
//

#include <metal_stdlib>
using namespace metal;

#include "CubeShaderType.h"

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
                               texture2d<half> texture[[texture(FragmentInputIndexTexture)]],
                               texture2d<half> texture2[[texture(FragmentInputIndexTexture2)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoord);
    const half4 colorSample2 = texture2.sample(textureSampler, in.texCoord);
    
    return float4(mix(colorSample, colorSample2, 0.2));
}
