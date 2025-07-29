//
//  WidgetRecentPeersController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

final class WidgetRecentPeersContainer: View {
    
    private final class PeerView : Control {
        private let avatar: AvatarControl = AvatarControl(font: .avatar(20))
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            avatar.setFrameSize(NSMakeSize(56, 56))
            addSubview(avatar)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            avatar.userInteractionEnabled = false
            scaleOnClick = true
        }
        
        override func layout() {
            super.layout()
            avatar.centerX(y: 0)
            textView.resize(frame.width - 8)
            textView.centerX(y: avatar.frame.maxY + 6)
        }
        
        func update(_ peer: Peer, context: AccountContext, animated: Bool) {
            self.avatar.setPeer(account: context.account, peer: peer, message: nil, size: NSMakeSize(56, 56))
            
            let layout = TextViewLayout(.initialize(string: peer.compactDisplayTitle, color: theme.colors.text, font: .medium(.small)), maximumNumberOfLines: 1, alignment: .center)
            layout.measure(width: frame.width - 8)
            textView.update(layout)
            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func update(_ state: WidgetRecentPeersController.State, context: AccountContext, animated: Bool, open: @escaping(PeerId)->Void) {
        let peers:[PeerEquatable]
        switch state.section {
        case .favorite:
            peers = state.favorite
        case .recent:
            peers = state.recent
        case .both:
            var cur:[PeerEquatable] = Array(state.recent.prefix(4))
            for peer in state.favorite {
                let contains = cur.contains(where: { $0.peer.id == peer.peer.id })
                if !contains {
                    cur.append(peer)
                }
                if cur.count == 8 {
                    break
                }
            }
            peers = cur
        }
        
        while subviews.count > peers.count {
            subviews.removeLast()
        }
        
        while subviews.count < peers.count {
            subviews.append(PeerView(frame: NSMakeRect(0, 0, frame.width / 4, frame.height / 2)))
        }
        
        for (i, peer) in peers.enumerated() {
            let view = (subviews[i] as! PeerView)
            view.update(peer.peer, context: context, animated: animated)
            view.removeAllHandlers()
            view.set(handler: { _ in
                open(peer.peer.id)
            }, for: .Click)
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        var point: CGPoint = CGPoint(x: 0, y: 0)

        let size = NSMakeSize(frame.width / 4, frame.height / 2)
        for (i, view) in subviews.enumerated() {
            view.frame = CGRect(origin: point, size: size)
            if i == 3 {
                point.y += view.frame.height
                point.x = 0
            } else {
                point.x += view.frame.width
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WidgetRecentPeersController : TelegramGenericViewController<WidgetView<WidgetRecentPeersContainer>> {

    struct State : Equatable {
        
        enum Section : Equatable {
            case favorite
            case recent
            case both
        }

        var favorite: [PeerEquatable] = []
        var recent:[PeerEquatable] = []
        
        var section: Section
    }
    
    private let disposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    override init(_ context: AccountContext) {
        super.init(context)
        self.bar = .init(height: 0)
    }
    
    
    
    deinit {
        actionsDisposable.dispose()
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context

        self.genericView.dataView = WidgetRecentPeersContainer(frame: .zero)
        
        
        let initialState = State(section: .favorite)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        var first = true
        
        let recent: Signal<[PeerEquatable], NoError> = context.recentlyUserPeerIds |> mapToSignal { ids in
            return context.account.postbox.transaction { transaction in
                let peers = ids.compactMap { transaction.getPeer($0) }
                return Array(peers.map { PeerEquatable($0) }.prefix(8))
            }
        }
        let favorite: Signal<[PeerEquatable], NoError> = context.engine.peers.recentPeers() |> map { recent in
            switch recent {
            case .disabled:
                return []
            case let .peers(peers):
                return Array(peers.map { PeerEquatable($0) }.prefix(8))
            }
        }
        
        actionsDisposable.add(combineLatest(recent, favorite).start(next: { recent, favorite in
            updateState { current in
                var current = current
                current.favorite = favorite
                current.recent = recent
                if current.section == .favorite, favorite.isEmpty {
                    current.section = .recent
                }
                if current.section == .recent, recent.isEmpty {
                    current.section = .favorite
                }
                return current
            }
        }))
        
        disposable.set(combineLatest(queue: .mainQueue(), statePromise.get(), appearanceSignal).start(next: { [weak self] state, _ in
            var buttons: [WidgetData.Button] = []
            

            if !state.favorite.isEmpty {
                buttons.append(.init(text: { strings().widgetRecentPopular }, selected: {
                    return state.section == .favorite
                }, image: {
                    return state.section == .favorite ? theme.icons.widget_peers_favorite_active: theme.icons.widget_peers_favorite
                }, click: {
                    updateState { current in
                        var current = current
                        current.section = .favorite
                        return current
                    }
                }))
            }
           
            if !state.recent.isEmpty {
                buttons.append(.init(text: { strings().widgetRecentRecent }, selected: {
                    return state.section == .recent
                }, image: {
                    return state.section == .recent ? theme.icons.widget_peers_recent_active: theme.icons.widget_peers_recent
                }, click: {
                    updateState { current in
                        var current = current
                        current.section = .recent
                        return current
                    }
                }))
            }
          
            if !state.recent.isEmpty && !state.favorite.isEmpty {
                buttons.append(.init(text: { strings().widgetRecentMixed }, selected: {
                    return state.section == .both
                }, image: {
                    return state.section == .both ? theme.icons.widget_peers_both_active: theme.icons.widget_peers_both
                }, click: {
                    updateState { current in
                        var current = current
                        current.section = .both
                        return current
                    }
                }))
            }
            
            
            let data: WidgetData = .init(title: { strings().widgetRecentTitle }, desc: { strings().widgetRecentDesc }, descClick: {
                showModal(with: QuickSwitcherModalController(context), for: context.window)
            }, buttons: buttons, contentHeight: 180)
            
            self?.genericView.update(data)
            self?.genericView.dataView?.update(state, context: context, animated: !first, open: { peerId in
                navigateToChat(navigation: context.bindings.rootNavigation(), context: context, chatLocation: .peer(peerId))
            })
            first = false
        }))
    }
}
