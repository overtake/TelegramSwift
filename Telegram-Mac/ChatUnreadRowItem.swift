//
//  ChatUnreadRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox

class ChatUnreadRowItem: ChatRowItem {

    override var height: CGFloat {
        return 32
    }
    
    override var canBeAnchor: Bool {
        return false
    }
    
    public let text: TextViewLayout;
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ entry:ChatHistoryEntry, theme: TelegramPresentationTheme) {
        
        let titleAttr:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleAttr.append(string: strings().messagesUnreadMark, color: theme.colors.grayText, font: .normal(.text))
        self.text = .init(titleAttr, maximumNumberOfLines: 1, alignment: .center)
        
        super.init(initialSize,chatInteraction,entry, theme: theme)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        text.measure(width: blockWidth)
        return true
    }
    
    override var messageIndex:MessageIndex? {
        switch entry {
        case .UnreadEntry(let index, _, _, _):
            return index
        default:
            break
        }
        return super.messageIndex
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChatUnreadRowView.self
    }
    
}

private class ChatUnreadRowView: TableRowView {
    
    private let text: TextView = TextView()
    private let backgroundView = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(text)
        text.isSelectable = false
        text.userInteractionEnabled = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = item as? ChatUnreadRowItem else {
            return
        }
        self.backgroundView.backgroundColor = item.presentation.colors.grayBackground
    }
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatUnreadRowItem else {
            return
        }
        text.update(item.text)
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? ChatRowItem else {
            return
        }
        transition.updateFrame(view: backgroundView, frame: size.bounds.insetBy(dx: 0, dy: 6))
        transition.updateFrame(view: text, frame: text.centerFrame().offsetBy(dx: item.monoforumState == .vertical ? 40 : 0, dy: 0))
    }
    

    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}
