//
//  Shader.metal
//  SkinAnimation
//
//  Created by Jacob Su on 5/8/21.
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
    float4 skinIndex [[attribute(ModelVertexAttributeSkinIndex)]];
    float4 skinWeight [[attribute(ModelVertexAttributeSkinWeight)]];
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
    float2 texCoords;
    float3 normal;
};

float4x4 getBoneMatrix(const float i,
                       texture2d<float> boneTexture,
                       const int boneTextureSize) {
    float j = i * 4.0;
    float size = float(boneTextureSize);
    
//    float x = j - size * floor(j / size);
    float x = modf(j, size);
//    float y = floor(j / float(boneTextureSize));
    float y = floor(j / size);

    float dx = 1.0 / float(boneTextureSize);
    float dy = 1.0 / float(boneTextureSize);
    
    y = (dy * (y + 0.5));
    
    float4 v1 = boneTexture.sample(Const::linearSampler, float2(dx * (x + 0.5), y));
    float4 v2 = boneTexture.sample(Const::linearSampler, float2(dx * (x + 1.5), y));
    float4 v3 = boneTexture.sample(Const::linearSampler, float2(dx * (x + 2.5), y));
    float4 v4 = boneTexture.sample(Const::linearSampler, float2(dx * (x + 3.5), y));
    
    return float4x4(v1, v2, v3, v4);
}

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(ModelVertexInputIndexPosition)]],
                                   constant Uniforms &uniforms [[buffer(ModelVertexInputIndexUniforms)]],
                                   texture2d<float> boneTexture [[texture(ModelVertexInputIndexBoneTexture)]],
                                   constant int &boneTextureSize [[buffer(ModelVertexInputIndexBoneTextureSize)]]
                                   )
{
    RasterizerData out;
    Vertex vert = vertices[vertexID];
    out.texCoords = vert.texCoord;
    out.normal = normalize(uniforms.normalMatrix * vert.normal);
    
    float4x4 boneMatX = getBoneMatrix(vert.skinIndex.x, boneTexture, boneTextureSize);
    float4x4 boneMatY = getBoneMatrix(vert.skinIndex.y, boneTexture, boneTextureSize);
    float4x4 boneMatZ = getBoneMatrix(vert.skinIndex.z, boneTexture, boneTextureSize);
    float4x4 boneMatW = getBoneMatrix(vert.skinIndex.w, boneTexture, boneTextureSize);
    
    // update normal
    float4x4 skinMatrix = float4x4(float4(0.0), float4(0.0), float4(0.0), float4(0.0));

    skinMatrix += vert.skinWeight.x * boneMatX;
    skinMatrix += vert.skinWeight.y * boneMatY;
    skinMatrix += vert.skinWeight.z * boneMatZ;
    skinMatrix += vert.skinWeight.w * boneMatW;
    out.normal = (skinMatrix * float4(out.normal, 0.0)).xyz;
    
    // update position
    float4 bindPos = float4(vert.position, 1.0);
    float4 transformed = float4(0.0);
    transformed += boneMatX * bindPos * vert.skinWeight.x;
    transformed += boneMatY * bindPos * vert.skinWeight.y;
    transformed += boneMatZ * bindPos * vert.skinWeight.z;
    transformed += boneMatW * bindPos * vert.skinWeight.w;
    
    float3 pos = transformed.xyz;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(pos, 1.0);
    
//    out.position = uniforms.projectionMatrix * uniforms.viewMatrix *uniforms.modelMatrix * float4(vert.position, 1.0);
//    out.texCoords = vert.texCoord;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> diffuseTexture[[texture(FragmentInputIndexDiffuseTexture)]])
{
    float3 tex = float3(diffuseTexture.sample(Const::linearSampler, in.texCoords).rgb);
    float3 normal = normalize(in.normal);
    float3 light = float3(0.0, 1.0, 0.0);
    float shading = min(0.0, dot(normal, light) * 0.2);

    float3 color = tex + shading;
    // gamma correct
    color = pow(color, float3(1.0/2.2));

    return float4(color, 1.0);
    
//    float3 colorSample = float3(diffuseTexture.sample(Const::linearSampler, in.texCoords).rgb);
//
//    // gamma correct
//    colorSample = pow(colorSample, float3(1.0/2.2));
    
//    return float4(colorSample, 1.0);
}
