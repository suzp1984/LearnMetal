//
//  ShapeShaderType.h
//  StencilTesting
//
//  Created by Jacob Su on 3/17/21.
//

#ifndef ShapeShaderType_h
#define ShapeShaderType_h


#include <simd/simd.h>

typedef enum VertexAttributeIndex {
    VertexAttributeIndexPosition = 0,
    VertexAttributeIndexTexcoord = 1,
} VertexAttribute;

typedef enum FragmentInputIndex {
    FragmentInputIndexDiffuseTexture = 0,
} FragmentInputIndex;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} ModelVertexInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

#endif /* ShapeShaderType_h */
