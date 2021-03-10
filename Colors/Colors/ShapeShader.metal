//
//  ShapeShader.metal
//  Colors
//
//  Created by Jacob Su on 3/8/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShapeShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    float3 position = vertices[vertexID].position;
    
    float4 pos = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vector_float4(position.xyz, 1.0);
    
    out.position = pos;
    
    return out;
}

fragment float4 fragmentObjectShader(RasterizerData in [[stage_in]],
                               constant float3 &objectColor [[buffer(FragmentInputIndexObjectColor)]],
                               constant float3 &lightColor [[buffer(FragmentInputIndexLightColor)]])
{
    return float4(lightColor * objectColor, 1.0);
}

fragment float4 fragmentLampShader(RasterizerData in [[stage_in]])
{
    return float4(1.0);
}
