//
//  ShaderType.h
//  Bloom
//
//  Created by Jacob Su on 4/8/21.
//

#ifndef ShaderType_h
#define ShaderType_h


#include <simd/simd.h>

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeNormal   = 1,
    ModelVertexAttributeTexCoord = 2,
} ModelVertexAttribute;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
} Uniforms;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniform  = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexTexture     = 0,
    FragmentInputIndexLights      = 1,
    FragmentInputIndexLightsCount = 2,
    FragmentInputIndexViewPos     = 3,
} FragmentInputIndex;

typedef struct Light {
    vector_float3 position;
    vector_float3 color;
} Light;

typedef struct QuadVertex {
    vector_float2 position;
    vector_float2 texCoord;
} QuadVertex;

typedef enum QuadVertexIndex {
    QuadVertexIndexPosition = 0
} QuadVertexIndex;

#endif /* ShaderType_h */
