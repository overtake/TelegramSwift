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
import SwiftSignalKit
import TelegramMedia
import TelegramVoip

internal final class Arguments {
    let toggleSecretKey:()->Void
    let makeAvatar:(NSView?, Peer?)->NSView?
    init(toggleSecretKey:@escaping()->Void, makeAvatar:@escaping(NSView?, Peer?)->NSView?) {
        self.toggleSecretKey = toggleSecretKey
        self.makeAvatar = makeAvatar
    }
}


public final class PeerCallArguments {
    let peerId: PeerId
    let engine: TelegramEngine
    let makeAvatar:(NSView?, Peer?)->NSView
    let toggleMute:()->Void
    let toggleCamera:()->Void
    let toggleScreencast:()->Void
    let endcall:(ExternalPeerCallState)->Void
    let recall:()->Void
    let acceptcall:()->Void
    let video:(Bool)->Signal<OngoingGroupCallContext.VideoFrameData, NoError>?
    public init(engine: TelegramEngine, peerId: PeerId, makeAvatar: @escaping (NSView?, Peer?) -> NSView, toggleMute:@escaping()->Void, toggleCamera:@escaping()->Void, toggleScreencast:@escaping()->Void, endcall:@escaping(ExternalPeerCallState)->Void, recall:@escaping()->Void, acceptcall:@escaping()->Void, video:@escaping(Bool)->Signal<OngoingGroupCallContext.VideoFrameData, NoError>?) {
        self.engine = engine
        self.peerId = peerId
        self.makeAvatar = makeAvatar
        self.toggleMute = toggleMute
        self.toggleCamera = toggleCamera
        self.toggleScreencast = toggleScreencast
        self.endcall = endcall
        self.recall = recall
        self.acceptcall = acceptcall
        self.video = video
    }
}
