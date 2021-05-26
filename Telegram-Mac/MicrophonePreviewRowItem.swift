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
    fileprivate let controller: MicroListenerContext
    fileprivate var powerLevel: Int = 0 {
        didSet {
            if powerLevel != oldValue {
                self.redraw(animated: true, presentAsNew: false)
            }
        }
    }
    init(_ initialSize: NSSize, stableId: AnyHashable, context: SharedAccountContext, viewType: GeneralViewType, customTheme: GeneralRowItem.Theme? = nil) {
        controller = MicroListenerContext(devices: context.devicesContext, accountManager: context.accountManager)
        
        super.init(initialSize, height: 40, stableId: stableId, viewType: viewType, customTheme: customTheme)
       
        controller.resume (onSpeaking: { [weak self] value in
            self?.powerLevel = max(min(Int(36 * value), 36), 0)
        }, always: true)
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

