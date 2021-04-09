//
//  Shader.metal
//  Bloom
//
//  Created by Jacob Su on 4/8/21.
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

vertex RasterizerData vertexShader(Vertex in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(VertexInputIndexUniform)]]) {
    RasterizerData out;
    
    out.fragPos = (uniforms.modelMatrix * float4(in.position, 1.0)).xyz;
    out.texCoord = in.texCoord;
    out.normal = normalize(uniforms.normalMatrix * in.normal);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    
    return out;
}

struct FragmentData {
    float4 color       [[color(0)]];
    float4 brightColor [[color(1)]];
};

fragment FragmentData fragmentShader(RasterizerData in [[stage_in]],
                                     texture2d<half> diffuseTexture [[texture(FragmentInputIndexTexture)]],
                                     constant Light  *lights        [[buffer(FragmentInputIndexLights)]],
                                     constant int    &lightsCount   [[buffer(FragmentInputIndexLightsCount)]],
                                     constant float3 &viewPos       [[buffer(FragmentInputIndexViewPos)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    FragmentData out;
    
    float3 color = float3(diffuseTexture.sample(textureSampler, in.texCoord).rgb);
    float3 normal = normalize(in.normal);
    
    // ambient
    float3 ambient = 0.1 * color;
    
    // lighting
    float3 lighting = float3(0.0);
//    float3 viewDir = normalize(viewPos - in.fragPos);
    
    for (int i = 0; i < lightsCount; i++) {
        // diffuse
        float3 lightDir = normalize(lights[i].position - in.fragPos);
        float diff = max(dot(lightDir, normal), 0.0);
        float3 result = lights[i].color * diff * color;
        // attenuation (use quadratic as we have gamma correction)
        float distance = length(in.fragPos - lights[i].position);
        result *= 1.0 / (distance * distance);
        lighting += result;
    }
    
    float3 result = ambient + lighting;
    // check whether result is higher than some threshold, if so, output as bloom theshold color
    float brightness = dot(result, float3(0.2126, 0.7152, 0.0722));
    if (brightness > 1.0) {
        out.brightColor = float4(result, 1.0);
    } else {
        out.brightColor = float4(0.0, 0.0, 0.0, 1.0);
    }
    
    out.color = float4(result, 1.0);
    
    return out;
}

fragment FragmentData lightFragmentShader(RasterizerData in [[stage_in]],
                                          constant float3 &lightColor [[buffer(0)]]) {
    FragmentData out;
    
    out.color = float4(lightColor, 1.0);
    float brightness = dot(lightColor, float3(0.2126, 0.7152, 0.0722));
    if (brightness > 1.0) {
        out.brightColor = float4(lightColor, 1.0);
    } else {
        out.brightColor = float4(0.0, 0.0, 0.0, 1.0);
    }
    
    return out;
}

struct QuadRasterizerData {
    float4 position [[position]];
    float2 texCoord;
};

vertex QuadRasterizerData quadVertexShader(uint vertexID [[vertex_id]],
                                           constant QuadVertex *vertices [[buffer(QuadVertexIndexPosition)]]) {
    QuadRasterizerData out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    
    return out;
}

fragment float4 quadFragmentShader(QuadRasterizerData in [[stage_in]],
                                   texture2d<half> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    float4 color = float4(colorTexture.sample(textureSampler, in.texCoord));
    
    return color;
}

fragment float4 blurFragmentShader(QuadRasterizerData in [[stage_in]],
                                   texture2d<half> colorTexture [[texture(0)]],
                                   constant float2 &textureSize [[buffer(1)]],
                                   constant int &isHorizontal [[buffer(2)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    const float weight[5] = {
        0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162
    };
    
    float2 texOffset = 1.0 / textureSize;
    float3 result = float3(colorTexture.sample(textureSampler, in.texCoord).rgb) * weight[0];
    
    if (isHorizontal >= 1) {
        for(int i = 1; i < 5; i++) {
            result += float3(colorTexture.sample(textureSampler, in.texCoord + float2(texOffset.x * i, 0.0)).rgb) * weight[i];
            result += float3(colorTexture.sample(textureSampler, in.texCoord - float2(texOffset.x * i, 0.0)).rgb) * weight[i];
        }
    } else {
        for(int i = 1; i < 5; i++) {
            result += float3(colorTexture.sample(textureSampler, in.texCoord + float2(0.0, texOffset.y * i)).rgb) * weight[i];
            result += float3(colorTexture.sample(textureSampler, in.texCoord - float2(0.0, texOffset.y * i)).rgb) * weight[i];
        }
    }
    
    return float4(result, 1.0);
}

fragment float4 bloomFragmentShader(QuadRasterizerData in [[stage_in]],
                                    texture2d<half> colorTexture [[texture(0)]],
                                    texture2d<half> blurTexture  [[texture(1)]],
                                    constant bool   &bloom       [[buffer(2)]],
                                    constant float  &exposure    [[buffer(3)]]) {
    constexpr sampler textureSampler (mag_filter::linear, min_filter::nearest, mip_filter::linear);

    const float gamma = 2.2;
    float3 hdrColor = float3(colorTexture.sample(textureSampler, in.texCoord).rgb);
    float3 bloomColor = float3(blurTexture.sample(textureSampler, in.texCoord).rgb);
    
    if (bloom) {
        hdrColor += bloomColor;
    }
    
    // tone mapping
    float3 result = float3(1.0) - exp(-hdrColor * exposure);
    // also gamma correct while we're at it
    result = pow(result, float3(1.0 / gamma));
    
    return float4(result, 1.0);
}
