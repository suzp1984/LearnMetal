//
//  JsonAnimationMesh.m
//  SkinAnimation
//
//  Created by Jacob Su on 5/9/21.
//

#import <Foundation/Foundation.h>
#import "JsonAnimationMesh.h"
#import "ShaderType.h"
#import <common/common.h>

@interface InverseMatrix : NSObject

@property matrix_float4x4 inverseMatrix;

@end

@implementation InverseMatrix

@end

@implementation JsonAnimationMesh {
    Transform *_root;
    NSArray<Transform*> *_bones;
    NSArray<InverseMatrix*> *_inverseMatrix;
    // animations
    NSArray *_frames;
    int _duration;
    float _elapsed;
}

- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device
                               jsonUrl:(nonnull NSURL*)jsonUrl
                          animationUrl:(nonnull NSURL*)animationUrl
                            textureURL:(nonnull NSURL*)textureURL {
    self = [super init];
    
    if (self) {
        NSError *error;
        NSData *jsonData = [[NSData alloc] initWithContentsOfURL:jsonUrl
                                                        options:NSDataReadingMappedIfSafe
                                                          error:&error];
        NSAssert(jsonData, @"json Url convert to NSData error %@", error);
        id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
        NSAssert(jsonObjects, @"JSONSerialization error: %@", error);
        NSAssert([jsonObjects isKindOfClass:[NSDictionary class]], @"json objects should be a dictionary");
        NSDictionary *dict = (NSDictionary*)jsonObjects;
        NSArray *positions = dict[@"position"];
        NSArray *uvs = dict[@"uv"];
        NSArray *normals = dict[@"normal"];
        NSArray *skinIndex = dict[@"skinIndex"];
        NSArray *skinWeight = dict[@"skinWeight"];
        
//        NSLog(@"%lu, %d, %d, %d, %lu", (unsigned long)[positions count], [uvs count], [normals count], [skinIndex count], (unsigned long)[skinWeight count]);
        
        
        MTLVertexDescriptor *mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];
        // position
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].offset = 0;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].bufferIndex = ModelVertexInputIndexPosition;
        
        // texture coordinate
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].offset = 16;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].bufferIndex = ModelVertexInputIndexPosition;
        
        // normal
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].offset = 32;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].bufferIndex = ModelVertexInputIndexPosition;
        
        // skin index
        mtlVertexDescriptor.attributes[ModelVertexAttributeSkinIndex].format = MTLVertexFormatFloat4;
        mtlVertexDescriptor.attributes[ModelVertexAttributeSkinIndex].offset = 48;
        mtlVertexDescriptor.attributes[ModelVertexAttributeSkinIndex].bufferIndex = ModelVertexInputIndexPosition;
        
        // skin Weight
        mtlVertexDescriptor.attributes[ModelVertexAttributeSkinWeight].format = MTLVertexFormatFloat4;
        mtlVertexDescriptor.attributes[ModelVertexAttributeSkinWeight].offset = 64;
        mtlVertexDescriptor.attributes[ModelVertexAttributeSkinWeight].bufferIndex = ModelVertexInputIndexPosition;
        
        // layout
        mtlVertexDescriptor.layouts[ModelVertexInputIndexPosition].stride = 80;
        mtlVertexDescriptor.layouts[ModelVertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[ModelVertexInputIndexPosition].stepFunction = MTLVertexStepFunctionPerVertex;
        
        _mtlVertexDescriptor = mtlVertexDescriptor;
        
        int vertexCount = (int)positions.count / 3;
        _vertexCount = vertexCount;
        
        float vertexData[vertexCount * 4 * 5];
        for (int i = 0; i < vertexCount; i++) {
            // position
            vertexData[i * 20] = [positions[i * 3] floatValue];
            vertexData[i * 20 + 1] = [positions[i * 3 + 1] floatValue];
            vertexData[i * 20 + 2] = [positions[i * 3 + 2] floatValue];
            
            // texture coordinate
            vertexData[i * 20 + 4] = [uvs[i * 2] floatValue];
            vertexData[i * 20 + 5] = 1.0 - [uvs[i * 2 + 1] floatValue];
            
            // normal
            vertexData[i * 20 + 8] = [normals[i * 3] floatValue];
            vertexData[i * 20 + 9] = [normals[i * 3 + 1] floatValue];
            vertexData[i * 20 + 10] = [normals[i * 3 + 2] floatValue];
            
            // skin index
            vertexData[i * 20 + 12] = [skinIndex[i * 4] floatValue];
            vertexData[i * 20 + 13] = [skinIndex[i * 4 + 1] floatValue];
            vertexData[i * 20 + 14] = [skinIndex[i * 4 + 2] floatValue];
            vertexData[i * 20 + 15] = [skinIndex[i * 4 + 3] floatValue];
            
            // skin weight
            vertexData[i * 20 + 16] = [skinWeight[i * 4] floatValue];
            vertexData[i * 20 + 17] = [skinWeight[i * 4 + 1] floatValue];
            vertexData[i * 20 + 18] = [skinWeight[i * 4 + 2] floatValue];
            vertexData[i * 20 + 19] = [skinWeight[i * 4 + 3] floatValue];
        }
        
        _geometryBuffer = [device newBufferWithBytes:vertexData
                                              length:sizeof(vertexData)
                                             options:MTLResourceStorageModeShared];
        
        NSDictionary *rigDict = dict[@"rig"];
        NSArray *bones = rigDict[@"bones"];
        NSDictionary *bindPose = rigDict[@"bindPose"];
        
        NSArray *bindPosition = bindPose[@"position"];
        NSArray *bindQuaternion = bindPose[@"quaternion"];
        NSArray *bindScale = bindPose[@"scale"];
        
        NSLog(@"position count: %lu", [bindPosition count]);
        
        [self createBone:bones
            bindPosition:bindPosition
          bindQuaternion:bindQuaternion
               bindScale:bindScale];
        [self createBoneTexture:bones device:device];
        
        // animation
        [self createAnimation:animationUrl];
        
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
        _diffuseTexture = [textureLoader newTextureWithContentsOfURL:textureURL options:nil error:&error];
        NSAssert(_diffuseTexture, @"load diffuse texture error %@", error);
    }
    
    return self;
}

- (void) createBone:(NSArray*)bones
       bindPosition:(NSArray*)positions
     bindQuaternion:(NSArray*)quaternion
          bindScale:(NSArray*)scale {
    Transform *root = [[Transform alloc] init];
    _root = root;
    
    NSMutableArray<Transform*> *mutableBones = [NSMutableArray new];
    for (int i = 0; i < bones.count; i++) {
        Transform *bone = [Transform new];
        bone.name = bones[i][@"name"];
        bone.position = (vector_float3) {
            [positions[i * 3] floatValue],
            [positions[i * 3 + 1] floatValue],
            [positions[i * 3 + 2] floatValue] };
        
        bone.quaternionVect = (vector_float4) {
            [quaternion[i * 4] floatValue],
            [quaternion[i * 4 + 1] floatValue],
            [quaternion[i * 4 + 2] floatValue],
            [quaternion[i * 4 + 3] floatValue]
        };
        
        bone.scale = (vector_float3) {
            [scale[i * 3] floatValue],
            [scale[i * 3 + 1] floatValue],
            [scale[i * 3 + 2] floatValue]
        };
        
        [mutableBones addObject:bone];
    }
    
    _bones = mutableBones;
    
    for (int i = 0; i < bones.count; i++) {
        int parent = [bones[i][@"parent"] intValue];
        if (parent == -1) {
            [_bones[i] setParent:_root notifyParent:YES];
        } else {
            [_bones[i] setParent:_bones[parent] notifyParent:YES];
        }
    }
    
    [_root forceCalculateModelMatrix];
    
    NSMutableArray<InverseMatrix*> *mutableInverseMatrix = [NSMutableArray new];
    // inverse
    for (int i = 0; i < _bones.count; i++) {
        matrix_float4x4 inverseMat = matrix_invert(_bones[i].modelMatrix);
        InverseMatrix *mat = [InverseMatrix new];
        mat.inverseMatrix = inverseMat;
        [mutableInverseMatrix addObject:mat];
    }
    
    _inverseMatrix = mutableInverseMatrix;
}

- (void) createBoneTexture:(NSArray*)bones
                    device:(nonnull id<MTLDevice>)device {
    if (bones.count <= 0) return;
    
    int size = MAX(4, pow(2, ceil(log(sqrt(bones.count * 4)) / M_LN2)));
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor new];
    textureDescriptor.textureType = MTLTextureType2D;
    textureDescriptor.width = size;
    textureDescriptor.height = size;
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA32Float;
    textureDescriptor.storageMode = MTLStorageModeManaged;
    textureDescriptor.mipmapLevelCount = 1;
    textureDescriptor.usage = MTLTextureUsageShaderRead;
    
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    _boneTextureSize = size;
    _boneTexture = texture;
}

- (void) createAnimation:(nonnull NSURL*)animationUrl {
    NSError *error;
    NSData *animData = [[NSData alloc] initWithContentsOfURL:animationUrl
                                                    options:NSDataReadingMappedIfSafe
                                                      error:&error];
    NSAssert(animData, @"animation Url convert to NSData error %@", error);
    id animObjects = [NSJSONSerialization JSONObjectWithData:animData
                                                     options:NSJSONReadingMutableContainers
                                                       error:&error];
    NSAssert(animObjects, @"JSONSerialization error: %@", error);
    NSAssert([animObjects isKindOfClass:[NSDictionary class]], @"anim objects should be a dictionary");
    NSDictionary *dict = (NSDictionary*)animObjects;
    
    NSArray *frames = dict[@"frames"];
    int duration = (int) (frames.count - 1);
    _frames = frames;
    _duration = duration;
    _elapsed = 0;
}

- (void) update {
    _elapsed += 0.1;
    if (_elapsed >= _duration) {
        _elapsed = _elapsed - _duration;
    }
    
    int floorFrame = floorf(_elapsed);
    float blend = _elapsed - floorFrame;
    NSDictionary *preKey = _frames[floorFrame];
    NSDictionary *nextKey =_frames[(floorFrame + 1) % _duration];
    
    vector_float3 prePos;
    vector_float4 preRot;
    vector_float3 preScl;
    
    vector_float3 nextPos;
    vector_float4 nextRot;
    vector_float3 nextScl;
    
    for (int i = 0 ; i < _bones.count; i++) {
        // pre keyframe
        prePos.x = [preKey[@"position"][i * 3] floatValue];
        prePos.y = [preKey[@"position"][i * 3 + 1] floatValue];
        prePos.z = [preKey[@"position"][i * 3 + 2] floatValue];
        
        preRot.x = [preKey[@"quaternion"][i * 4] floatValue];
        preRot.y = [preKey[@"quaternion"][i * 4 + 1] floatValue];
        preRot.z = [preKey[@"quaternion"][i * 4 + 2] floatValue];
        preRot.w = [preKey[@"quaternion"][i * 4 + 3] floatValue];
        
        preScl.x = [preKey[@"scale"][i * 3] floatValue];
        preScl.y = [preKey[@"scale"][i * 3 + 1] floatValue];
        preScl.z = [preKey[@"scale"][i * 3 + 2] floatValue];
        
        // next keyframe
        nextPos.x = [nextKey[@"position"][i * 3] floatValue];
        nextPos.y = [nextKey[@"position"][i * 3 + 1] floatValue];
        nextPos.z = [nextKey[@"position"][i * 3 + 2] floatValue];
        
        nextRot.x = [nextKey[@"quaternion"][i * 4] floatValue];
        nextRot.y = [nextKey[@"quaternion"][i * 4 + 1] floatValue];
        nextRot.z = [nextKey[@"quaternion"][i * 4 + 2] floatValue];
        nextRot.w = [nextKey[@"quaternion"][i * 4 + 3] floatValue];
        
        nextScl.x = [nextKey[@"scale"][i * 3] floatValue];
        nextScl.y = [nextKey[@"scale"][i * 3 + 1] floatValue];
        nextScl.z = [nextKey[@"scale"][i * 3 + 2] floatValue];
        
        prePos = vector_lerp(prePos, nextPos, blend);
        preRot = vector_lerp(preRot, nextRot, blend);
        preScl = vector_lerp(preScl, nextScl, blend);
        
//        _bones[i].position = vector_lerp(_bones[i].position, prePos, 1);
//        _bones[i].quaternionVect = vector_lerp(_bones[i].quaternionVect, preRot, 1);
//        _bones[i].scale = vector_lerp(_bones[i].scale, preScl, 1);
        _bones[i].position = prePos;
        _bones[i].quaternionVect = preRot;
        _bones[i].scale = preScl;
    }
    
    [_root forceCalculateModelMatrix];
    
    float *boneMatrices = (float*) malloc(sizeof(float) * 4 * _boneTextureSize * _boneTextureSize);
    
    for (int i = 0; i < _bones.count; i++) {
        matrix_float4x4 mat = matrix_multiply(_bones[i].modelMatrix, _inverseMatrix[i].inverseMatrix);

//        NSLog(@"boneMatrices %d: %f, %f, %f", i, mat.columns[0][0], mat.columns[0][1], mat.columns[0][2]);
        
        float *p = boneMatrices + i * 16;
        
        for (int j = 0; j < 16; j++) {
            p[j] = mat.columns[j % 4][j / 4];
        }
//        memcpy(p, mat.columns, 16 * 4);
    }
    
    // flipY
//    for (int i = 0; i < _boneTextureSize / 2; i++) {
//        int j = _boneTextureSize - 1 - i;
//
//        if (i < j) {
//            float *up = boneMatrices + i * _boneTextureSize * 4;
//            float *down = boneMatrices + j * _boneTextureSize * 4;
//
//            for (int t = 0; t < _boneTextureSize * 4; t++) {
//                float tmp = up[t];
//                up[t] = down[t];
//                down[t] = tmp;
//            }
//        }
//    }
    
    [_boneTexture replaceRegion:MTLRegionMake2D(0, 0, _boneTextureSize, _boneTextureSize)
                    mipmapLevel:0
                      withBytes:boneMatrices
                    bytesPerRow:_boneTextureSize * 16];
    
    free(boneMatrices);
}

@end
