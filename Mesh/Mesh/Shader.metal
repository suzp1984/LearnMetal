//
//  Shader.metal
//  Mesh
//
//  Created by Jacob Su on 4/14/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShapeType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
    float2 texCoord [[attribute(ModelVertexAttributeTexcoord)]];
    float3 normal   [[attribute(ModelVertexAttributeNormal)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoords;
    float3 fragPos;
    float3 normal;
};

vertex RasterizerData vertexShader(Vertex in [[stage_in]],
                                   constant Uniforms &uniform [[buffer(VertexInputIndexUniforms)]]) {
    RasterizerData out;
    
    float4 worldPos = uniform.modelMatrix * float4(in.position, 1.0);
    
    out.position = uniform.projectionMatrix * uniform.viewMatrix * worldPos;
    out.texCoords = in.texCoord;
    out.fragPos = worldPos.xyz;
    out.normal = uniform.normalMatrix * in.normal;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               constant Material &material [[buffer(FragmentInputIndexMaterial)]],
                               constant Light &light [[buffer(FragmentInputIndexLight)]],
                               constant float3 &viewPos [[buffer(FragmentInputIndexViewPos)]]) {
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
//    // blinn
//    float3 halfwayDir = normalize(lightDir + viewDir);
//    spec = pow(max(dot(normal, halfwayDir), 0.0), 16.0);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    float3 specular = light.specular * (spec * material.specular);
    
    float3 result = ambient + diffuse + specular;
    return float4(result, 1.0);
}
