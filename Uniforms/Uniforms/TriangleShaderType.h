//
//  TriangleShaderType.h
//  3.Uniforms
//
//  Created by Jacob Su on 3/2/21.
//

#ifndef TriangleShaderType_h
#define TriangleShaderType_h


#include <simd/simd.h>

typedef enum VertexInputIndex
{
    VertexInputIndexVertices = 0,
    VertexInputIndexViewportSize = 1,
} VertexInputIndex;

typedef enum FragmentInputIndex
{
    FragmentInputIndexBlueColor = 0,
} FragmentInputIndex;

typedef struct {
    vector_float2 position;
} Vertex;


#endif /* TriangleShaderType_h */
