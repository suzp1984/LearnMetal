//
//  ShapeShaderType.h
//  11.DrawTwoObjects
//
//  Created by Jacob Su on 3/7/21.
//

#ifndef ShapeShaderType_h
#define ShapeShaderType_h

#include <simd/simd.h>

typedef struct Vertex {
    vector_float3 position;
    vector_float2 texCoord;
} Vertex;

typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexTexture = 0,
} FragmentInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;


#endif /* ShapeShaderType_h */
