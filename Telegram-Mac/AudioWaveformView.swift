//
//  AudioWaveformView.swift
//  TelegramMac
//
//  Created by keepcoder on 04/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

fileprivate class AudioWaveformContainerView : View {
    var color:NSColor = .blueUI {
        didSet {
            self.setNeedsDisplayLayer()
        }
    }
    var waveform:AudioWaveform? {
        didSet {
            self.setNeedsDisplayLayer()
        }
    }
    var peakHeight:CGFloat = 12
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        //super.draw(layer, in: ctx)
        
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
        foregroundClipingView.backgroundColor = .clear
        super.init(frame: frameRect)
        
        addSubview(backgroundView)
        
        //foregroundClipingView.clipsToBounds = true;
        foregroundClipingView.addSubview(foregroundView)
        addSubview(foregroundClipingView)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        foregroundView.setFrameSize(newSize)
        backgroundView.setFrameSize(newSize)
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

