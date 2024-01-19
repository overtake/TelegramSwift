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
import TelegramMedia

final class ChatInputMenuView : View {
    private let button = Control()
    private let animationView: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 30, 30))
    weak var chatInteraction: ChatInteraction?
    private var botMenu: ChatPresentationInterfaceState.BotMenu?
    private var text: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(button)
                
        button.addSubview(animationView)
        button.scaleOnClick = true
        button.layer?.cornerRadius = 15
        
        
        updateLocalizationAndTheme(theme: theme)
        
        button.set(handler: { [weak self] _ in
            if let botMenu = self?.botMenu {
                switch botMenu.menuButton {
                case .commands:
                    self?.chatInteraction?.update {
                        $0.updateBotMenu { current in
                            var current = current
                            if let value = current {
                                current?.revealed = !value.revealed
                            }
                            return current
                        }
                    }
                case let .webView(text, url):
                    self?.chatInteraction?.openWebviewFromMenu(buttonText: text, url: url)
                }
            }
            
        }, for: .Click)
        
    }
    
    
    func update(_ botMenu: ChatPresentationInterfaceState.BotMenu, animated: Bool) {
        
        let previous = self.botMenu
        self.botMenu = botMenu
        
        let sticker: LocalAnimatedSticker
        let playPolicy: LottiePlayPolicy
        
        switch botMenu.menuButton {
        case .webView:
            sticker = .bot_menu_web_app
        default:
            if botMenu.revealed {
                sticker = .bot_menu_close
            } else {
                sticker = .bot_close_menu
            }
        }
        
        if previous == nil || previous?.revealed == botMenu.revealed || !animated {
            playPolicy = .toEnd(from: .max)
        } else {
            playPolicy = .toEnd(from: 0)
        }
        
        if let data = sticker.data {
            animationView.set(.init(compressed: data, key: .init(key: .bundle(sticker.rawValue + theme.colors.name), size: NSMakeSize(30, 30)), cachePurpose: .none, playPolicy: playPolicy, runOnQueue: .mainQueue()))
        }
        
        switch botMenu.menuButton {
        case let .webView(text, _):
            let current: TextView
            if let view = self.text {
                current = view
            } else {
                current = TextView()
                current.isSelectable = false
                current.userInteractionEnabled = false
                self.text = current
                button.addSubview(current)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            let layout = TextViewLayout(.initialize(string: text, color: theme.colors.underSelectedColor, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            
            current.update(layout)
            self.change(size: NSMakeSize(layout.layoutSize.width + 67, frame.height), animated: animated)
        default:
            if let view = self.text {
                performSubviewRemoval(view, animated: animated)
                self.text = nil
            }
            self.change(size: NSMakeSize(60, frame.height), animated: animated)
        }
        
        
        needsLayout = true
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
                
        if let text = self.text {
            button.setFrameSize(NSMakeSize(50 + text.frame.width, 30))
            button.centerY(x: frame.width - button.frame.width)
            animationView.centerY(x: 5)
            text.centerY(x: animationView.frame.maxX + 3)
        } else {
            button.setFrameSize(NSMakeSize(40, 30))
            button.centerY(x: frame.width - button.frame.width)
            animationView.center()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
