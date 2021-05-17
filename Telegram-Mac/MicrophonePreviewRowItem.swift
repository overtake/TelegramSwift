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

private func generateValueImage(_ color: NSColor, height: CGFloat) -> CGImage {
    return generateImage(NSMakeSize(4, height), rotatedContext: { size, ctx in
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
    init(_ initialSize: NSSize, stableId: AnyHashable, device: AVCaptureDevice, viewType: GeneralViewType, customTheme: GeneralRowItem.Theme? = nil) {
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
        
        super.init(initialSize, height: 40, stableId: stableId, viewType: viewType, customTheme: customTheme)
        
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
        self.session.stopRunning()
    }
    
    override func viewClass() -> AnyClass {
        return MicrophonePreviewRowView.self
    }
}

private final class PreviewView : View {
    
    fileprivate var customTheme: GeneralRowItem.Theme?
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let onsize = NSMakeSize(4, frame.height - 8)
        
        let count = Int(ceil(frame.width / (onsize.width * 2)))
        var pos: NSPoint = NSMakePoint(0, 4)
        
        
        
        let active: CGImage
        let passive: CGImage
        if let theme = self.customTheme {
            active = generateValueImage(theme.accentColor, height: onsize.height)
            passive = generateValueImage(theme.secondaryColor, height: onsize.height)
        } else {
            active = generateValueImage(theme.colors.accentIcon, height: onsize.height)
            passive = generateValueImage(theme.colors.grayIcon, height: onsize.height)
        }
        
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
    private let title: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
        addSubview(title)
        title.userInteractionEnabled = false
        title.isSelectable = false
    }
    override var backdorColor: NSColor {
        guard let item = item as? MicrophonePreviewRowItem else {
            return super.backdorColor
        }
        if let theme = item.customTheme {
            return theme.backgroundColor
        }
        return super.backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MicrophonePreviewRowItem else {
            return
        }
        view.customTheme = item.customTheme
        view.powerLevel = item.powerLevel
        needsLayout = true
        
        let layout = TextViewLayout(.initialize(string: L10n.callSettingsInputLevel, color: item.customTheme?.textColor ?? theme.colors.text, font: .normal(.title)))
        layout.measure(width: 200)
        title.update(layout)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? MicrophonePreviewRowItem else {
            return
        }
        view.setFrameSize(NSMakeSize(160, 20))
        view.centerY(x: containerView.frame.width - view.frame.width - item.viewType.innerInset.right)
        
        title.centerY(x: item.viewType.innerInset.left)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

