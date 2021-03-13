//
//  SpotLightShader.metal
//  SpotLightSoft
//
//  Created by Jacob Su on 3/13/21.
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
                                   uint objectIndex [[instance_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
                                   constant Uniforms *uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    Uniforms uniform = uniforms[objectIndex];
    
    float3 position = vertices[vertexID].position;
    
    float3 fragPos = (uniform.modelMatrix * vector_float4(position, 1.0)).xyz;
    
    out.texCoords = vertices[vertexID].texCoords;
    out.fragPos = fragPos;
    float4x4 transposed = transpose(uniform.inverseModelMatrix);
    float3x3 transpose3x3;
    transpose3x3.columns[0] = transposed.columns[0].xyz;
    transpose3x3.columns[1] = transposed.columns[1].xyz;
    transpose3x3.columns[2] = transposed.columns[2].xyz;
    
    //out.normal = (transpose(uniform.inverseModelMatrix) * float4(vertices[vertexID].normal, 1.0)).xyz;
    out.normal = transpose3x3 * vertices[vertexID].normal;
    
    out.position = uniform.projectionMatrix * uniform.viewMatrix * vector_float4(fragPos, 1.0);
    
    return out;
}

typedef struct FragmentMaterialArguments {
    texture2d<half> diffuseTexture [[ id(FragmentArgumentMaterialBufferIDDiffuse) ]];
    texture2d<half> specularTexture [[ id(FragmentArgumentMaterialBufferIDSpecular) ]];
    float  shininess [[ id(FragmentArgumentMaterialBufferIDShininess) ]];
} FragmentMaterialArguments;

typedef struct FragmentLightArguments {
    device Light  *light  [[id(FragmentArgumentLightBufferIDLight)]];
    float3 viewPos [[id(FragmentArgumentLightBufferIDViewPosition)]];
} FragmentLightArguments;

fragment float4 fragmentObjectShader(RasterizerData in [[stage_in]],
                               device FragmentMaterialArguments &material [[buffer(FragmentInputIndexMaterial)]],
                               device FragmentLightArguments &lightBuffer [[buffer(FragmentInputIndexLight)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);

    Light light = lightBuffer.light[0];
    
    
    
    // ambient
    float3 ambient = light.ambient * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    
    // diffuse
    float3 norm = normalize(in.normal);
    float3 lightDir = normalize(light.position - in.fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse = light.diffuse * (diff * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb));
    
    // specular
    float3 viewDir = normalize(lightBuffer.viewPos - in.fragPos);
    float3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    float3 specular = light.specular * (spec * float3(material.specularTexture.sample(textureSampler, in.texCoords).rgb));
    
    // spotlight (soft edges)
    float theta = dot(lightDir, normalize(-light.direction));
    float epsilon = light.cutOff - light.outerCutOff;
    float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);
    diffuse *= intensity;
    specular *= intensity;
    
    // attenuation
    float distance = length(light.position - in.fragPos);
    float attenuation = 1.0 / (light.constants + light.linear * distance + light.quadratic * (distance * distance));
    
    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;
    
    float3 result = ambient + diffuse + specular;
    return float4(result, 1.0);
    
}

