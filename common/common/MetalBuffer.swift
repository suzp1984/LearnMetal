//
//  MetalBuffer.swift
//  common
//
//  Created by Jacob Su on 3/11/21.
//

import MetalKit

public protocol Resource {
    associatedtype Element
}

/// A wrapper around MTLBuffer which provides type safe access and assignment to the underlying MTLBuffer's contents.

public struct MetalBuffer<Element>: Resource {
    
    /// The underlying MTLBuffer.
    fileprivate let buffer: MTLBuffer
    
    /// The index that the buffer should be bound to during encoding.
    /// Should correspond with the index that the buffer is expected to be at in Metal shaders.
    fileprivate let index: Int
    
    /// The number of elements of T the buffer can hold.
    public let count: Int
    public var stride: Int {
        MemoryLayout<Element>.stride
    }

    /// Initializes the buffer with zeros, the buffer is given an appropriate length based on the provided element count.
    public init(device: MTLDevice, count: Int, index: UInt32, label: String? = nil, options: MTLResourceOptions = []) {
        
        guard let buffer = device.makeBuffer(length: MemoryLayout<Element>.stride * count, options: options) else {
            fatalError("Failed to create MTLBuffer.")
        }
        self.buffer = buffer
        self.buffer.label = label
        self.count = count
        self.index = Int(index)
    }
    
    /// Initializes the buffer with the contents of the provided array.
    public init(device: MTLDevice, array: [Element], index: UInt32, options: MTLResourceOptions = []) {
        
        guard let buffer = device.makeBuffer(bytes: array, length: MemoryLayout<Element>.stride * array.count, options: .storageModeShared) else {
            fatalError("Failed to create MTLBuffer")
        }
        self.buffer = buffer
        self.count = array.count
        self.index = Int(index)
    }
    
    /// Replaces the buffer's memory at the specified element index with the provided value.
    public func assign<T>(_ value: T, at index: Int = 0) {
        precondition(index <= count - 1, "Index \(index) is greater than maximum allowable index of \(count - 1) for this buffer.")
        withUnsafePointer(to: value) {
            buffer.contents().advanced(by: index * stride).copyMemory(from: $0, byteCount: stride)
        }
    }
    
    /// Replaces the buffer's memory with the values in the array.
    public func assign<Element>(with array: [Element]) {
        let byteCount = array.count * stride
        precondition(byteCount == buffer.length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        buffer.contents().copyMemory(from: array, byteCount: byteCount)
    }
    
    /// Returns a copy of the value at the specified element index in the buffer.
    public subscript(index: Int) -> Element {
        get {
            precondition(stride * index <= buffer.length - stride, "This buffer is not large enough to have an element at the index: \(index)")
            return buffer.contents().advanced(by: index * stride).load(as: Element.self)
        }
        
        set {
            assign(newValue, at: index)
        }
    }
    
}

// Note: This extension is in this file because access to Buffer<T>.buffer is fileprivate.
// Access to Buffer<T>.buffer was made fileprivate to ensure that only this file can touch the underlying MTLBuffer.
extension MTLRenderCommandEncoder {
    public func setVertexBuffer<T>(_ vertexBuffer: MetalBuffer<T>, offset: Int = 0) {
        setVertexBuffer(vertexBuffer.buffer, offset: offset, index: vertexBuffer.index)
    }
    
    public func setFragmentBuffer<T>(_ fragmentBuffer: MetalBuffer<T>, offset: Int = 0) {
        setFragmentBuffer(fragmentBuffer.buffer, offset: offset, index: fragmentBuffer.index)
    }
    
    public func setVertexResource<R: Resource>(_ resource: R) throws {
        if let buffer = resource as? MetalBuffer<R.Element> {
            setVertexBuffer(buffer)
        }
        
        if let texture = resource as? Texture {
            if let index = texture.index {
                setVertexTexture(texture.texture, index: index)
            } else {
                throw Errors.runtimeError("set Vertex Texture must has a index.")
            }
        }
    }
    
    public func setFragmentResource<R: Resource>(_ resource: R) throws {
        if let buffer = resource as? MetalBuffer<R.Element> {
            setFragmentBuffer(buffer)
        }

        if let texture = resource as? Texture {
            if let index = texture.index {
                setFragmentTexture(texture.texture, index: index)
            } else {
                throw Errors.runtimeError("set fragment texture must has a index.")
            }
        }
    }
    
    public func setFragmentTexture(_ texture: Texture, index: Int? = nil) throws {
        guard let index = index ?? texture.index else {
            throw Errors.runtimeError("set fragment texture must has a index.")
        }
        
        setFragmentTexture(texture.texture, index: index)
        
    }
}

public struct Texture: Resource {
    public typealias Element = Any
    
    public let texture: MTLTexture
    public let index: Int?
}

extension Texture {
    public static func newTextureWithName(_ name: String,
                                         scaleFactor: CGFloat,
                                         device: MTLDevice,
                                         index: Int? = nil,
                                         bundle: Bundle? = nil,
                                         options: [MTKTextureLoader.Option : Any]? = nil
    ) throws -> Texture {
        let textureLoader = MTKTextureLoader(device: device)
        let texture = try textureLoader.newTexture(name: name,
                                                   scaleFactor: scaleFactor,
                                                   bundle: bundle ?? Bundle(identifier: "io.github.suzp1984.common"),
                                                   options: options)
        
        return Texture(texture: texture, index: index)
    }
    
    public func newTextureWithIndex(_ index: Int?) -> Texture {
        return Texture(texture: texture, index: index)
    }
}
