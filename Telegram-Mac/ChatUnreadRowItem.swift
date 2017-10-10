//
//  ChatUnreadRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
class ChatUnreadRowItem: ChatRowItem {

    override var height: CGFloat {
        return 20
    }
    
    
    public var text:NSAttributedString;
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ entry:ChatHistoryEntry) {
        
        let titleAttr:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleAttr.append(string:tr(.messagesUnreadMark), color: theme.colors.grayText, font: .normal(.text))
        text = titleAttr.copy() as! NSAttributedString

        
        super.init(initialSize,chatInteraction,entry)
    }
    
    override var messageIndex:MessageIndex? {
        switch entry {
        case .UnreadEntry(let index):
            return index
        default:
            break
        }
        return super.messageIndex
    }
    
    override func viewClass() -> AnyClass {
        return ChatUnreadRowView.self
    }
    
}
