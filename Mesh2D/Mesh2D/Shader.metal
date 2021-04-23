//
//  Shader.metal
//  Mesh2D
//
//  Created by Jacob Su on 4/23/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];;
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
};

vertex RasterizerData vertexShader(Vertex in [[stage_in]],
                                   constant Uniforms &uniform [[buffer(VertexInputIndexUniforms)]]) {
    RasterizerData out;
    
    out.position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * float4(in.position, 1.0);
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    return float4(1.0, 0.0, 0.0, 1.0);
}
