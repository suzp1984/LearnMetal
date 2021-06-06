//
//  ShaderType.h
//  ModelUsdz
//
//  Created by Jacob Su on 5/19/21.
//

#ifndef ShaderType_h
#define ShaderType_h

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

#endif /* ShaderType_h */
