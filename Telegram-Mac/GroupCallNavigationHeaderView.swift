//
//  GroupCallNavigationHeaderView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore





class GroupCallNavigationHeaderView: CallHeaderBasicView {




    private let audioLevelDisposable = MetaDisposable()

    var context: GroupCallContext? {
        get {
            return self.header?.contextObject as? GroupCallContext
        }
    }

    override func toggleMute() {
        self.context?.call.toggleIsMuted()
    }

    override func showInfoWindow() {
        self.context?.present()
    }

    override func hangUp() {
        self.context?.leave()
    }

    override var blueColor: NSColor {
        return NSColor(rgb: 0x0078ff)
    }
    override var grayColor: NSColor {
        return NSColor(rgb: 0x33c659)
    }

    override func hide(_ animated: Bool) {
        super.hide(true)
        audioLevelDisposable.set(nil)
    }

    override func update(with contextObject: Any) {
        super.update(with: contextObject)


        let context = contextObject as! GroupCallContext
        let peerId = context.call.peerId


        let data = context.call.summaryState
        |> filter { $0 != nil }
        |> map { $0! }
        |> map { summary -> GroupCallPanelData in
            return GroupCallPanelData(
                peerId: peerId,
                info: summary.info,
                topParticipants: summary.topParticipants,
                participantCount: summary.participantCount,
                activeSpeakers: summary.activeSpeakers,
                groupCall: nil
            )
        }

        let account = context.call.account

        let signal = Signal<Peer?, NoError>.single(context.call.peer) |> then(context.call.account.postbox.loadedPeerWithId(context.call.peerId) |> map(Optional.init) |> deliverOnMainQueue)

        let accountPeer: Signal<Peer?, NoError> = context.call.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }
        
        

        disposable.set(combineLatest(queue: .mainQueue(), context.call.state, context.call.isMuted, data, signal, accountPeer, appearanceSignal, context.call.members, context.call.summaryState).start(next: { [weak self] state, isMuted, data, peer, accountPeer, _, members, summary in
            
            let title: String?
            if let custom = state.title, !custom.isEmpty {
                title = custom
            } else {
                title = peer?.displayTitle
            }
            
            if let title = title {
                self?.setInfo(title)
            }
            self?.updateState(state, isMuted: isMuted, data: data, members: members, accountPeer: accountPeer, animated: false)
            self?.needsLayout = true
            self?.ready.set(.single(true))
        }))

        hideDisposable.set((context.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.hide(true)
            }
        }))
        let isVisible = context.window.takeOcclusionState |> map { $0.contains(.visible) }
        self.audioLevelDisposable.set((combineLatest(isVisible, context.call.myAudioLevel, .single([]) |> then(context.call.audioLevels), context.call.isMuted, context.call.state)
        |> deliverOnMainQueue).start(next: { [weak self] isVisible, myAudioLevel, audioLevels, isMuted, state in
            guard let strongSelf = self else {
                return
            }
            var effectiveLevel: Float = 0.0
            if isVisible {
                switch state.networkState {
                case .connected:
                    if !isMuted {
                        effectiveLevel = myAudioLevel
                    } else {
                        effectiveLevel = audioLevels.reduce(0, { current, value in
                            return current + value.2
                        })
                        if !audioLevels.isEmpty {
                            effectiveLevel = effectiveLevel / Float(audioLevels.count)
                        }
                    }
                case .connecting:
                    effectiveLevel = 0
                }
            }
            strongSelf.backgroundView.audioLevel = effectiveLevel
        }))
    }

    deinit {
        audioLevelDisposable.dispose()
    }


    private func updateState(_ state: PresentationGroupCallState, isMuted: Bool, data: GroupCallPanelData, members: PresentationGroupCallMembers?, accountPeer: Peer?, animated: Bool) {
        let isConnected: Bool
        switch state.networkState {
        case .connecting:
            self.status = .text(L10n.voiceChatStatusConnecting, nil)
            isConnected = false
        case .connected:
            
            if let first = data.topParticipants.first(where: { members?.speakingParticipants.contains($0.peer.id) ?? false }) {
                self.status = .text(first.peer.compactDisplayTitle.prefixWithDots(12), nil)
            } else {
                self.status = .text(L10n.voiceChatStatusMembersCountable(data.participantCount), nil)
            }
            isConnected = true
        }

        self.backgroundView.speaking = (isConnected && !isMuted, isConnected, state.muteState?.canUnmute ?? true)


        setMicroIcon(isMuted ? theme.icons.callInlineMuted : theme.icons.callInlineUnmuted)
        needsLayout = true

    }

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func getEndText() -> String {
        return L10n.voiceChatTitleEnd
    }
    
    override init(_ header: NavigationHeader) {
        super.init(header)
    }

}

