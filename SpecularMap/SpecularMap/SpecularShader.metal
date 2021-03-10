//
//  SpecularShader.metal
//  SpecularMap
//
//  Created by Jacob Su on 3/10/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShapeShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
    float3 fragPos;
    float3 normal;
    float2 texCoords;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    float3 position = vertices[vertexID].position;
    
    float3 fragPos = (uniforms.modelMatrix * vector_float4(position, 1.0)).xyz;
    
    out.texCoords = vertices[vertexID].texCoords;
    out.fragPos = fragPos;
    float4x4 transposed = transpose(uniforms.inverseModelMatrix);
    float3x3 transpose3x3;
    transpose3x3.columns[0] = transposed.columns[0].xyz;
    transpose3x3.columns[1] = transposed.columns[1].xyz;
    transpose3x3.columns[2] = transposed.columns[2].xyz;
    
    //out.normal = (transpose(uniforms.inverseModelMatrix) * float4(vertices[vertexID].normal, 1.0)).xyz;
    out.normal = transpose3x3 * vertices[vertexID].normal;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * vector_float4(fragPos, 1.0);
    
    return out;
}

typedef struct FragmentMaterialArguments {
    texture2d<half> diffuseTexture [[ id(FragmentArgumentMaterialBufferIDDiffuse) ]];
    texture2d<half> specularTexture [[ id(FragmentArgumentMaterialBufferIDSpecular) ]];
    float  shininess [[ id(FragmentArgumentMaterialBufferIDShininess) ]];
} FragmentMaterialArguments;

fragment float4 fragmentObjectShader(RasterizerData in [[stage_in]],
                               device FragmentMaterialArguments &material [[buffer(FragmentInputIndexMaterial)]],
                               constant Light &light [[buffer(FragmentInputIndexLight)]],
                               constant float3 &viewPos [[buffer(FragmentInputIndexViewPos)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);

    // ambient
    float3 ambient = light.ambient * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    
    // diffuse
    float3 norm = normalize(in.normal);
    float3 lightDir = normalize(light.position - in.fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse = light.diffuse * (diff * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb));
    
    // specular
    float3 viewDir = normalize(viewPos - in.fragPos);
    float3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    float3 specular = light.specular * (spec * float3(material.specularTexture.sample(textureSampler, in.texCoords).rgb));
    
    float3 result = ambient + diffuse + specular;
    return float4(result, 1.0);
}

fragment float4 fragmentLampShader(RasterizerData in [[stage_in]])
{
    return float4(1.0);
}

