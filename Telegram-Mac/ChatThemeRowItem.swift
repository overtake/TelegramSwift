//
//  ChatThemeRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


final class ChatThemeRowItem : GeneralRowItem {
    fileprivate let theme: (String, CGImage, TelegramPresentationTheme)?
    fileprivate let context: AccountContext
    fileprivate let selected: Bool
    fileprivate let select:((String, TelegramPresentationTheme)?)->Void
    fileprivate let emojies: [String: StickerPackItem]
    init(_ initialSize: NSSize, context: AccountContext, stableId: AnyHashable, emojies: [String: StickerPackItem], theme: (String, CGImage, TelegramPresentationTheme)?, selected: Bool, select:@escaping((String, TelegramPresentationTheme)?)->Void) {
        self.theme = theme
        self.select = select
        self.selected = selected
        self.context = context
        self.emojies = emojies
        super.init(initialSize, stableId: stableId)
    }
    
    override var width: CGFloat {
        return 90
    }
    override var height: CGFloat {
        return 80
    }
    
    override func viewClass() -> AnyClass {
        return ChatThemeRowView.self
    }
}

private final class ChatThemeRowView: HorizontalRowView {
    private let imageView: ImageView = ImageView()
    private let emojiView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 25, 25))
    private let textView = TextView()
    private let selectionView: View = View()
    
    private let overlay = OverlayControl()
    
    private var noThemeTextView: TextView?
    
    private var currentEmoji: String? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(emojiView)
        addSubview(textView)
        addSubview(selectionView)
        addSubview(overlay)
        imageView.isEventLess = true
        emojiView.userInteractionEnabled = false
        selectionView.isEventLess = true
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false

        
        selectionView.layer?.cornerRadius = 12
        selectionView.layer?.borderWidth = 2.5
        
        
        overlay.set(handler: { [weak self] _ in
            guard let item = self?.item as? ChatThemeRowItem else {
                return
            }
            if let theme = item.theme {
                item.select((theme.0, theme.2))
            } else {
                item.select(nil)
            }
        }, for: .Click)

        overlay.set(handler: { [weak self] _ in
            self?.emojiView.overridePlayValue = true
        }, for: .Hover)
        
        overlay.set(handler: { [weak self] _ in
            self?.emojiView.overridePlayValue = false
        }, for: .Normal)
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatThemeRowItem else {
            return
        }
        selectionView.layer?.borderColor = item.selected ? theme.colors.accentSelect.cgColor : theme.colors.border.cgColor

        let dBorder: CGFloat = item.theme?.2.bubbled == true ? 0 : 1
        
        selectionView.layer?.borderWidth = item.selected ? 2 : (item.theme == nil ? 1 : dBorder)
        
        if let current = item.theme {
            if self.currentEmoji != current.0 {
                self.currentEmoji = current.0
                
                let context = item.context
                
                if let first = item.emojies[current.0.fixed]  {
                    let params = ChatAnimatedStickerMediaLayoutParameters(playPolicy: nil, media: first.file)
                    self.emojiView.update(with: first.file, size: NSMakeSize(25, 25), context: context, table: nil, parameters: params, animated: animated)
                }
                
                self.emojiView.overridePlayValue = false
                self.imageView.image = current.1
                self.imageView.sizeToFit()
                self.imageView.isHidden = false
                self.noThemeTextView?.removeFromSuperview()
                self.noThemeTextView = nil
                self.textView.update(nil)
            }
        } else {
            let layout = TextViewLayout(.initialize(string: "❌", color: theme.colors.text, font: .normal(15)))
            layout.measure(width: .greatestFiniteMagnitude)
            self.textView.update(layout)
            self.imageView.isHidden = true
            self.noThemeTextView?.removeFromSuperview()
            self.noThemeTextView = TextView()
            self.noThemeTextView?.userInteractionEnabled = false
            self.noThemeTextView?.isSelectable = false
            self.addSubview(self.noThemeTextView!)
            let noTheme = TextViewLayout(.initialize(string: L10n.chatChatThemeNoTheme, color: theme.colors.text, font: .medium(.text)), alignment: .center)
            noTheme.measure(width: 80)
            self.noThemeTextView?.update(noTheme)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.imageView.setFrameSize(NSMakeSize(70, 80))
        self.imageView.centerX(y: 5)
        self.selectionView.frame = self.imageView.frame.insetBy(dx: -3, dy: -3)
        self.textView.centerX(y: 60)
        self.emojiView.centerX(y: 55)
        self.noThemeTextView?.centerX(y: 15)
        self.overlay.frame = bounds
    }
}
