//
//  ShapeShaderType.h
//  4.1.DepthTesting
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


typedef struct MyVertex
{
    vector_float3 position;
    vector_float2 texCoord;
} MyVertex;

#endif /* ShapeShaderType_h */
