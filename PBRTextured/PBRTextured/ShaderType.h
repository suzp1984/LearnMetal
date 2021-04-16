//
//  ShaderType.h
//  PBRTextured
//
//  Created by Jacob Su on 4/16/21.
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
    FragmentInputIndexLight   = 1,
    FragmentInputIndexCameraPostion = 2,
} FragmentInputIndex;

typedef enum MaterialArgumentIndex {
    MaterialArgumentIndexAlbedo = 0,
    MaterialArgumentIndexNormal = 1,
    MaterialArgumentIndexMetallic = 2,
    MaterialArgumentIndexRoughness = 3,
    MaterialArgumentIndexAO = 4,
} MaterialArgumentIndex;

#endif /* ShaderType_h */
