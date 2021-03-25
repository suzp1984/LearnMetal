//
//  EnvironmentMapShader.metal
//  4.8.EnvironmentMap
//
//  Created by Jacob Su on 3/24/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"


typedef struct Vertex
{
    float3 position [[attribute(VertexAttributeIndexPosition)]];
    float3 normal   [[attribute(VertexAttributeIndexNormal)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float3 modelPosition;
    float3 normal;
    float3 cameraPos [[flat]];
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]]
                                   )
{
    RasterizerData out;
    
    Vertex vert = vertices[vertexID];
    
    float4x4 transposed = transpose(uniforms.inverseModelMatrix);
    float3x3 transpose3x3;
    transpose3x3.columns[0] = transposed.columns[0].xyz;
    transpose3x3.columns[1] = transposed.columns[1].xyz;
    transpose3x3.columns[2] = transposed.columns[2].xyz;
    
    out.normal = transpose3x3 * vert.normal;
    out.modelPosition = (uniforms.modelMatrix * float4(vert.position, 1.0)).xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vert.position, 1.0);
     out.cameraPos = uniforms.cameraPos;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texturecube<half> cubeTexture [[texture(FragmentInputIndexCubeTexture)]])
{
    float3 I = normalize(in.modelPosition - in.cameraPos);
    float3 R = reflect(I, normalize(in.normal));
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
//    const half4 colorSample = half4(cubeTexture.sample(textureSampler, R).rgb, 1.0);
    
    return float4(cubeTexture.sample(textureSampler, R));
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
    // remove view matrix transpose part
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
                                      texturecube<half> cubeTexture [[texture(FragmentInputIndexCubeTexture)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    return float4(cubeTexture.sample(textureSampler, in.texCoords));
}
