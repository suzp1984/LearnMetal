//
//  ShaderType.h
//  GammaCorrection
//
//  Created by Jacob Su on 4/1/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniform  = 1,
} VertexInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 inverseModelMatrix;
} Uniforms;

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeNormal   = 1,
    ModelVertexAttributeTexCoord = 2,
} ModelVertexAttribute;

typedef enum FragmentInputIndex {
    FragmentInputIndexArgumentBuffer = 0,
    FragmentInputIndexTexture        = 1,
} FragmentInputIndex;

typedef enum FragmentArgumentBufferIndex {
    FragmentArgumentBufferIndexSampler       = 0,
    FragmentArgumentBufferIndexViewPosition  = 1,
    FragmentArgumentBufferIndexLightPosition = 2,
    FragmentArgumentBufferIndexLightColors = 6,
} FragmentArgumentBufferIndex;

#endif /* ShaderType_h */
