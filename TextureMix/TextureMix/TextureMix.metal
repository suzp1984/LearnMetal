//
//  TextureMix.metal
//  TextureMix
//
//  Created by Jacob Su on 3/3/21.
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
                                   constant vector_uint2 *viewportSizePointer [[buffer(VertexInputIndexViewportSize)]])
{
    RasterizerData out;
    
    float2 screenSpacePosition = vertices[vertexID].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
    
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = screenSpacePosition / (viewportSize / 2.0);
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
