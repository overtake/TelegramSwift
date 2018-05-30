//
//  TelegramAccountAuxiliaryMethods.swift
//  Telegram
//
//  Created by keepcoder on 23/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Foundation
import TelegramCoreMac
import PostboxMac

public let telegramAccountAuxiliaryMethods = AccountAuxiliaryMethods(updatePeerChatInputState: { interfaceState, inputState -> PeerChatInterfaceState? in
    if interfaceState == nil {
        return ChatInterfaceState().withUpdatedSynchronizeableInputState(inputState)
    } else if let interfaceState = interfaceState as? ChatInterfaceState {
        return interfaceState.withUpdatedSynchronizeableInputState(inputState)
    } else {
        return interfaceState
    }
}, fetchResource: { account, resource, range, tag in
    
    if let resource = resource as? LocalFileGifMediaResource {
        return fetchGifMediaResource(resource: resource)
    } else if let mapSnapshotResource = resource as? MapSnapshotMediaResource {
        return fetchMapSnapshotResource(resource: mapSnapshotResource)
    }
    
//    if let resource = resource as? VideoLibraryMediaResource {
//        return fetchVideoLibraryMediaResource(resource: resource)
//    } else if let resource = resource as? LocalFileVideoMediaResource {
//        return fetchLocalFileVideoMediaResource(resource: resource)
//    }
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
})
