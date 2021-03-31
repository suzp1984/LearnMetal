//
//  ShaderType.h
//  MSAA
//
//  Created by Jacob Su on 3/29/21.
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
} Uniforms;

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
} ModelVertexAttribute;

#endif /* ShaderType_h */
