//
//  ShaderType.h
//  InstanceQuad
//
//  Created by Jacob Su on 3/28/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

typedef enum VertexIndex {
    VertexIndexPosition = 0,
    VertexIndexOffset   = 1,
} VertexIndex;

typedef struct Vertex {
    vector_float2 position;
    vector_float3 color;
} Vertex;

typedef struct QuadOffset {
    vector_float2 offset;
} QuadOffset;

#endif /* ShaderType_h */
