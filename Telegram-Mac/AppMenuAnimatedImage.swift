//
//  AppMenuAnimatedImage.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.12.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import AppKit
import TelegramCore
import Postbox

typealias MenuAnimation = LocalAnimatedSticker

extension MenuAnimation {
    var value: (NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            return AppMenuAnimatedImage(self, color, item)
        }
    }
}

struct MenuRemoteAnimation {
    fileprivate let context: AccountContext
    fileprivate let file: TelegramMediaFile
    fileprivate let thumb: LocalAnimatedSticker
    fileprivate let bot: Peer
    init(_ context: AccountContext, file: TelegramMediaFile, bot: Peer, thumb: LocalAnimatedSticker)  {
        self.context = context
        self.file = file
        self.bot = bot
        self.thumb = thumb
    }
    
    var value: (NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            return AppMenuAnimatedRemoteImage(self, color, item)
        }
    }
}


final class AppMenuAnimatedImage : LottiePlayerView, AppMenuItemImageDrawable {
    
    private let sticker: LocalAnimatedSticker
    private let item: ContextMenuItem
    init(_ sticker: LocalAnimatedSticker, _ color: NSColor?, _ item: ContextMenuItem) {
        self.sticker = sticker
        self.item = item
        super.init(frame: NSMakeRect(0, 0, 18, 18))
        
        if let data = sticker.data {
            
            var colors:[LottieColor] = []
            if let color = color {
                colors = [.init(keyPath: "", color: color)]
            } else {
                colors = []
            }
            
            let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey.init(key: .bundle(self.sticker.rawValue), size: frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, colors: colors, metalSupport: false)
            
            self.set(animation, reset: true, saveContext: false, animated: false)

        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func isEqual(to item: ContextMenuItem) -> Bool {
        return self.item.id == item.id
    }
    func setColor(_ color: NSColor) {
        self.setColors([.init(keyPath: "", color: color)])
    }
    func updateState(_ controlState: ControlState) {
        switch controlState {
        case .Hover:
            if self.animation?.playPolicy == .framesCount(1) {
                self.set(self.animation?.withUpdatedPolicy(.once), reset: false)
            } else {
                self.playAgain()
            }
        default:
            break
        }
    }
    
}



final class AppMenuAnimatedRemoteImage : LottiePlayerView, AppMenuItemImageDrawable {
    
    private let sticker: MenuRemoteAnimation
    private let item: ContextMenuItem
    private let disposable = MetaDisposable()
    private let color: NSColor?
    init(_ sticker: MenuRemoteAnimation, _ color: NSColor?, _ item: ContextMenuItem) {
        self.sticker = sticker
        self.item = item
        self.color = color
        super.init(frame: NSMakeRect(0, 0, 18, 18))
        
        if let reference = PeerReference(sticker.bot) {
            _ = fetchedMediaResource(mediaBox: sticker.context.account.postbox.mediaBox, reference: .media(media: .attachBot(peer: reference, media: sticker.file), resource: sticker.file.resource)).start()
        }
        
        let signal = sticker.context.account.postbox.mediaBox.resourceData(sticker.file.resource, attemptSynchronously: true) |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] data in
            if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                self?.apply(data)
            } else {
                if let data = self?.sticker.thumb.data {
                    self?.apply(data)
                }
            }
        }))
        

    }
    
    private func apply(_ data: Data) {
        var colors:[LottieColor] = []
        if let color = color {
            colors = [.init(keyPath: "", color: color)]
        } else {
            colors = []
        }

        let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .bundle(self.sticker.thumb.rawValue), size: frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, colors: colors, metalSupport: false)

        self.set(animation, reset: true, saveContext: false, animated: false)
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func isEqual(to item: ContextMenuItem) -> Bool {
        return self.item.id == item.id
    }
    func setColor(_ color: NSColor) {
        self.setColors([.init(keyPath: "", color: color)])
    }
    func updateState(_ controlState: ControlState) {
        switch controlState {
        case .Hover:
            if self.animation?.playPolicy == .framesCount(1) {
                self.set(self.animation?.withUpdatedPolicy(.once), reset: false)
            } else {
                self.playAgain()
            }
        default:
            break
        }
    }
    
}


