//
//  Shader.metal
//  NormalMapping
//
//  Created by Jacob Su on 4/5/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoord;
    float3 fragPos;
    float3 tangentLightPos;
    float3 tangentViewPos;
    float3 tangentFragPos;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexPosition)]],
                                   constant Uniform &uniform [[buffer(VertexInputIndexUniforms)]]) {
    RasterizerData out;
    
    Vertex vertice = vertices[vertexID];
    out.fragPos = (uniform.modelMatrix * float4(vertice.position, 1.0)).xyz;
    out.texCoord = vertice.texCoord;
    float3 T = normalize(uniform.normalMatrix * vertice.tangent);
    float3 N = normalize(uniform.normalMatrix * vertice.normal);
    T = normalize(T - dot(T, N) * N);
    float3 B = cross(N, T);
    
    float3x3 TBN = transpose(matrix_float3x3(T, B, N));
    
    out.tangentLightPos = TBN * uniform.lightPos;
    out.tangentViewPos  = TBN * uniform.viewPos;
    out.tangentFragPos  = TBN * out.fragPos;
    
    out.position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * float4(vertice.position, 1.0);
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture [[texture(FragmentInputIndexDiffuseMap)]],
                               texture2d<half> normalMap [[texture(FragmentInputIndexNormalMap)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    // obtain normal from normal map in range [0, 1]
    float3 normal = float3(normalMap.sample(textureSampler, in.texCoord).rgb);
    // transform normal vector to range [-1, 1]
    normal = normalize(normal * 2.0 - 1.0);
    
    // get diffuse color
    float3 color = float3(diffuseTexture.sample(textureSampler, in.texCoord).rgb);
    
    // ambient
    float3 ambient = 0.1 * color;
    
    // diffuse
    float3 lightDir = normalize(in.tangentLightPos - in.tangentFragPos);
    float diff = max(dot(lightDir, normal), 0.0);
    float3 diffuse = diff * color;
    
    // specular
    float3 viewDir = normalize(in.tangentViewPos - in.tangentFragPos);
    float3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfwayDir), 0.0), 32.0);
    
    float3 specular = float3(0.2) * spec;
    
    return float4(ambient + diffuse + specular, 1.0);
}
