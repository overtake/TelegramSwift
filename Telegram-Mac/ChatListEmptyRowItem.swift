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
import TelegramCore
import SyncCore

class ChatListEmptyRowItem: TableRowItem {
    private let _stableId: AnyHashable
    
    override var stableId: AnyHashable {
        return _stableId
    }
    let context: AccountContext
    let filter: ChatListFilter?
    let openFilterSettings: (ChatListFilter?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, filter: ChatListFilter?, context: AccountContext, openFilterSettings: @escaping(ChatListFilter?)->Void) {
        self.context = context
        self.filter = filter
        self._stableId = stableId
        self.openFilterSettings = openFilterSettings
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        if let table = table {
            var tableHeight: CGFloat = 0
            table.enumerateItems { item -> Bool in
                if item.index < self.index {
                    tableHeight += item.height
                }
                return true
            }
            let height = table.frame.height == 0 ? initialSize.height : table.frame.height
            return height - tableHeight
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
    private let sticker: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        
        addSubview(separator)
        addSubview(sticker)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? ChatListEmptyRowItem else {
            return
        }
        
        let animatedSticker: LocalAnimatedSticker
        
        if let _ = item.filter {
            animatedSticker = .folder_empty
        } else {
            animatedSticker = .chiken_born
        }
        sticker.update(with: animatedSticker.file, size: NSMakeSize(112, 112), context: item.context, parent: nil, table: item.table, parameters: animatedSticker.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
        
        needsLayout = true
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func layout() {
        super.layout()
        
        separator.background = theme.colors.border
        
        guard let item = item as? ChatListEmptyRowItem else {
            return
        }
        
        
        let text: String
        if let _ = item.filter {
            text = L10n.chatListFilterEmpty
        } else {
            text = L10n.chatListEmptyText
        }

        
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.title), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .medium(.title), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.title), textColor: theme.colors.link), linkAttribute: { [weak item] contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { [weak item] value in
                if value == "filter" {
                    item?.openFilterSettings(item?.filter)
                }
               
            }))
        })).mutableCopy() as! NSMutableAttributedString
        
        
        attr.detectBoldColorInString(with: .medium(.title))
        
        let layout = TextViewLayout(attr, alignment: .center)

        layout.measure(width: frame.width - 40)
        layout.interactions = globalLinkExecutor
        textView.update(layout)
        textView.center()
        
        textView.isHidden = frame.width <= 70
        sticker.isHidden = frame.width <= 70
        
        separator.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
        
        sticker.centerX(y: textView.frame.minY - sticker.frame.height - 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}










class ChatListLoadingRowItem: TableRowItem {
    private let _stableId: AnyHashable
    
    override var stableId: AnyHashable {
        return _stableId
    }
    let context: AccountContext
    let filter: ChatListFilter?
    init(_ initialSize: NSSize, stableId: AnyHashable, filter: ChatListFilter?, context: AccountContext) {
        self.context = context
        self.filter = filter
        self._stableId = stableId
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        if let table = table {
            var tableHeight: CGFloat = 0
            table.enumerateItems { item -> Bool in
                if item.index < self.index {
                    tableHeight += item.height
                }
                return true
            }
            let height = table.frame.height == 0 ? initialSize.height : table.frame.height
            return height - tableHeight
        }
        return initialSize.height
    }
    
    override func viewClass() -> AnyClass {
        return ChatListLoadingRowView.self
    }
}


private class ChatListLoadingRowView : TableRowView {
    private let disposable = MetaDisposable()
    private let textView = TextView()
    private let separator = View()
    private let sticker: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let indicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        
        addSubview(separator)
        addSubview(sticker)
        addSubview(indicator)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? ChatListLoadingRowItem else {
            return
        }
        
        
        if let _ = item.filter {
            let animatedSticker: LocalAnimatedSticker = LocalAnimatedSticker.new_folder
            sticker.update(with: animatedSticker.file, size: NSMakeSize(112, 112), context: item.context, parent: nil, table: item.table, parameters: animatedSticker.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
            sticker.isHidden = false
            indicator.isHidden = true
        } else {
            sticker.isHidden = true
            indicator.isHidden = false
        }
        
        needsLayout = true
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func layout() {
        super.layout()
        
        separator.background = theme.colors.border
        
        guard let item = item as? ChatListLoadingRowItem else {
            return
        }
        
        let text: String
        if let _ = item.filter {
            text = L10n.chatListFilterLoading
        } else {
            text = "Loading"
        }
        
        let attr = NSAttributedString.initialize(string: text, color: theme.colors.text, font: .normal(.text)).mutableCopy() as! NSMutableAttributedString
        
        attr.detectBoldColorInString(with: .medium(.text))
        
        let layout = TextViewLayout(attr, alignment: .center)
        
        layout.measure(width: frame.width - 40)
        layout.interactions = globalLinkExecutor
        textView.update(layout)
        textView.center()
        
        textView.isHidden = frame.width <= 70 || item.filter == nil
        sticker.isHidden = frame.width <= 70 || item.filter == nil
        
        indicator.isHidden = item.filter != nil
        
        separator.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
        
        sticker.centerX(y: textView.frame.minY - sticker.frame.height - 20)
        indicator.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
