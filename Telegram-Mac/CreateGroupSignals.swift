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
