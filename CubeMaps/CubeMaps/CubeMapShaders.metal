//
//  CubeMapShader.metal
//  4.7.CubeMaps
//
//  Created by Jacob Su on 3/23/21.
//

#include <metal_stdlib>
using namespace metal;
#include <simd/simd.h>

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

struct CubeMapVertexOutput
{
    float4 position [[position]];
    float3 texCoords;
};

vertex CubeMapVertexOutput cubeMapVertexShader(uint vertexID [[vertex_id]],
                                          constant CubeMapVertex *vertices [[buffer(VertexInputIndexPosition)]],
                                          constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]]) {
    CubeMapVertexOutput out;
    
    float3 position = vertices[vertexID].position;
    out.texCoords = position;
    matrix_float4x4 viewMatrix = uniforms.viewMatrix;
    for(int i = 0; i < 3; i++) {
        viewMatrix.columns[i][3] = 0.0;
    }
    
    viewMatrix.columns[3] = {0.0, 0.0, 0.0, 1.0};
    
    float4 p = uniforms.projectionMatrix * viewMatrix * float4(position, 1.0);
    out.position = p.xyww;
    
    return out;
}

fragment float4 cubeMapFragmentShader(CubeMapVertexOutput in [[stage_in]],
                                      texturecube<half> cubeTexture [[texture(CubeMapFragmentInputIndexCubeMap)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    return float4(cubeTexture.sample(textureSampler, in.texCoords));
}
