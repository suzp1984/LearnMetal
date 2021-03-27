//
//  ModelShader.metal
//  ExploadingMesh
//
//  Created by Jacob Su on 3/27/21.
//

#include <metal_stdlib>
using namespace metal;
#include "ModelShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
    float2 texCoord [[attribute(ModelVertexAttributeTexcoord)]];
    float3 normal   [[attribute(ModelVertexAttributeNormal)]];
} Vertex;

kernel void exploadingCompute(uint vertexID [[ thread_position_in_grid ]],
                              constant float &time        [[ buffer(ComputeKernelIndexInputTime) ]],
                              device Vertex *inputVertex  [[ buffer(ComputeKernelIndexInputVertex) ]],
                              device Vertex *outputVertex [[ buffer(ComputeKernelIndexOutputVertex) ]]) {
    device Vertex &inputVert = inputVertex[vertexID];
    device Vertex &outputVert = outputVertex[vertexID];
    
    outputVert.texCoord = inputVert.texCoord;
    outputVert.normal   = inputVert.normal;
    outputVert.position = inputVert.position + normalize(inputVert.normal) * ((sin(time) + 1.0) / 2.0) * 1.0;
}

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoords;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(ModelVertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(ModelVertexInputIndexUniforms)]]
                                   )
{
    RasterizerData out;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vertices[vertexID].position, 1.0);
    out.texCoords = vertices[vertexID].texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const half4 colorSample = diffuseTexture.sample(textureSampler, in.texCoords);
    
    return float4(colorSample);
}
