//
//  ShapeShader.metal
//  4.1.DepthTesting
//
//  Created by Jacob Su on 3/17/21.
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
