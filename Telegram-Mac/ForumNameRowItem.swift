//
//  ForumNameRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 27.09.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import TelegramMedia

final class ForumNameRowItem : InputDataRowItem {
    
    struct Icon : Equatable {
        let file: TelegramMediaFile?
        let fileId: Int64
        let fromRect: CGRect?
    }
    
    fileprivate let context: AccountContext
    fileprivate let icon: Icon?
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, icon: Icon?, name: String, updatedText:@escaping(String)->Void, viewType: GeneralViewType) {
        self.context = context
        self.icon = icon
        super.init(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: viewType, currentText: name, placeholder: nil, inputPlaceholder: strings().forumTopicNamePlaceholder, filter: { $0 }, updated: updatedText, limit: 70)
    }
    
    override var textFieldLeftInset: CGFloat {
        return 30
    }
    
    override func viewClass() -> AnyClass {
        return ForumNameRowItemView.self
    }
}


private final class ForumNameRowItemView: InputDataRowView {
    private let control = View()
    private var inlineLayer: InlineStickerItemLayer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(control)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataRowItem else {
            return
        }
        control.frame = NSMakeRect(item.viewType.innerInset.left - 2, 4, 30, 30)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        let previous = self.item as? ForumNameRowItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? ForumNameRowItem else {
            return
        }
        
        let getColors:(TelegramMediaFile)->[LottieColor] = { file in
            var colors: [LottieColor] = []
            if isDefaultStatusesPackId(file.emojiReference) {
                colors.append(.init(keyPath: "", color: theme.colors.accent))
            }
            return colors
        }
        
        let play:(NSView, Int64)->Void = { control, fileId in
            guard let superview = control.superview, let window = superview.window else {
                return
            }
            
            let panel = Window(contentRect: NSMakeRect(0, 0, 160, 120), styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
            panel._canBecomeMain = false
            panel._canBecomeKey = false
            panel.ignoresMouseEvents = true
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false

            let player = CustomReactionEffectView(frame: NSMakeSize(160, 120).bounds, context: item.context, fileId: fileId)
            
            player.isEventLess = true
            
            player.triggerOnFinish = { [weak panel] in
                if let panel = panel  {
                    panel.parent?.removeChildWindow(panel)
                    panel.orderOut(nil)
                }
            }
                    
            let controlRect = superview.convert(control.frame, to: nil)
            
            var rect = CGRect(origin: CGPoint(x: controlRect.midX - player.frame.width / 2, y: controlRect.midY - player.frame.height / 2), size: player.frame.size)
            
            
            rect = window.convertToScreen(rect)
            
            panel.setFrame(rect, display: true)
            
            panel.contentView?.addSubview(player)
            
            window.addChildWindow(panel, ordered: .above)
        }

        
        if let icon = item.icon {
            let current: InlineStickerItemLayer
            if let layer = self.inlineLayer, previous?.icon?.fileId == icon.fileId {
                current = layer
            } else {
                if let layer = inlineLayer {
                    performSublayerRemoval(layer, animated: animated)
                    self.inlineLayer = nil
                }
                current = InlineStickerItemLayer(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: icon.fileId, file: icon.file, emoji: ""), size: NSMakeSize(30, 30), getColors: getColors)
                
                self.inlineLayer = current
                control.layer?.addSublayer(current)
                
                if animated {
                    current.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, center: false)
                }
                if let fromRect = icon.fromRect {
                    
                    current.isHidden = true
                    
                    let layer = InlineStickerItemLayer(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: icon.fileId, file: icon.file, emoji: ""), size: NSMakeSize(26, 26), getColors: getColors)

                    let toRect = control.convert(control.frame.size.bounds, to: nil)
                    
                    let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
                    let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
                    
                    let completed: (Bool)->Void = { [weak self, weak current] _ in
                        current?.isHidden = false
                        DispatchQueue.main.async {
                            if let container = self?.control {
                                play(container, icon.fileId)
                                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                            }
                        }
                    }
                    parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: item.context.window, completion: completed)
                }
            }
            current.isPlayable = true
        } else if let layer = inlineLayer {
            performSublayerRemoval(layer, animated: animated)
            self.inlineLayer = nil
        }
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
