import CoreVideo
import Metal

public enum CV {
    public struct MetalTexture {
        @usableFromInline internal var _texture: CVMetalTexture
        
        @inlinable @inline(__always)
        public var asCVMetalTexture: CVMetalTexture { _texture }
        
        @inlinable @inline(__always)
        public init(_ texture: CVMetalTexture) {
            self._texture = texture
        }
        
        @inlinable @inline(__always)
        public static var typeID: CFTypeID { CVMetalTextureGetTypeID() }
        
        @inlinable @inline(__always)
        public var texture: MTLTexture? {
            CVMetalTextureGetTexture(_texture)
        }
        
        @inlinable @inline(__always)
        public var isFlipped: Bool {
            CVMetalTextureIsFlipped(_texture)
        }
        
        @inlinable @inline(__always)
        public func getCleanTexCoords(_ lowerLeft:  UnsafeMutablePointer<Float>, _ lowerRight: UnsafeMutablePointer<Float>,
                                      _ upperRight: UnsafeMutablePointer<Float>, _ upperLeft:  UnsafeMutablePointer<Float>) {
            CVMetalTextureGetCleanTexCoords(_texture, lowerLeft, lowerRight, upperRight, upperLeft)
        }
    }
}

public extension Optional where Wrapped == CVMetalTextureCache {
    
    @inlinable @inline(__always)
    init(_ allocator: CFAllocator?, _ cacheAttributes: [CFString : Any]?,
         _ metalDevice: MTLDevice, _ textureAttributes: [CFString : Any]?,
         _ returnRef: UnsafeMutablePointer<CVReturn>? = nil)
    {
        var cacheOut: CVMetalTextureCache?
        let output = CVMetalTextureCacheCreate(allocator,   cacheAttributes as CFDictionary?,
                                               metalDevice, textureAttributes as CFDictionary?, &cacheOut)
        
        if let returnRef = returnRef {
            returnRef.pointee = output
        }
        
        self = cacheOut
    }
    
}

public extension CVMetalTextureCache {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CVMetalTextureCacheGetTypeID() }
    
    @inlinable @inline(__always)
    func createMTLTexture(_ sourceImage: CVImageBuffer, _ pixelFormat: MTLPixelFormat,
                          _ width: Int, _ height: Int,  _ planeIndex: Int = 0) -> MTLTexture? {
        createTexture(nil, sourceImage, nil, pixelFormat, width, height, planeIndex)?.texture
    }
    
    @inlinable @inline(__always)
    func createTexture(_ allocator: CFAllocator?, _ sourceImage: CVImageBuffer,
                       _ textureAttributes: [CFString : Any]?,
                       _ pixelFormat: MTLPixelFormat, _ width: Int, _ height: Int, _ planeIndex: Int,
                       _ returnRef: UnsafeMutablePointer<CVReturn>? = nil) -> CV.MetalTexture?
    {
        var textureOut: CVMetalTexture?
        let output = CVMetalTextureCacheCreateTextureFromImage(allocator, self, sourceImage,
                                                               textureAttributes as CFDictionary?,
                                                               pixelFormat, width, height, planeIndex, &textureOut)
        
        if let returnRef = returnRef {
            returnRef.pointee = output
        }
        
        guard let texture = textureOut else {
            return nil
        }
        
        return CV.MetalTexture(texture)
    }
    
    @inlinable @inline(__always)
    func flush(_ options: CVOptionFlags) {
        CVMetalTextureCacheFlush(self, options)
    }
    
}
