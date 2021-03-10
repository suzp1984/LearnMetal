//
//  TriangleShaderType.h
//  HelloTriangle
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

typedef struct {
    vector_float2 position;
    vector_float4 color;
} Vertex;

#endif /* TriangleShaderType_h */
