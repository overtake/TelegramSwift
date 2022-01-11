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


typealias MenuAnimation = LocalAnimatedSticker

extension MenuAnimation {
    var value: (NSColor, ContextMenuItem)-> AppMenuItemImageDrawable {
        { color, item in
            return AppMenuAnimatedImage(self, color, item)
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
            
            let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey.init(key: .bundle(self.sticker.rawValue), size: frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, colors: [.init(keyPath: "", color: color)], metalSupport: false)
            
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
                self.set(self.animation?.withUpdatedPolicy(.once), reset: false)
            } else {
                self.playAgain()
            }
        default:
            break
        }
    }
    
}


