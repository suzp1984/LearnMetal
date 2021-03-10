//
//  TextureShaderType.h
//  4.Texture
//
//  Created by Jacob Su on 3/3/21.
//

#ifndef TextureShaderType_h
#define TextureShaderType_h

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
} FragmentInputIndex;
#endif /* TextureShaderType_h */
