import Metal
import simd

public protocol MTLBufferLayer: CaseIterable {
    var rawValue: UInt16 { get }
    init?(rawValue: UInt16)
    
    static var bufferLabel: String { get }
    func getSize(capacity: Int) -> Int
}

public extension MTLBufferLayer {
    @inlinable @inline(__always)
    @nonobjc static var numCases: Int { Self.allCases.count }
}

public struct MTLLayeredBuffer<Layer: MTLBufferLayer> {
    @usableFromInline internal var _capacity: Int
    @usableFromInline internal var _offsets: [Int]
    @usableFromInline internal var _buffer: MTLBuffer
    
    @inlinable @inline(__always)
    public internal(set) var capacity: Int {
        get { _capacity }
        @usableFromInline set { _capacity = newValue }
    }
    
    @inlinable @inline(__always)
    public internal(set) var buffer: MTLBuffer {
        get { _buffer }
        @usableFromInline set { _buffer = newValue }
    }
    
    
    
    @inlinable @inline(__always)
    public var label: String? {
        get { buffer.label }
        nonmutating set { buffer.label = newValue }
    }
    
    @inlinable @inline(__always)
    public var optLabel: String {
        get { debugLabelReturn("") { label! } }
        nonmutating set { debugLabel { label = newValue } }
    }
    
    @inlinable @inline(__always)
    public var length: Int {
        return buffer.length
    }
    
    @usableFromInline
    internal init(_device: MTLDevice, _capacity: Int, _options: MTLResourceOptions) {
        self._capacity = _capacity
        
        _offsets = []
        _offsets.reserveCapacity(Layer.numCases)
        
        var size = 0
        
        for layer in Layer.allCases {
            _offsets.append(size)
            size += layer.getSize(capacity: _capacity)
        }
        
        _buffer = _device.makeBuffer(length: size, options: _options)!
        buffer.optLabel = Layer.bufferLabel
        
        debugLabel {
            var start = _offsets[0]
            
            for i in 1...Layer.numCases {
                let end = (i == Layer.numCases) ? size : _offsets[i]
                let marker = String(describing: Layer(rawValue: UInt16(i - 1))!)
                
                buffer.addDebugMarker(marker, range: start..<end)
                
                start = end
            }
        }
    }
    
    @inlinable @inline(__always)
    public func offset(for layer: Layer) -> Int {
        _offsets[Int(layer.rawValue)]
    }
    
    @inlinable @inline(__always)
    public subscript(layer: Layer) -> UnsafeMutableRawPointer {
        buffer.contents() + offset(for: layer)
    }
    
    @inlinable
    public mutating func ensureCapacity(device: MTLDevice, capacity: Int) {
        guard self.capacity < capacity else {
            return
        }
        
        changeCapacity(device: device, capacity: capacity)
    }
    
    @inlinable
    public mutating func changeCapacity(device: MTLDevice, capacity: Int) {
        self.capacity = capacity
        
        var size = 0
        
        for layer in Layer.allCases {
            _offsets[Int(layer.rawValue)] = size
            size += layer.getSize(capacity: capacity)
        }
        
        let oldLabel = optLabel
        buffer = device.makeBuffer(length: size, options: buffer.resourceOptions)!
        buffer.optLabel = oldLabel
        
        debugLabel {
            var start = _offsets[0]
            
            for i in 1...Layer.numCases {
                let end = (i == Layer.numCases) ? size : _offsets[i]
                let marker = String(describing: Layer(rawValue: UInt16(i - 1))!)
                
                buffer.addDebugMarker(marker, range: start..<end)
                
                start = end
            }
        }
    }
    
    @inlinable @inline(__always)
    public func makeTexture(descriptor: MTLTextureDescriptor, layer: Layer, offset: Int = 0, bytesPerRow: Int) -> MTLTexture {
        buffer.makeTexture(descriptor: descriptor, offset: self.offset(for: layer) + offset, bytesPerRow: bytesPerRow)!
    }
}

public extension MTLDevice {
    
    @inlinable @inline(__always)
    func makeLayeredBuffer<Layer: MTLBufferLayer>(
        capacity: Int, options: MTLResourceOptions = .storageModeShared) -> MTLLayeredBuffer<Layer>
    {
        .init(_device:   self,
              _capacity: capacity,
              _options:  options)
    }
    
}

// MARK: - Compute Commands

public extension MTLComputeCommandEncoder {
    @inlinable @inline(__always)
    func setBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                          offset: Int = 0, index: Int, bound: Bool = false)
    {
        let internalOffset = buffer.offset(for: layer) + offset
        
        if bound {
            setBufferOffset(internalOffset, index: index)
        } else {
            setBuffer(buffer.buffer, offset: internalOffset, index: index)
        }
    }
    
    @inlinable @inline(__always)
    func dispatchThreadgroups<Layer: MTLBufferLayer>(indirectBuffer: MTLLayeredBuffer<Layer>, indirectBufferLayer: Layer,
                                                     indirectLayerOffset: Int = 0, threadsPerThreadgroup: MTLSize)
    {
        let internalOffset = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        dispatchThreadgroups(indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset,
                             threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    @inlinable @inline(__always)
    func setStageInRegionWithIndirectBuffer<Layer: MTLBufferLayer>(_ indirectBuffer: MTLLayeredBuffer<Layer>,
                                                                   indirectBufferLayer: Layer, indirectLayerOffset: Int = 0)
    {
        let internalOffset = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        setStageInRegionWithIndirectBuffer(indirectBuffer.buffer, indirectBufferOffset: internalOffset)
    }
    
    #if !os(macOS)
    @inlinable @inline(__always)
    func executeCommandsInBuffer<Layer: MTLBufferLayer>(_ buffer: MTLIndirectCommandBuffer,
                                                        indirectBuffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int)
    {
        let internalOffset = indirectBuffer.offset(for: layer) + offset
        executeCommandsInBuffer(buffer, indirectBuffer: indirectBuffer.buffer, offset: internalOffset)
    }
    #endif
    
}

public extension MTLIndirectComputeCommand {
    @inlinable @inline(__always)
    func setKernelBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int = 0, at index: Int) {
        setKernelBuffer(buffer.buffer, offset: buffer.offset(for: layer) + offset, at: index)
    }
    
}

public extension MTLRenderCommandEncoder {
    @inlinable @inline(__always)
    func setTessellationFactorBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                            offset: Int = 0, instanceStride: Int)
    {
        setTessellationFactorBuffer(buffer.buffer, offset: buffer.offset(for: layer) + offset, instanceStride: instanceStride)
    }
    
    @inlinable @inline(__always)
    func setVertexBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                offset: Int = 0, index: Int, bound: Bool = false)
    {
        let internalOffset = buffer.offset(for: layer) + offset
        
        if bound {
            setVertexBufferOffset(internalOffset, index: index)
        } else {
            setVertexBuffer(buffer.buffer, offset: internalOffset, index: index)
        }
    }

    @inlinable @inline(__always)
    func setFragmentBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                  offset: Int = 0, index: Int, bound: Bool = false)
    {
        let internalOffset = buffer.offset(for: layer) + offset
        
        if bound {
            setFragmentBufferOffset(internalOffset, index: index)
        } else {
            setFragmentBuffer(buffer.buffer, offset: internalOffset, index: index)
        }
    }
    
    @inlinable @inline(__always)
    func setTileBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                              offset: Int = 0, index: Int, bound: Bool = false)
    {
        let internalOffset = buffer.offset(for: layer) + offset
        
        if bound {
            setTileBufferOffset(internalOffset, index: index)
        } else {
            setTileBuffer(buffer.buffer, offset: internalOffset, index: index)
        }
    }

    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        type:        MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer: MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        drawIndexedPrimitives(type:        type,               indexCount: indexCount, indexType: indexType,
                              indexBuffer: indexBuffer.buffer, indexBufferOffset: internalOffset)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        type:          MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer:   MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0,
        instanceCount: Int)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        drawIndexedPrimitives(type:          type,               indexCount: indexCount, indexType: indexType,
                              indexBuffer:   indexBuffer.buffer, indexBufferOffset: internalOffset,
                              instanceCount: instanceCount)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        type:          MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer:   MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0,
        instanceCount: Int,                     baseVertex:       Int,   baseInstance:     Int)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        drawIndexedPrimitives(type:          type,               indexCount: indexCount, indexType: indexType,
                              indexBuffer:   indexBuffer.buffer, indexBufferOffset: internalOffset,
                              instanceCount: instanceCount,      baseVertex: baseVertex, baseInstance: baseInstance)
    }
    
    @inlinable @inline(__always)
    func drawPatches<Layer: MTLBufferLayer>(
        numberOfPatchControlPoints: Int,                     patchStart: Int,              patchCount: Int,
        patchIndexBuffer:           MTLLayeredBuffer<Layer>, patchIndexBufferLayer: Layer, patchIndexLayerOffset: Int = 0,
        instanceCount:              Int,                     baseInstance: Int)
    {
        let internalOffset = patchIndexBuffer.offset(for: patchIndexBufferLayer) + patchIndexLayerOffset
        drawPatches(numberOfPatchControlPoints: numberOfPatchControlPoints, patchStart: patchStart, patchCount: patchCount,
                    patchIndexBuffer:           patchIndexBuffer.buffer,    patchIndexBufferOffset: internalOffset,
                    instanceCount:              instanceCount,              baseInstance:           baseInstance)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPatches<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer>(
        numberOfPatchControlPoints: Int,                      patchStart:                   Int,    patchCount:                   Int,
        patchIndexBuffer:           MTLLayeredBuffer<Layer1>, patchIndexBufferLayer:        Layer1, patchIndexLayerOffset:        Int = 0,
        controlPointIndexBuffer:    MTLLayeredBuffer<Layer2>, controlPointIndexBufferLayer: Layer2, controlPointIndexLayerOffset: Int = 0,
        instanceCount:              Int,                      baseInstance:                 Int)
    {
        let internalOffset1 = patchIndexBuffer       .offset(for: patchIndexBufferLayer)        + patchIndexLayerOffset
        let internalOffset2 = controlPointIndexBuffer.offset(for: controlPointIndexBufferLayer) + controlPointIndexLayerOffset
        
        drawIndexedPatches(numberOfPatchControlPoints: numberOfPatchControlPoints,     patchStart: patchStart, patchCount: patchCount,
                           patchIndexBuffer:           patchIndexBuffer.buffer,        patchIndexBufferOffset:        internalOffset1,
                           controlPointIndexBuffer:    controlPointIndexBuffer.buffer, controlPointIndexBufferOffset: internalOffset2,
                           instanceCount:              instanceCount,                  baseInstance:                  baseInstance)
    }
    
    @inlinable @inline(__always)
    func drawPrimitives<Layer: MTLBufferLayer>(type:     MTLPrimitiveType, indirectBuffer: MTLLayeredBuffer<Layer>,
                                               indirectBufferLayer: Layer, indirectLayerOffset: Int = 0)
    {
        let internalOffset = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        drawPrimitives(type: type, indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer>(
        type:           MTLPrimitiveType,         indexType:           MTLIndexType,
        indexBuffer:    MTLLayeredBuffer<Layer1>, indexBufferLayer:    Layer1, indexLayerOffset:    Int = 0,
        indirectBuffer: MTLLayeredBuffer<Layer2>, indirectBufferLayer: Layer2, indirectLayerOffset: Int = 0)
    {
        let internalOffset1 = indexBuffer   .offset(for: indexBufferLayer)    + indexLayerOffset
        let internalOffset2 = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        
        drawIndexedPrimitives(type:           type,                  indexType:            indexType,
                              indexBuffer:    indexBuffer.buffer,    indexBufferOffset:    internalOffset1,
                              indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset2)
    }
    
    @inlinable @inline(__always)
    func drawPatches<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer>(
        numberOfPatchControlPoints: Int,
        patchIndexBuffer:           MTLLayeredBuffer<Layer1>, patchIndexBufferLayer: Layer1, patchIndexLayerOffset: Int = 0,
        indirectBuffer:             MTLLayeredBuffer<Layer2>, indirectBufferLayer:   Layer2, indirectLayerOffset:   Int = 0)
    {
        let internalOffset1 = patchIndexBuffer.offset(for: patchIndexBufferLayer) + patchIndexLayerOffset
        let internalOffset2 = indirectBuffer  .offset(for: indirectBufferLayer)   + indirectLayerOffset
        
        drawPatches(numberOfPatchControlPoints: numberOfPatchControlPoints,
                    patchIndexBuffer:           patchIndexBuffer.buffer, patchIndexBufferOffset: internalOffset1,
                    indirectBuffer:             indirectBuffer.buffer,   indirectBufferOffset:   internalOffset2)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPatches<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer, Layer3: MTLBufferLayer>(
        numberOfPatchControlPoints: Int,
        patchIndexBuffer:           MTLLayeredBuffer<Layer1>, patchIndexBufferLayer:        Layer1, patchIndexLayerOffset:        Int = 0,
        controlPointIndexBuffer:    MTLLayeredBuffer<Layer2>, controlPointIndexBufferLayer: Layer2, controlPointIndexLayerOffset: Int = 0,
        indirectBuffer:             MTLLayeredBuffer<Layer3>, indirectBufferLayer:          Layer3, indirectLayerOffset:          Int = 0)
    {
        let internalOffset1 = patchIndexBuffer       .offset(for: patchIndexBufferLayer)        + patchIndexLayerOffset
        let internalOffset2 = controlPointIndexBuffer.offset(for: controlPointIndexBufferLayer) + controlPointIndexLayerOffset
        let internalOffset3 = indirectBuffer         .offset(for: indirectBufferLayer)          + indirectLayerOffset
        
        drawIndexedPatches(numberOfPatchControlPoints: numberOfPatchControlPoints,
                           patchIndexBuffer:           patchIndexBuffer.buffer,        patchIndexBufferOffset:        internalOffset1,
                           controlPointIndexBuffer:    controlPointIndexBuffer.buffer, controlPointIndexBufferOffset: internalOffset2,
                           indirectBuffer:             indirectBuffer.buffer,          indirectBufferOffset:          internalOffset3)
    }
    
    @inlinable @inline(__always)
    func executeCommandsInBuffer<Layer: MTLBufferLayer>(_ buffer: MTLIndirectCommandBuffer,
                                                        indirectBuffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int = 0)
    {
        let internalOffset = indirectBuffer.offset(for: layer) + offset
        executeCommandsInBuffer(buffer, indirectBuffer: indirectBuffer.buffer, offset: internalOffset)
    }
       
}

public extension MTLIndirectRenderCommand {
    @inlinable @inline(__always)
    func setVertexBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                offset: Int = 0, at index: Int)
    {
        setVertexBuffer(buffer.buffer, offset: buffer.offset(for: layer) + offset, at: index)
    }
    
    @inlinable @inline(__always)
    func setFragmentBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                  offset: Int = 0, at index: Int)
    {
        setFragmentBuffer(buffer.buffer, offset: buffer.offset(for: layer) + offset, at: index)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        _ primitiveType: MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer:     MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0,
        instanceCount:   Int,                     baseVertex:       Int,   baseInstance:     Int)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        drawIndexedPrimitives(primitiveType,                     indexCount: indexCount, indexType: indexType,
                              indexBuffer:   indexBuffer.buffer, indexBufferOffset: internalOffset,
                              instanceCount: instanceCount,      baseVertex: baseVertex, baseInstance: baseInstance)
    }
    
    @inlinable @inline(__always)
    func drawPatches<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer>(
        _ numberOfPatchControlPoints: Int,                      patchStart:                    Int,    patchCount:                    Int,
        patchIndexBuffer:             MTLLayeredBuffer<Layer1>, patchIndexBufferLayer:         Layer1, patchIndexLayerOffset:         Int = 0,
        instanceCount:                Int,                      baseInstance: Int,
        tessellationFactorBuffer:     MTLLayeredBuffer<Layer2>, tessellationFactorBufferLayer: Layer2, tessellationFactorLayerOffset: Int = 0,
        tessellationFactorBufferInstanceStride: Int)
    {
        let internalOffset1 = patchIndexBuffer        .offset(for: patchIndexBufferLayer)         + patchIndexLayerOffset
        let internalOffset2 = tessellationFactorBuffer.offset(for: tessellationFactorBufferLayer) + tessellationFactorLayerOffset
        
        drawPatches(numberOfPatchControlPoints,                                patchStart: patchStart, patchCount: patchCount,
                    patchIndexBuffer:         patchIndexBuffer.buffer,         patchIndexBufferOffset:         internalOffset1,
                    instanceCount:            instanceCount,                   baseInstance:                   baseInstance,
                    tessellationFactorBuffer: tessellationFactorBuffer.buffer, tessellationFactorBufferOffset: internalOffset2,
                    tessellationFactorBufferInstanceStride: tessellationFactorBufferInstanceStride)
    }
    
    @inlinable @inline(__always)
    func drawIndexedPatches<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer, Layer3: MTLBufferLayer>(
        _ numberOfPatchControlPoints: Int,                      patchStart:                    Int,    patchCount:                    Int,
        patchIndexBuffer:             MTLLayeredBuffer<Layer1>, patchIndexBufferLayer:         Layer1, patchIndexLayerOffset:         Int = 0,
        controlPointIndexBuffer:      MTLLayeredBuffer<Layer2>, controlPointIndexBufferLayer:  Layer2, controlPointIndexLayerOffset:  Int = 0,
        instanceCount:                Int,                      baseInstance: Int,
        tessellationFactorBuffer:     MTLLayeredBuffer<Layer3>, tessellationFactorBufferLayer: Layer3, tessellationFactorLayerOffset: Int = 0,
        tessellationFactorBufferInstanceStride: Int)
    {
        let internalOffset1 = patchIndexBuffer        .offset(for: patchIndexBufferLayer)         + patchIndexLayerOffset
        let internalOffset2 = controlPointIndexBuffer .offset(for: controlPointIndexBufferLayer)  + controlPointIndexLayerOffset
        let internalOffset3 = tessellationFactorBuffer.offset(for: tessellationFactorBufferLayer) + tessellationFactorLayerOffset
        
        drawIndexedPatches(numberOfPatchControlPoints,                                patchStart: patchStart, patchCount: patchCount,
                           patchIndexBuffer:         patchIndexBuffer.buffer,         patchIndexBufferOffset:         internalOffset1,
                           controlPointIndexBuffer:  controlPointIndexBuffer.buffer,  controlPointIndexBufferOffset:  internalOffset2,
                           instanceCount:            instanceCount,                   baseInstance:                   baseInstance,
                           tessellationFactorBuffer: tessellationFactorBuffer.buffer, tessellationFactorBufferOffset: internalOffset3,
                           tessellationFactorBufferInstanceStride: tessellationFactorBufferInstanceStride)
    }
    
}

public extension MTLBlitCommandEncoder {
    @inlinable @inline(__always)
    func copy<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer>(
        from sourceBuffer:      MTLLayeredBuffer<Layer1>, sourceLayer:      Layer1, sourceOffset:      Int = 0,
        to   destinationBuffer: MTLLayeredBuffer<Layer2>, destinationLayer: Layer2, destinationOffset: Int = 0, size: Int)
    {
        let internalOffset1 = sourceBuffer.offset(for: sourceLayer) + sourceOffset
        let internalOffset2 = destinationBuffer.offset(for: destinationLayer) + destinationOffset
        
        copy(from: sourceBuffer.buffer,      sourceOffset: internalOffset1,
             to:   destinationBuffer.buffer, destinationOffset: internalOffset2, size: size)
    }
    
    @inlinable @inline(__always)
    func copy<Layer: MTLBufferLayer>(
        from sourceBuffer:     MTLLayeredBuffer<Layer>, sourceLayer:         Layer, sourceOffset:     Int = 0,
        sourceBytesPerRow:     Int,                     sourceBytesPerImage: Int,   sourceSize:       MTLSize,
        to destinationTexture: MTLTexture,              destinationSlice:    Int,   destinationLevel: Int,
        destinationOrigin:     MTLOrigin,               options:             MTLBlitOption? = nil)
    {
        let internalOffset = sourceBuffer.offset(for: sourceLayer) + sourceOffset
        
        if let options = options {
            copy(from:              sourceBuffer.buffer, sourceOffset:        internalOffset,
                 sourceBytesPerRow: sourceBytesPerRow,   sourceBytesPerImage: sourceBytesPerImage, sourceSize:       sourceSize,
                 to:                destinationTexture,  destinationSlice:    destinationSlice,    destinationLevel: destinationLevel,
                 destinationOrigin: destinationOrigin,   options:             options)
        } else {
            copy(from:              sourceBuffer.buffer, sourceOffset:        internalOffset,
                 sourceBytesPerRow: sourceBytesPerRow,   sourceBytesPerImage: sourceBytesPerImage, sourceSize:       sourceSize,
                 to:                destinationTexture,  destinationSlice:    destinationSlice,    destinationLevel: destinationLevel,
                 destinationOrigin: destinationOrigin)
        }
    }
    
    @inlinable @inline(__always)
    func copy<Layer: MTLBufferLayer>(
        from sourceTexture:     MTLTexture,              sourceSlice:              Int,     sourceLevel: Int,
        sourceOrigin:           MTLOrigin,               sourceSize:               MTLSize,
        to destinationBuffer:   MTLLayeredBuffer<Layer>, destinationLayer:         Layer,   destinationOffset: Int = 0,
        destinationBytesPerRow: Int,                     destinationBytesPerImage: Int,     options: MTLBlitOption? = nil)
    {
        let internalOffset = destinationBuffer.offset(for: destinationLayer) + destinationOffset
        
        if let options = options {
            copy(from:                   sourceTexture,            sourceSlice:       sourceSlice, sourceLevel: sourceLevel,
                 sourceOrigin:           sourceOrigin,             sourceSize:        sourceSize,
                 to:                     destinationBuffer.buffer, destinationOffset: internalOffset,
                 destinationBytesPerRow: destinationBytesPerRow,   destinationBytesPerImage: destinationBytesPerImage,
                 options:                options)
        } else {
            copy(from:                   sourceTexture,            sourceSlice:       sourceSlice, sourceLevel: sourceLevel,
                 sourceOrigin:           sourceOrigin,             sourceSize:        sourceSize,
                 to:                     destinationBuffer.buffer, destinationOffset: internalOffset,
                 destinationBytesPerRow: destinationBytesPerRow,   destinationBytesPerImage: destinationBytesPerImage)
        }
        
        
    }
    
    @inlinable @inline(__always)
    func fill<Layer: MTLBufferLayer>(buffer: MTLLayeredBuffer<Layer>, layer: Layer, range: Range<Int>, value: UInt8) {
        let internalOffset = buffer.offset(for: layer)
        
        let fillStart = internalOffset + range.startIndex
        let fillEnd   = internalOffset + range.endIndex
        fill(buffer: buffer.buffer, range: fillStart..<fillEnd, value: value)
    }
    
    @inlinable @inline(__always)
    func resolveCounters<Layer: MTLBufferLayer>(
        _ sampleBuffer: MTLCounterSampleBuffer,     range: Range<Int>,
        destinationBuffer: MTLLayeredBuffer<Layer>, destinationBufferLayer: Layer, destinationLayerOffset: Int = 0)
    {
        let internalOffset = destinationBuffer.offset(for: destinationBufferLayer) + destinationLayerOffset
        resolveCounters(sampleBuffer, range: range, destinationBuffer: destinationBuffer.buffer, destinationOffset: internalOffset)
    }
    
    @inlinable @inline(__always)
    func getTextureAccessCounters<Layer: MTLBufferLayer>(
        _ texture: MTLTexture, region: MTLRegion, mipLevel: Int, slice: Int,  resetCounters: Bool,
        countersBuffer:  MTLLayeredBuffer<Layer>, countersBufferLayer: Layer, countersLayerOffset: Int = 0)
    {
        let internalOffset = countersBuffer.offset(for: countersBufferLayer) + countersLayerOffset
        #if os(macOS)
        getTextureAccessCounters?(texture, region: region, mipLevel: mipLevel, slice: slice, resetCounters: resetCounters,
                                  countersBuffer:  countersBuffer.buffer,      countersBufferOffset: internalOffset)
        #else
        getTextureAccessCounters(texture, region: region, mipLevel: mipLevel, slice: slice, resetCounters: resetCounters,
                                 countersBuffer:  countersBuffer.buffer,      countersBufferOffset: internalOffset)
        #endif
    }
    
}

extension MTLAccelerationStructureCommandEncoder {
    @inlinable @inline(__always)
    func build<Layer: MTLBufferLayer>(
        accelerationStructure: MTLAccelerationStructure, descriptor:         MTLAccelerationStructureDescriptor,
        scratchBuffer:         MTLLayeredBuffer<Layer>,  scratchBufferLayer: Layer, scratchLayerOffset: Int = 0)
    {
        let internalOffset = scratchBuffer.offset(for: scratchBufferLayer) + scratchLayerOffset
        build(accelerationStructure: accelerationStructure, descriptor:          descriptor,
              scratchBuffer:         scratchBuffer.buffer,  scratchBufferOffset: internalOffset)
    }
    
    @inlinable @inline(__always)
    func writeCompactedSize<Layer: MTLBufferLayer>(accelerationStructure: MTLAccelerationStructure,
                                                   buffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int = 0,
                                                   sizeDataType: MTLDataType? = nil)
    {
        let internalOffset = buffer.offset(for: layer) + offset
        
        if let sizeDataType = sizeDataType, #available(iOS 15.0, macOS 12.0, *) {
            writeCompactedSize(accelerationStructure: accelerationStructure,
                               buffer: buffer.buffer, offset: internalOffset, sizeDataType: sizeDataType)
        } else {
            writeCompactedSize(accelerationStructure: accelerationStructure,
                               buffer: buffer.buffer, offset: internalOffset)
        }
    }
    
    @inlinable @inline(__always)
    func refit<Layer: MTLBufferLayer>(
        sourceAccelerationStructure:      MTLAccelerationStructure, descriptor: MTLAccelerationStructureDescriptor,
        destinationAccelerationStructure: MTLAccelerationStructure,
        scratchBuffer:                    MTLLayeredBuffer<Layer>,  scratchBufferLayer: Layer, scratchLayerOffset: Int = 0)
    {
        let internalOffset = scratchBuffer.offset(for: scratchBufferLayer) + scratchLayerOffset
        refit(sourceAccelerationStructure:      sourceAccelerationStructure, descriptor: descriptor,
              destinationAccelerationStructure: destinationAccelerationStructure,
              scratchBuffer:                    scratchBuffer.buffer,        scratchBufferOffset: internalOffset)
    }
}

public extension MTLArgumentEncoder {
    @inlinable @inline(__always)
    func setArgumentBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int) {
        setArgumentBuffer(buffer.buffer, offset: buffer.offset(for: layer) + offset)
    }
    
    @inlinable @inline(__always)
    func setArgumentBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                         startOffset: Int = 0, arrayElement: Int)
    {
        let internalOffset = buffer.offset(for: layer) + startOffset
        setArgumentBuffer(buffer.buffer, startOffset: internalOffset, arrayElement: arrayElement)
    }
    
    @inlinable @inline(__always)
    func setBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int = 0, index: Int) {
        setBuffer(buffer.buffer, offset: buffer.offset(for: layer) + offset, index: index)
    }
}

public extension MTLResourceStateCommandEncoder {
    @inlinable @inline(__always)
    func updateTextureMapping<Layer: MTLBufferLayer>(
        _ texture:      MTLTexture,              mode:                MTLSparseTextureMappingMode,
        indirectBuffer: MTLLayeredBuffer<Layer>, indirectBufferLayer: Layer, indirectLayerOffset: Int = 0)
    {
        let internalOffset = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        #if os(macOS)
        updateTextureMapping?(texture, mode: mode, indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset)
        #else
        updateTextureMapping(texture, mode: mode, indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset)
        #endif
    }
}

public extension MTLRasterizationRateMap {
    @inlinable @inline(__always)
    func copyParameterData<Layer: MTLBufferLayer>(buffer: MTLLayeredBuffer<Layer>, layer: Layer, offset: Int = 0) {
        copyParameterData(buffer: buffer.buffer, offset: buffer.offset(for: layer) + offset)
    }
}
