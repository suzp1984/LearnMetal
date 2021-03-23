//
//  ShapeShader.metal
//  FrameBuffers
//
//  Created by Jacob Su on 3/23/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShapeShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(VertexAttributeIndexPosition)]];
    float2 texCoord [[attribute(VertexAttributeIndexTexcoord)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoords;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]]
                                   )
{
    RasterizerData out;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vertices[vertexID].position, 1.0);
    out.texCoords = vertices[vertexID].texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoords);
    
    return float4(colorSample);
}

vertex RasterizerData postVertexShader(uint vertexID [[vertex_id]],
                                       constant Vertex *vertices [[buffer(VertexInputIndexPosition)]])
{
    RasterizerData out;
        
    out.position = float4(vertices[vertexID].position, 1.0);
    out.texCoords = vertices[vertexID].texCoord;
    
    return out;
}

fragment float4 postFragmentShader(
                RasterizerData in [[stage_in]],
                                   texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoords);
    
    return float4(colorSample);
}

fragment float4 inversionFragmentShader(
                RasterizerData in [[stage_in]],
                                   texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoords);
    
    return float4(float3(1.0 - colorSample.rgb), 1.0);
}

fragment float4 grayscaleFragmentShader(
                RasterizerData in [[stage_in]],
                                   texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = texture.sample(textureSampler, in.texCoords);
    float average = colorSample.r * 0.2126 + colorSample.g * 0.7152 + colorSample.b * 0.0722;
    
    return float4(float3(average), 1.0);
}

float4 kernelFragmentShader(RasterizerData in,
                            texture2d<half> texture,
                            const float keernalArr[9]) {
    const float offset = 1.0 / 760.0;
    float2 offsets[9] = {
        float2(-offset,  offset),
        float2( 0.0,     offset),
        float2( offset,  offset),
        float2(-offset,  0.0),
        float2( 0.0,     0.0),
        float2( offset,  0.0),
        float2(-offset, -offset),
        float2( 0.0,    -offset),
        float2( offset, -offset)
    };
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    float3 sampleTex[9];
    for(int i = 0; i < 9; i++) {
        sampleTex[i] = float3(texture.sample(textureSampler, in.texCoords + offsets[i]).rgb);
    }
    
    float3 color = float3(0.0);
    for(int i = 0; i < 9; i++) {
        color += sampleTex[i] * keernalArr[i];
    }

    return float4(color, 1.0);
}

fragment float4 sharpenFragmentShader(RasterizerData in [[stage_in]],
                                      texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    float ker[9] = {
        -1.0, -1.0, -1.0,
        -1.0,  9.0, -1.0,
        -1.0, -1.0, -1.0
    };
    
    return kernelFragmentShader(in, texture, ker);
}

fragment float4 blurFragmentShader(RasterizerData in [[stage_in]],
                                   texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    float ker[9] = {
        1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
        2.0 / 16.0, 4.0 / 16.0, 2.0 / 16.0,
        1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
    };
    
    return kernelFragmentShader(in, texture, ker);
}

fragment float4 edgeDetectFragmentShader(RasterizerData in [[stage_in]],
                                         texture2d<half> texture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    float ker[9] = {
        1.0, 1.0, 1.0,
        1.0, -8.0, 1.0,
        1.0, 1.0, 1.0
    };
    
    return kernelFragmentShader(in, texture, ker);
}
