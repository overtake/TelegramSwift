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
    let toggleAnim:()->Void
    let toggleSecretKey:()->Void
    init(external: PeerCallArguments, toggleAnim:@escaping()->Void, toggleSecretKey:@escaping()->Void) {
        self.external = external
        self.toggleAnim = toggleAnim
        self.toggleSecretKey = toggleSecretKey
    }
}


public final class PeerCallArguments {
    let peerId: PeerId
    let engine: TelegramEngine
    let makeAvatar:(NSView?, Peer?)->NSView
    public init(engine: TelegramEngine, peerId: PeerId, makeAvatar: @escaping (NSView?, Peer?) -> NSView) {
        self.engine = engine
        self.peerId = peerId
        self.makeAvatar = makeAvatar
    }
}
