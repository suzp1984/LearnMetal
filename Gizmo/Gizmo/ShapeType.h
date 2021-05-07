//
//  ShapeType.h
//  Gizmo
//
//  Created by Jacob Su on 5/6/21.
//

#ifndef ShapeType_h
#define ShapeType_h

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
    FragmentInputIndexMaterial = 0,
    FragmentInputIndexLight    = 1,
    FragmentInputIndexViewPos  = 2,
} FragmentInputIndex;

typedef struct Material
{
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
    float shininess;
} Material;

typedef struct Light
{
    vector_float3 position;
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
} Light;

#endif /* ShapeType_h */
