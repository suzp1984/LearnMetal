//
//  Shader.metal
//  PointShadows
//
//  Created by Jacob Su on 4/4/21.
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
    float3 fragPos;
    uint   layer    [[render_target_array_index]];
};

vertex DepthOutput depthVertexShader(const uint instanceId [[instance_id]],
                                     Vertex vertice       [[stage_in]],
                                     constant ModelUniform &uniforms [[buffer(DepthVertexIndexModelUniform)]],
                                     constant InstanceParams *instances [[buffer(DepthVertexIndexInstanceParams)]]) {
    DepthOutput out;
    
    InstanceParams param = instances[instanceId];
    out.fragPos = (uniforms.modelMatrix * float4(vertice.position, 1.0)).xyz;
    
    out.position = param.lightSpaceMatrix * uniforms.modelMatrix * float4(vertice.position, 1.0);
    
    out.layer = param.layer;
    
    return out;
}

struct FragmentOut {
    float4 color [[color(0)]];
    float  depth [[depth(any)]];
};

fragment FragmentOut depthFragmentShader(DepthOutput in [[stage_in]],
                                         constant float3 &lightPos [[buffer(DepthFragmentIndexLightPos)]],
                                         constant float &farPlane  [[buffer(DepthFragmentIndexFarPlane)]]) {
    FragmentOut out;
    out.color = float4(1.0, 0.0, 0.0, 1.0);
    
    float lightDistance = length(in.fragPos - lightPos);
    lightDistance = lightDistance / farPlane;
    
    out.depth = lightDistance;
    
    return out;
}

struct RasterizerData
{
    float4 position [[position]];
    float3 fragPos;
    float3 normal;
    float2 texCoord;
};

vertex RasterizerData shadowVertexShader(Vertex vertice  [[stage_in]],
                                         constant Uniforms &uniform [[buffer(VertexInputIndexUniform)]]) {
    RasterizerData out;
    
    out.position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * float4(vertice.position, 1.0);
    out.fragPos = (uniform.modelMatrix * float4(vertice.position, 1.0)).xyz;
    
    float4x4 transposed = transpose(uniform.inverseModelMatrix);
    float3x3 transpose3x3;
    transpose3x3.columns[0] = transposed.columns[0].xyz;
    transpose3x3.columns[1] = transposed.columns[1].xyz;
    transpose3x3.columns[2] = transposed.columns[2].xyz;
    
    if (uniform.isContainer == 1.0) {
        out.normal = transpose3x3 * (-1.0 * vertice.normal);
    } else {
        out.normal = transpose3x3 * vertice.normal;
    }
    
    out.texCoord = vertice.texCoord;
    
    return out;
}

float ShadowCalculation(float3 fragPos,
                        float3 lightPos,
                        float3 viewPos,
                        float farPlane,
                        texturecube<half> depthMapTexture,
                        sampler textureSampler) {
    // get vector between fragment position and light position.
    float3 fragToLight = fragPos - lightPos;
    float currentDepth = length(fragToLight);
    float shadow = 0.0;
    
    float bias = 0.15;
    int samples = 20;
    float viewDistance = length(viewPos - fragPos);
    float diskRadius = (1.0 + (viewDistance / farPlane)) / 25.0;
    
    float3 gridSamplingDisk[20] = {
        float3(1.0, 1.0, 1.0), float3(1.0, -1.0, 1.0), float3(-1.0, -1.0, 1.0), float3(-1.0, 1.0, 1.0),
        float3(1.0, 1.0, -1.0), float3(1.0, -1.0, -1.0), float3(-1.0, -1.0, -1.0), float3(-1.0, 1.0, -1.0),
        float3(1.0, 1.0, 0.0), float3(1.0, -1.0, 0.0), float3(-1.0, -1.0, 0.0), float3(-1.0, 1.0, 0.0),
        float3(1.0, 0.0, 1.0), float3(-1.0, 0.0, 1.0), float3(1.0, 0.0, -1.0), float3(-1.0, 0.0, -1.0),
        float3(0.0, 1.0, 1.0), float3(0.0, -1.0, 1.0), float3(0.0, -1.0, -1.0), float3(0.0, 1.0, -1.0),
    };
    
    for(int i = 0; i < samples; i++) {
        float closestDepth = depthMapTexture.sample(textureSampler, fragToLight + gridSamplingDisk[i] * diskRadius).r;
        closestDepth *= farPlane;
        if ((currentDepth - bias) > closestDepth) {
            shadow += 1.0;
        }
    }
    shadow /= float(samples);
    
    return shadow;
}

fragment float4 shadowFragmentShader(RasterizerData in [[stage_in]],
                                     texture2d<half>   diffuseTexture    [[texture(FragmentInputIndexTexture)]],
                                     texturecube<half> depthMapTexture   [[texture(FragmentInputIndexDepthMap)]],
                                     constant float3 &lightPos [[buffer(FragmentInputIndexLightPos)]],
                                     constant float3 &viewPos  [[buffer(FragmentInputIndexViewPos)]],
                                     constant float  &farPlane [[buffer(FragmentInputindexFarPlane)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    float3 color = float3(diffuseTexture.sample(textureSampler, in.texCoord).rgb);
    float3 normal = normalize(in.normal);
    float3 lightColor = float3(0.3, 0.3, 0.3);
    // ambient
    float3 ambient = 0.3 * color;
    // diffuse
    float3 lightDir = normalize(lightPos - in.fragPos);
    float diff = max(dot(lightDir, normal), 0.0);
    float3 diffuse = diff * lightColor;
    // specular
    float3 viewDir = normalize(viewPos - in.fragPos);
//    float3 reflectDir = reflect(-lightDir, normal);
    float spec = 0.0;
    float3 halfwayDir = normalize(lightDir + viewDir);
    spec = pow(max(dot(normal, halfwayDir), 0.0), 64.0);
    float3 specular = spec * lightColor;
    // calculate shadow
    float shadow = ShadowCalculation(in.fragPos, lightPos, viewPos, farPlane, depthMapTexture, textureSampler);
//    shadow = 0.0;
    float3 lighting = (ambient + (1.0 - shadow) * (diffuse + specular)) * color;
    
    return float4(lighting, 1.0);
}
