//
//  Shader.metal
//  PBRTextured
//
//  Created by Jacob Su on 4/16/21.
//

#include <metal_stdlib>
using namespace metal;
#include "ShaderType.h"

namespace Const {
    constexpr sampler linearSampler (mag_filter::linear, min_filter::linear);
}

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
    float3 worldPos;
    float3 normal;
};

matrix_float3x3 matrix3x3_upper_left(matrix_float4x4 mat4x4) {
    matrix_float3x3 out;
    out.columns[0] = mat4x4.columns[0].xyz;
    out.columns[1] = mat4x4.columns[1].xyz;
    out.columns[2] = mat4x4.columns[2].xyz;
    
    return out;
}

vertex RasterizerData pbrVertexShader(Vertex in [[stage_in]],
                                      constant Uniforms &uniform [[buffer(VertexInputIndexUniforms)]]) {
    RasterizerData out;
    
    out.texCoords = in.texCoord;
    out.worldPos = (uniform.modelMatrix * float4(in.position, 1.0)).xyz;

    out.normal = matrix3x3_upper_left(uniform.modelMatrix) * in.normal;
    out.position = uniform.projectionMatrix * uniform.viewMatrix * float4(out.worldPos, 1.0);
    
    return out;
}

// Easy trick to get tangent-normals to world-space to keep PBR code simplified.
// Don't worry if you don't get what's going on; you generally want to do normal
// mapping the usual way for performance anyways;
float3 getNormalFromMap(RasterizerData in, texture2d<half> normalMap) {
    float3 tangentNormal = float3(normalMap.sample(Const::linearSampler, in.texCoords).xyz) * 2.0 - 1.0;
    
    float3 Q1 = dfdx(in.worldPos);
    float3 Q2 = dfdy(in.worldPos);
    float2 st1 = dfdx(in.texCoords);
    float2 st2 = dfdy(in.texCoords);
    
    float3 N = normalize(in.normal);
    float3 T = normalize(Q1 * st2.y - Q2 * st1.y);
    float3 B = -normalize(cross(N, T));
    matrix_float3x3 TBN;
    TBN.columns[0] = T;
    TBN.columns[1] = B;
    TBN.columns[2] = N;
    
    return normalize(TBN * tangentNormal);
}

float DistributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI_F * denom * denom;
    
    return nom / max(denom, 0.0000001);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    
    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return nom / denom;
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}

typedef struct MaterialArguments {
    texture2d<half> albedoTexture   [[id(MaterialArgumentIndexAlbedo)]];
    texture2d<half> normalTexture   [[id(MaterialArgumentIndexNormal)]];
    texture2d<half> metallicTexture [[id(MaterialArgumentIndexMetallic)]];
    texture2d<half> roughnessTexture [[id(MaterialArgumentIndexRoughness)]];
    texture2d<half> aoTexture        [[id(MaterialArgumentIndexAO)]];
} MaterialArguments;

fragment float4 pbrFragmentShader(RasterizerData in [[stage_in]],
                                  constant MaterialArguments &material [[buffer(FragmentInputIndexMaterial)]],
                                  constant Light &light [[buffer(FragmentInputIndexLight)]],
                                  constant float3 &cameraPos [[buffer(FragmentInputIndexCameraPostion)]])
{
    float3 albedo = pow(float3(material.albedoTexture.sample(Const::linearSampler, in.texCoords).rgb), float3(2.2));
    float metallic = material.metallicTexture.sample(Const::linearSampler, in.texCoords).r;
    float roughness = material.roughnessTexture.sample(Const::linearSampler, in.texCoords).r;
    float ao = material.aoTexture.sample(Const::linearSampler, in.texCoords).r;
    
    float3 N = getNormalFromMap(in, material.normalTexture);
    float3 V = normalize(cameraPos - in.worldPos);
    
    // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0
    // of 0.04 and if it's a metal, use the albedo color as F0 (metallic workflow)
    float3 F0 = float3(0.04);
    F0 = mix(F0, albedo, metallic);
    
    // reflectance equation
    float3 Lo = float3(0.0);
    
    // calculate per-light radiance
    float3 L = normalize(light.position - in.worldPos);
    float3 H = normalize(V + L);
    float distanc = length(light.position - in.worldPos);
    float attenuation = 1.0 / (distanc * distanc);
    float3 radiance = light.color * attenuation;
    
    // Cook-Torrance BRDF
    float NDF = DistributionGGX(N, H, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    float3 F = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
    
    float3 nominator = NDF * G * F;
    float denominator = 4 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
    float3 specular = nominator / max(denominator, 0.001);
    
    // kS is equal to Fresnel
    float3 kS = F;
    // for energy conservation, the diffuse and specular light can't
    // be above 1.0 (unless the surface emits light); to preserve this
    // relationship the diffuse component (kD) should equal 1.0 - kS.
    float3 kD = float3(1.0) - kS;
    // multiply kD by the inverse metalness such that only non-metals
    // have diffuse lighting, or a linear blend if partly metal (pure metals
    // have no diffuse light).
    kD *= 1.0 - metallic;
    
    // scale light by NdotL
    float NdotL = max(dot(N, L), 0.0);
    
    // add to outgoing radiance Lo
    Lo += (kD * albedo / M_PI_F + specular) * radiance * NdotL;
    
    float3 ambient = float3(0.03) * albedo * ao;
    float3 color = ambient + Lo;
    
    // HDR tonemapping
    color = color / (color + float3(1.0));
    // gamma correct
    color = pow(color, float3(1.0/2.2));
    
    return float4(color, 1.0);
}
