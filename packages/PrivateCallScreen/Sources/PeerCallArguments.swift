//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 08.02.2024.
//

import Foundation
import TelegramCore
import Postbox
import AppKit


internal final class Arguments {
    let external: PeerCallArguments
    let toggleSecretKey:()->Void
    init(external: PeerCallArguments, toggleSecretKey:@escaping()->Void) {
        self.external = external
        self.toggleSecretKey = toggleSecretKey
    }
}


public final class PeerCallArguments {
    let peerId: PeerId
    let engine: TelegramEngine
    let makeAvatar:(NSView?, Peer?)->NSView
    let toggleMute:()->Void
    let toggleCamera:()->Void
    let toggleScreencast:()->Void
    let endcall:()->Void
    let recall:()->Void
    public init(engine: TelegramEngine, peerId: PeerId, makeAvatar: @escaping (NSView?, Peer?) -> NSView, toggleMute:@escaping()->Void, toggleCamera:@escaping()->Void, toggleScreencast:@escaping()->Void, endcall:@escaping()->Void, recall:@escaping()->Void) {
        self.engine = engine
        self.peerId = peerId
        self.makeAvatar = makeAvatar
        self.toggleMute = toggleMute
        self.toggleCamera = toggleCamera
        self.toggleScreencast = toggleScreencast
        self.endcall = endcall
        self.recall = recall
    }
}
