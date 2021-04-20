//
//  Shader.metal
//  IBLSpecular
//
//  Created by Jacob Su on 4/19/21.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

namespace Const {
    constexpr sampler linearSampler (mag_filter::linear, min_filter::linear);
    constant uint SAMPLE_COUNT = 1024u;
    constant uint CUBEMAP_SIZE = 512u;
}

typedef struct Vertex
{
    float3 position [[attribute(ModelVertexAttributePosition)]];
    float2 texCoord [[attribute(ModelVertexAttributeTexcoord)]];
    float3 normal   [[attribute(ModelVertexAttributeNormal)]];
} Vertex;

struct CubeMapRasterizerData
{
    float4 position [[position]];
    float3 worldPos;
    uint   layer    [[render_target_array_index]];
};

vertex CubeMapRasterizerData cubeMapVertexShader(Vertex in [[stage_in]],
                                                 const uint instanceId [[instance_id]],
                                                 constant float4x4 &projectionMatrix [[buffer(CubeMapVertexIndexProjection)]],
                                                 constant CubeMapParams *params [[buffer(CubeMapVertexIndexInstanceParams)]]) {
    CubeMapRasterizerData out;
    
    CubeMapParams param = params[instanceId];
    out.layer = param.layerId;
    out.worldPos = in.position;
    out.position = projectionMatrix * param.viewMatrix * float4(in.position, 1.0);
    
    return out;
}

float2 SampleSphericalMap(float3 v) {
    const float2 invAtan = float2(0.1591, 0.3183);

    float2 uv = float2(atan2(v.z, v.x), asin(v.y));
    uv *= invAtan;
    uv += 0.5;
    return uv;
}

fragment float4 cubeMapFragmentShader(CubeMapRasterizerData in [[stage_in]],
                                      texture2d<half> equirectangularMap [[texture(0)]]) {

    float2 uv = SampleSphericalMap(normalize(in.worldPos));
    float3 color = float3(equirectangularMap.sample(Const::linearSampler, uv).rgb);
    
    return float4(color, 1.0);
}

fragment float4 irradianceFragmentShader(CubeMapRasterizerData in [[stage_in]],
                                         texturecube<half> environmentMap [[texture(0)]]) {

    // The world vector acts as the normal of a tangent surface
    // from the origin, aligned to WorldPos. Given this normal, calculate all
    // incoming radiance of the environment. The result of this radiance
    // is the radiance of light coming from -Normal direction, which is what
    // we use in the PBR shader to sample irradiance.
    float3 N = normalize(in.worldPos);
    float3 irradiance = float3(0.0);
    
    // tangent space calculation from origin point
    float3 up = float3(0.0, 1.0, 0.0);
    float3 right = cross(up, N);
    up = cross(N, right);
    
    float sampleDelta = 0.025;
    float nrSamples = 0.0;
    for (float phi = 0.0; phi < 2.0 * M_PI_F; phi += sampleDelta) {
        for (float theta = 0.0; theta < 0.5 * M_PI_F; theta += sampleDelta) {
            // spherical to cartesian (in tangent space)
            float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
            // tangent space to world
            float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * N;

            irradiance += float3(environmentMap.sample(Const::linearSampler, sampleVec).rgb) * cos(theta) * sin(theta);
            nrSamples ++;
        }
    }
    
    irradiance = M_PI_F * irradiance * (1.0 / nrSamples);
    
    return float4(irradiance, 1.0);
}

// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// efficient VanDerCorpus calculation.
float RadicalInverse_VdC(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    
    return float(bits) * 2.3283064365386963e-10;
}

float2 Hammersley(uint i, uint N) {
    return float2(float(i) / float(N), RadicalInverse_VdC(i));
}

float3 ImportanceSampleGGX(float2 Xi, float3 N, float roughness) {
    float a = roughness * roughness;
    
    float phi = 2.0 * M_PI_F * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    // from spherical coordinate to cartesian coordinate - halfway vector
    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
    
    // from tangent-sapce H vector to world-space sample vector
    float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);
    
    float3 sampleVec = tangent * H.x * bitangent * H.y + N * H.z;
    return normalize(sampleVec);
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

fragment float4 preFilterFragmentShader(CubeMapRasterizerData in [[stage_in]],
                                        texturecube<half> environmentMap [[texture(0)]],
                                        constant float &roughness [[buffer(1)]]) {
    float3 N = normalize(in.worldPos);
    
    // make the simplyfying assumption that V equals R equals the normal
    float3 R = N;
    float3 V = R;
    
    float3 prefilteredColor = float3(0.0);
    float totalWeight = 0.0;
    
    for (uint i = 0; i < Const::SAMPLE_COUNT; ++i) {
        // generates a sample vector that's biased towards the preferred alignment direction (importance sampling).
        float2 Xi = Hammersley(i, Const::SAMPLE_COUNT);
        float3 H = ImportanceSampleGGX(Xi, N, roughness);
        float3 L = normalize(2.0 * dot(V, H) * H - V);
        
        float NdotL = max(dot(N, L), 0.0);
        if (NdotL > 0.0) {
            // TODO: don't known how to render to differene mip level;
            // sample from the environment's mip level based on roughness/pdf
//            float D = DistributionGGX(N, H, roughness);
//            float NdotH = max(dot(N, H), 0.0);
//            float HdotV = max(dot(H, V), 0.0);
//            float pdf = D * NdotH / (4.0 * HdotV) + 0.0001;
//
//            float resolution = Const::CUBEMAP_SIZE;
//            float saTexel = 4.0 * M_PI_F / (6.0 * resolution * resolution);
//            float saSample = 1.0 / (float(Const::SAMPLE_COUNT) * pdf + 0.0001);
//
//            float mipLevel = roughness == 0.0 ? 0.0 : 0.5 * log2(saSample / saTexel);
//            prefilteredColor += float3(environmentMap.sample(Const::linearSampler, L, min_lod_clamp(mipLevel)).rgb) * NdotL;
            prefilteredColor += float3(environmentMap.sample(Const::linearSampler, L).rgb) * NdotL;
            totalWeight += NdotL;
        }
    }
    
    prefilteredColor = prefilteredColor / totalWeight;
    
    return float4(prefilteredColor, 1.0);
}

struct BackgroundRasterizerData
{
    float4 position [[position]];
    float3 worldPos;
};

matrix_float3x3 matrix3x3_upper_left(matrix_float4x4 mat4x4) {
    matrix_float3x3 out;
    out.columns[0] = mat4x4.columns[0].xyz;
    out.columns[1] = mat4x4.columns[1].xyz;
    out.columns[2] = mat4x4.columns[2].xyz;
    
    return out;
}

matrix_float4x4 matrix4x4_upper_left(matrix_float3x3 mat3x3) {
    matrix_float4x4 out;
    out.columns[0] = float4(mat3x3.columns[0].xyz, 0.0);
    out.columns[1] = float4(mat3x3.columns[1].xyz, 0.0);
    out.columns[2] = float4(mat3x3.columns[2].xyz, 0.0);
    out.columns[3] = {0.0, 0.0, 0.0, 1.0};
    
    return out;
}

vertex BackgroundRasterizerData backgroundVertexShader(Vertex in [[stage_in]],
                                                       constant Uniforms &uniform [[buffer(1)]]) {
    BackgroundRasterizerData out;
    
    out.worldPos = in.position;
    
    float4x4 viewMatrixWithoutTranslation = matrix4x4_upper_left(matrix3x3_upper_left(uniform.viewMatrix));
    float4 position = uniform.projectionMatrix * viewMatrixWithoutTranslation * float4(in.position, 1.0);
    out.position = position.xyww;
    
    return out;
}

fragment float4 backgroundFragmentShader(BackgroundRasterizerData in [[stage_in]],
                                         texturecube<half> environmentMap [[texture(0)]]) {

    float3 envColor = float3(environmentMap.sample(Const::linearSampler, in.worldPos).rgb);
    
    // HDR tonemap and gamma correct
    envColor = envColor / (envColor + float3(1.0));
    envColor = pow(envColor, float3(1.0/2.2));
    
    return float4(envColor, 1.0);
}

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoords;
    float3 worldPos;
    float3 normal;
};

vertex RasterizerData pbrVertexShader(Vertex in [[stage_in]],
                                      constant Uniforms &uniform [[buffer(VertexInputIndexUniforms)]]) {
    RasterizerData out;
    
    out.texCoords = in.texCoord;
    out.worldPos = (uniform.modelMatrix * float4(in.position, 1.0)).xyz;

    out.normal = matrix3x3_upper_left(uniform.modelMatrix) * in.normal;
    out.position = uniform.projectionMatrix * uniform.viewMatrix * float4(out.worldPos, 1.0);
    
    return out;
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

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness) {
    return F0 + (max(float3(1.0 - roughness), F0) - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}

typedef struct PBRArguments {
    texturecube<half> irradianceMap [[id(PBRArgumentIndexIrradianceMap)]];
    texturecube<half> prefilterMap [[id(PBRArgumentIndexPrefilterMap)]];
    texture2d<half> brdfMap [[texture(PBRArgumentIndexBrdfLUT)]];
} PBRArguments;

fragment float4 pbrFragmentShader(RasterizerData in [[stage_in]],
                                  constant Material &material [[buffer(FragmentInputIndexMaterial)]],
                                  constant Light *lights [[buffer(FragmentInputIndexLights)]],
                                  constant int &lightsCount [[buffer(FragmentInputIndexLightsCount)]],
                                  constant float3 &cameraPos [[buffer(FragmentInputIndexCameraPostion)]],
                                  constant PBRArguments &pbrArguments [[buffer(FragmentInputIndexArguments)]])
{
    float3 N = normalize(in.normal);
    float3 V = normalize(cameraPos - in.worldPos);
    float3 R = reflect(-V, N);
    
    // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0
    // of 0.04 and if it's a metal, use the albedo color as F0 (metallic workflow)
    float3 F0 = float3(0.04);
    F0 = mix(F0, material.albedo, material.metallic);
    
    // reflectance equation
    float3 Lo = float3(0.0);
    
    for (int i = 0; i < lightsCount; i++) {
        // calculate per-light radiance
        float3 L = normalize(lights[i].position - in.worldPos);
        float3 H = normalize(V + L);
        float distanc = length(lights[i].position - in.worldPos);
        float attenuation = 1.0 / (distanc * distanc);
        float3 radiance = lights[i].color * attenuation;
        
        // Cook-Torrance BRDF
        float NDF = DistributionGGX(N, H, material.roughness);
        float G = GeometrySmith(N, V, L, material.roughness);
        float3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);
//        float3 F = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
        
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
        kD *= 1.0 - material.metallic;
        
        // scale light by NdotL
        float NdotL = max(dot(N, L), 0.0);
        
        // add to outgoing radiance Lo
        Lo += (kD * material.albedo / M_PI_F + specular) * radiance * NdotL;
    }
    
    // ambient lighting
    float3 F = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, material.roughness);
    
    float3 kS = F;
    float3 kD = 1.0 - kS;
    kD *= 1.0 - material.metallic;

    float3 irradiance = float3(pbrArguments.irradianceMap.sample(Const::linearSampler, N).rgb);
    float3 diffuse = irradiance * material.albedo;
    
    // sample both the prefilter map and the BRDF lut and combine them together as
    // per the Split-Sum approximation to get the IBL specular part.
    float3 prefilteredColor = float3(pbrArguments.prefilterMap.sample(Const::linearSampler, R).rgb);
    float2 brdf = float2(pbrArguments.brdfMap.sample(Const::linearSampler, float2(max(dot(N, V), 0.0), material.roughness)).rg);
    float3 specular = prefilteredColor * (F * brdf.x + brdf.y);

    float3 ambient = (kD * diffuse + specular) * material.ao;
    
//    float3 ambient = (kD * diffuse) * material.ao;
    float3 color = ambient + Lo;
    
    // HDR tonemapping
    color = color / (color + float3(1.0));
    // gamma correct
    color = pow(color, float3(1.0/2.2));
    
    return float4(color, 1.0);
}

struct BRDFRasterizerData {
    float4 position [[position]];
    float2 texCoords;
};

vertex BRDFRasterizerData brdfVertexShader(uint vertexID [[vertex_id]],
                                           constant QuadVertex *verties [[buffer(0)]]) {
    BRDFRasterizerData out;
    
    QuadVertex vert = verties[vertexID];
    out.position = float4(vert.position, 0.0, 1.0);
    out.texCoords = vert.texCoords;
    
    return out;
}

float2 IntegrateBRDF(float NdotV, float roughness) {
    float3 V;
    V.x = sqrt(1.0 - NdotV * NdotV);
    V.y = 0.0;
    V.z = NdotV;
    
    float A = 0.0;
    float B = 0.0;
    
    float3 N = float3(0.0, 0.0, 1.0);
    
    for (uint i = 0; i < Const::SAMPLE_COUNT; ++i) {
        // generate a sample vector that's biased towards the
        // preferred alignment direction
        float2 Xi = Hammersley(i, Const::SAMPLE_COUNT);
        float3 H = ImportanceSampleGGX(Xi, N, roughness);
        float3 L = normalize(2.0 * dot(V, H) * H - V);
        
        float NdotL = max(L.z, 0.0);
        float NdotH = max(H.z, 0.0);
        float VdotH = max(dot(V, H), 0.0);
        
        if (NdotL > 0.0) {
            float G = GeometrySmith(N, V, L, roughness);
            float G_Vis = (G * VdotH) / (NdotH * NdotV);
            float Fc = pow(1.0 - VdotH, 5.0);
            
            A += (1.0 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }
    
    A /= float(Const::SAMPLE_COUNT);
    B /= float(Const::SAMPLE_COUNT);
    
    return float2(A, B);
}

fragment float2 brdfFragmentShader(BRDFRasterizerData in [[stage_in]]) {
    return IntegrateBRDF(in.texCoords.x, in.texCoords.y);
}
