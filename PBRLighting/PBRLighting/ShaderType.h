//
//  ShaderType.h
//  PBRLighting
//
//  Created by Jacob Su on 4/15/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#import <simd/simd.h>

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeTexcoord = 1,
    ModelVertexAttributeNormal   = 2,
} VertexAttribute;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef struct Material {
    vector_float3 albedo;
    float metallic;
    float roughness;
    float ao;
} Material;

typedef struct Light {
    vector_float3 position;
    vector_float3 color;
} Light;

typedef enum FragmentInputIndex {
    FragmentInputIndexMaterial = 0,
    FragmentInputIndexLights   = 1,
    FragmentInputIndexLightsCount = 2,
    FragmentInputIndexCameraPostion = 3,
} FragmentInputIndex;

#endif /* ShaderType_h */
