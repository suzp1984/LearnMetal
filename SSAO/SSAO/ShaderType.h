//
//  ShaderType.h
//  SSAO
//
//  Created by Jacob Su on 4/13/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#import <simd/simd.h>

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeTexcoord = 1,
    ModelVertexAttributeNormal   = 2,
} VertexAttribute;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
} Uniforms;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexDiffuse  = 0,
    FragmentInputIndexSpecular = 1,
} FragmentInputIndex;

typedef enum SSAOFragmentIndex {
    SSAOFragmentIndexGPosition = 0,
    SSAOFragmentIndexGNormal   = 1,
    SSAOFragmentIndexTexNoise = 2,
    SSAOFragmentIndexKernalSample = 3,
    SSAOFragmentIndexKernalSize = 4,
    SSAOFragmentIndexNoiseScale = 5,
    SSAOFragmentIndexProjectionMatrix = 6,
} SSAOFragmentIndex;

typedef enum LightFragmentIndex {
    LightFragmentIndexGPosition = 0,
    LightFragmentIndexGNormal   = 1,
    LightFragmentIndexGAlbedo   = 2,
    LightFragmentIndexSSAOTexture = 3,
    LightFragmentIndexLight       = 4,
} LightFragmentIndex;

typedef struct QuadVertex {
    vector_float2 position;
    vector_float2 texCoords;
} QuadVertex;

typedef struct Light {
    vector_float3 position;
    vector_float3 color;
    
    float linear;
    float quadratic;
} Light;

#endif /* ShaderType_h */
