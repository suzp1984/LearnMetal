//
//  ShapeShaderType.h
//  2.6.SpecularMap
//
//  Created by Jacob Su on 3/10/21.
//

#ifndef ShapeShaderType_h
#define ShapeShaderType_h

#include <simd/simd.h>

typedef struct Vertex {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texCoords;
} Vertex;

typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
    VertexInputIndexUniforms = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexMaterial = 0,
    FragmentInputIndexLight    = 1,
    FragmentInputIndexViewPos  = 2,
} FragmentInputIndex;

typedef enum FragmentArgumentMaterialBufferID {
    FragmentArgumentMaterialBufferIDDiffuse   = 0,
    FragmentArgumentMaterialBufferIDSpecular  = 1,
    FragmentArgumentMaterialBufferIDShininess = 2,
} FragmentArgumentMaterialBufferID;

typedef struct Uniforms
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    
    matrix_float4x4 inverseModelMatrix;
} Uniforms;

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


#endif /* ShapeShaderType_h */
