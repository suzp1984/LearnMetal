//
//  Shader.metal
//  ShadowMapping
//
//  Created by Jacob Su on 4/2/21.
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

struct DepthOutput {
    float4 position [[position]];
};

vertex DepthOutput depthVertexShader(uint vertexID [[vertex_id]],
                                     constant Vertex *vertices [[buffer(DepthVertexIndexPosition)]],
                                     constant LightSpaceUniforms &uniforms [[buffer(DepthVertexIndexUniform)]]) {
    DepthOutput out;
    
    out.position = uniforms.lightSpaceMatrix * uniforms.modelMatrix * float4(vertices[vertexID].position, 1.0);
    
    return out;
}

fragment float4 depthFragmentShader(DepthOutput in [[stage_in]]) {
    return float4(1.0, 0.0, 0.0, 1.0);
}

struct RasterizerData
{
    float4 position [[position]];
    float4 fragPosInLightSpace;
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
    
//    out.fragPosInLightSpace = uniforms.lightSpaceMatrix * float4(out.fragPos, 1.0);
    out.fragPosInLightSpace = uniforms.lightSpaceMatrix * uniforms.modelMatrix * float4(vert.position, 1.0);
    out.texCoord = vert.texCoord * uniforms.texCoordScale;
    
    return out;
}

typedef struct FragmentShaderArguments {
    sampler         sampler       [[ id(FragmentArgumentBufferIndexSampler)  ]];
    device float3   &viewPos      [[ id(FragmentArgumentBufferIndexViewPosition) ]];
    float3          lightPos      [[ id(FragmentArgumentBufferIndexLightPosition) ]];
    float3          lightColor    [[ id(FragmentArgumentBufferIndexLightColor) ]];
} FragmentShaderArguments;

fragment float4 blinnPhongWithGammaCorrectionFragmentShader(RasterizerData in [[stage_in]],
                                        device FragmentShaderArguments &fragmentShaderArgs [[ buffer(FragmentInputIndexArgumentBuffer) ]],
                                        texture2d<half> diffuseTexture[[texture(FragmentInputIndexTexture)]],
                                        texture2d<half> depthMapTexture[[texture(FragmentInputIndexDepthMap)]]
                                         )
{
    float3 color = float3(diffuseTexture.sample(fragmentShaderArgs.sampler, in.texCoord).rgb);
    float3 normal = normalize(in.normal);
    float3 lightColor = float3(0.3);
    // ambient
    float3 ambient = 0.3 * color;
    // diffuse
    float3 lightDir = normalize(fragmentShaderArgs.lightPos - in.fragPos);
    float diff = max(dot(lightDir, normal), 0.0);
    float3 diffuse = diff * lightColor;
    // specular
    float3 viewDir = normalize(fragmentShaderArgs.viewPos - in.fragPos);
    float3 reflectDir = reflect(-lightDir, normal);
    float spec = 0.0;
    float3 halfwayDir = normalize(lightDir + viewDir);
    spec = pow(max(dot(normal, halfwayDir), 0.0), 64.0);
    float3 specular = spec * lightColor;
    
    // calculate shadow
    float3 projCoords = in.fragPosInLightSpace.xyz / in.fragPosInLightSpace.w;
    projCoords = projCoords * 0.5 + 0.5;
    // get closest depth value from light's perspective
    float closestDepth = depthMapTexture.sample(fragmentShaderArgs.sampler, projCoords.xy).r;
    // get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;
    // calculate bias (based on depth map resolution and slope)
    float bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);
    // check wether current frag pos is in shadow
    // PCF
    float shadow = 0.0;
    float2 texelSize = 1.0 / float2(depthMapTexture.get_width(), depthMapTexture.get_height());
//    float2 texelSize = 1.0 / float2(1024.0, 1024.0);

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            float pcfDepth = depthMapTexture.sample(fragmentShaderArgs.sampler, projCoords.xy + float2(x, y) * texelSize).r;
            shadow += currentDepth - bias > pcfDepth ? 1.0 : 0.0;
        }
    }
    
    shadow /= 9.0;
    
    if (projCoords.z > 1.0) {
        shadow = 0.0;
    }
    
    float3 lighting = (ambient + (1.0 - shadow) * (diffuse + specular)) * color;
    
    // gamma
    lighting = pow(lighting, float3(1.0/2.2));
    
    return float4(lighting, 1.0);
}

