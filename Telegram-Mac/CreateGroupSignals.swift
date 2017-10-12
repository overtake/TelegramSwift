//
//  CreateGroupSignals.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac
import MtProtoKitMac

public func removeUserPhoto(account: Account, reference: TelegramMediaRemoteImageReference) -> Signal<Void, Void> {
    
    switch reference {
    case let .remoteImage(imageId, accesshash):
        let api = Api.functions.photos.deletePhotos(id: [Api.InputPhoto.inputPhoto(id: imageId, accessHash: accesshash)])
        return account.network.request(api) |> map {_ in} |> retryRequest
    case .none:
        let api = Api.functions.photos.updateProfilePhoto(id: Api.InputPhoto.inputPhotoEmpty)
        return account.network.request(api) |> map { _ in } |> retryRequest
    }
    
}


func channelAdminIds(postbox: Postbox, network: Network, peerId: PeerId, hash: Int32) -> Signal<[PeerId], Void> {
    return postbox.modify { modifier in
        if let peer = modifier.getPeer(peerId) as? TelegramChannel, case .group = peer.info, let apiChannel = apiInputChannel(peer) {
            let api = Api.functions.channels.getParticipants(channel: apiChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 100, hash: hash)
            return network.request(api) |> retryRequest |> mapToSignal { result in
                switch result {
                case let .channelParticipants(_, _, users):
                    return .single(users.map({TelegramUser(user: $0).id}))
                default:
                    return .complete()
                }
            }
        }
        return .complete()
    } |> switchToLatest
}
