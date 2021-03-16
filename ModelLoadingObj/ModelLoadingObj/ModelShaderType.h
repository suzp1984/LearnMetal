//
//  ModelShaderType.h
//  ModelLoadingObj
//
//  Created by Jacob Su on 3/16/21.
//

#ifndef ModelShaderType_h
#define ModelShaderType_h

#include <simd/simd.h>

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeTexcoord = 1,
    ModelVertexAttributeNormal   = 2,
} VertexAttribute;

typedef enum FragmentInputIndex {
    FragmentInputIndexDiffuseTexture = 0,
} FragmentInputIndex;

typedef enum ModelVertexInputIndex {
    ModelVertexInputIndexPosition = 0,
    ModelVertexInputIndexUniforms = 1,
} ModelVertexInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

#endif /* ModelShaderType_h */
