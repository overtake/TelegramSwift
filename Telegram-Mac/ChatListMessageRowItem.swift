//
//  ChatListMessageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox

class ChatListMessageRowItem: ChatListRowItem {

    init(_ initialSize:NSSize, context: AccountContext, message: Message, id: EngineChatList.Item.Id, query: String, renderedPeer:RenderedPeer, readState: CombinedPeerReadState?, mode: ChatListRowItem.Mode, titleMode: ChatListRowItem.TitleMode) {
        super.init(initialSize, context: context, stableId: .chatId(id, message.id.peerId, message.id.id), mode: mode, messages: [message], readState: .init(state: readState, isMuted: false), renderedPeer: .init(renderedPeer), highlightText: query, showBadge: false, titleMode: titleMode)
    }
    
    override var stableId: AnyHashable {
        return message!.id
    }
}
