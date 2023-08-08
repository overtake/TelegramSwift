//
//  PeersStatusView.swift
//  Telegram
//
//  Created by Mike Renoir on 08.08.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import Reactions
import SwiftSignalKit
import InAppSettings


private final class ProxyView : Control {
    fileprivate let button:ImageButton = ImageButton()
    private var connecting: ProgressIndicator?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        button.userInteractionEnabled = false
        button.isEventLess = true
        self.scaleOnClick = true
    }
    
    func update(_ pref: ProxySettings, connection: ConnectionStatus, animated: Bool) {
        switch connection {
        case .connecting, .waitingForNetwork:
            if pref.enabled {
                let current: ProgressIndicator
                if let view = self.connecting {
                    current = view
                } else {
                    current = ProgressIndicator(frame: focus(NSMakeSize(11, 11)))
                    self.connecting = current
                    addSubview(current)
                }
                current.userInteractionEnabled = false
                current.isEventLess = true
                current.progressColor = theme.colors.accentIcon
            } else if let view = connecting {
                performSubviewRemoval(view, animated: animated)
                self.connecting = nil
            }
            
            button.set(image: pref.enabled ? theme.icons.proxyState : theme.icons.proxyEnable, for: .Normal)
        case .online, .updating:
            if let view = connecting {
                performSubviewRemoval(view, animated: animated)
                self.connecting = nil
            }
            if pref.enabled  {
                button.set(image: theme.icons.proxyEnabled, for: .Normal)
            } else {
                button.set(image: theme.icons.proxyEnable, for: .Normal)
            }
        }
        button.sizeToFit()
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        button.center()
        if let connecting = connecting {
            var rect = connecting.centerFrame()
            if backingScaleFactor == 2.0 {
                rect.origin.x -= 0.5
                rect.origin.y -= 0.5
            }
            connecting.frame = rect
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        connecting?.progressColor = theme.colors.accentIcon
    }
}

private final class StatusView : Control {
    fileprivate var button:PremiumStatusControl?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.masksToBounds = false
    }
    
    private var peer: Peer?
    private weak var effectPanel: Window?
    
    func update(_ peer: Peer, context: AccountContext, animated: Bool) {
        
        
        var interactiveStatus: Reactions.InteractiveStatus? = nil
        if visibleRect != .zero, window != nil, let interactive = context.reactions.interactiveStatus, !context.isLite(.emoji_effects) {
            interactiveStatus = interactive
        }
        if let view = self.button, interactiveStatus != nil, interactiveStatus?.fileId != nil {
            performSubviewRemoval(view, animated: animated, duration: 0.3)
            self.button = nil
        }
        
        let control = PremiumStatusControl.control(peer, account: context.account, inlinePacksContext: context.inlinePacksContext, isSelected: false, isBig: true, playTwice: true, cached: self.button, animated: animated)
        if let control = control {
            self.button = control
            addSubview(control)
            control.center()
            
        } else {
            self.button?.removeFromSuperview()
            self.button = nil
        }
        self.peer = peer
        
        if let interactive = interactiveStatus {
            self.playAnimation(interactive, context: context)
        }
    }
    
    private func playAnimation(_  status: Reactions.InteractiveStatus, context: AccountContext) {
        guard let control = self.button, let window = self.window else {
            return
        }
        
        guard let fileId = status.fileId else {
            return
        }
        
        control.isHidden = true
        
        let play:(StatusView)->Void = { [weak control] superview in
            
            guard let control = control else {
                return
            }
            control.isHidden = false
            
            let panel = Window(contentRect: NSMakeRect(0, 0, 160, 120), styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
            panel._canBecomeMain = false
            panel._canBecomeKey = false
            panel.ignoresMouseEvents = true
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false

            let player = CustomReactionEffectView(frame: NSMakeSize(160, 120).bounds, context: context, fileId: fileId)
            
            player.isEventLess = true
            
            player.triggerOnFinish = { [weak panel] in
                if let panel = panel  {
                    panel.parent?.removeChildWindow(panel)
                    panel.orderOut(nil)
                }
            }
            superview.effectPanel = panel
                    
            let controlRect = superview.convert(control.frame, to: nil)
            
            var rect = CGRect(origin: CGPoint(x: controlRect.midX - player.frame.width / 2, y: controlRect.midY - player.frame.height / 2), size: player.frame.size)
            
            
            rect = window.convertToScreen(rect)
            
            panel.setFrame(rect, display: true)
            
            panel.contentView?.addSubview(player)
            
            window.addChildWindow(panel, ordered: .above)
        }
        if let fromRect = status.rect {
            let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: control.frame.size)
            
            let toRect = control.convert(control.frame.size.bounds, to: nil)
            
            let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
            let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
            
            let completed: (Bool)->Void = { [weak self] _ in
                DispatchQueue.main.async {
                    if let container = self {
                        play(container)
                        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                    }
                }
            }
            parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: completed)
        } else {
            play(self)
        }
    }
    
  
    override func layout() {
        super.layout()
        button?.center()
    }
    
    deinit {
        if let panel = effectPanel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
}

fileprivate final class TitleView : Control {
    
    enum Source {
        case contacts
        case forum
        case chats
        case settings
        case archivedChats
        var text: String {
            switch self {
            case .contacts:
                return strings().peerListTitleContacts
            case .chats:
                return strings().peerListTitleChats
            case .settings:
                return "Settings"
            case .archivedChats:
                return strings().peerListTitleArchive
            case .forum:
                return strings().peerListTitleForum
            }
        }
    }
    
    var openStatus:((Control)->Void)? = nil
    
    private let textView = TextView()
    private var premiumStatus: StatusView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        self.layer?.masksToBounds = false
    }
    
    
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
        
    func updateState(_ state: PeerListState, context: AccountContext, maxWidth: CGFloat, animated: Bool) {
        
        let source: Source
        if state.isContacts {
            source = .contacts
        } else if state.mode.groupId == .archive {
            source = .archivedChats
        } else if state.mode.isForum {
            source = .forum
        } else {
            source = .chats
        }
        let text: String
        if state.mode.isForum {
            text = state.forumPeer?.peer.title ?? source.text
        } else {
            text = source.text
        }
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        layout.measure(width: maxWidth)
        textView.update(layout)
        
        let hasStatus = state.peer?.peer.isPremium ?? false && state.mode == .plain

        if hasStatus, let peer = state.peer?.peer, source != .contacts {
            
            let current: StatusView
            if let view = self.premiumStatus {
                current = view
            } else {
                current = StatusView(frame: CGRect(origin: NSMakePoint(textView.frame.width + 4, (frame.height - 20) / 2), size: NSMakeSize(20, 20)))
                self.premiumStatus = current
                self.addSubview(current)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                current.set(handler: { [weak self] control in
                    self?.openStatus?(control)
                }, for: .Click)
                current.scaleOnClick = true
            }
            current.update(peer, context: context, animated: animated)
            
        } else if let view = self.premiumStatus {
            performSubviewRemoval(view, animated: animated)
            self.premiumStatus = nil
        }
    }
    
    var hasPremium: Bool {
        return premiumStatus != nil
    }
    
    var size: NSSize {
        var width: CGFloat = textView.frame.width
        if let premiumStatus = self.premiumStatus {
            width += premiumStatus.frame.width + 4
        }
        return NSMakeSize(width, 20)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: textView.centerFrameY(x: 0))
        if let premiumStatus = self.premiumStatus {
            transition.updateFrame(view: premiumStatus, frame: premiumStatus.centerFrameY(x: textView.frame.width + 4, addition: 1))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol PeersStatusView {
    func updateState(_ state: PeerListState, context: AccountContext, animated: Bool)
}

extension PeersStatusView {
    static func make(state: PeerListState, width: CGFloat) -> NSView & PeersStatusView {
        return PlainStatusView.init(frame: NSMakeRect(0, 0, width, 50))
    }
}

private final class PlainStatusView : View, PeersStatusView {
    private var compose:ImageButton?
    private var proxy: ProxyView?

    fileprivate let titleView = TitleView(frame: .zero)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        titleView.scaleOnClick = true
        backgroundColor = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateState(_ state: PeerListState, context: AccountContext, animated: Bool) {
        
        let componentSize = NSMakeSize(40, 30)
        
        var controlPoint = NSMakePoint(frame.width - 10, floorToScreenPixels(backingScaleFactor, (frame.height - componentSize.height)/2.0))
        
        let hasControls = state.splitState != .minimisize && state.mode.isPlain && state.mode == .plain
        
        let hasProxy = (!state.proxySettings.servers.isEmpty || state.proxySettings.effectiveActiveServer != nil) && hasControls && !state.isContacts
        
        
        if hasProxy {
            controlPoint.x -= componentSize.width
            
            let current: ProxyView
            if let view = self.proxy {
                current = view
            } else {
                current = ProxyView(frame: CGRect(origin: controlPoint, size: componentSize))
                self.proxy = current
                self.addSubview(current, positioned: .below, relativeTo: nil)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                current.set(handler: { [weak self] control in
                  //  self?.openProxy?(control)
                }, for: .Click)
            }
            current.update(state.proxySettings, connection: state.connectionStatus, animated: animated)
            
        } else if let view = self.proxy {
            performSubviewRemoval(view, animated: animated)
            self.proxy = nil
        }
        
        /*
         
         var controlPoint = NSMakePoint(containerSize.width - 14, floorToScreenPixels(backingScaleFactor, (statusHeight - componentSize.height)/2.0))

         controlPoint.x -= componentSize.width
         
         transition.updateFrame(view: compose, frame: CGRect(origin: controlPoint, size: componentSize))
         
         if state.splitState == .minimisize {
             transition.updateAlpha(view: compose, alpha: 1)
         } else {
             transition.updateAlpha(view: compose, alpha: progress)
         }

         if let view = proxy {
             controlPoint.x -= componentSize.width
             transition.updateFrame(view: view, frame: CGRect(origin: controlPoint, size: componentSize))
             transition.updateAlpha(view: view, alpha: progress)
         }
         
         var maxTitleWidth: CGFloat = max(size.width, 300) - 60
         if !compose.isHidden {
             maxTitleWidth -= compose.frame.width
         }
         if let proxy = proxy {
             maxTitleWidth -= proxy.frame.width
         }
         
         self.titleView.updateState(state, arguments: arguments, maxWidth: maxTitleWidth, animated: transition.isAnimated)
         
         if isContacts {
             compose.set(background: .clear, for: .Highlight)
             compose.set(image: theme.icons.contactsNewContact, for: .Normal)
             compose.set(image: theme.icons.contactsNewContact, for: .Hover)
             compose.set(image: theme.icons.contactsNewContact, for: .Highlight)
         } else {
             compose.set(background: theme.colors.accent, for: .Highlight)
             compose.set(image: theme.icons.composeNewChat, for: .Normal)
             compose.set(image: theme.icons.composeNewChat, for: .Hover)
             compose.set(image: theme.icons.composeNewChatActive, for: .Highlight)
         }
         
         compose.set(background: .clear, for: .Normal)
         compose.set(background: .clear, for: .Hover)

       
              
         compose.layer?.cornerRadius = .cornerRadius
         compose.sizeToFit()
         */
        
    }
}
