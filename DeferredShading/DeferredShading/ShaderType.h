//
//  ShaderType.h
//  DeferredShading
//
//  Created by Jacob Su on 4/10/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

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

typedef struct QuadVertex {
    vector_float2 position;
    vector_float2 texCoords;
} QuadVertex;

typedef struct Light {
    vector_float3 position;
    vector_float3 color;
    
    float linear;
    float quadratic;
    float radius;
} Light;

typedef enum DeferredFragmentIndex {
    DeferredFragmentIndexGPositionTexture = 0,
    DeferredFragmentIndexGNormalTexture   = 1,
    DeferredFragmentIndexGAlbedoTexture   = 2,
    DeferredFragmentIndexLights           = 3,
    DeferredFragmentIndexLightsCount      = 4,
    DeferredFragmentIndexViewPosition     = 5,
    DeferredFragmentIndexEnableLightVolumn = 6,
} DeferredFragmentIndex;

typedef struct LightCubeUniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} LightCubeUniforms;

#endif /* ShaderType_h */
