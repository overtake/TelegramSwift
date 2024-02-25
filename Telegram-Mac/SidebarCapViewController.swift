//
//  SidebarCapViewController.swift
//  Telegram
//
//  Created by keepcoder on 28/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit

class SidebarCapView : View {
    private let text:NSTextField = NSTextField()
    fileprivate let close:TextButton = TextButton()
    fileprivate var restrictedByPeer: Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        text.font = .normal(.header)
        text.drawsBackground = false
       // text.backgroundColor = .clear
        text.isSelectable = false
        text.isEditable = false
        text.isBordered = false
        text.focusRingType = .none
        text.isBezeled = false
        
        
        addSubview(text)
        
        close.set(font: .medium(.title), for: .Normal)
       
        
        addSubview(close)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        text.textColor = theme.colors.grayText
        text.stringValue = restrictedByPeer ? strings().sidebarPeerRestricted : strings().sidebarAvalability
        text.setFrameSize(text.sizeThatFits(NSMakeSize(300, 100)))
        self.background = theme.colors.background.withAlphaComponent(0.97)
        close.set(color: theme.colors.accent, for: .Normal)
        close.set(text: strings().sidebarHide, for: .Normal)
        _ = close.sizeToFit()
        needsLayout = true
    }
    
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        text.center()
        close.centerX(y: text.frame.maxY + 10)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SidebarCapViewController: GenericViewController<SidebarCapView> {
    private let context:AccountContext
    private let globalPeerDisposable = MetaDisposable()
    private var inChatAbility: Bool = true {
        didSet {
            navigationWillChangeController()
        }
    }
    init(_ context:AccountContext) {
        self.context = context
        super.init()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController = context.bindings.rootNavigation()
        (navigationController as? MajorNavigationController)?.add(listener: WeakReference(value: self))
        genericView.close.set(handler: { [weak self] _ in
            self?.context.bindings.rootNavigation().closeSidebar()
            FastSettings.toggleSidebarShown(false)
            self?.context.bindings.entertainment().closedBySide()
        }, for: .Click)
        
        let postbox = self.context.account.postbox
        
        globalPeerDisposable.set((context.globalPeerHandler.get() |> mapToSignal { value -> Signal<Bool, NoError> in
            if let value = value {
                switch value {
                case .peer:
                    return getPeerView(peerId: value.peerId, postbox: postbox) |> map {
                        return $0?.canSendMessage(false) ?? false
                    }
                case let .thread(message):
                    return combineLatest(getPeerView(peerId: value.peerId, postbox: postbox), postbox.transaction {
                        $0.getMessageHistoryThreadInfo(peerId: value.peerId, threadId: message.threadId)
                    }) |> map { peer, data in
                        let data = data?.data.get(MessageHistoryThreadData.self)
                        return peer?.canSendMessage(true, threadData: data) ?? false
                    }
                }
               
            } else {
                return .single(false)
            }
        } |> deliverOnMainQueue).start(next: { [weak self] accept in
            self?.readyOnce()
            self?.inChatAbility = accept
        }))
    }
    
    deinit {
        
    }
    
    override func viewDidChangedNavigationLayout(_ state: SplitViewState) {
        super.viewDidChangedNavigationLayout(state)
        navigationWillChangeController()
    }
    

    override func navigationWillChangeController() {
        
        self.genericView.restrictedByPeer = !inChatAbility
        self.genericView.updateLocalizationAndTheme(theme: theme)
        
        self.view.setFrameSize(context.bindings.entertainment().frame.size)
        
        if let controller = navigationController as? MajorNavigationController, controller.genericView.state != .dual {
            view.removeFromSuperview()
        } else if context.bindings.rootNavigation().controller is ChatController, inChatAbility {
            view.removeFromSuperview()
        } else {
            context.bindings.entertainment().addSubview(view)
        }
        
       // NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: mainWindow)

    }
    
}
