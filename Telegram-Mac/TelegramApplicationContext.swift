//
//  TelegramApplicationContext.swift
//  TelegramMac
//
//  Created by keepcoder on 28/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

public var isDebug = false

class TelegramApplicationContext : NSObject {
    var layout:SplitViewState = .none
    let layoutHandler:ValuePromise<SplitViewState> = ValuePromise(ignoreRepeated:true)
    private(set) var mediaKeyTap:SPMediaKeyTap?
    let entertainment:EntertainmentViewController
    private var _recentlyPeerUsed:[PeerId] = []
    let cachedAdminIds: CachedAdminIds = CachedAdminIds()
    private(set) var timeDifference:TimeInterval  = 0
    private(set) var recentlyPeerUsed:[PeerId] {
        set {
            _recentlyPeerUsed = newValue
        }
        get {
            if _recentlyPeerUsed.count > 2 {
                return Array(_recentlyPeerUsed.prefix(through: 2))
            } else {
                return _recentlyPeerUsed
            }
        }
    }
    
    var globalSearch:((String)->Void)?
    
    private let logoutDisposable = MetaDisposable()
    
    weak var mainNavigation:NavigationViewController?
    private let updateDifferenceDisposable = MetaDisposable()
    init(_ mainNavigation:NavigationViewController?, _ entertainment:EntertainmentViewController, network: Network) {
        self.mainNavigation = mainNavigation
        self.entertainment = entertainment
        timeDifference = network.globalTime - Date().timeIntervalSince1970
        super.init()
        
        
        _ = layoutHandler.get().start(next: { [weak self] (state) in
            self?.layout = state
        })
        
        updateDifferenceDisposable.set((Signal<Void, Void>.single(Void())
            |> delay(5 * 60, queue: Queue.mainQueue()) |> restart).start(next: { [weak self, weak network] in
                if let network = network {
                    self?.timeDifference = network.globalTime - Date().timeIntervalSince1970
                }
            }))
        
    }
    
    func showCallHeader(with session:PCallSession) {
        mainNavigation?.callHeader?.show(true)
        if let view = mainNavigation?.callHeader?.view as? CallNavigationHeaderView {
            view.update(with: session)
        }
    }
    
    func checkFirstRecentlyForDuplicate(peerId:PeerId) {
        if let index = recentlyPeerUsed.index(of: peerId), index == 0 {
            recentlyPeerUsed.remove(at: index)
        }
    }
    
    func addRecentlyUsedPeer(peerId:PeerId) {
        if let index = recentlyPeerUsed.index(of: peerId) {
            recentlyPeerUsed.remove(at: index)
        }
        recentlyPeerUsed.insert(peerId, at: 0)
        if recentlyPeerUsed.count > 4 {
            recentlyPeerUsed = Array(recentlyPeerUsed.prefix(through: 4))
        }
    }
    
    deinit {
        updateDifferenceDisposable.dispose()
    }
    
    
    func deinitMediaKeyTap() {
        mediaKeyTap?.stopWatchingMediaKeys()
        mediaKeyTap = nil
    }
    
    func initMediaKeyTap() {
        mediaKeyTap = SPMediaKeyTap(delegate: self)
    }

    override func mediaKeyTap(_ keyTap: SPMediaKeyTap, receivedMediaKeyEvent event: NSEvent) {
        let keyCode: Int32 = (Int32((event.data1 & 0xffff0000) >> 16))
        let keyFlags: Int = (event.data1 & 0x0000ffff)
        let keyIsPressed: Bool = ((keyFlags & 0xff00) >> 8) == 0xa
        if keyIsPressed {
            switch keyCode {
            case NX_KEYTYPE_PLAY:
                globalAudio?.playOrPause()
            case NX_KEYTYPE_FAST:
                globalAudio?.next()
            case NX_KEYTYPE_REWIND:
                globalAudio?.prev()
            default:
                break
            }
        }
    }
    
}
