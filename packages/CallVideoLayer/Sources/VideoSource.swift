//
//  File.swift
//  
//
//  Created by Mike Renoir on 15.01.2024.
//

import Foundation
import MetalKit
import CoreVideo
import SwiftSignalKit


public final class VideoSourceOutput {
    public struct MirrorDirection: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let horizontal = MirrorDirection(rawValue: 1 << 0)
        public static let vertical = MirrorDirection(rawValue: 1 << 1)
    }
    
    open class DataBuffer {
        open var pixelBuffer: CVPixelBuffer? {
            return nil
        }
        
        public init() {
        }
    }
    
    public final class BiPlanarTextureLayout {
        public let y: MTLTexture
        public let uv: MTLTexture
        
        public init(y: MTLTexture, uv: MTLTexture) {
            self.y = y
            self.uv = uv
        }
    }
    
    public final class BGRATextureLayout {
        public let bgra: MTLTexture
        
        public init(bgra: MTLTexture) {
            self.bgra = bgra
        }
    }
    
    public final class TriPlanarTextureLayout {
        public let y: MTLTexture
        public let u: MTLTexture
        public let v: MTLTexture
        
        public init(y: MTLTexture, u: MTLTexture, v: MTLTexture) {
            self.y = y
            self.u = u
            self.v = v
        }
    }
    
    public enum TextureLayout {
        case bgra(BGRATextureLayout)
        case biPlanar(BiPlanarTextureLayout)
        case triPlanar(TriPlanarTextureLayout)
    }
    
    public final class NativeDataBuffer: DataBuffer {
        private let pixelBufferValue: CVPixelBuffer
        override public var pixelBuffer: CVPixelBuffer? {
            return self.pixelBufferValue
        }
        
        public init(pixelBuffer: CVPixelBuffer) {
            self.pixelBufferValue = pixelBuffer
        }
    }
    
    public let resolution: CGSize
    public let textureLayout: TextureLayout
    public let dataBuffer: DataBuffer
    public let rotationAngle: Float
    public let followsDeviceOrientation: Bool
    public let mirrorDirection: MirrorDirection
    public let sourceId: Int
    
    public init(resolution: CGSize, textureLayout: TextureLayout, dataBuffer: DataBuffer, rotationAngle: Float, followsDeviceOrientation: Bool, mirrorDirection: MirrorDirection, sourceId: Int) {
        self.resolution = resolution
        self.textureLayout = textureLayout
        self.dataBuffer = dataBuffer
        self.rotationAngle = rotationAngle
        self.followsDeviceOrientation = followsDeviceOrientation
        self.mirrorDirection = mirrorDirection
        self.sourceId = sourceId
    }
}

public protocol VideoSource: AnyObject {
    typealias Output = VideoSourceOutput
    
    var currentOutput: Output? { get }
    
    func addOnUpdated(_ f: @escaping () -> Void) -> Disposable
}
