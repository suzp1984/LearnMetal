//
//  ShaderType.h
//  EnvironmentMap
//
//  Created by Jacob Su on 3/24/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

typedef enum VertexAttributeIndex {
    VertexAttributeIndexPosition = 0,
    VertexAttributeIndexNormal   = 1,
} VertexAttribute;

typedef enum FragmentInputIndex {
    FragmentInputIndexCubeTexture = 0,
    FragmentInputIndexCameraPos   = 1,
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
    
    matrix_float4x4 inverseModelMatrix;
    
    vector_float3 cameraPos;
} Uniforms;

typedef struct CubeMapVertex {
    vector_float3 position;
} CubeMapVertex;

typedef struct TestVertex {
    vector_float3 position;
    vector_float3 normal;
} TestVertex;

#endif /* ShaderType_h */
