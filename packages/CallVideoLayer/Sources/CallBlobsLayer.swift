import Foundation
import MetalKit
import MetalEngine
import TGUIKit



struct VertexWave : sizable {
    var time: Float = 0
    var speed: Float = 0.5
    var amplitude: SIMD3<Float> = .init(0, 0, 0)
    var wavelength: SIMD3<Float> = .init(0, 0, 0)
}

public func interpolateFloat(_ value1: Float, _ value2: Float, at factor: Float) -> Float {
    return value1 * (1.0 - factor) + value2 * factor
}

private func generateAmplitudes() -> [Float] {
    return [Float.random(in: 0.1 ..< 0.3),
     Float.random(in: 0.1 ..< 0.3),
     Float.random(in: 0.1 ..< 0.3)]
}
private func generateWavelengths() -> [Float] {
    return [Float.random(in: 0.4 ..< 0.5),
             Float.random(in: 0.4 ..< 0.5),
             Float.random(in: 0.4 ..< 0.5)]
}

public final class CallBlobsLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    public var internalData: MetalEngineSubjectInternalData?
    
    struct Blob {
        
        struct Wave {
            var amplitudes: [Float]
            var lengths: [Float]
            var speed: Float = 0.5
            init(speed: Float = 0.5) {
                self.speed = speed
                self.amplitudes = generateAmplitudes()
                self.lengths = generateWavelengths()
            }
            
            func interpolate(_ wave: Wave, t: Float, speed: Float) -> Wave {
                var interpolated = Wave()
                let speed = interpolateFloat(self.speed, speed, at: t)
                interpolated.speed = speed
                for i in 0 ..< wave.amplitudes.count {
                    interpolated.amplitudes[i] = interpolateFloat(self.amplitudes[i], wave.amplitudes[i], at: t)
                    interpolated.lengths[i] = interpolateFloat(self.lengths[i], wave.lengths[i], at: t)
                }
                return interpolated
            }
            
            func vertexWave(_ t: Float) -> VertexWave {
                return .init(time: t, speed: self.speed, amplitude: SIMD3<Float>(amplitudes[0] * speed, amplitudes[1] * speed, amplitudes[2] * speed), wavelength: SIMD3<Float>(lengths[0] * speed, lengths[1] * speed, lengths[2] * speed))
            }
        }
        
        var points: Int
        var wave: Wave
        var nextWave: Wave
        
        init(count: Int) {
            self.points = count
            
            self.wave = Wave()
            self.nextWave = Wave()
        }

        
        mutating func advance(t: Float, speed: Float) {
            self.wave = self.wave.interpolate(nextWave, t: t, speed: speed)
            self.nextWave = Wave()
        }
    }
    
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "callBlobVertex"), let fragmentFunction = library.makeFunction(name: "callBlobFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    private var phase: Float = 0.0
    
    public var waveSpeed: Float = 0.5
    
    private var blobs: [Blob] = []
    
    private var displayLinkSubscription: SharedDisplayLinkDriver.Link?
    
    public override init() {
        super.init()
        
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] deltaTime in
                guard let self else {
                    return
                }
                self.phase += Float(deltaTime)
                if self.phase - floor(self.phase) <= Float(deltaTime) {
                    for i in 0 ..< self.blobs.count {
                        self.blobs[i].advance(t: 0, speed: self.waveSpeed)
                    }
                }
                self.setNeedsUpdate()
            })
        }
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = nil
        }
        
        self.isOpaque = false
        self.blobs = (0 ..< 3).map { _ in
            Blob(count: 16)
        }
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(context: MetalEngineSubjectContext) {
        if self.bounds.isEmpty {
            return
        }
        
        let phase = self.phase
        let blobs = self.blobs
        
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: Int(self.bounds.width * 4.0), height: Int(self.bounds.height * 4.0)), edgeInset: 0), state: RenderState.self, layer: self, commands: { encoder, placement in
            let rect = placement.effectiveRect
            
            for i in 0 ..< blobs.count {
                var wave = blobs[i].wave.vertexWave(phase)
                
                var count: Int32 = Int32(blobs[i].points)
                
                let insetFraction: CGFloat = CGFloat(i) * 0.1
                
                let blobRect = rect.insetBy(dx: insetFraction * 0.5 * rect.width, dy: insetFraction * 0.5 * rect.height)
                var rect = SIMD4<Float>(Float(blobRect.minX), Float(blobRect.minY), Float(blobRect.width), Float(blobRect.height))
                
               // encoder.setTriangleFillMode(.lines)
                encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
                encoder.setVertexBytes(&count, length: MemoryLayout<Float>.size, index: 1)
                encoder.setVertexBytes(&wave, length: VertexWave.stride(), index: 2)
                
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3 * 8 * Int(count))
            }
        })
    }
}
