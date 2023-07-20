//
//  GifKeyboardTabRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 29.07.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore


class GifKeyboardTabRowItem: TableRowItem {
    
    let selected: Bool
    
    let select:()->Void
        
    enum Source {
        case icon(CGImage)
        case file(TelegramMediaFile)
    }
    let source: Source
    
    private let _stableId: AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    let context: AccountContext
    let theme: PresentationTheme
    init(_ initialSize: NSSize, stableId: AnyHashable, selected: Bool, context: AccountContext, source: Source, select: @escaping()->Void, theme: PresentationTheme) {
        self.theme = theme
        self.selected = selected
        self.source = source
        self.select = select
        self._stableId = stableId
        self.context = context
        super.init(initialSize)
    }
    
    override var height:CGFloat {
        return 36.0
    }
    override var width: CGFloat {
        return 36.0
    }
    
    override func viewClass() -> AnyClass {
        return GifKeyboardTabRowView.self
    }
}


private final class GifKeyboardTabRowView: HorizontalRowView {
    
    private let selectView: View = View()
    private let control = Control()
    
    private var imageLayer: SimpleLayer?
    private var animationLayer: InlineStickerItemLayer?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        control.set(handler: { [weak self] control in
            if let item = self?.item as? GifKeyboardTabRowItem {
                item.select()
            }
        }, for: .Click)
        
        control.frame = NSMakeRect(0, 0, 36, 36)
        
        selectView.frame = NSMakeRect(0, 0, 36, 36)
        
        addSubview(selectView)
        addSubview(control)
        
    }

    override func updateAnimatableContent() -> Void {
        if let value = self.animationLayer, let superview = value.superview {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && isKeyWindow && !isEmojiLite
        }
    }
    

    override var isEmojiLite: Bool {
        if let item = item as? GifKeyboardTabRowItem {
            return item.context.isLite(.emoji)
        }
        return super.isEmojiLite
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GifKeyboardTabRowItem else {
            return
        }
        
        switch item.source {
        case let .file(file):
            selectView.layer?.cornerRadius = .cornerRadius
            
            if let layer = self.imageLayer {
                self.imageLayer = nil
                performSublayerRemoval(layer, animated: animated)
            }
            let current: InlineStickerItemLayer
            if let layer = animationLayer, layer.file == file {
                current = layer
            } else {
                self.animationLayer?.removeFromSuperlayer()
                current = InlineStickerItemLayer(account: item.context.account, file: file, size: NSMakeSize(28, 28))
                current.contentsGravity = .center
                self.animationLayer = current
                control.layer?.addSublayer(current)
            }
            current.superview = self.control
            current.frame = CGRect(origin: NSMakePoint(4, 4), size: NSMakeSize(28, 28))

        case let .icon(image):
            selectView.layer?.cornerRadius = selectView.frame.height / 2
            
            if let layer = self.animationLayer {
                self.animationLayer = nil
                performSublayerRemoval(layer, animated: animated)
            }
            let current: SimpleLayer
            if let layer = imageLayer {
                current = layer
            } else {
                current = SimpleLayer()
                current.contentsGravity = .resizeAspectFill
                self.imageLayer = current
                control.layer?.addSublayer(current)
            }
            current.contents = image
            current.frame = CGRect(origin: NSMakePoint(4, 4), size: NSMakeSize(28, 28))
        }
        
        selectView.backgroundColor = item.theme.colors.grayBackground
        selectView.change(opacity: item.selected ? 1 : 0, animated: animated)
        
        control.frame = bounds
        control.center()
        
        selectView.frame = bounds
        selectView.center()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
