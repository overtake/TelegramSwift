//
//  ChatCommentsHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15/09/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox



class ChatCommentsHeaderItem : TableStickItem {
    
    private let entry:ChatHistoryEntry
    fileprivate let chatInteraction:ChatInteraction?
    let isBubbled: Bool
    let layout:TextViewLayout
    init(_ initialSize:NSSize, _ entry:ChatHistoryEntry, interaction: ChatInteraction, theme: TelegramPresentationTheme) {
        self.entry = entry
        self.isBubbled = entry.renderType == .bubble
        self.chatInteraction = interaction
       
        
        let text: String
        switch entry {
        case let .commentsHeader(empty, _, _):
            if empty {
                text = L10n.chatCommentsHeaderEmpty
            } else {
                text = L10n.chatCommentsHeaderFull
            }
        default:
            text = ""
        }
        
        self.layout = TextViewLayout(.initialize(string: text, color: theme.chatServiceItemTextColor, font: .medium(theme.fontSize)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)
        
        
        super.init(initialSize)
    }
    
    override var canBeAnchor: Bool {
        return false
    }
    
    required init(_ initialSize: NSSize) {
        entry = .commentsHeader(true, MessageIndex.absoluteLowerBound(), .list)
        self.isBubbled = false
        self.layout = TextViewLayout(NSAttributedString())
        self.chatInteraction = nil
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(width: width - 40)
        return success
    }
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override var height: CGFloat {
        return 30
    }
    
    override func viewClass() -> AnyClass {
        return ChatCommentsHeaderView.self
    }
    
    
}

class ChatCommentsHeaderView : TableRowView {
    private let textView:TextView
    private let containerView: Control = Control()
    private var borderView: View = View()
    required init(frame frameRect: NSRect) {
        self.textView = TextView()
        self.textView.isSelectable = false
        self.containerView.wantsLayer = true
        self.textView.disableBackgroundDrawing = true
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = theme.chatServiceItemColor
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    override func layout() {
        super.layout()
        textView.center()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        if let item = item as? ChatCommentsHeaderItem {
            textView.update(item.layout)
            textView.setFrameSize(item.layout.layoutSize.width + 16, item.layout.layoutSize.height + 6)
            textView.layer?.cornerRadius = textView.frame.height / 2
            self.needsLayout = true
        }
        super.set(item: item, animated:animated)
    }
}
