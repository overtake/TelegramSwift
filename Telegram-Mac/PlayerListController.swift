//
//  PlayerListController.swift
//  Telegram
//
//  Created by keepcoder on 26/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class PlayerListArguments {
    let chatInteraction: ChatInteraction
    init(chatInteraction: ChatInteraction) {
        self.chatInteraction = chatInteraction
    }
}

private enum PlayerListEntry: TableItemListNodeEntry {
    static func < (lhs: PlayerListEntry, rhs: PlayerListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var index: MessageIndex {
        switch self {
        case let .message(_, message):
            return MessageIndex(message)
        }
    }
    
    case message(sectionId: Int32, Message)
    
    var stableId: ChatHistoryEntryId {
        switch self {
        case let .message(_, message):
            return .message(message)
        }
    }
    
    func item(_ arguments: PlayerListArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .message(_, message):
            return PeerMediaMusicRowItem(initialSize, arguments.chatInteraction, .messageEntry(message, .defaultSettings, .singleItem),  isCompactPlayer: true)
        }
    }
    
    static func ==(lhs: PlayerListEntry, rhs: PlayerListEntry) -> Bool {
        switch lhs {
        case let .message(_, lhsMessage):
            if case let .message(_, rhsMessage) = rhs {
                return isEqualMessages(lhsMessage, rhsMessage)
            } else {
                return false
            }
        }
    }
}


private func playerAudioEntries(_ update: PeerMediaUpdate, timeDifference: TimeInterval) -> [PlayerListEntry] {
    var entries: [PlayerListEntry] = []
    var sectionId: Int32 = 0
    
    for message in update.messages {
        entries.append(.message(sectionId: sectionId, message))
    }
    
    return entries
}
fileprivate func preparedAudioListTransition(from fromView:[PlayerListEntry], to toView:[PlayerListEntry], initialSize:NSSize, arguments: PlayerListArguments, animated:Bool, scroll:TableScrollState) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntries(fromView, right: toView, { (entry) -> TableRowItem in
        
        return entry.item(arguments, initialSize: initialSize)
        
    })
    
    for item in inserted {
        _ = item.1.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    for item in updated {
        _ = item.1.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated:updated, animated:animated, state:scroll)
}


class PlayerListController: TableViewController {
    private let audioPlayer: InlineAudioPlayerView
    private let chatInteraction: ChatInteraction
    private let disposable = MetaDisposable()
    private let messageIndex: MessageIndex
    init(audioPlayer: InlineAudioPlayerView, context: AccountContext, messageIndex: MessageIndex) {
        self.chatInteraction = ChatInteraction(chatLocation: .peer(messageIndex.id.peerId), context: context)
        self.messageIndex = messageIndex
        self.audioPlayer = audioPlayer
        super.init(context)
        
        
        chatInteraction.inlineAudioPlayer = { [weak self] controller in
            self?.audioPlayer.update(with: controller, context: context, tableView: self?.genericView)
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            return theme.colors.background
        }
        
        let location = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
        
        let historyViewUpdate = location.get() |> deliverOnMainQueue
            |> mapToSignal { [weak self] location -> Signal<(PeerMediaUpdate, TableScrollState?), NoError> in
                
                guard let `self` = self else {return .complete()}
                
                return chatHistoryViewForLocation(location, account: self.chatInteraction.context.account, chatLocation: self.chatInteraction.chatLocation, fixedCombinedReadStates: nil, tagMask: [.music], additionalData: []) |> mapToQueue { view -> Signal<(PeerMediaUpdate, TableScrollState?), NoError> in
                    switch view {
                    case .Loading:
                        return .single((PeerMediaUpdate(), nil))
                    case let .HistoryView(view: view, _, scroll, _):
                        var messages:[Message] = []
                        for entry in view.entries {
                             messages.append(entry.message)
                        }
                        var laterId = view.laterId
                        var earlierId = view.earlierId

                        var state: TableScrollState?
                        if let scroll = scroll {
                            switch scroll {
                            case let .index(_, position, _, _):
                                state = position
                            default:
                                break
                            }
                        }
                        return .single((PeerMediaUpdate(messages: messages, updateType: .history, laterId: laterId, earlierId: earlierId), state))
                    }
                }
        }
        
        let animated: Atomic<Bool> = Atomic(value: false)
        let context = self.chatInteraction.context
        let previous:Atomic<[PlayerListEntry]> = Atomic(value: [])
        let updateView = Atomic<PeerMediaUpdate?>(value: nil)
        
        
        let arguments = PlayerListArguments(chatInteraction: chatInteraction)
        
        let historyViewTransition = historyViewUpdate |> deliverOnPrepareQueue |> map { update, scroll -> TableUpdateTransition in
            let animated = animated.swap(true)
            let scroll:TableScrollState = scroll ?? (animated ? .none(nil) : .saveVisible(.upper))
            
            let entries = playerAudioEntries(update, timeDifference: context.timeDifference)
            _ = updateView.swap(update)
            
            return preparedAudioListTransition(from: previous.swap(entries), to: entries, initialSize: NSMakeSize(300, 0), arguments: arguments, animated: animated, scroll: scroll)
            
        } |> deliverOnMainQueue
        
        
        disposable.set(historyViewTransition.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            self.genericView.merge(with: transition)
            if !self.didSetReady, !self.genericView.isEmpty {
                self.view.setFrameSize(300, min(self.genericView.listHeight, 325))
                self.genericView.scroll(to: .top(id: PeerMediaSharedEntryStableId.messageId(self.messageIndex.id), innerId: nil, animated: false, focus: .init(focus: false), inset: -25))
                self.readyOnce()
            }
        }))
        
        location.set(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 50, side: .upper))

        
        genericView.setScrollHandler { scroll in
            let view = updateView.modify({$0})
            if let view = view {
                var messageIndex:MessageIndex?
                switch scroll.direction {
                case .bottom:
                    messageIndex = view.earlierId
                case .top:
                    messageIndex = view.laterId
                case .none:
                    break
                }
                
                if let messageIndex = messageIndex {
                    let _ = animated.swap(false)
                    location.set(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 50, side: scroll.direction == .bottom ? .lower : .upper))
                }
            }
        }
    }
    
}
