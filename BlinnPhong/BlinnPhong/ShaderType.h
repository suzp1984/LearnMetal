//
//  ShaderType.h
//  BlinnPhong
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
} FragmentInputIndex;

typedef enum FragmentArgumentBufferIndex {
    FragmentArgumentBufferIndexTexture       = 0,
    FragmentArgumentBufferIndexSampler       = 1,
    FragmentArgumentBufferIndexViewPosition  = 2,
    FragmentArgumentBufferIndexLightPosition = 3,
} FragmentArgumentBufferIndex;

#endif /* ShaderType_h */
