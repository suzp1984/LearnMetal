//
//  MultipleLightShader.metal
//  MultipleLight
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
    out.normal = normalize(transpose3x3 * vertices[vertexID].normal);
    
    out.position = uniform.projectionMatrix * uniform.viewMatrix * vector_float4(fragPos, 1.0);
    
    return out;
}

typedef struct FragmentMaterialArguments {
    texture2d<half> diffuseTexture [[ id(FragmentArgumentMaterialBufferIDDiffuse) ]];
    texture2d<half> specularTexture [[ id(FragmentArgumentMaterialBufferIDSpecular) ]];
    float  shininess [[ id(FragmentArgumentMaterialBufferIDShininess) ]];
} FragmentMaterialArguments;

typedef struct FragmentLightArguments {
    device DirLight  *dirLight  [[id(FragmentArgumentLightBufferIDDirLight)]];
    device PointLight *pointLight [[id(FragmentArgumentLightBufferIDPointLight)]];
    device SpotLight *spotLight [[id(FragmentArgumentLightBufferIDSpotLight)]];
    int pointLightNumber [[id(FragmentArgumentLightBufferIDPointNumber)]];
} FragmentLightArguments;

float3 calcDirLight(DirLight light, float3 viewDir,
                    device FragmentMaterialArguments &material,
                    sampler textureSampler,
                    RasterizerData in) {
    float3 lightDir = normalize(-light.direction);
    // diffuse shading
    float diff = max(dot(in.normal, lightDir), 0.0);
    // specular shading
    float3 reflectDir = reflect(-lightDir, in.normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // combine results
    float3 ambient = light.ambient * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float3 diffuse = light.diffuse * diff * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float3 specular = light.specular * spec * float3(material.specularTexture.sample(textureSampler, in.texCoords).rgb);
    
    return ambient + diffuse + specular;
}

float3 calcPointLight(PointLight light, float3 viewDir,
                      device FragmentMaterialArguments &material,
                      sampler textureSampler,
                      RasterizerData in)
{
    float3 lightDir = normalize(light.position - in.fragPos);
    // diffuse shading
    float diff = max(dot(in.normal, lightDir), 0.0);
    // specular shading
    float3 reflectDir = reflect(-lightDir, in.normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // attenuation
    float distance = length(light.position - in.fragPos);
    float attenuation  = 1.0 / (light.constants + light.linear * distance + light.quadratic * (distance * distance));
    // combine results
    float3 ambient = light.ambient * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float3 diffuse = light.diffuse * diff * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float3 specular = light.specular * spec * float3(material.specularTexture.sample(textureSampler, in.texCoords).rgb);
    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;
    
    return  ambient + diffuse + specular;
}

float3 calcSpotLight(SpotLight light, float3 viewDir,
                     device FragmentMaterialArguments &material,
                     sampler textureSampler,
                     RasterizerData in)
{
    float3 lightDir = normalize(light.position - in.fragPos);
    // diffuse shading
    float diff = max(dot(in.normal, lightDir), 0.0);
    // specular shading
    float3 reflectDir = reflect(-lightDir, in.normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // attenuation
    float distance = length(light.position - in.fragPos);
    float attenuation = 1.0 / (light.constants + light.linear * distance + light.quadratic * (distance * distance));
    // spotlight intensity
    float theta = dot(lightDir, normalize(-light.direction));
    float epsilon = light.cutOff - light.outerCutOff;
    float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);
    // combine results
    float3 ambient = light.ambient * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float3 diffuse = light.diffuse * diff * float3(material.diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float3 specular = light.specular * spec * float3(material.specularTexture.sample(textureSampler, in.texCoords).rgb);
    ambient *= attenuation * intensity;
    diffuse *= attenuation * intensity;
    specular *= attenuation * intensity;
    
    return  ambient + diffuse + specular;
}

fragment float4 fragmentObjectShader(RasterizerData in [[stage_in]],
                               device FragmentMaterialArguments &material [[buffer(FragmentInputIndexMaterial)]],
                               device FragmentLightArguments &lightBuffer [[buffer(FragmentInputIndexLight)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    DirLight dirLight = lightBuffer.dirLight[0];
    
    SpotLight spotLight = lightBuffer.spotLight[0];
    float3 viewPos = spotLight.position;
    
    float3 viewDir = normalize(viewPos - in.fragPos);
    // phase 1: directional lighting
    float3 result = calcDirLight(dirLight, viewDir, material, textureSampler, in);
    // phase 2: point lights
    for(int i = 0; i < lightBuffer.pointLightNumber; i++) {
        PointLight pointLight = lightBuffer.pointLight[i];
        
        result += calcPointLight(pointLight, viewDir, material, textureSampler, in);
    }
    
    // phase 3: spot light
    result += calcSpotLight(spotLight, in.normal, material, textureSampler, in);
    
    return float4(result, 1.0);
}

fragment float4 fragmentLampShader(RasterizerData in [[stage_in]])
{
    return float4(1.0);
}
