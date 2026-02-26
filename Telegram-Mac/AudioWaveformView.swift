//
//  AudioWaveformView.swift
//  TelegramMac
//
//  Created by keepcoder on 04/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramMedia

fileprivate class AudioWaveformContainerView : SimpleLayer {
    var color:NSColor = .accent {
        didSet {
            self.setNeedsDisplay()
        }
    }
    var waveform:AudioWaveform? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    var peakHeight:CGFloat = 12
    override init(frame frameRect: NSRect) {
        super.init()
        self.frame = frameRect
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(layer: Any) {
        super.init()
    }
    
    override func draw(in ctx: CGContext) {
        
        let sampleWidth:CGFloat = 2
        let halfSampleWidth:CGFloat = 1
        let distance:CGFloat = 1
        let size = frame.size
        
        ctx.setFillColor(color.cgColor)
        
        if let waveform = waveform {

            
            waveform.samples.withUnsafeBytes { (samples: UnsafePointer<UInt16>) -> Void in
                let peakHeight: CGFloat = 12.0
                let maxReadSamples = waveform.samples.count / 2
                
                var maxSample: UInt16 = 0
                for i in 0 ..< maxReadSamples {
                    let sample = samples[i]
                    if maxSample < sample {
                        maxSample = sample
                    }
                }
                
                let invScale = 1.0 / max(1.0, CGFloat(maxSample))
                let numSamples = Int(floor(size.width / (sampleWidth + distance)))
                
                let adjustedSamplesMemory = malloc(numSamples * 2)!
                let adjustedSamples = adjustedSamplesMemory.assumingMemoryBound(to: UInt16.self)
                defer {
                    free(adjustedSamplesMemory)
                }
                memset(adjustedSamplesMemory, 0, numSamples * 2)
                
                for i in 0 ..< maxReadSamples {
                    let index = i * numSamples / maxReadSamples
                    let sample = samples[i]
                    if adjustedSamples[index] < sample {
                        adjustedSamples[index] = sample
                    }
                }
                
                for i in 0 ..< numSamples {
                    let offset = CGFloat(i) * (sampleWidth + distance)
                    let peakSample = adjustedSamples[i]
                    
                    var sampleHeight = CGFloat(peakSample) * peakHeight * invScale
                    if abs(sampleHeight) > peakHeight {
                        sampleHeight = peakHeight
                    }
                    
                    let adjustedSampleHeight = sampleHeight - sampleWidth
                    if adjustedSampleHeight.isLessThanOrEqualTo(sampleWidth) {
                       // ctx.fillEllipse(in: CGRect(x: offset, y: size.height - sampleWidth, width: sampleWidth, height: sampleHeight))
                        ctx.fill(CGRect(x: offset, y: size.height - halfSampleWidth, width: sampleWidth, height: halfSampleWidth))
                    } else {
                        let adjustedRect = CGRect(x: offset, y: size.height - adjustedSampleHeight, width: sampleWidth, height: adjustedSampleHeight)
                        ctx.fill(adjustedRect)
                        ctx.fillEllipse(in: CGRect(x: adjustedRect.minX, y: adjustedRect.minY - halfSampleWidth, width: sampleWidth, height: sampleWidth))
                        ctx.fillEllipse(in: CGRect(x: adjustedRect.minX, y: adjustedRect.maxY - halfSampleWidth, width: sampleWidth, height: sampleHeight))
                    }
                }
            }
        } else {
            
            ctx.fill(NSMakeRect(halfSampleWidth, size.height - sampleWidth, size.width - sampleWidth, sampleWidth))
            ctx.fillEllipse(in: NSMakeRect(0.0, size.height - sampleWidth, sampleWidth, sampleWidth))
            ctx.fillEllipse(in: NSMakeRect(size.width - sampleWidth, size.height - sampleWidth, sampleWidth, sampleWidth))
            
  
        }
    }
    
}

class AudioWaveformView: View {
    private let foregroundView:AudioWaveformContainerView
    private let backgroundView:AudioWaveformContainerView
    let foregroundClipingView:View
    
    var peakHeight:CGFloat = 12 {
        didSet {
            foregroundView.peakHeight = peakHeight
            backgroundView.peakHeight = peakHeight
        }
    }
    
    var waveform:AudioWaveform? {
        didSet {
            foregroundView.waveform = waveform
            backgroundView.waveform = waveform
        }
    }
    
    required init(frame frameRect: NSRect) {
        foregroundView = AudioWaveformContainerView(frame: NSMakeRect(0,0,frameRect.width,frameRect.height))
        backgroundView = AudioWaveformContainerView(frame: NSMakeRect(0,0,frameRect.width,frameRect.height))
        foregroundClipingView = View(frame: NSMakeRect(0,0,frameRect.width,frameRect.height))
        super.init(frame: frameRect)
        
        self.layer?.addSublayer(backgroundView)
        
        foregroundClipingView.layer?.addSublayer(foregroundView)
        addSubview(foregroundClipingView)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        foregroundView.frame = self.bounds
        backgroundView.frame = self.bounds

    }
    
    func set(foregroundColor:NSColor, backgroundColor:NSColor) {
        self.foregroundView.color = foregroundColor
        self.backgroundView.color = backgroundColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}


private struct ContentParticle {
    var position: CGPoint
    var direction: CGPoint
    var velocity: CGFloat
    var alpha: CGFloat
    var lifetime: Double
    var beginTime: Double
    
    init(position: CGPoint, direction: CGPoint, velocity: CGFloat, alpha: CGFloat, lifetime: Double, beginTime: Double) {
        self.position = position
        self.direction = direction
        self.velocity = velocity
        self.alpha = alpha
        self.lifetime = lifetime
        self.beginTime = beginTime
    }
}


private class DrawingLayer : SimpleLayer {
    var color: NSColor = .black
    var particles: [ContentParticle] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(in context: CGContext) {
        super.draw(in: context)
        
        context.setFillColor(self.color.cgColor)
        
        for particle in self.particles {
            let size: CGFloat = 1.4
            context.setAlpha(particle.alpha * 1.0)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
        }
    }
}

class SparksView: View {
    private var particles: [ContentParticle] = []
    private var color: NSColor = .black
    private let drawingLayer = DrawingLayer()
    required init(frame: CGRect) {
        super.init(frame: frame)
        drawingLayer.frame = bounds
        self.layer?.addSublayer(drawingLayer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var presentationSampleHeight: CGFloat = 0.0
    private var sampleHeight: CGFloat = 0.0
    
    func update(position: CGPoint, sampleHeight: CGFloat, color: NSColor) {
        self.color = color
        self.drawingLayer.color = color
        
    
        self.sampleHeight = sampleHeight
        self.presentationSampleHeight = self.presentationSampleHeight * 0.9 + self.sampleHeight * 0.1
        
        let v = CGPoint(x: 1.0, y: 0.0)
        let c = CGPoint(x: position.x - 4.0, y: position.y + 1.0 - self.presentationSampleHeight * CGFloat(arc4random_uniform(100)) / 100.0)

        let timestamp = CACurrentMediaTime()
        
        let dt: CGFloat = 1.0 / 60.0
        var removeIndices: [Int] = []
        for i in 0 ..< self.particles.count {
            let currentTime = timestamp - self.particles[i].beginTime
            if currentTime > self.particles[i].lifetime {
                removeIndices.append(i)
            } else {
                let input: CGFloat = CGFloat(currentTime / self.particles[i].lifetime)
                let decelerated: CGFloat = (1.0 - (1.0 - input) * (1.0 - input))
                self.particles[i].alpha = 1.0 - decelerated
                
                var p = self.particles[i].position
                let d = self.particles[i].direction
                let v = self.particles[i].velocity
                p = CGPoint(x: p.x + d.x * v * dt, y: p.y + d.y * v * dt)
                self.particles[i].position = p
            }
        }
        
        for i in removeIndices.reversed() {
            self.particles.remove(at: i)
        }
        
        let newParticleCount = 3
        for _ in 0 ..< newParticleCount {
            let degrees: CGFloat = CGFloat(arc4random_uniform(100)) - 65.0
            let angle: CGFloat = degrees * CGFloat.pi / 180.0
            
            let direction = CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
            let velocity = (80.0 + (CGFloat(arc4random()) / CGFloat(UINT32_MAX)) * 4.0) * 0.5
            
            let lifetime = Double(0.65 + CGFloat(arc4random_uniform(100)) * 0.01)
            
            let particle = ContentParticle(position: c, direction: direction, velocity: velocity, alpha: 1.0, lifetime: lifetime, beginTime: timestamp)
            self.particles.append(particle)
        }
        
        drawingLayer.particles = particles
    }
    

    override func layout() {
        super.layout()
        drawingLayer.frame = bounds
    }
    
}
