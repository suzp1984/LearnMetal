//
//  Shader.metal
//  SSAO
//
//  Created by Jacob Su on 4/13/21.
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
    // output gbuffer fragPos in view space
    float4 viewSpacePos = uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    
    out.fragPos = viewSpacePos.xyz;
    out.position = uniforms.projectionMatrix * viewSpacePos;
    out.texCoords = in.texCoord;
    out.normal = uniforms.normalMatrix * in.normal;
    
    return out;
}

struct GBufferData {
    float4 gPosition [[color(0)]];
    float4 gNormal   [[color(1)]];
    float4 gAlbedo   [[color(2)]];
};

fragment GBufferData gBufferFragmentShader(RasterizerData in [[stage_in]])
{
//    constexpr sampler textviewSpacePosureSampler (mag_filter::linear, min_filter::linear);
    
    GBufferData out;
    out.gPosition = float4(in.fragPos, 1.0);
    out.gNormal = float4(normalize(in.normal), 1.0);
    
//    float3 rgb = float3(diffuseTexture.sample(textureSampler, in.texCoords).rgb);
//    float  a = specularTexture.sample(textureSampler, in.texCoords).r;
//    out.gAlbedo = float4(rgb, a);
    
    out.gAlbedo = float4(0.95, 0.95, 0.95, 1.0);
    
    return out;
}

struct QuadRasterizerData {
    float4 position [[position]];
    float2 texCoords;
};

vertex QuadRasterizerData quadVertexShader(uint vertexID [[vertex_id]],
                                           constant QuadVertex *vertices [[buffer(0)]]) {
    QuadRasterizerData out;
    QuadVertex vert = vertices[vertexID];
    
    out.position = float4(vert.position, 0.0, 1.0);
    out.texCoords = vert.texCoords;
    
    return out;
}

fragment float4 quadFragmentShader(QuadRasterizerData in [[stage_in]],
                                   texture2d<half> diffuse [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    float r = diffuse.sample(textureSampler, in.texCoords).r;
    
    return float4(r, r, r, 1.0);
}

fragment float ssaoFragmentShader(QuadRasterizerData in [[stage_in]],
                                   texture2d<half> gPosition [[texture(SSAOFragmentIndexGPosition)]],
                                   texture2d<half> gNormal [[texture(SSAOFragmentIndexGNormal)]],
                                   texture2d<float> texNoise [[texture(SSAOFragmentIndexTexNoise)]],
                                   constant float3 *kernalSample [[buffer(SSAOFragmentIndexKernalSample)]],
                                   constant int &kernalSize [[buffer(SSAOFragmentIndexKernalSize)]],
                                   constant float2 &noiseScale [[buffer(SSAOFragmentIndexNoiseScale)]],
                                   constant float4x4 &projection [[buffer(SSAOFragmentIndexProjectionMatrix)]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear,
                                      mip_filter::linear,
                                      s_address::repeat,
                                      t_address::repeat);
    float radius = 0.5;
    float bias = 0.025;
    // get input for SSAO algorithm
    float3 fragPos = float3(gPosition.sample(textureSampler, in.texCoords).xyz);
    float3 normal = normalize(float3(gNormal.sample(textureSampler, in.texCoords).rgb));
    
//    float3 randomVec = normalize(float3(texNoise.sample(textureSampler, in.texCoords * noiseScale).xyz));
    float2 noiseCoord = fract(in.texCoords * noiseScale);
    float3 randomVec = normalize(float3(texNoise.sample(textureSampler, noiseCoord).xyz));
    // create TBN change-of-basis matrix: from tangent-space to view-space
    float3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    float3 bitangent = cross(normal, tangent);
//    float3x3 TBN = float3x3(tangent, bitangent, normal);
    float3x3 TBN;
    TBN.columns[0] = tangent;
    TBN.columns[1] = bitangent;
    TBN.columns[2] = normal;
    
    // iterator over the sample kernel and calculate occlusion factor
    float occlusion = 0.0;
    for (int i = 0; i < kernalSize; i++) {
        // get sample position
        float3 samplePos = TBN * kernalSample[i]; // from tangent to view-space
        samplePos = fragPos + samplePos * radius;
        
        // project sample position (to sample texture) (to get position on screen/texture)
        float4 offset = float4(samplePos, 1.0);
        offset = projection * offset; // from view to clip-space
        offset = offset / offset.w; // perspective divide
        offset = offset * 0.5 + float4(0.5); // transform to range 0.0 - 1.0
        
        // get sample depth
        float sampleDepth = gPosition.sample(textureSampler, offset.xy).z; // get depth value of kernel sample
        // range check & accumulate
        float rangeCheck = smoothstep(0.0, 1.0, radius / abs(fragPos.z - sampleDepth));
        occlusion += (sampleDepth >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;
    }
    
    occlusion = 1.0 - (occlusion / (float)kernalSize);
    
    return occlusion;
}

fragment float blurFragmentShader(QuadRasterizerData in [[stage_in]],
                                  texture2d<half> ssaoTexture [[texture(0)]],
                                  constant float2 &textureSize [[buffer(1)]]
) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear,
                                      s_address::repeat,
                                      t_address::repeat);
    
    float2 texelSize = 1.0 / textureSize;
    float result = 0.0;
    for (int x = -2; x < 2; x++) {
        for (int y = -2; y < 2; y++) {
            float2 offset = float2(x, y) * texelSize;
            result += ssaoTexture.sample(textureSampler, in.texCoords + offset).r;
        }
    }
    
    return result / (4.0 * 4.0);
}

fragment float4 lightingFragmentShader(QuadRasterizerData in [[stage_in]],
                                       texture2d<half> gPosition [[texture(LightFragmentIndexGPosition)]],
                                       texture2d<half> gNormal [[texture(LightFragmentIndexGNormal)]],
                                       texture2d<half> gAlbedo [[texture(LightFragmentIndexGAlbedo)]],
                                       texture2d<half> ssao    [[texture(LightFragmentIndexSSAOTexture)]],
                                       constant Light &light [[buffer(LightFragmentIndexLight)]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear,
                                      s_address::repeat,
                                      t_address::repeat);
    // retrieve data from gbuffer
    float3 fragPos = float3(gPosition.sample(textureSampler, in.texCoords).rgb);
    float3 normal  = float3(gNormal.sample(textureSampler, in.texCoords).rgb);
    float3 diffuse = float3(gAlbedo.sample(textureSampler, in.texCoords).rgb);
    float AmbientOcclusion = ssao.sample(textureSampler, in.texCoords).r;
    
    // then calculate lighting as usual
    float3 ambient = float3(0.3 * diffuse * AmbientOcclusion);
    float3 lighting = ambient;
    float3 viewDir = normalize(-fragPos); // gPosition was in view-space;
    // diffuse
    float3 lightDir = normalize(light.position - fragPos);
    float3 diffuseLight = max(dot(normal, lightDir), 0.0) * diffuse * light.color;
    // specular
    float3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfwayDir), 0.0), 8.0);
    float3 specularLight = light.color * spec;
    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (1.0 + light.linear * distance + light.quadratic * distance * distance);
    diffuseLight *= attenuation;
    specularLight *= attenuation;
    lighting += diffuseLight + specularLight;
    
    return float4(lighting, 1.0);
}
