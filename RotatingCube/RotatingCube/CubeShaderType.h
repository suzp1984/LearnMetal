//
//  CubeShaderType.h
//  RotatingCube
//
//  Created by Jacob Su on 3/17/21.
//

#ifndef CubeShaderType_h
#define CubeShaderType_h

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
    FragmentInputIndexTexture2 = 1,
} FragmentInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

#endif /* CubeShaderType_h */
