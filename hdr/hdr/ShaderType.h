//
//  ShaderType.h
//  hdr
//
//  Created by Jacob Su on 4/7/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeNormal   = 1,
    ModelVertexAttributeTexCoord = 2,
} ModelVertexAttribute;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
} Uniforms;

typedef enum LightFragmentIndex {
    LightFragmentIndexDiffuseTexture = 0,
    LightFragmentIndexViewPos        = 1,
    LightFragmentIndexLights         = 2,
    LightFragmentIndexLightCount     = 3,
} LightFragmentIndex;

typedef struct Light {
    vector_float3 position;
    vector_float3 color;
} Light;

typedef struct HDRVertex {
    vector_float2 position;
    vector_float2 texCoords;
} HDRVertex;

typedef enum HDRVertexInput {
    HDRVertexInputPosition = 0,
} HDRVertexInput;

typedef enum HDRFragmentInput {
    HDRFragmentInputHDRTexture = 0,
    HDRFragmentInputHDRSwitch  = 1,
    HDRFragmentInputExposure   = 2,
} HDRFragmentInput;
#endif /* ShaderType_h */
