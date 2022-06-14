//
//  MatrixView.swift
//  Telegram
//
//  Created by Mike Renoir on 14.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import TGUIKit

public final class DataRainView: MTKView, MTKViewDelegate, PremiumDecorationProtocol {
    public func draw(in view: MTKView) {
        
    }
    
    private let commandQueue: MTLCommandQueue
    private let drawPassthroughPipelineState: MTLRenderPipelineState
    
    private var displayLink: ConstantDisplayLinkAnimator?

//    private var metalLayer: CAMetalLayer {
//        return self.layer as! CAMetalLayer
//    }

    private let symbolTexture: MTLTexture
    private let randomTexture: MTLTexture
    
    private var viewportDimensions = CGSize(width: 1, height: 1)
    
    private var startTimestamp = CACurrentMediaTime()
    
    public init?(test: Bool = false) {
        let bundle = Bundle.main
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let defaultLibrary = device.makeDefaultLibrary() else {
            return nil
        }

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        guard let loadedVertexProgram = defaultLibrary.makeFunction(name: "matrixVertex") else {
            return nil
        }

        guard let loadedFragmentProgram = defaultLibrary.makeFunction(name: "matrixFragment") else {
            return nil
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = loadedVertexProgram
        pipelineStateDescriptor.fragmentFunction = loadedFragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        self.drawPassthroughPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
  
        guard let url = bundle.url(forResource: "chars", withExtension: "png"), let texture = try? textureLoader.newTexture(URL: url, options: nil) else {
            return nil
        }
        self.symbolTexture = texture
        
        guard let url = bundle.url(forResource: "random", withExtension: "jpg"), let texture = try? textureLoader.newTexture(URL: url, options: nil) else {
            return nil
        }
        self.randomTexture = texture
        
        super.init(frame: CGRect(), device: device)
        
        self.delegate = self


        self.framebufferOnly = true

        self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.displayLinkEvent()
        }, fps: 60)
        
        self.wantsLayer = true

        self.layer?.isOpaque = false
        
        self.displayLink?.isPaused = true
        self.isPaused = true
    }
    
    public override var isOpaque: Bool {
        return false
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportDimensions = size
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        var bp = 0
        bp += 1
    }
    
    func setVisible(_ visible: Bool) {
        if visible {
            self.displayLink?.isPaused = false
        }
        
        self._change(opacity: visible ? 0.6 : 0.0, animated: true, completion: { [weak self] finished in
            if let strongSelf = self, !visible {
                strongSelf.displayLink?.isPaused = true
            }
        })

    }
    
    func resetAnimation() {
    }
    func startAnimation() {
    }

    @objc private func displayLinkEvent() {
        self.draw()
    }

    override public func draw(_ rect: CGRect) {
        if let drawable = self.currentDrawable {
            self.redraw(drawable: drawable)
        }
    }

    
    private func redraw(drawable: MTLDrawable) {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }

        let renderPassDescriptor = self.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let viewportDimensions = self.viewportDimensions
        renderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: viewportDimensions.width, height: viewportDimensions.height, znear: -1.0, zfar: 1.0))
        
        renderEncoder.setRenderPipelineState(self.drawPassthroughPipelineState)

        var vertices: [Float] = [
             1,  -1,
            -1,  -1,
            -1,   1,
             1,  -1,
            -1,   1,
             1,   1
        ]
        renderEncoder.setVertexBytes(&vertices, length: 4 * vertices.count, index: 0)
        
        renderEncoder.setFragmentTexture(self.symbolTexture, index: 0)
        renderEncoder.setFragmentTexture(self.randomTexture, index: 1)
        
        var resolution = simd_uint2(UInt32(viewportDimensions.width), UInt32(viewportDimensions.height))
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 0)
        
        var time = Float(CACurrentMediaTime() - self.startTimestamp) * 0.75
        renderEncoder.setFragmentBytes(&time, length: 4, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

    }
}

