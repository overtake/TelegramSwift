//
//  TelegramAccountAuxiliaryMethods.swift
//  Telegram
//
//  Created by keepcoder on 23/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Foundation
import TelegramCore

import Postbox

public let telegramAccountAuxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { postbox, resource, range, tag in
    if let resource = resource as? LocalFileGifMediaResource {
        return fetchGifMediaResource(resource: resource)
    } else if let resource = resource as? LocalFileArchiveMediaResource {
        return fetchArchiveMediaResource(resource: resource)
    } else if let resource = resource as? ExternalMusicAlbumArtResource {
        return fetchExternalMusicAlbumArtResource(resource: resource)
    } else if let resource = resource as? LocalFileVideoMediaResource {
        return fetchMovMediaResource(resource: resource)
    } else if let resource = resource as? LottieSoundMediaResource {
        return fetchLottieSoundData(resource: resource)
    }
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
}, prepareSecretThumbnailData: { resource in
    return nil
}, backgroundUpload: { _, _, _ in
    return .single(nil)
})
