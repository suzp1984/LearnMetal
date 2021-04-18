//
//  ShaderType.h
//  RadianceHDR
//
//  Created by Jacob Su on 4/18/21.
//

#ifndef ShaderType_h
#define ShaderType_h

#import <simd/simd.h>

typedef enum SkyDomeVertexIndex {
    SkyDomeVertexIndexPosition = 0,
    SkyDomeVertexIndexUniform  = 1,
} SkyDomeVertexIndex;

typedef struct SkyDomeVertex {
    vector_float2 position;
} SkyDomeVertex;

typedef struct Uniform {
    matrix_float4x4 viewMatrix;
    matrix_float4x4 inverseViewMatrix;
    
    vector_float3 skyDomeOffsets;
} Uniform;

#endif /* ShaderType_h */
