//
//  Triangle.metal
//  Uniforms
//
//  Created by Jacob Su on 3/2/21.
//

#include <metal_stdlib>
using namespace metal;

#include "TriangleShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
                                   constant vector_uint2 *viewportSizePointer [[buffer(VertexInputIndexViewportSize)]])
{
    RasterizerData out;
    
    float2 screenSpacePosition = vertices[vertexID].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
    
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = screenSpacePosition / (viewportSize / 2.0);
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               constant float *greenColor [[buffer(VertexInputIndexVertices)]])
{
    return float4(0.0, *greenColor, 0.0, 1.0);
}
