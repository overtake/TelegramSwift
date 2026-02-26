//
//  DeclareEncodables.swift
//  Telegram-Mac
//
//  Created by keepcoder on 04/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(VideoLibraryMediaResource.self, f: { VideoLibraryMediaResource(decoder: $0) })
    declareEncodable(LocalFileVideoMediaResource.self, f: { LocalFileVideoMediaResource(decoder: $0) })
    declareEncodable(LocalFileGifMediaResource.self, f: { LocalFileGifMediaResource(decoder: $0) })
    declareEncodable(LottieSoundMediaResource.self, f: { LottieSoundMediaResource(decoder: $0) })
    declareEncodable(LocalFileArchiveMediaResource.self, f: { LocalFileArchiveMediaResource(decoder: $0) })
    declareEncodable(ExternalMusicAlbumArtResource.self, f: { ExternalMusicAlbumArtResource(decoder: $0) })
    declareEncodable(LocalBundleResource.self, f: { LocalBundleResource(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
