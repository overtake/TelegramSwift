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



extension AppMenu {
    static var add_to_folder:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_add_to_folder, color, item)
        }
    }
    static var archive:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_archive, color, item)
        }
    }
    static var clear_history:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_clear_history, color, item)
        }
    }
    static var delete:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_delete, color, item)
        }
    }
    static var mute:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_mute, color, item)
        }
    }
    static var pin:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_pin, color, item)
        }
    }
    static var unmute:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_unmuted, color, item)
        }
    }
    static var unread:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_unread, color, item)
        }
    }
    static var unarchive:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_unarchive, color, item)
        }
    }
    static var read:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_read, color, item)
        }
    }
    static var unpin:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_unpin, color, item)
        }
    }
    static var mute_for_1_hour:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_mute_for_1_hour, color, item)
        }
    }
    static var mute_for_2_days:(NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            AppMenuAnimatedImage(.menu_mute_for_2_days, color, item)
        }
    }
    
}


final class AppMenuAnimatedImage : LottiePlayerView, AppMenuItemImageDrawable {
    
    private let sticker: LocalAnimatedSticker
    private let item: ContextMenuItem
    init(_ sticker: LocalAnimatedSticker, _ color: NSColor, _ item: ContextMenuItem) {
        self.sticker = sticker
        self.item = item
        super.init(frame: NSMakeRect(0, 0, 18, 18))
        
        if let data = sticker.data {
            
            let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey.init(key: .bundle(self.sticker.rawValue), size: frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, colors: [.init(keyPath: "", color: color)], runOnQueue: .mainQueue())
            
            self.set(animation, reset: true, saveContext: false, animated: false)

        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
                self.set(self.animation?.withUpdatedPolicy(.once))
            } else {
                self.playAgain()
            }
        default:
            break
        }
    }
    
}


