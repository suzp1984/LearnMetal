//
//  ShaderType.h
//  ParallaxMapping
//
//  Created by Jacob Su on 4/6/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexDiffuseMap = 0,
    FragmentInputIndexNormalMap  = 1,
    FragmentInputIndexDepthMap   = 2,
    FragmentInputIndexHeightScale = 3,
    FragmentInputIndexParallaxMethod = 4,
} FragmentInputIndex;

typedef struct Uniform {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
    
    vector_float3 lightPos;
    vector_float3 viewPos;
} Uniform;

typedef struct Vertex
{
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texCoord;
    vector_float3 tangent;
    vector_float3 biTangent;
} Vertex;

#endif /* ShaderType_h */
