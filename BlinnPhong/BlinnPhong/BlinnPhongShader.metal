//
//  BlinnPhoneShader.metal
//  BlinnPhong
//
//  Created by Jacob Su on 4/1/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
    float3 normal   [[attribute(ModelVertexAttributeNormal)]];
    float2 texCoord [[attribute(ModelVertexAttributeTexCoord)]];
} Vertex;


struct RasterizerData
{
    float4 position [[position]];
    float3 fragPos;
    float3 normal;
    float2 texCoord;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(VertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniform)]]) {
    RasterizerData out;
    
    Vertex vert = vertices[vertexID];
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(vert.position, 1.0);
    out.fragPos = (uniforms.modelMatrix * float4(vert.position, 1.0)).xyz;
    
    float4x4 transposed = transpose(uniforms.inverseModelMatrix);
    float3x3 transpose3x3;
    transpose3x3.columns[0] = transposed.columns[0].xyz;
    transpose3x3.columns[1] = transposed.columns[1].xyz;
    transpose3x3.columns[2] = transposed.columns[2].xyz;
    
    out.normal = transpose3x3 * vert.normal;
    
    out.texCoord = vert.texCoord * 5.0;
    
    return out;
}

typedef struct FragmentShaderArguments {
    texture2d<half> plainTexture  [[ id(FragmentArgumentBufferIndexTexture)  ]];
    sampler         sampler       [[ id(FragmentArgumentBufferIndexSampler)  ]];
    device float3   &viewPos      [[ id(FragmentArgumentBufferIndexViewPosition) ]];
    float3          lightPos      [[ id(FragmentArgumentBufferIndexLightPosition) ]];
} FragmentShaderArguments;

fragment float4 blinnPhongFragmentShader(RasterizerData in [[stage_in]],
                                         device FragmentShaderArguments & fragmentShaderArgs [[ buffer(FragmentInputIndexArgumentBuffer) ]]
                                         )
{
    float3 color = float3(fragmentShaderArgs.plainTexture.sample(fragmentShaderArgs.sampler, in.texCoord).rgb);
    
    // ambient
    float3 ambient = 0.05 * color;
    // diffuse
    float3 lightDir = normalize(fragmentShaderArgs.lightPos - in.fragPos);
    float3 normal = normalize(in.normal);
    float diff = max(dot(lightDir, normal), 0.0);
    float3 diffuse = diff * color;
    // specular
    float3 viewDir = normalize(fragmentShaderArgs.viewPos - in.fragPos);
    // float3 reflectDir = reflect(-fragmentShaderArgs.lightPos, normal);
    float spec = 0.0;
    
    // blinn
    float3 halfwayDir = normalize(lightDir + viewDir);
    spec = pow(max(dot(normal, halfwayDir), 0.0), 16.0);
    
    float3 specular = float3(0.3) * spec;
    
    return float4(ambient + diffuse + specular, 1.0);
}

fragment float4 phongFragmentShader(RasterizerData in [[stage_in]],
                                         device FragmentShaderArguments & fragmentShaderArgs [[ buffer(FragmentInputIndexArgumentBuffer) ]]
                                         )
{
    float3 color = float3(fragmentShaderArgs.plainTexture.sample(fragmentShaderArgs.sampler, in.texCoord).rgb);
    
    // ambient
    float3 ambient = 0.05 * color;
    // diffuse
    float3 lightDir = normalize(fragmentShaderArgs.lightPos - in.fragPos);
    float3 normal = normalize(in.normal);
    float diff = max(dot(lightDir, normal), 0.0);
    float3 diffuse = diff * color;
    // specular
    float3 viewDir = normalize(fragmentShaderArgs.viewPos - in.fragPos);
    float spec = 0.0;
    
    // phong
    float3 reflectDir = reflect(-fragmentShaderArgs.lightPos, normal);
    spec = pow(max(dot(viewDir, reflectDir), 0.0), 8.0);
    
    float3 specular = float3(0.3) * spec;
    
    return float4(ambient + diffuse + specular, 1.0);
}
