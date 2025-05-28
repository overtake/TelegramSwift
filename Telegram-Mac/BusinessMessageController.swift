//
//  BusinessMessageController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit


private final class MessageRowItem : GeneralRowItem {
    
    let shortcut: ShortcutMessageList.Item
    let context: AccountContext
    let myPeer: EnginePeer
    let textLayout: TextViewLayout
    let titleLayout: TextViewLayout
    let count: TextViewLayout
    let open: ()->Void
    let remove: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, shortcut: ShortcutMessageList.Item, myPeer: EnginePeer, context: AccountContext, viewType: GeneralViewType, open: @escaping()->Void, remove: @escaping()->Void) {
        self.shortcut = shortcut
        self.myPeer = myPeer
        self.open = open
        self.context = context
        self.remove = remove
        let attr = chatListText(account: context.account, for: shortcut.topMessage._asMessage())
        
        self.textLayout = TextViewLayout(attr)
        self.titleLayout = TextViewLayout(.initialize(string: myPeer._asPeer().displayTitle, color: theme.colors.text, font: .medium(.title)))
        
        self.count = TextViewLayout(.initialize(string: "\(shortcut.totalCount)", color: theme.colors.grayText, font: .normal(.text)))
        self.count.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .next([.init(strings().contextRemove, handler: { [weak self] in
            self?.remove()
        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
    }
    
    private var textWidth: CGFloat {
        var width = blockWidth
        width -= (leftInset + viewType.innerInset.left)
        
        width -= 60 // photo
        width -= viewType.innerInset.left // photo
        
        return width
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        textLayout.measure(width: textWidth)
        titleLayout.measure(width: textWidth)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return MessageRowItemView.self
    }
    
    override var height: CGFloat {
        return 70
    }
    
    var leftInset: CGFloat {
        return 20
    }
}

private final class MessageRowItemView: GeneralContainableRowView {
    private let textView = InteractiveTextView(frame: .zero)
    private let titleView = TextView()
    private let imageView = AvatarControl(font: .avatar(15))
    private let container = View()
    
    private let countView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(imageView)
        container.addSubview(textView)
        container.addSubview(titleView)
        container.addSubview(countView)
        
        countView.userInteractionEnabled = false
        countView.isSelectable = false

        imageView.setFrameSize(NSMakeSize(50, 50))
        
        imageView.layer?.cornerRadius = imageView.frame.height / 2
        
        textView.userInteractionEnabled = false
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? MessageRowItem {
                item.open()
            }
        }, for: .Click)
        
        containerView.scaleOnClick = true

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageRowItem else {
            return
        }
        
        imageView.setPeer(account: item.context.account, peer: item.myPeer._asPeer())
        
        textView.set(text: item.textLayout, context: item.context)
        titleView.update(item.titleLayout)
        countView.update(item.count)
        
        self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        let contentInset: CGFloat = 16
        
        let containerRect = NSMakeRect(contentInset, 0, containerView.frame.width - contentInset, containerView.frame.height)
        
        transition.updateFrame(view: container, frame: containerRect)
        
        transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 0))
        
        transition.updateFrame(view: titleView, frame: CGRect(origin: NSMakePoint(imageView.frame.maxX + 10, imageView.frame.minY), size: titleView.frame.size))
        
        transition.updateFrame(view: textView, frame: CGRect(origin: NSMakePoint(imageView.frame.maxX + 10, titleView.frame.maxY + 6), size: textView.frame.size))
        
        transition.updateFrame(view: countView, frame: CGRect(origin: NSMakePoint(containerRect.width - countView.frame.width - 10, imageView.frame.minY), size: countView.frame.size))
    }
}



class BusinessSelectChatsCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    private let limitReachedText: String
    private let contacts: Set<PeerId>
    init(_ context: AccountContext, defaultSelectedIds: Set<PeerId>, contacts: Set<PeerId> = Set(), additionTopItems: ShareAdditionItems?, limit: Int?, limitReachedText: String, callback:@escaping([PeerId])->Signal<Never, NoError>, excludePeerIds: Set<PeerId> = Set()) {
        self.callback = callback
        self.contacts = contacts
        self.limitReachedText = limitReachedText
        super.init(context, excludePeerIds: excludePeerIds, defaultSelectedIds: defaultSelectedIds, additionTopItems: additionTopItems, limit: limit)
    }
    
    override var selectTopics: Bool {
        return false
    }
    
    override var hasFolders: Bool {
        return false
    }
    
    override var hasCaptionView: Bool {
        return false
    }
    override var blockCaptionView: Bool {
        return true
    }
    
    override func statusStyle(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> ControlStyle {
        return ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText)
    }
    
    override func statusString(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> String? {
        if peer.id.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace {
            return nil
        }
        if contacts.contains(peer.id) {
            return strings().businessMessageContact
        } else {
            return strings().businessMessageNonContact
        }
    }
    
    override func perform(to peerIds:[PeerId], threadId: Int64?, comment: ChatTextInputState? = nil, sendPaidMessageStars: [PeerId: StarsAmount] = [:]) -> Signal<Never, String> {
        return callback(peerIds) |> castError(String.self)
    }
    override func limitReached() {
        alert(for: context.window, info: limitReachedText)
    }
    override var searchPlaceholderKey: String {
        return "ChatList.Add.Placeholder"
    }
    override var interactionOk: String {
        return strings().chatListFilterAddDone
    }
    override var alwaysEnableDone: Bool {
        return true
    }
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        if peer is TelegramSecretChat {
            return false
        }
        if excludePeerIds.contains(peer.id) {
            return false
        }
        return peer.isUser && !peer.isBot
    }
    
}


enum SelectChatType {
    case include
    case exclude
}
private final class Arguments {
    let context: AccountContext
    let type: BusinessMessageType
    let toggleEnabled:()->Void
    let createMessage:()->Void
    let remove:()->Void
    let toggleSchedule:(State.Schedule)->Void
    let toggleRecepient:(State.Recepient)->Void
    let selectScheduleStart:(Date, Date)->Void
    let selectScheduleEnd:(Date, Date)->Void
    let selectChats:(SelectChatType)->Void
    let removeSelected:(SelectChatType, PeerId)->Void
    let updateAwayPeriod:(Int32)->Void
    let toggleOnlyOffline:()->Void
    init(context: AccountContext, type: BusinessMessageType, toggleEnabled:@escaping()->Void, createMessage:@escaping()->Void, remove:@escaping()->Void, toggleSchedule:@escaping(State.Schedule)->Void, toggleRecepient:@escaping(State.Recepient)->Void, selectScheduleStart:@escaping(Date, Date)->Void, selectScheduleEnd:@escaping(Date, Date)->Void, selectChats:@escaping(SelectChatType)->Void, removeSelected:@escaping(SelectChatType, PeerId)->Void, updateAwayPeriod:@escaping(Int32)->Void, toggleOnlyOffline:@escaping()->Void) {
        self.context = context
        self.type = type
        self.toggleEnabled = toggleEnabled
        self.createMessage = createMessage
        self.remove = remove
        self.toggleSchedule = toggleSchedule
        self.toggleRecepient = toggleRecepient
        self.selectScheduleStart = selectScheduleStart
        self.selectScheduleEnd = selectScheduleEnd
        self.selectChats = selectChats
        self.removeSelected = removeSelected
        self.updateAwayPeriod = updateAwayPeriod
        self.toggleOnlyOffline = toggleOnlyOffline
    }
}

private struct State : Equatable {
    
    enum Recepient : Equatable {
        case all
        case selected
    }
    
    enum Schedule : Equatable {
        case alwaysSend
        case outsideWorking
        case custom(from: Date, to: Date)
        
        var isCustom: Bool {
            if case .custom = self {
                return true
            }
            return false
        }
    }
    var type: BusinessMessageType
    var enabled: Bool = false
    var shortcut: ShortcutMessageList.Item? = nil
    var myPeer: EnginePeer?
    var schedule: Schedule = .alwaysSend
    var recepient: Recepient = .all
    
    var includeIds: [PeerId] = []
    var excludeIds: [PeerId] = []

    var includePeers: [EnginePeer] = []
    var excludePeers: [EnginePeer] = []

    var contacts: Set<PeerId> = Set()
    
    var awayPeriod: Int = 7
    
    var onlyOffline = true
    
    var initialAway: TelegramBusinessAwayMessage?
    var initialGreeting: TelegramBusinessGreetingMessage?
    
    var mappedCategories: TelegramBusinessRecipients.Categories {
        var categories: TelegramBusinessRecipients.Categories = []
        let catpeers: Set<PeerId>
        switch recepient {
        case .all:
            catpeers = Set(self.excludeIds.filter {
                $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
            })
        case .selected:
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
        return categories
    }
    
    var mappedGreeting: TelegramBusinessGreetingMessage? {
        if enabled, let shortcut = shortcut, let shortcutId = shortcut.id {
            let peerIds: Set<PeerId>
            switch recepient {
            case .all:
                peerIds = Set(self.excludeIds.filter {
                    $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
                })
            case .selected:
                peerIds = Set(self.includeIds.filter {
                    $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
                })
            }
            
            let recepients: TelegramBusinessRecipients = .init(categories: mappedCategories, additionalPeers: peerIds, excludePeers: Set(), exclude: recepient == .all)
            return .init(shortcutId: shortcutId, recipients: recepients, inactivityDays: awayPeriod)
        } else {
            return nil
        }
    }
    
    var mappedAway: TelegramBusinessAwayMessage? {
        if enabled, let shortcut = shortcut, let shortcutId = shortcut.id {
            let peerIds: Set<PeerId>
            switch recepient {
            case .all:
                peerIds = Set(self.excludeIds.filter {
                    $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
                })
            case .selected:
                peerIds = Set(self.includeIds.filter {
                    $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
                })
            }
            let recepients: TelegramBusinessRecipients = .init(categories: mappedCategories, additionalPeers: peerIds, excludePeers: Set(), exclude: recepient == .all)
            return .init(shortcutId: shortcutId, recipients: recepients, schedule: scheduleAway, sendWhenOffline: onlyOffline)
        } else {
            return nil
        }
    }

    var scheduleAway: TelegramBusinessAwayMessage.Schedule {
        switch self.schedule {
        case .alwaysSend:
            return .always
        case .outsideWorking:
            return .outsideWorkingHours
        case .custom(let from, let to):
            return .custom(beginTimestamp: Int32(from.timeIntervalSince1970), endTimestamp: Int32(to.timeIntervalSince1970))
        }
    }
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_enabled = InputDataIdentifier("_id_enabled")

private let _id_create_message = InputDataIdentifier("_id_create_message")
private let _id_message = InputDataIdentifier("_id_message")

private let _id_schedule_always = InputDataIdentifier("_id_schedule_always")
private let _id_schedule_outside = InputDataIdentifier("_id_schedule_outside")
private let _id_schedule_custom = InputDataIdentifier("_id_schedule_custom")


private let _id_recepient_1x1 = InputDataIdentifier("_id_recepient_1x1")
private let _id_recepient_selected = InputDataIdentifier("_id_recepient_selected")

private let _id_start_time = InputDataIdentifier("_id_start_time")
private let _id_end_time = InputDataIdentifier("_id_end_time")


private let _id_include_chats = InputDataIdentifier("_id_include_chats")
private let _id_exclude_chats = InputDataIdentifier("_id_exclude_chats")

private let _id_away_period = InputDataIdentifier("_id_away_period")

private let _id_only_offline = InputDataIdentifier("_id_only_offline")

private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: arguments.type.sticker, text: .initialize(string: arguments.type.headerInfo, color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: arguments.type.enableText, color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
  
    // entries
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(arguments.type.title.uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        if state.shortcut == nil {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_create_message, data: .init(name: arguments.type.createMessageText, color: theme.colors.accent, icon: theme.icons.create_new_message_general, type: .next, viewType: .singleItem, action: arguments.createMessage)))
        } else if let myPeer = state.myPeer, let shortcut = state.shortcut {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_message, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return MessageRowItem(initialSize, stableId: stableId, shortcut: shortcut, myPeer: myPeer, context: arguments.context, viewType: .singleItem, open: arguments.createMessage, remove: arguments.remove)
            }))
        }
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
       
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageScheduleTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule_always, data: .init(name: strings().businessMessageScheduleAlwaysSend, color: theme.colors.text, type: .selectable(state.schedule == .alwaysSend), viewType: .firstItem, action: {
            arguments.toggleSchedule(.alwaysSend)
        })))
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule_outside, data: .init(name: strings().businessMessageScheduleOutsideHours, color: theme.colors.text, type: .selectable(state.schedule == .outsideWorking), viewType: .innerItem, action: {
            arguments.toggleSchedule(.outsideWorking)
        })))

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule_custom, data: .init(name: strings().businessMessageScheduleCustom, color: theme.colors.text, type: .selectable(state.schedule.isCustom), viewType: .lastItem, action: {
            arguments.toggleSchedule(.custom(from: Date(), to: Date(timeIntervalSinceNow: TimeInterval(Int32.secondsInWeek))))

        })))
        
        switch arguments.type {
        case .away:
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_only_offline, data: .init(name: strings().businessAwayOnlyOffline, color: theme.colors.text, type: .switchable(state.onlyOffline), viewType: .singleItem, action: arguments.toggleOnlyOffline)))
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessAwayOnlyOfflineInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1

            
        case .greetings:
            break
        }
        
        switch state.schedule {
        case let .custom(from, to):
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            let fromString = stringForMediumDate(timestamp: Int32(from.timeIntervalSince1970))
            let toString = stringForMediumDate(timestamp: Int32(to.timeIntervalSince1970))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_start_time, data: .init(name: strings().businessMessageScheduleCustomStartTime, color: theme.colors.text, type: .nextContext(fromString), viewType: .firstItem, justUpdate: arc4random64(), action: {
                arguments.selectScheduleStart(from, to)
            })))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_end_time, data: .init(name: strings().businessMessageScheduleCustomEndTime, color: theme.colors.text, type: .nextContext(toString), viewType: .lastItem, justUpdate: arc4random64(), action: {
                arguments.selectScheduleEnd(from, to)
            })))
        default:
            break
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_recepient_1x1, data: .init(name: strings().businessMessageRecepientsAll, color: theme.colors.text, type: .selectable(state.recepient == .all), viewType: .firstItem, action: {
            arguments.toggleRecepient(.all)
        })))
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_recepient_selected, data: .init(name: strings().businessMessageRecepientsSelected, color: theme.colors.text, type: .selectable(state.recepient == .selected), viewType: .lastItem, action: {
            arguments.toggleRecepient(.selected)
        })))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        switch state.recepient {
        case .all:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsExcludeTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exclude_chats, data: .init(name: strings().businessMessageRecepientsExclude, color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.excludePeers.isEmpty ? .singleItem : .firstItem, action: {
                arguments.selectChats(.exclude)
            })))
            
        case .selected:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessMessageRecepientsIncludeTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_chats, data: .init(name: strings().businessMessageRecepientsInclude, color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.includePeers.isEmpty ? .singleItem : .firstItem, action: {
                arguments.selectChats(.include)
            })))
        }
                
        struct Tuple : Equatable {
            let peer: PeerEquatable
            let viewType: GeneralViewType
            let status: String?
            let recepient: State.Recepient
        }
        var tuples: [Tuple] = []
        
        var selectedPeers: [Peer] = []
        
        
        
        let categories: [PeerId]
        
        switch state.recepient {
        case .all:
            categories = state.excludeIds.filter {
                $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
            }
        case .selected:
            categories = state.includeIds.filter {
                $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
            }
        }
        
        for category in categories {
            let cat = ChatListFilterPeerCategories(rawValue: Int32(category.id._internalGetInt64Value()))
            selectedPeers.append(TelegramFilterCategory(category: cat))
        }
        
        switch state.recepient {
        case .all:
            selectedPeers.append(contentsOf: state.excludePeers.map { $0._asPeer() })
        case .selected:
            selectedPeers.append(contentsOf: state.includePeers.map { $0._asPeer() })
        }
        
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
            tuples.append(.init(peer: .init(peer), viewType: viewType, status: status, recepient: state.recepient))
        }
        
        for tuple in tuples {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(tuple.peer.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), viewType: tuple.viewType, action: {
                    //arguments.openInfo(peer.id)
                }, contextMenuItems: {
                    return .single([ContextMenuItem(strings().contextRemove, handler: {
                        if state.recepient == .all {
                            arguments.removeSelected(.exclude, tuple.peer.id)
                        } else {
                            arguments.removeSelected(.include, tuple.peer.id)
                        }
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
                }, highlightVerified: true, menuOnAction: true)
            }))
        }
    }
    
    switch arguments.type {
    case .away:
        break
    case .greetings:
        if state.enabled {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessGreetingMessageNoActivityTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_away_period, equatable: .init(state.awayPeriod), comparable: nil, item: { initialSize, stableId in
                let values: [Int32] = [7, 14, 21, 28]
                return SelectSizeRowItem(initialSize, stableId: stableId, current: Int32(state.awayPeriod), sizes: values, hasMarkers: false, titles: [strings().businessGreetingMessageNoActivityDaysCountable(7), strings().businessGreetingMessageNoActivityDaysCountable(14), strings().businessGreetingMessageNoActivityDaysCountable(21), strings().businessGreetingMessageNoActivityDaysCountable(28)], viewType: .singleItem, selectAction: { selected in
                    arguments.updateAwayPeriod(values[selected])
                })
            }))
            
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessGreetingMessageNoActivityInfo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
        }
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum BusinessMessageType {
    case away
    case greetings
    
    fileprivate var title: String {
        switch self {
        case .away:
            return strings().businessAwayMessageTitle
        case .greetings:
            return strings().businessGreetingMessageTitle
        }
    }
    fileprivate var createMessageText: String {
        switch self {
        case .away:
            return strings().businessAwayMessageCreateMessage
        case .greetings:
            return strings().businessGreetingMessageCreateMessage
        }
    }
    fileprivate var sticker: LocalAnimatedSticker {
        switch self {
        case .away:
            return LocalAnimatedSticker.business_away_message
        case .greetings:
            return LocalAnimatedSticker.business_greeting_message
        }
    }
    fileprivate var headerInfo: String {
        switch self {
        case .away:
            return strings().businessAwayMessageHeader
        case .greetings:
            return strings().businessGreetingMessageHeader
        }
    }
    fileprivate var enableText: String {
        switch self {
        case .away:
            return strings().businessAwayMessageEnable
        case .greetings:
            return strings().businessGreetingMessageEnable
        }
    }
}

func BusinessMessageController(context: AccountContext, type: BusinessMessageType) -> InputDataController {
    
    let actionsDisposable = DisposableSet()
    
    let initialState = State(type: type)
    
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
    
    let awayMessage = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BusinessAwayMessage(id: context.peerId))
    let greetingMessage = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BusinessGreetingMessage(id: context.peerId))
    
    let shortcuts = context.engine.accountData.shortcutMessageList(onlyRemote: false)
    
    
    actionsDisposable.add(combineLatest(awayMessage, greetingMessage, shortcuts).start(next: { awayMessage, greetingMessage, shortcuts in
        updateState { current in
            var current = current
            switch type {
            case .away:
                if let awayMessage {
                    current.shortcut = shortcuts.items.first(where: { $0.id == awayMessage.shortcutId })
                } else {
                    current.shortcut = shortcuts.items.first(where: { $0.shortcut == "away" || $0.shortcut == "_away" })
                    current.recepient = .all
                }
            case .greetings:
                if let greetingMessage {
                    current.shortcut = shortcuts.items.first(where: { $0.id == greetingMessage.shortcutId })
                } else {
                    current.shortcut = shortcuts.items.first(where: { $0.shortcut == "hello" || $0.shortcut == "_hello" })
                    current.recepient = .all
                }
            }
            return current
        }
    }))

    
    actionsDisposable.add((combineLatest(awayMessage, greetingMessage) |> take(1)).start(next: { awayMessage, greetingMessage in
        updateState { current in
            var current = current
            current.awayPeriod = greetingMessage?.inactivityDays ?? 7
            current.initialAway = awayMessage
            current.initialGreeting = greetingMessage
            current.onlyOffline = awayMessage?.sendWhenOffline ?? true
            
            switch awayMessage?.schedule {
            case .always:
                current.schedule = .alwaysSend
            case let .custom(beginTimestamp, endTimestamp):
                current.schedule = .custom(from: Date(timeIntervalSince1970: TimeInterval(beginTimestamp)), to: Date(timeIntervalSince1970: TimeInterval(endTimestamp)))
            case .outsideWorkingHours:
                current.schedule = .outsideWorking
            case .none:
                break
            }
            
            var categories: [PeerId] = []
            switch type {
            case .away:
                if let awayMessage {
                    if awayMessage.recipients.categories.contains(.nonContacts) {
                        categories.insert(TelegramFilterCategory(category: .nonContacts).id, at: 0)
                    }
                    if awayMessage.recipients.categories.contains(.contacts) {
                        categories.insert(TelegramFilterCategory(category: .contacts).id, at: 0)
                    }
                    if awayMessage.recipients.categories.contains(.newChats) {
                        categories.insert(TelegramFilterCategory(category: .newChats).id, at: 0)
                    }
                    if awayMessage.recipients.categories.contains(.existingChats) {
                        categories.insert(TelegramFilterCategory(category: .existingChats).id, at: 0)
                    }
                }
            case .greetings:
                if let greetingMessage {
                    if greetingMessage.recipients.categories.contains(.nonContacts) {
                        categories.insert(TelegramFilterCategory(category: .nonContacts).id, at: 0)
                    }
                    if greetingMessage.recipients.categories.contains(.contacts) {
                        categories.insert(TelegramFilterCategory(category: .contacts).id, at: 0)
                    }
                    if greetingMessage.recipients.categories.contains(.newChats) {
                        categories.insert(TelegramFilterCategory(category: .newChats).id, at: 0)
                    }
                    if greetingMessage.recipients.categories.contains(.existingChats) {
                        categories.insert(TelegramFilterCategory(category: .existingChats).id, at: 0)
                    }
                }
            }
            
            switch type {
            case .away:
                current.enabled = awayMessage != nil
                if let awayMessage {
                    if awayMessage.recipients.exclude {
                        current.recepient = .all
                        current.includeIds = Array(awayMessage.recipients.additionalPeers)
                    } else {
                        current.recepient = .selected
                        current.excludeIds = Array(awayMessage.recipients.additionalPeers)
                    }
                }
            case .greetings:
                current.enabled = greetingMessage != nil
                if let greetingMessage {
                    if greetingMessage.recipients.exclude {
                        current.recepient = .all
                        current.includeIds = Array(greetingMessage.recipients.additionalPeers)
                    } else {
                        current.recepient = .selected
                        current.excludeIds = Array(greetingMessage.recipients.additionalPeers)
                    }
                }
            }
            switch current.recepient {
            case .all:
                current.excludeIds.insert(contentsOf: categories, at: 0)
            case .selected:
                current.includeIds.insert(contentsOf: categories, at: 0)
            }
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
    
    
    actionsDisposable.add(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.peerId)).startStandalone(next: { myPeer in
        updateState { current in
            var current = current
            current.myPeer = myPeer
            return current
        }
    }))
    
    let arguments = Arguments(context: context, type: type, toggleEnabled: {
        updateState { current in
            var current = current
            current.enabled = !current.enabled
            return current
        }
    }, createMessage: {
        let messages = AutomaticBusinessMessageSetupChatContents(context: context, kind: type == .away ? .awayMessageInput : .greetingMessageInput, shortcutId: stateValue.with { $0.shortcut?.id })
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(context.peerId),mode: .customChatContents(contents: messages)))
    }, remove: {
        if let shortcut = stateValue.with({ $0.shortcut }), let shortcutId = shortcut.id {
            context.engine.accountData.deleteMessageShortcuts(ids: [shortcutId])
            updateState { current in
                var current = current
                current.shortcut = nil
                current.enabled = false
                return current
            }
        }
    }, toggleSchedule: { schedule in
        updateState { current in
            var current = current
            current.schedule = schedule
            return current
        }
    }, toggleRecepient: { recepient in
        updateState { current in
            var current = current
            current.recepient = recepient
            return current
        }
    }, selectScheduleStart: { from, to in
        showModal(with: DateSelectorModalController(context: context, defaultDate: from, mode: .date(title: strings().businessScheduleStart, doneTitle: strings().modalDone), selectedAt: { updated in
            updateState { current in
                var current = current
                if updated.timeIntervalSince1970 > to.timeIntervalSince1970 {
                    current.schedule = .custom(from: updated, to: Date(timeIntervalSince1970: updated.timeIntervalSince1970 + 1 * 24 * 60 * 60))
                } else {
                    current.schedule = .custom(from: updated, to: to)
                }
                return current
            }
        }), for: context.window)
    }, selectScheduleEnd: { from, to in
        showModal(with: DateSelectorModalController(context: context, defaultDate: to, mode: .date(title: strings().businessScheduleEnd, doneTitle: strings().modalDone), selectedAt: { updated in
            updateState { current in
                var current = current
                if from.timeIntervalSince1970 > updated.timeIntervalSince1970 {
                    current.schedule = .custom(from: Date(timeIntervalSince1970: max(Date().timeIntervalSince1970, updated.timeIntervalSince1970 - 1 * 24 * 60 * 60)), to: updated)
                } else {
                    current.schedule = .custom(from: from, to: updated)
                }
                return current
            }
        }), for: context.window)
    }, selectChats: { type in
        
        var items: [ShareAdditionItem] = []
        
        switch type {
        case .exclude:
            items.append(.init(peer: TelegramFilterCategory(category: .existingChats), status: ""))
        case .include:
            items.append(.init(peer: TelegramFilterCategory(category: .newChats), status: ""))
        }
        items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
        let additionTopItems = ShareAdditionItems(items: items, topSeparator: strings().businessMessageSelectPeersChatTypes, bottomSeparator: strings().businessMessageSelectPeersChats)
        
        let selected: Set<PeerId>
        switch type {
        case .exclude:
            selected = stateValue.with { Set($0.excludeIds) }
        case .include:
            selected = stateValue.with { Set($0.includeIds) }
        }
        
        showModal(with: ShareModalController(BusinessSelectChatsCallbackObject(context, defaultSelectedIds: selected, contacts: stateValue.with { $0.contacts }, additionTopItems: additionTopItems, limit: 100, limitReachedText: strings().businessSelectPeersLimit, callback: { peerIds in
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
    }, updateAwayPeriod: { period in
        updateState { current in
            var current = current
            current.awayPeriod = Int(period)
            return current
        }
    }, toggleOnlyOffline: {
        updateState { current in
            var current = current
            current.onlyOffline = !current.onlyOffline
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), grouping: false)
    }
    
    let controller = InputDataController(dataSignal: signal, title: type.title, removeAfterDisappear: false, hasDone: true, identifier: "business_message")
    
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        
        if state.recepient == .selected, state.includeIds.isEmpty {
            return .fail(.fields([_id_include_chats : .shake, _id_recepient_selected : .shake]))
        }
        if state.enabled, state.shortcut == nil {
            return .fail(.fields([_id_create_message : .shake]))
        }
        
        switch type {
        case .away:
            if state.initialAway != state.mappedAway {
                _ = context.engine.accountData.updateBusinessAwayMessage(awayMessage: state.mappedAway).startStandalone()
                showModalText(for: context.window, text: strings().businessUpdated)
                return .success(.navigationBack)
            }
        case .greetings:
            if state.initialGreeting != state.mappedGreeting {
                _ = context.engine.accountData.updateBusinessGreetingMessage(greetingMessage: state.mappedGreeting).startStandalone()
                showModalText(for: context.window, text: strings().businessUpdated)
                return .success(.navigationBack)
            }
        }

        return .none
    }
    
    
    controller.updateDoneValue = { data in
        return { f in
            let state = stateValue.with { $0 }
            var isEnabled: Bool = state.enabled
            if state.shortcut != nil {
                switch type {
                case .away:
                    isEnabled = state.initialAway != state.mappedAway
                case .greetings:
                    isEnabled = state.initialGreeting != state.mappedGreeting
                }
            }
            if isEnabled {
                f(.enabled(strings().navigationDone))
            } else {
                f(.disabled(strings().navigationDone))
            }
        }
    }
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}

