//
//  BusinessChatbotController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class BusinessBotRowItem : GeneralRowItem {
    let bot: EnginePeer
    let context: AccountContext
    let titleLayout: TextViewLayout
    let statusLayout: TextViewLayout
    let selected: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, bot: EnginePeer, selected: Bool, viewType: GeneralViewType, action: @escaping()->Void) {
        self.bot = bot
        self.context = context
        self.selected = selected
        titleLayout = .init(.initialize(string: bot._asPeer().displayTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        statusLayout = .init(.initialize(string: "@\(bot.addressName ?? "")", color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        titleLayout.measure(width: blockWidth - 30 - 100)
        statusLayout.measure(width: blockWidth - 30 - 100)
        return true
    }
    
    override var height: CGFloat {
        return 44
    }
    
    override func viewClass() -> AnyClass {
        return BusinessBotRowView.self
    }
}

private final class BusinessBotRowView: GeneralContainableRowView {
    private let avatar = AvatarControl(font: .avatar(10))
    private let titleView = TextView()
    private let statusView = TextView()
    private var add: TextButton?
    private var remove: ImageButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(30, 30))
        addSubview(avatar)
        addSubview(titleView)
        addSubview(statusView)
        
        avatar.userInteractionEnabled = false
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BusinessBotRowItem else {
            return
        }
        
        avatar.setPeer(account: item.context.account, peer: item.bot._asPeer())
        titleView.update(item.titleLayout)
        statusView.update(item.statusLayout)
        
        if item.selected {
            if let view = self.add {
                performSubviewRemoval(view, animated: animated)
                self.add = nil
            }
            let current: ImageButton
            if let view = self.remove {
                current = view
            } else {
                current = ImageButton()
                current.scaleOnClick = true
                addSubview(current)
                self.remove = current
                
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? GeneralRowItem {
                        item.action()
                    }
                }, for: .Click)
            }
            current.set(image: theme.icons.stickersRemove, for: .Normal)
            current.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        } else {
            if let view = self.remove {
                performSubviewRemoval(view, animated: animated)
                self.remove = nil
            }
            let current: TextButton
            if let view = self.add {
                current = view
            } else {
                current = TextButton()
                current.scaleOnClick = true
                addSubview(current)
                self.add = current
                
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? GeneralRowItem {
                        item.action()
                    }
                }, for: .Click)
            }
            current.set(font: .medium(.text), for: .Normal)
            current.set(color: theme.colors.underSelectedColor, for: .Normal)
            current.set(background: theme.colors.accent, for: .Normal)
            current.set(text: strings().businessChatbotsAdd, for: .Normal)
            current.sizeToFit(NSMakeSize(10, 6))
            current.layer?.cornerRadius = current.frame.height / 2
        }
        
        needsLayout = true
    }
    

    override func layout() {
        super.layout()
        guard let item = item as? BusinessBotRowItem else {
            return
        }
        avatar.centerY(x: item.viewType.innerInset.left)
        titleView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, 7))
        statusView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, containerView.frame.height - statusView.frame.height - 5))
        
        if let add {
            add.centerY(x: containerView.frame.width - add.frame.width - item.viewType.innerInset.left)
        }
        if let remove {
            remove.centerY(x: containerView.frame.width - remove.frame.width - item.viewType.innerInset.left)
        }
    }
}

private final class Arguments {
    let context: AccountContext
    let toggleAccess:(State.Access)->Void
    let selectChats:(SelectChatType)->Void
    let toggleReplyAccess:()->Void
    let removeSelected:(SelectChatType, PeerId)->Void
    let setBot:(EnginePeer?)->Void
    init(context: AccountContext, toggleAccess:@escaping(State.Access)->Void, selectChats:@escaping(SelectChatType)->Void, toggleReplyAccess:@escaping()->Void, removeSelected:@escaping(SelectChatType, PeerId)->Void, setBot:@escaping(EnginePeer?)->Void) {
        self.context = context
        self.toggleAccess = toggleAccess
        self.selectChats = selectChats
        self.toggleReplyAccess = toggleReplyAccess
        self.removeSelected = removeSelected
        self.setBot = setBot
    }
}

private struct State : Equatable {
    enum Access : Equatable {
        case all
        case selected
    }
    enum BotsResult : Equatable {
        case found([EnginePeer])
        case loading
    }
    var username: String?
    var access: Access = .all
    
    var botsResult: BotsResult? = nil
    var bot: EnginePeer? = nil
    
    var replyAccess: Bool = true

    
    var includeIds: [PeerId] = []
    var excludeIds: [PeerId] = []
    var disableIds: [PeerId] = []

    var includePeers: [EnginePeer] = []
    var excludePeers: [EnginePeer] = []
    
    var contacts: Set<PeerId> = Set()
    
    
    var initialBot: TelegramAccountConnectedBot?
    
    var mapped: TelegramAccountConnectedBot? {
        if let bot = bot {
            var categories: TelegramBusinessRecipients.Categories = []
            let peerIds: Set<PeerId>
            let catpeers: Set<PeerId>
            switch self.access {
            case .all:
                peerIds = Set(self.excludeIds.filter {
                    $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
                })
                catpeers = Set(self.excludeIds.filter {
                    $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
                })
            case .selected:
                peerIds = Set(self.includeIds.filter {
                    $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
                })
                catpeers = Set(self.includeIds.filter {
                    $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
                })
            }
            for peerId in catpeers {
                if peerId.id == PeerId.Id._internalFromInt64Value(Int64(ChatListFilterPeerCategories.contacts.rawValue)) {
                    categories.insert(.contacts)
                }
                if peerId.id == PeerId.Id._internalFromInt64Value(Int64(ChatListFilterPeerCategories.nonContacts.rawValue)) {
                    categories.insert(.nonContacts)
                }
                if peerId.id == PeerId.Id._internalFromInt64Value(Int64(ChatListFilterPeerCategories.newChats.rawValue)) {
                    categories.insert(.newChats)
                }
                if peerId.id == PeerId.Id._internalFromInt64Value(Int64(ChatListFilterPeerCategories.existingChats.rawValue)) {
                    categories.insert(.existingChats)
                }
            }
            return .init(id: bot.id, recipients: .init(categories: categories, additionalPeers: peerIds, excludePeers: Set(excludeIds.filter { $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace }), exclude: self.access == .all), canReply: self.replyAccess)
        } else {
            return nil
        }
    }
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_input = InputDataIdentifier("_id_username")
private let _id_attached_bot = InputDataIdentifier("_id_attached_bot")

private let _id_access_1x1 = InputDataIdentifier("_id_access_1x1")
private let _id_access_selected = InputDataIdentifier("_id_access_selected")

private let _id_include_chats = InputDataIdentifier("_id_include_chats")
private let _id_exclude_chats = InputDataIdentifier("_id_exclude_chats")

private let _id_exclude_users = InputDataIdentifier("_id_exclude_users")


private let _id_reply_to_message = InputDataIdentifier("_id_reply_to_message")

private let _id_remove = InputDataIdentifier("_id_remove")
private let _id_loading = InputDataIdentifier("_id_loading")

private func _id_peer(_ id: PeerId, _ include: Bool) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())_\(include)")
}
private func _id_bot(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_bot_\(id.toInt64())")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let hText = strings().businessChatbotsHeader
    
    let attr = parseMarkdownIntoAttributedString(hText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
        return (NSAttributedString.Key.link.rawValue, inApp(for: contents.nsstring, context: arguments.context))
    }))
    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.business_chatbot, text: attr)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let bot = state.bot {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .firstItem, text: "https://t.me/\(bot.addressName ?? "")", font: .normal(.text), color: theme.colors.text)
        }))
    } else {
        entries.append(.input(sectionId: sectionId, index: 0, value: .string(state.username), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: state.botsResult == nil ? .singleItem : .firstItem, defaultText: ""), placeholder: nil, inputPlaceholder: strings().businessChatbotsPlaceholder, filter: { $0 }, limit: 60))
    }
    
    if let result = state.botsResult {
        switch result {
        case .loading:
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
                return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
            }))
        case let .found(peers):
            struct Tuple : Equatable {
                let peer: EnginePeer
                let viewType: GeneralViewType
                let selected: Bool
            }
            var tuples: [Tuple] = []
            
            if peers.isEmpty {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_bot(.init(0)), equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .lastItem, text: strings().businessChatbotsNotFound, font: .normal(.text), color: theme.colors.grayText, centerViewAlignment: true)
                }))
            } else {
                for (i, peer) in peers.enumerated() {
                    var viewType: GeneralViewType = bestGeneralViewType(peers, for: i)
                    if i == 0 {
                        if i < peers.count - 1 {
                            viewType = .innerItem
                        } else {
                            viewType = .lastItem
                        }
                    }
                    tuples.append(.init(peer: peer, viewType: viewType, selected: state.bot?.id == peer.id))
                }
                for tuple in tuples {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_bot(tuple.peer.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                        return BusinessBotRowItem(initialSize, stableId: stableId, context: arguments.context, bot: tuple.peer, selected: tuple.selected, viewType: tuple.viewType, action: {
                            if tuple.selected {
                                arguments.setBot(nil)
                            } else {
                                arguments.setBot(tuple.peer)
                            }
                        })
                    }))
                }
            }
        }
    }

    if let _ = state.bot {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessChatbotsChatTypes), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_access_1x1, data: .init(name: strings().businessMessageRecepientsAll, color: theme.colors.text, type: .selectable(state.access == .all), viewType: .firstItem, action: {
            arguments.toggleAccess(.all)
        })))
        
        entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_access_selected, data: .init(name: strings().businessMessageRecepientsSelected, color: theme.colors.text, type: .selectable(state.access == .selected), viewType: .lastItem, action: {
            arguments.toggleAccess(.selected)
        })))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        struct Tuple : Equatable {
            let peer: PeerEquatable
            let type: State.Access
            let viewType: GeneralViewType
            let status: String?
            let include: Bool
        }
        
        let makePeers:(Bool)->[Peer] = { include in
            let ids = !include ? state.excludeIds : state.includeIds
            let peers = !include ? state.excludePeers : state.includePeers
            
            var selectedPeers: [Peer] = []
            let categories: [PeerId] = ids.filter {
                $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
            }
            for category in categories {
                let cat = ChatListFilterPeerCategories(rawValue: Int32(category.id._internalGetInt64Value()))
                selectedPeers.append(TelegramFilterCategory(category: cat))
            }
            selectedPeers.append(contentsOf: peers.map { $0._asPeer() })

            
            return selectedPeers
        }
        
        let insertPeers: (Bool)->Void = { include in
            
            let selectedPeers = makePeers(include)
            
            var tuples: [Tuple] = []

            for (i, peer) in selectedPeers.enumerated() {
                var viewType: GeneralViewType = bestGeneralViewType(selectedPeers, for: i)
                if i == 0 {
                    if i < selectedPeers.count - 1 {
                        viewType = .innerItem
                    } else {
                        viewType = .lastItem
                    }
                }
                let status: String?
                if peer is TelegramFilterCategory {
                    status = nil
                } else {
                    status = state.contacts.contains(peer.id) ? strings().businessMessageContact : strings().businessMessageNonContact
                }
                tuples.append(.init(peer: .init(peer), type: state.access, viewType: viewType, status: status, include: include))
            }

            for tuple in tuples {
                entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_peer(tuple.peer.id, tuple.include), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), viewType: tuple.viewType, action: {
                        //arguments.openInfo(peer.id)
                    }, contextMenuItems: {
                        return .single([ContextMenuItem(strings().contextRemove, handler: {
                            if state.access == .all {
                                arguments.removeSelected(.exclude, tuple.peer.id)
                            } else {
                                arguments.removeSelected(.include, tuple.peer.id)
                            }
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
                    }, highlightVerified: true, menuOnAction: true)
                }))
            }
        }

       
        
        switch state.access {
        case .all:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsExcludeTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_exclude_chats, data: .init(name: strings().businessMessageRecepientsExclude, color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.excludeIds.isEmpty ? .singleItem : .firstItem, action: {
                arguments.selectChats(.exclude)
            })))
            
            insertPeers(false)
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsExcludeInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1
            
        case .selected:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsIncludeTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_include_chats, data: .init(name: strings().businessMessageRecepientsInclude, color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.includeIds.isEmpty ? .singleItem : .firstItem, action: {
                arguments.selectChats(.include)
            })))
            
            insertPeers(true)
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsIncludeInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsExcludeTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_exclude_chats, data: .init(name: strings().businessMessageRecepientsExclude, color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.excludeIds.isEmpty ? .singleItem : .firstItem, action: {
                arguments.selectChats(.exclude)
            })))
            
            insertPeers(false)
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsExcludeInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1

        }

        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessChatbotsPermissionHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_reply_to_message, data: .init(name: strings().businessChatbotsPermission, color: theme.colors.text, type: .switchable(state.replyAccess), viewType: .singleItem, action: arguments.toggleReplyAccess)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessChatbotsPermissionInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

    }
    

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func BusinessChatbotController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    let includePeers: Signal<[EnginePeer], NoError> = statePromise.get() |> map { $0.includeIds } |> distinctUntilChanged |> mapToSignal { peerIds in
        return context.account.postbox.transaction { transaction -> [EnginePeer] in
            return peerIds.compactMap {
                transaction.getPeer($0)
            }.map {
                .init($0)
            }
        }
    } |> deliverOnMainQueue
    
    actionsDisposable.add(includePeers.start(next: { peers in
        updateState { current in
            var current = current
            current.includePeers = peers
            return current
        }
    }))
    
    let excludedPeers: Signal<[EnginePeer], NoError> = statePromise.get() |> map { $0.excludeIds } |> distinctUntilChanged |> mapToSignal { peerIds in
        return context.account.postbox.transaction { transaction -> [EnginePeer] in
            return peerIds.compactMap {
                transaction.getPeer($0)
            }.map {
                .init($0)
            }
        }
    } |> deliverOnMainQueue
    
    actionsDisposable.add(excludedPeers.start(next: { peers in
        updateState { current in
            var current = current
            current.excludePeers = peers
            return current
        }
    }))
    
    
    let contacts = context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
    actionsDisposable.add(contacts.start(next: { contacts in
        updateState { current in
            var current = current
            current.contacts = Set(contacts.peers.map { $0.id })
            return current
        }
    }))
    
    let chatbot = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BusinessConnectedBot(id: context.peerId)) |> take(1)

    
    actionsDisposable.add(chatbot.start(next: { connectedBot in
        updateState { current in
            var current = current
            current.initialBot = connectedBot
            if let connectedBot = connectedBot {
                
                var categories: [PeerId] = []
                if connectedBot.recipients.categories.contains(.nonContacts) {
                    categories.insert(TelegramFilterCategory(category: .nonContacts).id, at: 0)
                }
                if connectedBot.recipients.categories.contains(.contacts) {
                    categories.insert(TelegramFilterCategory(category: .contacts).id, at: 0)
                }
                if connectedBot.recipients.categories.contains(.newChats) {
                    categories.insert(TelegramFilterCategory(category: .newChats).id, at: 0)
                }
                if connectedBot.recipients.categories.contains(.existingChats) {
                    categories.insert(TelegramFilterCategory(category: .existingChats).id, at: 0)
                }
                
                current.access = connectedBot.recipients.exclude ? .all : .selected
                switch current.access {
                case .all:
                    current.excludeIds = Array(connectedBot.recipients.additionalPeers)
                    current.excludeIds.insert(contentsOf: categories, at: 0)
                case .selected:
                    current.includeIds = Array(connectedBot.recipients.additionalPeers)
                    current.includeIds.insert(contentsOf: categories, at: 0)
                    current.excludeIds = Array(connectedBot.recipients.excludePeers)
                }
                current.replyAccess = connectedBot.canReply
                current.disableIds = Array(connectedBot.recipients.excludePeers)
            }
            return current
        }
        
    }))

    let arguments = Arguments(context: context, toggleAccess: { value in
        updateState { current in
            var current = current
            current.access = value
            return current
        }
    }, selectChats: { type in
        
        let access = stateValue.with { $0.access }
        
        var items: [ShareAdditionItem] = []
        if access == .all || type == .include {
            switch type {
            case .exclude:
                items.append(.init(peer: TelegramFilterCategory(category: .existingChats), status: ""))
            case .include:
                items.append(.init(peer: TelegramFilterCategory(category: .newChats), status: ""))
            }
            items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
            items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))

        }
        
        let additionTopItems = ShareAdditionItems(items: items, topSeparator: strings().businessMessageSelectPeersChatTypes, bottomSeparator: strings().businessMessageSelectPeersChats)

        let selected: Set<PeerId>
        switch type {
        case .exclude:
            selected = stateValue.with { Set($0.excludeIds) }
        case .include:
            selected = stateValue.with { Set($0.includeIds) }
        }
        
        
        showModal(with: ShareModalController(BusinessSelectChatsCallbackObject(context, defaultSelectedIds: selected, contacts: stateValue.with { $0.contacts }, additionTopItems: items.isEmpty ? nil : additionTopItems, limit: 100, limitReachedText: strings().businessSelectPeersLimit, callback: { peerIds in
            
            updateState { current in
                var current = current
                switch type {
                case .exclude:
                    current.excludeIds = Array(peerIds)
                case .include:
                    current.includeIds = Array(peerIds)
                }
                return current
            }
            
            return .complete()
        }, excludePeerIds: Set([context.peerId]))), for: context.window)
    }, toggleReplyAccess: {
        updateState { current in
            var current = current
            current.replyAccess = !current.replyAccess
            return current
        }
    }, removeSelected: { type, peerId in
        updateState { current in
            var current = current
            switch type {
            case .exclude:
                current.excludeIds.removeAll(where: { $0 == peerId })
            case .include:
                current.includeIds.removeAll(where: { $0 == peerId })
            }
            return current
        }
    }, setBot: { bot in
        
        if let user = bot?._asPeer() as? TelegramUser, let botInfo = user.botInfo {
            if !botInfo.flags.contains(.isBusiness) {
                alert(for: context.window, info: strings().businessChatBotsBotNotSupported)
                return
            }
        }
        
        updateState { current in
            var current = current
            current.bot = bot
            current.username = nil
            if let bot = bot {
                current.botsResult = .found([bot])
            } else {
                current.botsResult = nil
            }
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().businessChatbotsTitle, removeAfterDisappear: false, hasDone: true, identifier: "business_chatbot")
    
    
    controller.updateDatas = { datas in
        updateState { current in
            var current = current
            current.username = datas[_id_input]?.stringValue
            return current
        }
        return .none
    }
    
    controller.validateData = { data in
        let state = stateValue.with { $0 }
        if state.initialBot != state.mapped {
            _ = context.engine.accountData.setAccountConnectedBot(bot: state.mapped).start()
            showModalText(for: context.window, text: strings().businessUpdated)
            return .success(.navigationBack)
        }
        return .none
    }
    
    controller.updateDoneValue = { data in
        return { f in
            let isEnabled = stateValue.with { $0.initialBot != $0.mapped }
            if isEnabled {
                f(.enabled(strings().navigationDone))
            } else {
                f(.disabled(strings().navigationDone))
            }
        }
    }
    
    let usernameUpdate: Signal<State.BotsResult?, NoError> = statePromise.get() |> filter { $0.bot == nil }
    |> map { $0.username }
    |> distinctUntilChanged
    |> mapToSignal { username in
        if let username = username, !username.isEmpty {
            return .single(.loading) |> then(context.engine.contacts.searchRemotePeers(query: username) |> map {
                return .found(($0.0 + $0.1).prefix(5).filter { $0.peer.isBot }.map { EnginePeer($0.peer) })
            })
        } else {
            return .single(nil)
        }
    }
    
    
    let initialIdUpdate: Signal<EnginePeer?, NoError> = statePromise.get() |> filter { $0.bot == nil }
    |> map { $0.initialBot?.id }
    |> distinctUntilChanged
    |> mapToSignal { peerId in
        if let peerId = peerId {
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        } else {
            return .never()
        }
    }
    
    
    actionsDisposable.add(usernameUpdate.startStandalone(next: { result in
        updateState { current in
            var current = current
            current.botsResult = result
            return current
        }
    }))
    
    actionsDisposable.add(initialIdUpdate.start(next: { result in
        updateState { current in
            var current = current
            current.bot = result
            if let result {
                current.botsResult = .found([result])
            }
            return current
        }
    }))
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
