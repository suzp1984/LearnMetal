//
//  MaterialShader.metal
//  Materials
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
                               constant Material &material [[buffer(FragmentInputIndexMaterial)]],
                               constant Light &light [[buffer(FragmentInputIndexLight)]],
                               constant float3 &viewPos [[buffer(FragmentInputIndexViewPos)]])
{
    // ambient
    float3 ambient = light.ambient * material.ambient;
    
    // diffuse
    float3 norm = normalize(in.normal);
    float3 lightDir = normalize(light.position - in.fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse = light.diffuse * (diff * material.diffuse);
    
    // specular
    float3 viewDir = normalize(viewPos - in.fragPos);
    float3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    float3 specular = light.specular * (spec * material.specular);
    
    float3 result = ambient + diffuse + specular;
    return float4(result, 1.0);
}

fragment float4 fragmentLampShader(RasterizerData in [[stage_in]])
{
    return float4(1.0);
}
