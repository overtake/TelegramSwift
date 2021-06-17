//
//  ChatInputMenuView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.06.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit


final class ChatInputMenuView : View {
    private let button = Control()
    private let animationView: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 30, 30))
    weak var chatInteraction: ChatInteraction?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(button)
        
        animationView.background = .random
        
        button.addSubview(animationView)
        button.scaleOnClick = true
        button.layer?.cornerRadius = 15
        
        updateLocalizationAndTheme(theme: theme)
        
        button.set(handler: { [weak self] _ in
            self?.chatInteraction?.update {
                $0.updateBotMenu { current in
                    var current = current
                    if let value = current {
                        current?.revealed = !value.revealed
                    }
                    return current
                }
            }
        }, for: .Click)
        
    }
    
    private var botMenu: ChatPresentationInterfaceState.BotMenu?
    
    func update(_ botMenu: ChatPresentationInterfaceState.BotMenu, animated: Bool) {
        
        let previous = self.botMenu
        self.botMenu = botMenu
        
        let sticker: LocalAnimatedSticker
        let playPolicy: LottiePlayPolicy
        
        if botMenu.revealed {
            sticker = .bot_menu_close
        } else {
            sticker = .bot_close_menu
        }
        
        if previous == nil || previous?.revealed == botMenu.revealed || !animated {
            playPolicy = .toEnd(from: .max)
        } else {
            playPolicy = .toEnd(from: 0)
        }
        
        if let data = sticker.data {
            animationView.set(.init(compressed: data, key: .init(key: .bundle(sticker.rawValue + theme.colors.name), size: NSMakeSize(30, 30)), cachePurpose: .none, playPolicy: playPolicy, runOnQueue: .mainQueue()))
        }
    }
    
    deinit {
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
//
        button.set(background: theme.colors.accent, for: .Normal)
        button.set(background: theme.colors.accent, for: .Hover)
        button.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)

    }
    
    override func layout() {
        super.layout()
        
        button.setFrameSize(NSMakeSize(40, 30))
        button.centerY(x: frame.width - button.frame.width)
        animationView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
