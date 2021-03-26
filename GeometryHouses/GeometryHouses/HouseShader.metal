//
//  HouseShader.metal
//  GeometryHouses
//
//  Created by Jacob Su on 3/26/21.
//

#include <metal_stdlib>
using namespace metal;

#import "ShapeType.h"

static constant vector_float2 houseOffsets[VertexNumberOfOneHouse] = {
    { -0.2, -0.2 }, // 0: bottom-left
    { -0.2,  0.2 }, // 2: top-left
    {  0.2, -0.2 }, // 1: bottom-right
    {  0.2, -0.2 }, // 1: bottom-right
    { -0.2,  0.2 }, // 2: top-left
    {  0.2,  0.2 }, // 3: top-right
    {  0.2,  0.2 }, // 3: top-right
    { -0.2,  0.2 }, // 2: top-left
    {  0.0,  0.4 }, // 4: top
};

kernel void computeHouses(uint   houseID                   [[ thread_position_in_grid ]],
                          device HouseVertex *inputVertex  [[ buffer(ComputeInputIndexHousePosition) ]],
                          device HouseVertex *outputVertex [[ buffer(ComputeInputIndexHouseVertex) ]]) {
    if (houseID >= NumOfHouses) {
        return;
    }
    
    device HouseVertex &housePosition = inputVertex[houseID];
    
    for(int i = 0; i < VertexNumberOfOneHouse; i++) {
        device HouseVertex &ver = outputVertex[houseID * VertexNumberOfOneHouse + i];
        ver.position = housePosition.position + houseOffsets[i];
        ver.color    = housePosition.color;
        
        if (i == (VertexNumberOfOneHouse - 1)) {
            ver.color = {1.0, 1.0, 1.0};
        }
    }
}

struct RasterizerData
{
    float4 position [[position]];
    float3 color;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant HouseVertex *vertices [[buffer(VertexInputIndexVertices)]])
{
    RasterizerData out;
    
    HouseVertex ver = vertices[vertexID];
    
    out.position = vector_float4(ver.position, 0.0, 1.0);
    
    out.color = ver.color;
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]])
{
    return float4(in.color, 1.0);
}
