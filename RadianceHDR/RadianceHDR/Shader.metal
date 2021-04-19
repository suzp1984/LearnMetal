//
//  Shader.metal
//  RadianceHDR
//
//  Created by Jacob Su on 4/18/21.
//

#include <metal_stdlib>
using namespace metal;
#include "ShaderType.h"

namespace Const {
    constexpr sampler linearSampler (mag_filter::linear, min_filter::linear);
}

struct SkyDomeRasterizerData
{
    float4 position [[position]];
    float3 sampleDirection;
};

vertex SkyDomeRasterizerData SkyDomeVertexShader(const uint vertexID [[vertex_id]],
                                                 constant SkyDomeVertex *vertices [[buffer(SkyDomeVertexIndexPosition)]],
                                                 constant Uniform &uniform [[buffer(SkyDomeVertexIndexUniform)]]) {
    SkyDomeRasterizerData out;
    
    SkyDomeVertex vert = vertices[vertexID];
    float2 skyDomeDirection = vert.position;
    out.position = float4(skyDomeDirection, 0.9999, 1.0);
    
    float3 sampleDirection;
    sampleDirection.x = skyDomeDirection.x * uniform.skyDomeOffsets.x;
    sampleDirection.y = skyDomeDirection.y * uniform.skyDomeOffsets.y;
    sampleDirection.z = uniform.skyDomeOffsets.z;
    
    out.sampleDirection = (uniform.inverseViewMatrix * float4(sampleDirection, 1.0)).xyz;
    
    return out;
}

fragment half4 SkyDomeFragmentShader(SkyDomeRasterizerData in [[stage_in]],
                                     texture2d<half> skyTexture [[texture(0)]]) {

    float3 d = normalize(in.sampleDirection);
    float2 t = float2((atan2(d.z, d.x) + M_PI_F) / (2.0 * M_PI_F), acos(d.y) / M_PI_F);
    
    half3 color = skyTexture.sample(Const::linearSampler, t).rgb;
    
    // HDR tonemap and gamma correct
    color = color / (color + half3(1.0));
    color = pow(color, half3(1.0/2.2));
    
    return half4(clamp(color, half3(0.0), half3(500.0)), 1.0);
}
