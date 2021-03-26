//
//  ShapeType.h
//  GeometryHouses
//
//  Created by Jacob Su on 3/26/21.
//

#ifndef ShapeType_h
#define ShapeType_h

#include <simd/simd.h>

#define NumOfHouses 4
#define VertexNumberOfOneHouse 9

typedef struct HouseVertex {
    vector_float2 position;
    vector_float3 color;
} HouseVertex;

typedef enum ComputeInputIndex {
    ComputeInputIndexHousePosition,
    ComputeInputIndexHouseVertex,
} ComputeInputIndex;

typedef enum VertexInputIndex {
    VertexInputIndexVertices,
    
} VertexInputIndex;

#endif /* ShapeType_h */
