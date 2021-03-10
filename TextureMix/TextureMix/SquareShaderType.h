//
//  SquareShaderType.h
//  5.TextureMix
//
//  Created by Jacob Su on 3/3/21.
//

#ifndef SquareShaderType_h
#define SquareShaderType_h
#include <simd/simd.h>

typedef struct Vertex {
    vector_float2 position;
    vector_float2 texCoord;
} Vertex;

typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
    VertexInputIndexViewportSize = 1
} VertexInputIndex;

typedef enum FragmentInputIndex {
    FragmentInputIndexTexture = 0,
    FragmentInputIndexTexture2 = 1,
} FragmentInputIndex;

#endif /* SquareShaderType_h */
