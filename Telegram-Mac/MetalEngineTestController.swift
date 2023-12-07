//
//  MetalEngineTestController.swift
//  Telegram
//
//  Created by Mike Renoir on 07.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import MetalEngine


private var metalLibraryValue: MTLLibrary?
private func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }
    
    guard let library = device.makeDefaultLibrary() else {
        return nil
    }
    
    metalLibraryValue = library
    return library
}


private final class EdgeTestLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "edgeTestVertex"), let fragmentFunction = library.makeFunction(name: "edgeTestFragment") else {
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
    
    var internalData: MetalEngineSubjectInternalData?
    
    func update(context: MetalEngineSubjectContext) {
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: 300, height: 300), edgeInset: 100), state: RenderState.self, layer: self, commands: { encoder, placement in
            let effectiveRect = placement.effectiveRect
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            
            var color = SIMD4<Float>(1.0, 0.0, 0.0, 1.0)
            encoder.setFragmentBytes(&color, length: 4 * 4, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        })
    }
}

final class MetalEngineTestView: View {
    private let metalLayer: EdgeTestLayer = .init()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        background = .gray
        metalLayer.frame = frameRect.size.bounds
        self.layer?.addSublayer(metalLayer)
        metalLayer.setNeedsUpdate()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
final class  MetalEngineTestController : GenericViewController<MetalEngineTestView> {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
}
