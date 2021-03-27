//
//  ModelShaderType.h
//  GeometryNormals
//
//  Created by Jacob Su on 3/27/21.
//

#ifndef ModelShaderType_h
#define ModelShaderType_h

#include <simd/simd.h>

typedef enum ComputeKernelIndex {
    ComputeKernelIndexInputVertex  = 0,
    ComputeKernelIndexOutputVertex = 1,
} ComputeKernelIndex;

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeTexcoord = 1,
    ModelVertexAttributeNormal   = 2,
} VertexAttribute;

typedef enum FragmentInputIndex {
    FragmentInputIndexDiffuseTexture = 0,
} FragmentInputIndex;

typedef enum ModelVertexInputIndex {
    ModelVertexInputIndexPosition = 0,
    ModelVertexInputIndexUniforms = 1,
} ModelVertexInputIndex;

typedef enum NormalVertexInputIndex {
    NormalVertexInputIndexPosition = 0,
    NormalVertexInputIndexUniforms = 1,
} NormalVertexInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;

typedef struct NormalVertex
{
    vector_float3 position;
} NormalVertex;

#endif /* ModelShaderType_h */
