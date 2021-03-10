//
//  ShapeShaderType.h
//  2.2.DiffuseLighting
//
//  Created by Jacob Su on 3/9/21.
//

#ifndef ShapeShaderType_h
#define ShapeShaderType_h

#include <simd/simd.h>

typedef struct Vertex {
    vector_float3 position;
    vector_float3 normal;
} Vertex;

typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexObjectColor = 0,
    FragmentInputIndexLightColor  = 1,
    FragmentInputIndexLightPos    = 2,
} FragmentInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniforms;


#endif /* ShapeShaderType_h */
