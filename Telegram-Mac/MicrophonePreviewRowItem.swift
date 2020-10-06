//
//  MicrophonePreviewRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

private func generateValueImage(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(4, 32), rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        ctx.round(size, 2)
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
    })!
}

class MicrophonePreviewRowItem: GeneralRowItem {
    fileprivate let device: AVCaptureDevice
    fileprivate let session: AVCaptureSession
    private let peakDisposable = MetaDisposable()
    fileprivate var powerLevel: Int {
        didSet {
            if powerLevel != oldValue {
                self.redraw(animated: true, presentAsNew: false)
            }
        }
    }
    init(_ initialSize: NSSize, stableId: AnyHashable, device: AVCaptureDevice, viewType: GeneralViewType) {
        self.device = device
        self.session = AVCaptureSession()
        let input = try? AVCaptureDeviceInput(device: device)
        if let input = input {
            self.session.addInput(input)
        }
        let output = AVCaptureAudioDataOutput()
        self.session.addOutput(output)
        
        let connection = output.connection(with: .audio)
        
        let channel = connection?.audioChannels.first
        
        if let channel = channel {
            let value = Int(floor(max(0, 36 - abs(channel.averagePowerLevel))))
            self.powerLevel = value
        } else {
            self.powerLevel = 0
        }
        
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType)
        
        if let channel = channel {
            let signal: Signal<Void, NoError> = .single(Void()) |> delay(0.1, queue: .mainQueue()) |> restart
            peakDisposable.set(signal.start(next: { [weak channel, weak self] in
                if let channel = channel {
                    let value = Int(floor(max(0, 36 - abs(channel.averagePowerLevel))))
                    self?.powerLevel = value
                }
            }))
        }
        
        self.session.startRunning()
        
    }
    deinit {
        peakDisposable.dispose()
    }
    
    override func viewClass() -> AnyClass {
        return MicrophonePreviewRowView.self
    }
}

private final class PreviewView : View {
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let onsize = NSMakeSize(4, frame.height - 8)
        
        let count = Int(ceil(frame.width / (onsize.width * 2)))
        var pos: NSPoint = NSMakePoint(0, 4)
        
        let active = generateValueImage(theme.colors.accentIcon)
        let passive = generateValueImage(theme.colors.grayIcon)

        let percent = Float(powerLevel) / Float(36)
        let value = Int(floor(percent * Float(count)))
        for i in 0 ..< count {
            if value > i {
                ctx.draw(active, in: CGRect(origin: pos, size: onsize))
            } else {
                ctx.draw(passive, in: CGRect(origin: pos, size: onsize))
            }
            pos.x += onsize.width * 2
        }
    }
    
    
    var powerLevel: Int = 0 {
        didSet {
            needsDisplay = true
        }
    }
}

private final class MicrophonePreviewRowView : GeneralContainableRowView {
    private let view = PreviewView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? MicrophonePreviewRowItem else {
            return
        }
        view.powerLevel = item.powerLevel
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? MicrophonePreviewRowItem else {
            return
        }
        view.setFrameSize(NSMakeSize(item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right, 40))
        view.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

