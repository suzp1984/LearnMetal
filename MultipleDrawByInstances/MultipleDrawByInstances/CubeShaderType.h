//
//  CubeShaderType.h
//  10.MultipleDrawByInstances
//
//  Created by Jacob Su on 3/6/21.
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
    VertexInputIndexObjParams = 2,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexArgument = 0,
} FragmentInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

typedef struct ObjectParams
{
    matrix_float4x4 modelMatrix;
} ObjectParams;

typedef enum ArgumentBufferID
{
    ArgumentBufferIDTextureFirst = 0,
    ArgumentBufferIDTextureSecond = 1,
} ArgumentBufferID;

#endif /* CubeShaderType_h */
