//
//  CubeShaderType.h
//  FaceCulling
//
//  Created by Jacob Su on 3/22/21.
//

#ifndef CubeShaderType_h
#define CubeShaderType_h

#include <simd/simd.h>

typedef enum VertexAttributeIndex {
    VertexAttributeIndexPosition = 0,
    VertexAttributeIndexTexcoord = 1,
} VertexAttribute;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} ModelVertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexTexture = 0,
} FragmentInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;


#endif /* CubeShaderType_h */
