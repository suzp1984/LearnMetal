//
//  Shader.metal
//  DeferredShading
//
//  Created by Jacob Su on 4/10/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

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

vertex RasterizerData gBufferVertexShader(Vertex in [[stage_in]],
                                          constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    
    out.fragPos = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.texCoords = in.texCoord;
    out.normal = uniforms.normalMatrix * in.normal;
    
    return out;
}

struct GBufferData {
    float4 gPosition [[color(0)]];
    float4 gNormal   [[color(1)]];
    float4 gAlbedo   [[color(2)]];
};

fragment GBufferData gBufferFragmentShader(RasterizerData in [[stage_in]],
                                      texture2d<half> diffuseTexture[[texture(FragmentInputIndexDiffuse)]],
                                      texture2d<half> specularTexture[[texture(FragmentInputIndexSpecular)]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    GBufferData out;
    out.gPosition = float4(in.fragPos, 1.0);
    out.gNormal = float4(normalize(in.normal), 1.0);
    
    float3 rgb = float3(diffuseTexture.sample(textureSampler, in.texCoords).rgb);
    float  a = specularTexture.sample(textureSampler, in.texCoords).r;
    out.gAlbedo = float4(rgb, a);
    
    return out;
}

struct DeferredRasterizerData {
    float4 position [[position]];
    float2 texCoords;
};

vertex DeferredRasterizerData deferredVertexShader(uint vertexID [[vertex_id]],
                                                   constant QuadVertex *vertices [[buffer(0)]]) {
    DeferredRasterizerData out;
    QuadVertex in = vertices[vertexID];
    
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoords = in.texCoords;
    
    return out;
}

fragment float4 deferredFragmentShader(DeferredRasterizerData in [[stage_in]],
                                       texture2d<half> gPosition [[texture(DeferredFragmentIndexGPositionTexture)]],
                                       texture2d<half> gNormal [[texture(DeferredFragmentIndexGNormalTexture)]],
                                       texture2d<half> gAlbedo [[texture(DeferredFragmentIndexGAlbedoTexture)]],
                                       constant Light *lights [[buffer(DeferredFragmentIndexLights)]],
                                       constant int &lightsCount [[buffer(DeferredFragmentIndexLightsCount)]],
                                       constant float3 &viewPos [[buffer(DeferredFragmentIndexViewPosition)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);

    // retrieve data from gbuffer
    float3 fragPos = float3(gPosition.sample(textureSampler, in.texCoords).rgb);
    float3 normal  = float3(gNormal.sample(textureSampler, in.texCoords).rgb);
    float3 diffuse = float3(gAlbedo.sample(textureSampler, in.texCoords).rgb);
    float  specular = gAlbedo.sample(textureSampler, in.texCoords).a;
    
    // calculate lighting as usual
    float3 lighting = diffuse * 0.2;
    float3 viewDir = normalize(viewPos - fragPos);
    for (int i = 0; i < lightsCount; i++) {
        // diffuse
        float3 lightDir = normalize(lights[i].position - fragPos);
        float3 diffuseColor = max(dot(normal, lightDir), 0.0) * diffuse * lights[i].color;
        // specular
        float3 halfwayDir = normalize(lightDir + viewDir);
        float spec = pow(max(dot(normal, halfwayDir), 0.0), 16.0);
        float3 specularColor = lights[i].color * spec * specular;
        
        // attenuation
        float distance = length(lights[i].position - fragPos);
        float attenuation = 1.0 / (1.0 + lights[i].linear * distance + lights[i].quadratic * distance * distance);
        diffuseColor *= attenuation;
        specularColor *= attenuation;
        lighting += diffuseColor + specularColor;
    }
    
    return float4(lighting, 1.0);
}

struct QuadRasterizerData
{
    float4 position [[position]];
};

vertex QuadRasterizerData lightBoxVertexShader(Vertex in [[stage_in]],
                                               constant LightCubeUniforms &uniforms [[buffer(1)]] ) {
    QuadRasterizerData out;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    return out;
}

fragment float4 lightBoxFragmentShader(QuadRasterizerData in [[stage_in]],
                                       constant float3 &lightColor [[buffer(0)]]) {
    return float4(lightColor, 1.0);
}
