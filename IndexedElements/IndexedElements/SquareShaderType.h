//
//  SquareShaderType.h
//  7.IndexedElements
//
//  Created by Jacob Su on 3/4/21.
//

#ifndef SquareShaderType_h
#define SquareShaderType_h


#include <simd/simd.h>

typedef struct Vertex {
    vector_float2 position;
    vector_float2 texCoord;
} Vertex;

typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexTexture = 0,
    FragmentInputIndexTexture2 = 1,
} FragmentInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

#endif /* SquareShaderType_h */
