//
//  ChatListEmptyRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit
import Cocoa
import SwiftSignalKit
import Postbox

class ChatListEmptyRowItem: TableRowItem {
    private let _stableId: UInt32 = arc4random()
    
    override var stableId: AnyHashable {
        return _stableId
    }
    let context: AccountContext
    init(_ initialSize: NSSize, context: AccountContext) {
        self.context = context
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        }
        return initialSize.height
    }
    
    override func viewClass() -> AnyClass {
        return ChatListEmptyRowView.self
    }
}


private class ChatListEmptyRowView : TableRowView {
    private let disposable = MetaDisposable()
    private let textView = TextView()
    private let separator = View()
    private var preset: ChatListFilterPreset? = nil {
        didSet {
            if preset != oldValue {
                needsLayout = true
            }
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        
        addSubview(separator)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatListEmptyRowItem {
            let signal = chatListFilterPreferences(postbox: item.context.account.postbox) |> deliverOnMainQueue
            disposable.set(signal.start(next: { [weak self] settings in
                self?.preset = settings.current
            }))
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func layout() {
        super.layout()
        
        separator.background = theme.colors.border
        
        let text: String
        if let _ = self.preset {
            text = L10n.chatListFilterEmpty
        } else {
            text = L10n.chatListEmptyText
        }

        
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { [weak self] contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { [weak self] _ in
                guard let item = self?.item as? ChatListEmptyRowItem else {
                   return
                }
                _ = updateChatListFilterPreferencesInteractively(postbox: item.context.account.postbox, {
                    $0.withUpdatedCurrentPreset(nil)
                }).start()
            }))
        })).mutableCopy() as! NSMutableAttributedString
        
        
        attr.detectBoldColorInString(with: .bold(.text))
        
        let layout = TextViewLayout(attr, alignment: .center)

        layout.measure(width: frame.width - 40)
        layout.interactions = globalLinkExecutor
        textView.update(layout)
        textView.center()
        
        textView.isHidden = frame.width <= 70
        
        separator.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
