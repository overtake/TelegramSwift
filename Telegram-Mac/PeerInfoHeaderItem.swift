//
//  PeerInfoHeaderItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
class PeerInfoHeaderItem: GeneralRowItem {


    let firstTextEdited:String?
    let lastTextEdited:String?
    
    override var height: CGFloat {
        return 130.0
    }
    
    let photoDimension:CGFloat = 70.0
    let textMargin:CGFloat = 15.0
    var textInset:CGFloat {
        return self.inset.left + photoDimension + textMargin
    }
    
    var photo:Signal<(CGImage?, Bool), NoError>?
    var status:(TextNodeLayout, TextNode)?
    var name:(TextNodeLayout, TextNode)?
    
    let account:Account
    let peer:Peer?
    let isVerified: Bool
    let peerView:PeerView
    let result:PeerStatusStringResult
    let editable:Bool
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    let textChangeHandler:(String, String?)->Void
    let canCall:Bool
    init(_ initialSize:NSSize, stableId:AnyHashable, account:Account, peerView:PeerView, editable:Bool = false, updatingPhotoState:PeerInfoUpdatingPhotoState? = nil, firstNameEditableText:String? = nil, lastNameEditableText:String? = nil, textChangeHandler:@escaping (String, String?)->Void = {_,_  in}) {
        let peer = peerViewMainPeer(peerView)
        self.peer = peer
        self.peerView = peerView
        self.editable = editable
        self.account = account
        self.updatingPhotoState = updatingPhotoState
        self.textChangeHandler = textChangeHandler
        self.firstTextEdited = firstNameEditableText
        self.lastTextEdited = lastNameEditableText
        
        canCall = peer != nil && (peer!.canCall && peer!.id != account.peerId && !editable)
        
        isVerified = peer?.isVerified ?? false
        
        if let peer = peer {
            photo = peerAvatarImage(account: account, photo: .peer(peer.id, peer.smallProfileImage, peer.displayLetters), displayDimensions:NSMakeSize(photoDimension, photoDimension))
        }
        self.result = stringStatus(for: peerView, theme: PeerStatusStringTheme(titleFont: .medium(.huge), highlightIfActivity: false))
        
        super.init(initialSize, stableId:stableId)
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoHeaderView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        name = TextNode.layoutText(maybeNode: nil,  result.title, nil, 1, .end, NSMakeSize(size.width - textInset - inset.right - (canCall ? 40 : 0), size.height), nil, false, .left)
        status = TextNode.layoutText(maybeNode: nil,  result.status, nil, 1, .end, NSMakeSize(size.width - textInset - inset.right - (canCall ? 40 : 0), size.height), nil, false, .left)

        return super.makeSize(width, oldWidth: oldWidth)
    }
    
}
