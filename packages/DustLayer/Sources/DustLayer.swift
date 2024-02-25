import TGUIKit
import MetalEngine
import MetalKit

private final class BundleMarker: NSObject {
}

private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }

    guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
        return nil
    }
    
    metalLibraryValue = library
    return library
}

public final class DustLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    public var internalData: MetalEngineSubjectInternalData?
    
    private final class Item {
        let frame: CGRect
        let texture: MTLTexture
        
        var phase: Float = 0.35
        var particleBufferIsInitialized: Bool = false
        var particleBuffer: SharedBuffer?
        
        init?(frame: CGRect, image: NSImage) {
            self.frame = frame
            
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil), let texture = try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: cgImage, options: [.SRGB: false as NSNumber]) else {
                return nil
            }
            self.texture = texture
        }
    }
    
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "dustEffectVertex"), let fragmentFunction = library.makeFunction(name: "dustEffectFragment") else {
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
    
    final class DustComputeState: ComputeState {
        let computePipelineStateInitializeParticle: MTLComputePipelineState
        let computePipelineStateUpdateParticle: MTLComputePipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            
            guard let functionDustEffectInitializeParticle = library.makeFunction(name: "dustEffectInitializeParticle") else {
                return nil
            }
            guard let computePipelineStateInitializeParticle = try? device.makeComputePipelineState(function: functionDustEffectInitializeParticle) else {
                return nil
            }
            self.computePipelineStateInitializeParticle = computePipelineStateInitializeParticle
            
            guard let functionDustEffectUpdateParticle = library.makeFunction(name: "dustEffectUpdateParticle") else {
                return nil
            }
            guard let computePipelineStateUpdateParticle = try? device.makeComputePipelineState(function: functionDustEffectUpdateParticle) else {
                return nil
            }
            
            self.computePipelineStateUpdateParticle = computePipelineStateUpdateParticle
        }
    }
    
    private var updateLink: SharedDisplayLinkDriver.Link?
    private var items: [Item] = []
    private var lastTimeStep: Double = 0.02
    
    public var animationSpeed: Float = 1.0
    
    public var becameEmpty: (() -> Void)?
    
    override public init() {
        super.init()
        
        self.isOpaque = false
        self.backgroundColor = nil
        
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updateNeedsAnimation()
        }
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updateNeedsAnimation()
        }
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var lastUpdateTimestamp: Double?
    
    private func updateItems(deltaTime: Double) {
        let timestamp = CACurrentMediaTime()
        let localDeltaTime: Double
        if let lastUpdateTimestamp = self.lastUpdateTimestamp {
            localDeltaTime = timestamp - lastUpdateTimestamp
        } else {
            localDeltaTime = 0.0
        }
        self.lastUpdateTimestamp = timestamp
        
        let deltaTimeValue: Double
        if localDeltaTime <= 0.001 || localDeltaTime >= 0.2 {
            deltaTimeValue = deltaTime
        } else {
            deltaTimeValue = localDeltaTime
        }
        
        self.lastTimeStep = deltaTimeValue
        
        var didRemoveItems = false
        for i in (0 ..< self.items.count).reversed() {
            self.items[i].phase += Float(deltaTimeValue) * self.animationSpeed / Float(NSView.animationDurationFactor())
            
            if self.items[i].phase >= 3.0 {
                self.items.remove(at: i)
                didRemoveItems = true
            }
        }
        self.updateNeedsAnimation()
        
        if didRemoveItems && self.items.isEmpty {
            self.becameEmpty?()
        }
    }
    
    private func updateNeedsAnimation() {
        if !self.items.isEmpty && self.isInHierarchy {
            if self.updateLink == nil {
                self.updateLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                    guard let self else {
                        return
                    }
                    self.updateItems(deltaTime: deltaTime)
                    self.setNeedsUpdate()
                })
                self.setNeedsUpdate()
            }
        } else {
            if self.updateLink != nil {
                self.updateLink = nil
            }
        }
    }
    
    public func addItem(frame: CGRect, image: NSImage) {
        if let item = Item(frame: frame, image: image) {
            self.items.append(item)
            self.updateNeedsAnimation()
            self.setNeedsUpdate()
        }
    }
    
    private var delta = CACurrentMediaTime()
    
    public func update(context: MetalEngineSubjectContext) {
        
        delta = CACurrentMediaTime()
        
        if self.bounds.isEmpty {
            return
        }
        
        let containerSize = self.bounds.size
        
        for item in self.items {
            var itemFrame = item.frame
            itemFrame.origin.y = containerSize.height - itemFrame.maxY
            
            let particleColumnCount = Int(itemFrame.width)
            let particleRowCount = Int(itemFrame.height)
            let particleCount = particleColumnCount * particleRowCount
            
            if item.particleBuffer == nil {
                if let particleBuffer = MetalEngine.shared.sharedBuffer(spec: BufferSpec(length: particleCount * 4 * (4 + 1))) {
                    item.particleBuffer = particleBuffer
                }
            }
        }
        
        let lastTimeStep = self.lastTimeStep
        self.lastTimeStep = 0.0
        
        let _ = context.compute(state: DustComputeState.self, commands: { [weak self] commandBuffer, state in
            guard let self else {
                return
            }
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            
            for item in self.items {
                guard let particleBuffer = item.particleBuffer else {
                    continue
                }
                
                let itemFrame = item.frame
                let particleColumnCount = Int(itemFrame.width)
                let particleRowCount = Int(itemFrame.height)
                
                let threadgroupSize = MTLSize(width: 32, height: 1, depth: 1)
                let threadgroupCount = MTLSize(width: (particleRowCount * particleColumnCount + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
                
                computeEncoder.setBuffer(particleBuffer.buffer, offset: 0, index: 0)
                
                if !item.particleBufferIsInitialized {
                    item.particleBufferIsInitialized = true
                    computeEncoder.setComputePipelineState(state.computePipelineStateInitializeParticle)
                    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                }
                
                if lastTimeStep != 0.0 {
                    computeEncoder.setComputePipelineState(state.computePipelineStateUpdateParticle)
                    var particleCount = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
                    computeEncoder.setBytes(&particleCount, length: 4 * 2, index: 1)
                    var phase = item.phase
                    computeEncoder.setBytes(&phase, length: 4, index: 2)
                    var timeStep: Float = Float(lastTimeStep) / Float(NSView.animationDurationFactor())
                    timeStep *= 2.0
                    computeEncoder.setBytes(&timeStep, length: 4, index: 3)
                    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                }
            }
            
            computeEncoder.endEncoding()
        })
        
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: Int(self.bounds.width * 3.0), height: Int(self.bounds.height * 3.0))), state: RenderState.self, layer: self, commands: { [weak self] encoder, placement in
            guard let self else {
                return
            }
            
            for item in self.items {
                guard let particleBuffer = item.particleBuffer else {
                    continue
                }
                
                var itemFrame = item.frame
                itemFrame.origin.y = containerSize.height - itemFrame.maxY
                
                let particleColumnCount = Int(itemFrame.width)
                let particleRowCount = Int(itemFrame.height)
                let particleCount = particleColumnCount * particleRowCount
                
                var effectiveRect = placement.effectiveRect
                effectiveRect.origin.x += itemFrame.minX / containerSize.width * effectiveRect.width
                effectiveRect.origin.y += itemFrame.minY / containerSize.height * effectiveRect.height
                effectiveRect.size.width = itemFrame.width / containerSize.width * effectiveRect.width
                effectiveRect.size.height = itemFrame.height / containerSize.height * effectiveRect.height
                
                var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
                encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
                
                var size = SIMD2<Float>(Float(itemFrame.width), Float(itemFrame.height))
                encoder.setVertexBytes(&size, length: 4 * 2, index: 1)
                
                var particleResolution = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
                encoder.setVertexBytes(&particleResolution, length: 4 * 2, index: 2)
                
                encoder.setVertexBuffer(particleBuffer.buffer, offset: 0, index: 3)
                
                encoder.setFragmentTexture(item.texture, index: 0)
                
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: particleCount)
            }
        })
    }
}

public class DustLayerView : View {
    fileprivate let metalLayer = DustLayer()

    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        metalLayer.frame = frameRect.size.bounds
        self.layer?.addSublayer(metalLayer)
        metalLayer.isInHierarchy = true
        self.isEventLess = true
    }
    public override func layout() {
        super.layout()
        metalLayer.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public func ApplyDustAnimation(for currentView: NSView) {
    guard let window = currentView.window else {
        return
    }
    #if arch(arm64)
//    if MetalEngine.shared.rootLayer.superlayer == nil {
    window.contentView?.layer?.addSublayer(MetalEngine.shared.rootLayer)
//    }
    let metalLayer = DustLayer()
    metalLayer.isInHierarchy = true
    metalLayer.frame = window.contentView!.bounds
    let view = View(frame: metalLayer.frame.size.bounds)
    view.isEventLess = true
    view.layer?.addSublayer(metalLayer)
    window.contentView?.addSubview(view)

    metalLayer.addItem(frame: CGRect(origin: currentView.convert(.zero, to: view), size: currentView.frame.size), image: currentView.snapshot)
    metalLayer.becameEmpty = { [weak view] in
        view?.removeFromSuperview()
    }
    #endif

}

public func ApplyDustAnimations(for views: [NSView], superview: DustLayerView? = nil) -> DustLayerView? {
    guard let window = views.first?.window else {
        return nil
    }
    #if arch(arm64)
    window.contentView?.layer?.addSublayer(MetalEngine.shared.rootLayer)


    let isNew = superview == nil
    
    let view = DustLayerView(frame: window.contentView!.bounds)
    window.contentView?.addSubview(view)

    for subview in views {
        view.metalLayer.addItem(frame: CGRect(origin: subview.convert(.zero, to: view), size: subview.frame.size), image: subview.snapshot)
    }
    if isNew {
        view.metalLayer.becameEmpty = { [weak view] in
            view?.removeFromSuperview()
        }
    }
   
    return view
    #endif
    return nil
}
