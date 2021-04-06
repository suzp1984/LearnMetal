//
//  Shader.metal
//  ParallaxMapping
//
//  Created by Jacob Su on 4/6/21.
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

float2 parallaxMapping(float2 texCoords,
                       float3 viewDir,
                       texture2d<half> depthMap,
                       sampler textureSampler,
                       float heightScale) {
    float height = depthMap.sample(textureSampler, texCoords).r;
    
    return texCoords - viewDir.xy * (height * heightScale);
}

float2 steepParallaxMapping(float2 texCoords,
                       float3 viewDir,
                       texture2d<half> depthMap,
                       sampler textureSampler,
                       float heightScale) {
    // number of depth layers
    const float minLayers = 8;
    const float maxLayers = 32;
    float numLayers = mix(maxLayers, minLayers, abs(dot(float3(0.0, 0.0, 1.0), viewDir)));
    
    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;
    // depth of current layer
    float currentLayerDepth = 0.0;
    // the amount to shift the texture coordinates per layers (from vector P)
    float2 P = viewDir.xy / viewDir.z * heightScale;
    float2 deltaTexCoords = P / numLayers;
    
    // get initial values
    float2 currentTexCoords = texCoords;
    float currentDepthMapValue =  depthMap.sample(textureSampler, currentTexCoords).r;
    
    while(currentLayerDepth < currentDepthMapValue) {
        // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;
        // get depthmap value at current texture coordinates
        currentDepthMapValue = depthMap.sample(textureSampler, currentTexCoords).r;
        // get depth of next layer
        currentLayerDepth += layerDepth;
    }
    
    return currentTexCoords;
}

float2 occlusionParallaxMapping(float2 texCoords,
                            float3 viewDir,
                            texture2d<half> depthMap,
                            sampler textureSampler,
                            float heightScale) {
    // number of depth layers
    const float minLayers = 8;
    const float maxLayers = 32;
    float numLayers = mix(maxLayers, minLayers, abs(dot(float3(0.0, 0.0, 1.0), viewDir)));
    
    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;
    // depth of current layer
    float currentLayerDepth = 0.0;
    // the amount to shift the texture coordinates per layers (from vector P)
    float2 P = viewDir.xy / viewDir.z * heightScale;
    float2 deltaTexCoords = P / numLayers;
    
    // get initial values
    float2 currentTexCoords = texCoords;
    float currentDepthMapValue =  depthMap.sample(textureSampler, currentTexCoords).r;
    
    while(currentLayerDepth < currentDepthMapValue) {
        // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;
        // get depthmap value at current texture coordinates
        currentDepthMapValue = depthMap.sample(textureSampler, currentTexCoords).r;
        // get depth of next layer
        currentLayerDepth += layerDepth;
    }
    
    // get texture coordinates before collision (reverse operations)
    float2 prevTexCoords = currentTexCoords + deltaTexCoords;
    
    // get depth after and before collision for linear interpolation
    float afterDepth = currentDepthMapValue - currentLayerDepth;
    float beforeDepth = depthMap.sample(textureSampler, prevTexCoords).r - currentLayerDepth + layerDepth;
    
    // interpolation of texture coordinates
    float weight = afterDepth / (afterDepth - beforeDepth);
    float2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);
    
    return finalTexCoords;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture [[texture(FragmentInputIndexDiffuseMap)]],
                               texture2d<half> normalMap [[texture(FragmentInputIndexNormalMap)]],
                               texture2d<half> depthMap [[texture(FragmentInputIndexDepthMap)]],
                               constant float &heightScale [[buffer(FragmentInputIndexHeightScale)]],
                               constant uint  &paramParallaxMethod [[buffer(FragmentInputIndexParallaxMethod)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    // offset texture coordinates with parallax mapping
    float3 viewDir = normalize(in.tangentViewPos - in.tangentFragPos);
    float2 texCoords = in.texCoord;
    
    if (paramParallaxMethod == 0) {
        texCoords = parallaxMapping(texCoords, viewDir, depthMap, textureSampler, heightScale);
    } else if (paramParallaxMethod == 1) {
        texCoords = steepParallaxMapping(texCoords, viewDir, depthMap, textureSampler, heightScale);
    } else if (paramParallaxMethod == 2) {
        texCoords = occlusionParallaxMapping(texCoords, viewDir, depthMap, textureSampler, heightScale);
    } else {
        texCoords = parallaxMapping(texCoords, viewDir, depthMap, textureSampler, heightScale);
    }
    
    if (texCoords.x > 1.0 || texCoords.y > 1.0 || texCoords.x < 0.0 || texCoords.y < 0.0) {
        discard_fragment();
    }
    
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
    float3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfwayDir), 0.0), 32.0);
    
    float3 specular = float3(0.2) * spec;
    
    return float4(ambient + diffuse + specular, 1.0);
}
