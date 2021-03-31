//
//  Shader.metal
//  MSAA
//
//  Created by Jacob Su on 3/29/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
} Vertex;


struct RasterizerData
{
    float4 position [[position]];
    float2 texCoord;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniform)]])
{
    RasterizerData out;
    
    float3 position = vertices[vertexID].position;
    
    float4 pos = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(position, 1.0);
    
    out.position = pos;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]])
{
    return float4(0.0, 1.0, 0.0, 1.0);
}
