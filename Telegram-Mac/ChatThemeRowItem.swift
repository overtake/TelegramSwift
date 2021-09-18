//
//  ChatThemeRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class ChatThemeRowItem : GeneralRowItem {
    fileprivate let theme: (String, CGImage, TelegramPresentationTheme)?
    fileprivate let selected: Bool
    fileprivate let select:((String, TelegramPresentationTheme)?)->Void
    init(_ initialSize: NSSize, width: CGFloat, stableId: AnyHashable, theme: (String, CGImage, TelegramPresentationTheme)?, selected: Bool, select:@escaping((String, TelegramPresentationTheme)?)->Void) {
        self.theme = theme
        self.select = select
        self.selected = selected
        super.init(initialSize, height: width, stableId: stableId)
    }
    
    override var width: CGFloat {
        return 90
    }
    override var height: CGFloat {
        return 90
    }
    
    override func viewClass() -> AnyClass {
        return ChatThemeRowView.self
    }
}

private final class ChatThemeRowView: HorizontalRowView {
    private let imageView: ImageView = ImageView()
    private let textView = TextView()
    private let selectionView: View = View()
    
    private var noThemeTextView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        addSubview(selectionView)
        
        imageView.isEventLess = true
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        selectionView.isEventLess = true
        
        selectionView.layer?.cornerRadius = 12
        selectionView.layer?.borderWidth = 2.5

    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        guard let item = item as? ChatThemeRowItem else {
            return
        }
        if let theme = item.theme {
            item.select((theme.0, theme.2))
        } else {
            item.select(nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            let layout = TextViewLayout(.initialize(string: current.0, color: theme.colors.text, font: .normal(15)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            self.imageView.image = current.1
            self.imageView.sizeToFit()
            self.imageView.isHidden = false
            self.noThemeTextView?.removeFromSuperview()
            self.noThemeTextView = nil
        } else {
            let layout = TextViewLayout(.initialize(string: "❌", color: theme.colors.text, font: .normal(15)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            self.imageView.isHidden = true
         
            
            self.noThemeTextView?.removeFromSuperview()
            
            self.noThemeTextView = TextView()
            self.noThemeTextView?.userInteractionEnabled = false
            self.noThemeTextView?.isSelectable = false
            addSubview(self.noThemeTextView!)
            let noTheme = TextViewLayout(.initialize(string: L10n.chatChatThemeNoTheme, color: theme.colors.text, font: .medium(.text)), alignment: .center)
            noTheme.measure(width: 80)
            
            self.noThemeTextView?.update(noTheme)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.imageView.setFrameSize(NSMakeSize(80, 80))
        self.imageView.centerX(y: 5)
        self.selectionView.frame = self.imageView.frame.insetBy(dx: -3, dy: -3)
        self.textView.centerX(y: 60)
        
        noThemeTextView?.centerX(y: 15)
    }
}
