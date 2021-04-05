//
//  Shader.metal
//  GammaCorrection
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
    sampler         sampler       [[ id(FragmentArgumentBufferIndexSampler)  ]];
    device float3   &viewPos      [[ id(FragmentArgumentBufferIndexViewPosition) ]];
    array<float3, 4> lightPoses   [[ id(FragmentArgumentBufferIndexLightPosition) ]];
    array<float3, 4> lightColors  [[ id(FragmentArgumentBufferIndexLightColors) ]];
} FragmentShaderArguments;

float3 BlinnPhong(float3 normal,
                  float3 fragPos,
                  float3 lightPos,
                  float3 lightColor,
                  float3 viewPos,
                  bool hasGammaCorrection) {
    // diffuse
    float3 lightDir = normalize(lightPos - fragPos);
    float diff = max(dot(lightDir, normal), 0.0);
    float3 diffuse = diff * lightColor;
    // specular
    float3 viewDir = normalize(viewPos - fragPos);
//    float3 reflectDir = reflect(-lightDir, normal);
    float spec = 0.0;
    float3 halfwayDir = normalize(lightDir + viewDir);
    spec = pow(max(dot(normal, halfwayDir), 0.0), 64.0);
    float3 specular = spec * lightColor;
    // simple attenuation
//    float max_distance = 1.5;
    float distance = length(lightPos - fragPos);
    
    float attenuation = 1.0 / (hasGammaCorrection ? distance * distance : distance);
    
    diffuse *= attenuation;
    specular *= attenuation;
    
    return diffuse + specular;
}

fragment float4 blinnPhongWithGammaCorrectionFragmentShader(RasterizerData in [[stage_in]],
                                         device FragmentShaderArguments &fragmentShaderArgs [[ buffer(FragmentInputIndexArgumentBuffer) ]],
                                         texture2d<half> diffuseTexture[[texture(FragmentInputIndexTexture)]]
                                         )
{
    float3 color = float3(diffuseTexture.sample(fragmentShaderArgs.sampler, in.texCoord).rgb);
    
    float3 lighting = float3(0.0, 0.0, 0.0);
    for(int i = 0; i < 4; i++) {
        lighting += BlinnPhong(normalize(in.normal),
                               in.fragPos,
                               fragmentShaderArgs.lightPoses[i],
                               fragmentShaderArgs.lightColors[i],
                               fragmentShaderArgs.viewPos,
                               true);
    }
    color *= lighting;
    
    // gamma
    color = pow(color, float3(1.0/2.2));
    
    return float4(color, 1.0);
}

fragment float4 blinnPhongWithoutGammaCorrectionFragmentShader(RasterizerData in [[stage_in]],
                                         device FragmentShaderArguments &fragmentShaderArgs [[ buffer(FragmentInputIndexArgumentBuffer) ]],
                                         texture2d<half> diffuseTexture[[texture(FragmentInputIndexTexture)]]
                                         )
{
    float3 color = float3(diffuseTexture.sample(fragmentShaderArgs.sampler, in.texCoord).rgb);
    
    float3 lighting = float3(0.0, 0.0, 0.0);
    for(int i = 0; i < 4; i++) {
        lighting += BlinnPhong(normalize(in.normal),
                               in.fragPos,
                               fragmentShaderArgs.lightPoses[i],
                               fragmentShaderArgs.lightColors[i],
                               fragmentShaderArgs.viewPos,
                               false);
    }
    
    color *= lighting;
    
    return float4(color, 1.0);
}
