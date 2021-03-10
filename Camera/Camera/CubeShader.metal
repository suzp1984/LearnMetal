//
//  CubeShader.metal
//  Camera
//
//  Created by Jacob Su on 3/8/21.
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
                                   uint objectIndex [[instance_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]],
                                   constant ObjectParams *objectParams [[buffer(VertexInputIndexObjParams)]])
{
    RasterizerData out;
    
    float3 position = vertices[vertexID].position;
    
    float4 pos = uniforms.projectionMatrix * uniforms.viewMatrix * objectParams[objectIndex].modelMatrix * vector_float4(position.xyz, 1.0);
    
    out.position = pos;
    out.texCoord = vertices[vertexID].texCoord;
    
    return out;
}

typedef struct FragmentArguments {
    texture2d<half> firstTexture[[id(ArgumentBufferIDTextureFirst)]];
    texture2d<half> secondTexture[[id(ArgumentBufferIDTextureSecond)]];
} FragmentArguments;

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               device FragmentArguments &fragmentArguments [[buffer(FragmentInputIndexArgument)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = fragmentArguments.firstTexture.sample(textureSampler, in.texCoord);
    const half4 colorSample2 = fragmentArguments.secondTexture.sample(textureSampler, in.texCoord);
    
    return float4(mix(colorSample, colorSample2, 0.2));
}
