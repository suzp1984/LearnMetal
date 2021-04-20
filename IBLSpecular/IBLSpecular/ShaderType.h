//
//  ShaderType.h
//  IBLSpecular
//
//  Created by Jacob Su on 4/19/21.
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
} Uniforms;

typedef struct CubeMapParams {
    matrix_float4x4 viewMatrix;
    int layerId;
} CubeMapParams;

typedef enum CubeMapVertexIndex {
    CubeMapVertexIndexPosition = 0,
    CubeMapVertexIndexProjection = 1,
    CubeMapVertexIndexInstanceParams = 2,
} CubeMapVertexIndex;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef struct Material {
    vector_float3 albedo;
    float metallic;
    float roughness;
    float ao;
} Material;

typedef struct Light {
    vector_float3 position;
    vector_float3 color;
} Light;

typedef enum FragmentInputIndex {
    FragmentInputIndexMaterial = 0,
    FragmentInputIndexLights   = 1,
    FragmentInputIndexLightsCount = 2,
    FragmentInputIndexCameraPostion = 3,
    FragmentInputIndexArguments = 4,
//    FragmentInputIndexIrradianceMap = 4,
//    FragmentInputIndexPrefilterMap = 5,
//    FragmentInputIndexBrdfLUT = 6,
} FragmentInputIndex;

typedef enum PBRArgumentIndex {
    PBRArgumentIndexIrradianceMap = 0,
    PBRArgumentIndexPrefilterMap = 1,
    PBRArgumentIndexBrdfLUT = 2,
} PBRArgumentIndex;

typedef struct QuadVertex {
    vector_float2 position;
    vector_float2 texCoords;
} QuadVertex;

#endif /* ShaderType_h */
