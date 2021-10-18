//
//  EmptyChatViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit



class EmptyChatView : View {
    private let containerView: View = View()
    private let label:TextView = TextView()
    private let imageView:ImageView = ImageView()
    
    let toggleTips: ImageButton = ImageButton()
    
    private var cards: NSView?
    
    func toggleTips(_ isEnabled: Bool, animated: Bool, view: NSView) {
        if isEnabled {
            addSubview(view)
            self.cards = view
            view.frame = NSMakeRect(0, 0, frame.width, 370)
            view.center()
            if animated {
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.3, timingFunction: .spring)
                view.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.3)
            }
        } else {
            performSubviewRemoval(view, animated: animated, duration: 0.3, timingFunction: .spring, checkCompletion: true)
            if animated {
                view.layer?.animateScaleSpring(from: 1, to: 0.1, duration: 0.3, bounce: false)
            }

            self.cards = nil
        }
        containerView.change(opacity: isEnabled ? 0 : 1, animated: animated)
        toggleTips.set(image: isEnabled ? theme.empty_chat_hidetips : theme.empty_chat_showtips, for: .Normal)
        
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer = CAGradientLayer()
        self.layer?.disableActions()
        
        toggleTips.set(image: theme.empty_chat_showtips, for: .Normal)
        toggleTips.setFrameSize(NSMakeSize(30, 30))
        toggleTips.set(background: .clear, for: .Normal)
        toggleTips.blurBackground = theme.chatServiceItemColor
        toggleTips.autohighlight = false
        toggleTips.scaleOnClick = true
        toggleTips.layer?.cornerRadius = 15

        addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(label)
        addSubview(toggleTips)
        label.userInteractionEnabled = false
        label.isSelectable = false
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        imageView.image = theme.icons.chatEmpty
        switch theme.controllerBackgroundMode {
        case .plain:
            imageView.isHidden = false
        default:
            imageView.isHidden = true
        }
        
        toggleTips.set(image: cards != nil ? theme.empty_chat_hidetips : theme.empty_chat_showtips, for: .Normal)
        if theme.shouldBlurService {
            toggleTips.set(background: .clear, for: .Normal)
            toggleTips.blurBackground = theme.chatServiceItemColor
        } else {
            toggleTips.set(background: theme.chatServiceItemColor, for: .Normal)
            toggleTips.blurBackground = nil
        }

        imageView.sizeToFit()
        label.disableBackgroundDrawing = true
        if imageView.isHidden && theme.bubbled {
            label.blurBackground = theme.chatServiceItemColor
        } else {
            label.blurBackground = nil
            label.backgroundColor = theme.chatBackground
        }

        label.update(TextViewLayout(.initialize(string: L10n.emptyPeerDescription, color: imageView.isHidden ? theme.chatServiceItemTextColor : theme.colors.grayText, font: .medium(imageView.isHidden ? .text : .header)), maximumNumberOfLines: 1, alignment: .center))
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        label.textLayout?.measure(width: frame.size.width - 20)
        label.update(label.textLayout)
        
        cards?.frame = NSMakeRect(0, 0, frame.width, 370)
        cards?.center()
        
        
        
        if imageView.isHidden {
            
            label.setFrameSize(label.frame.width + 16, label.frame.height + 6)
            
            containerView.setFrameSize(label.frame.width + 20, 24)
            containerView.center()
            label.center()
            label.layer?.cornerRadius = label.frame.height / 2
            containerView.layer?.cornerRadius = containerView.frame.height / 2
        } else {
            containerView.setFrameSize(max(imageView.frame.width, label.frame.width) + 40, imageView.frame.size.height + label.frame.size.height + 70)
            imageView.centerX(y: 20)
            containerView.center()
            label.centerX(y: imageView.frame.maxY + 30)
            containerView.layer?.cornerRadius = 0
        }
        
        toggleTips.setFrameOrigin(NSMakePoint(frame.width - toggleTips.frame.width - 10, 10))
    }
}

class EmptyChatViewController: TelegramGenericViewController<EmptyChatView> {
    
    
    
    private let cards: WidgetController
    override init(_ context: AccountContext) {
        cards = WidgetController(context)
        super.init(context)
        self.bar = NavigationBarStyle(height:0)
    }
    
    private var temporaryTouchBar: Any?
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        if temporaryTouchBar == nil {
            temporaryTouchBar = ChatListTouchBar(context: self.context, search: { [weak self] in
                self?.context.sharedContext.bindings.globalSearch("")
            }, newGroup: { [weak self] in
                self?.context.composeCreateGroup()
            }, newSecretChat: { [weak self] in
                self?.context.composeCreateSecretChat()
            }, newChannel: { [weak self] in
                self?.context.composeCreateChannel()
            })
        }
        return temporaryTouchBar as? NSTouchBar
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (navigationController as? MajorNavigationController)?.closeSidebar()
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        updateBackgroundColor(theme.controllerBackgroundMode)
    }
    
    override func updateBackgroundColor(_ backgroundMode: TableBackgroundMode) {
        super.updateBackgroundColor(backgroundMode)
        var containerBg = self.backgroundColor
        if theme.bubbled {
            switch theme.backgroundMode {
            case .background, .tiled, .gradient:
                containerBg = .clear
            case .plain:
                if theme.colors.chatBackground == theme.colors.background {
                    containerBg = theme.colors.border
                } else {
                    containerBg = .clear
                }
            case let .color(color):
                if color == theme.colors.background {
                    containerBg = theme.colors.border
                } else {
                    containerBg = .clear
                }
            }
        } else {
            if theme.colors.chatBackground == theme.colors.background {
                containerBg = theme.colors.border
            } else {
                containerBg = .clear
            }
        }
        self.backgroundColor = containerBg
    }
    
    override public var isOpaque: Bool {
        return false
    }
    
    override var responderPriority: HandlerPriority {
        return .medium
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        context.globalPeerHandler.set(.single(nil))
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return cards.backKeyAction()
    }
    override func nextKeyAction() -> KeyHandlerResult {
        return cards.nextKeyAction()
    }
    
    private let disposable = MetaDisposable()
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        readyOnce()
        
        self.ready.set(cards.ready.get())
        
        
        self.genericView.toggleTips(FastSettings.emptyTips, animated: false, view: cards.view)
        
        self.genericView.toggleTips.set(handler: { [weak self] _ in
            guard let cards = self?.cards.view else {
                return
            }
            FastSettings.updateEmptyTips(!FastSettings.emptyTips)
            self?.genericView.toggleTips(FastSettings.emptyTips, animated: true, view: cards)
        }, for: .Click)
    }
}
