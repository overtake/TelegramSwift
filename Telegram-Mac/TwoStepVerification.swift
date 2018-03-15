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
           // return Api.functions.messages.
        }
    }
}

public struct WebAuthorization : Equatable {
    public let hash: Int64
    public let botId: PeerId
    public let domain: String
    public let browser: String
    public let platform: String
    public let dateCreated: Int32
    public let dateActive: Int32
    public let ip: String
    public let region: String
    
    public static func ==(lhs: WebAuthorization, rhs: WebAuthorization) -> Bool {
        return lhs.hash == rhs.hash && lhs.botId == rhs.botId && lhs.domain == rhs.domain && lhs.browser == rhs.browser && lhs.platform == rhs.platform && lhs.dateActive == rhs.dateActive && lhs.dateCreated == rhs.dateCreated && lhs.ip == rhs.ip && lhs.region == rhs.region
    }
}

public func webSessions(network: Network) -> Signal<([WebAuthorization], [PeerId: Peer]), NoError> {
    return network.request(Api.functions.account.getWebAuthorizations())
        |> retryRequest
        |> map { result -> ([WebAuthorization], [PeerId : Peer]) in
            var sessions: [WebAuthorization] = []
            var peers:[PeerId : Peer] = [:]
            switch result {
            case let .webAuthorizations(authorizations, users):
                for authorization in authorizations {
                    switch authorization {
                    case let .webAuthorization(hash, botId, domain, browser, platform, dateCreated, dateActive, ip, region):
                        sessions.append(WebAuthorization(hash: hash, botId: PeerId(namespace: Namespaces.Peer.CloudUser, id: botId), domain: domain, browser: browser, platform: platform, dateCreated: dateCreated, dateActive: dateActive, ip: ip, region: region))
                        
                    }
                }
                for user in users {
                    let peer = TelegramUser(user: user)
                    peers[peer.id] = peer
                }
            }
            return (sessions, peers)
    }
}


public func terminateWebSession(network: Network, hash: Int64) -> Signal<Bool, Void> {
    return network.request(Api.functions.account.resetWebAuthorization(hash: hash)) |> retryRequest |> map { result in
        switch result {
        case .boolFalse:
            return false
        case .boolTrue:
            return true
        }
    }
}

public func terminateAllWebSessions(network: Network) -> Signal<Void, Void> {
    return network.request(Api.functions.account.resetWebAuthorizations()) |> retryRequest |> map {_ in}
}
