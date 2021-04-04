//
//  ShaderType.h
//  PointShadows
//
//  Created by Jacob Su on 4/4/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

typedef enum ModelVertexAttribute {
    ModelVertexAttributePosition = 0,
    ModelVertexAttributeNormal   = 1,
    ModelVertexAttributeTexCoord = 2,
} ModelVertexAttribute;

typedef struct ModelUniform {
    matrix_float4x4 modelMatrix;
} ModelUniform;

typedef struct InstanceParams {
    matrix_float4x4 lightSpaceMatrix;
    uint layer;
} InstanceParams;

typedef enum DepthVertexIndex {
    DepthVertexIndexPosition     = 0,
    DepthVertexIndexModelUniform = 1,
    DepthVertexIndexInstanceParams = 2,
} DepthVertexIndex;

typedef enum DepthFragmentIndex {
    DepthFragmentIndexLightPos = 0,
    DepthFragmentIndexFarPlane = 1,
} DepthFragmentIndex;

typedef enum VertexInputIndex {
    VertexInputIndexPosition = 0,
    VertexInputIndexUniform  = 1,
} VertexInputIndex;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 inverseModelMatrix;
    int isContainer;
} Uniforms;

typedef enum FragmentInputIndex {
    FragmentInputIndexTexture  = 0,
    FragmentInputIndexDepthMap = 1,
    FragmentInputIndexLightPos = 2,
    FragmentInputIndexViewPos  = 3,
    FragmentInputindexFarPlane = 4,
} FragmentInputIndex;

#endif /* ShaderType_h */
