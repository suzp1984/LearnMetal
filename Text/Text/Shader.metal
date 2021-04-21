//
//  Shader.metal
//  Text
//
//  Created by Jacob Su on 4/21/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

namespace Const {
    constexpr sampler linearSampler (mag_filter::linear, min_filter::linear);
}

struct RasterizationData {
    float4 position [[position]];
    float2 texCoords;
};

vertex RasterizationData vertexShader(uint vertexID [[vertex_id]],
                                      constant Vertex *verties [[buffer(0)]],
                                      constant float4x4 &projectionMatrix [[buffer(1)]]) {
    RasterizationData out;
    Vertex vert = verties[vertexID];
    
    out.position = projectionMatrix * float4(vert.position, 0.0, 1.0);
    out.texCoords = vert.texCoords;
    
    return out;
}

fragment float4 fragmentShader(RasterizationData in [[stage_in]],
                               texture2d<half> glyphTexture [[texture(0)]]) {
    half4 sampleColor = glyphTexture.sample(Const::linearSampler, in.texCoords);
    float c = sampleColor.r;
    if (c < 0.01) {
        discard_fragment();
    }
    
    return float4(c, c, c, 1.0);
    
}
