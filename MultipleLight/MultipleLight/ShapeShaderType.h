//
//  ShapeShaderType.h
//  2.12.MultipleLight
//
//  Created by Jacob Su on 3/13/21.
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
} FragmentInputIndex;

typedef enum FragmentArgumentMaterialBufferID {
    FragmentArgumentMaterialBufferIDDiffuse   = 0,
    FragmentArgumentMaterialBufferIDSpecular  = 1,
    FragmentArgumentMaterialBufferIDShininess = 2,
} FragmentArgumentMaterialBufferID;

typedef enum FragmentArgumentLightBufferID {
    FragmentArgumentLightBufferIDDirLight    = 0,
    FragmentArgumentLightBufferIDPointLight  = 1,
    FragmentArgumentLightBufferIDSpotLight   = 2,
    FragmentArgumentLightBufferIDPointNumber = 3,
} FragmentArgumentLightBufferID;

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

typedef struct DirLight {
    vector_float3 direction;
    
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
} DirLight;

typedef struct PointLight {
    vector_float3 position;
    
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
    
    float constants;
    float linear;
    float quadratic;
    
} PointLight;

typedef struct SpotLight {
    vector_float3 position;
    vector_float3 direction;
    
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
    
    float cutOff;
    float outerCutOff;
    
    float constants;
    float linear;
    float quadratic;
} SpotLight;

#endif /* ShapeShaderType_h */
