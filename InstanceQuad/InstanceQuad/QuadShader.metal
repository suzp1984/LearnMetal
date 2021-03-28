//
//  QuadShader.metal
//  InstanceQuad
//
//  Created by Jacob Su on 3/28/21.
//

#include <metal_stdlib>
using namespace metal;
#include "ShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
    float3 color;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   uint instanceID [[instance_id]],
                                   constant Vertex *verties [[buffer(VertexIndexPosition)]],
                                   constant QuadOffset *offsets [[buffer(VertexIndexOffset)]]) {
    RasterizerData out;
    
    out.position = float4(verties[vertexID].position + offsets[instanceID].offset, 0.0, 1.0);
    out.color = verties[vertexID].color;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    return float4(in.color, 1.0);
}
