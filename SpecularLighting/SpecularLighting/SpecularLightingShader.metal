//
//  SpecularLightingShader.metal
//  SpecularLighting
//
//  Created by Jacob Su on 3/9/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShapeShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
    float3 fragPos;
    float3 normal;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    float3 position = vertices[vertexID].position;
    
    float3 fragPos = (uniforms.modelMatrix * vector_float4(position, 1.0)).xyz;
    
    out.fragPos = fragPos;
    out.normal = vertices[vertexID].normal;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * vector_float4(fragPos, 1.0);
    
    return out;
}

fragment float4 fragmentObjectShader(RasterizerData in [[stage_in]],
                               constant float3 &objectColor [[buffer(FragmentInputIndexObjectColor)]],
                               constant float3 &lightColor [[buffer(FragmentInputIndexLightColor)]],
                               constant float3 &lightPos [[buffer(FragmentInputIndexLightPos)]],
                               constant float3 &viewPos [[buffer(FragmentInputIndexViewPos)]])
{
    // ambient
    float ambientStrength = 0.1;
    float3 ambient = ambientStrength * lightColor;
    
    // diffuse
    float3 norm = normalize(in.normal);
    float3 lightDir = normalize(lightPos - in.fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse =  diff * lightColor;
    
    // specular
    float specularStrength = 0.5;
    float3 viewDir = normalize(viewPos - in.fragPos);
    float3 reflectDir = reflect(-lightDir, norm);
    
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    float3 specular = specularStrength * spec * lightColor;
    
    float3 result = (ambient + diffuse + specular) * objectColor;
    return float4(result, 1.0);
}

fragment float4 fragmentLampShader(RasterizerData in [[stage_in]])
{
    return float4(1.0);
}

