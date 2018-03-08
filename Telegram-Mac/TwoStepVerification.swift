//
//  TwoStepVerification.swift
//  TelegramMac
//
//  Created by keepcoder on 17/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import MtProtoKitMac



func apiInputPeer(_ peer: Peer) -> Api.InputPeer? {
    
    switch peer {
    case let user as TelegramUser where user.accessHash != nil:
        return Api.InputPeer.inputPeerUser(userId: user.id.id, accessHash: user.accessHash!)
    case let group as TelegramGroup:
        return Api.InputPeer.inputPeerChat(chatId: group.id.id)
    case let channel as TelegramChannel:
        if let accessHash = channel.accessHash {
            return Api.InputPeer.inputPeerChannel(channelId: channel.id.id, accessHash: accessHash)
        } else {
            return nil
        }
    default:
        return nil
    }
}

func apiInputChannel(_ peer: Peer) -> Api.InputChannel? {
    if let channel = peer as? TelegramChannel, let accessHash = channel.accessHash {
        return Api.InputChannel.inputChannel(channelId: channel.id.id, accessHash: accessHash)
    } else {
        return nil
    }
}

func apiInputUser(_ peer: Peer) -> Api.InputUser? {
    if let user = peer as? TelegramUser, let accessHash = user.accessHash {
        return Api.InputUser.inputUser(userId: user.id.id, accessHash: accessHash)
    } else {
        return nil
    }
}



public func reportMessages(postbox: Postbox, network: Network, peerId: PeerId, messageIds: [MessageId], reason:ReportReason) -> Signal<Void, Void> {
    return postbox.modify{ modifier -> Void in
        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
           // return Api.functions.messages.report
        }
    }
}


