//
//  ChatListPresetController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/01/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import InAppSettings
import TGUIKit
import InputView


private enum FolderColorEntryId: Hashable {
    case color(String)
}

private enum  FolderColorEntry: Comparable, Identifiable {
    case color(Int, NSColor, Bool)
    
    var stableId:  FolderColorEntryId {
        switch self {
            case let .color(_, color, _):
            return .color(color.hexString)
        }
    }
    
    static func ==(lhs:  FolderColorEntry, rhs: FolderColorEntry) -> Bool {
        switch lhs {
            case let .color(index, color, selected):
                if case .color(index, color, selected) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: FolderColorEntry, rhs: FolderColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, _, _):
                switch rhs {
                    case let .color(rhsIndex, _, _):
                        return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(initialSize: NSSize, context: AccountContext, action: @escaping (NSColor) -> Void) -> FolderColorIconItem {
        switch self {
            case let .color(_, color, selected):
            return FolderColorIconItem(initialSize: initialSize, stableId: self.stableId, context: context, color: color, selected: selected, action: action)
        }
    }
}



private class FolderColorIconItem: TableRowItem {
    let color: NSColor
    let selected: Bool
    let action: (NSColor) -> Void
    let context: AccountContext
    public init(initialSize: NSSize, stableId: AnyHashable, context: AccountContext, color: NSColor, selected: Bool, action: @escaping (NSColor) -> Void) {
        self.color = color
        self.selected = selected
        self.action = action
        self.context = context
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 55
    }
    override var width: CGFloat {
        return 55
    }
    
    override func viewClass() -> AnyClass {
        return FolderColorIconView.self
    }
}

private final class FolderColorIconView : View {
    
    private let fillView: SimpleLayer = SimpleLayer()
    private let ringView: SimpleLayer = SimpleLayer()
    private let control = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(ringView)
        self.layer?.addSublayer(fillView)
        addSubview(control)
        let bounds = focus(CGSize(width: 35, height: 35))
        
        fillView.frame = bounds
        ringView.frame = bounds

        
        control.frame = bounds
        
        
        control.set(handler: { [weak self] _ in
            guard let item = self?.item as? FolderColorIconItem else {
                return
            }
            item.action(item.color)
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var wasSelected: Bool = false
    
    private var item: TableRowItem?
    
    func set(item: TableRowItem, animated: Bool) {
        
        self.item = item
        
        guard let item = item as? FolderColorIconItem else {
            return
        }
                
        self.fillView.contents = generateFillImage(nameColor: .init(main: item.color))
        self.ringView.contents = generateRingImage(nameColor: .init(main: item.color))

        if wasSelected != item.selected {
            if item.selected {
                self.fillView.transform = CATransform3DScale(CATransform3DIdentity, 0.8, 0.8, 1.0)
                if animated {
                    self.fillView.animateScale(from: 1, to: 0.8, duration: animated ? 0.2 : 0, removeOnCompletion: true)
                }
            } else {
                self.fillView.transform = CATransform3DScale(CATransform3DIdentity, 1.0, 1.0, 1.0)
                if animated {
                    self.fillView.animateScale(from: 0.8, to: 1, duration: animated ? 0.2 : 0, removeOnCompletion: true)
                }
            }
        }
        
        self.wasSelected = item.selected

    }
}



private final class FolderColorRowItem : GeneralRowItem {
    fileprivate let colors: [NSColor]
    fileprivate let selected: NSColor?
    fileprivate let selectAction:(NSColor)->Void
    fileprivate let context: AccountContext

    let itemSize: NSSize = NSMakeSize(45, 45)
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, colors: [NSColor], selected: NSColor?, viewType: GeneralViewType, action: @escaping(NSColor)->Void) {
        self.colors = colors
        self.context = context
        self.selected = selected
        self.selectAction = action
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var frames:[CGRect] = []
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)

        frames.removeAll()
        
        let perRow = Int(floor((blockWidth - 10) / itemSize.width))

        var point: CGPoint = NSMakePoint(5, 5)
        for i in 1 ... colors.count {
            frames.append(CGRect(origin: point, size: itemSize))
            if i % perRow == 0 {
                point.x = 5
                point.y += itemSize.height
            } else {
                point.x += itemSize.width
            }
        }
        
        return true
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var height: CGFloat {
        let perRow = floor((blockWidth - 10) / itemSize.width)
        
        return frames[frames.count - 1].maxY + 5
    }
    
    override func viewClass() -> AnyClass {
        return PeerNamesRowView.self
    }
}

private final class PeerNamesRowView : GeneralContainableRowView {
    let tableView: View
    required init(frame frameRect: NSRect) {
        tableView = View(frame: frameRect)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    override func layout() {
        super.layout()
        tableView.frame = containerView.bounds
        guard let item = item as? FolderColorRowItem else {
            return
        }
        
        for (i, subview) in tableView.subviews.enumerated() {
            subview.frame = item.frames[i]
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var previous: [FolderColorEntry] = []
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? FolderColorRowItem else {
            return
        }
        
        var entries: [FolderColorEntry] = []
        
        var index: Int = 0
        for color in item.colors {
            entries.append(.color(index, color, color == item.selected))
            index += 1
        }

        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previous, rightList: entries)
        
        
        for rdx in deleteIndices.reversed() {
            tableView.subviews[rdx].removeFromSuperview()
        }
        
        
        for (idx, entry, _) in indicesAndItems {
            let view = FolderColorIconView(frame: item.itemSize.bounds)
            let item = entry.item(initialSize: bounds.size, context: item.context, action: item.selectAction)
            view.set(item: item, animated: animated)
            tableView.subviews.insert(view, at: idx)
        }
        for (idx, entry, _) in updateIndices {
            let item = item
            let updatedItem = entry.item(initialSize: bounds.size, context: item.context, action: item.selectAction)
            (tableView.subviews[idx] as? FolderColorIconView)?.set(item: updatedItem, animated: animated)
        }

        self.previous = entries
        
        needsLayout = true
        
    }
    
}



func shareFolderPremiumLimits(context: AccountContext, current: ChatListFilter, links: [ExportedChatFolderLink]?) -> Signal<(limitFilters: Bool, limitInvites: Bool), NoError> {
    return chatListFilterPreferences(engine: context.engine) |> take(1) |> map { data in
        var shared = data.list.filter { $0.data?.isShared == true }
        if current.data?.isShared == true, current.data?.hasSharedLinks == true {
            shared.removeAll()
        }
        let links = links ?? []
        var limitFilters: Bool = false
        var limitInvites: Bool = false
        if context.isPremium {
            if shared.count >= context.premiumLimits.communities_joined_limit_premium {
                limitFilters = true
            } else if links.count >= context.premiumLimits.community_invites_limit_premium {
                limitInvites = true
            }
        } else {
            if shared.count >= context.premiumLimits.communities_joined_limit_default {
                limitFilters = true
            }
            if links.count >= context.premiumLimits.community_invites_limit_default {
                limitInvites = true
            }
        }
        return (limitFilters: limitFilters, limitInvites: limitInvites)
    }
}


enum ChatListFilterType {
    case generic
    case unmuted
    case unread
    case channels
    case groups
    case bots
    case contacts
    case nonContacts
}

func chatListFilterType(_ filter: ChatListFilter) -> ChatListFilterType {
    let filterType: ChatListFilterType
    switch filter {
    case .allChats:
        filterType = .generic
    case let .filter(_, _, _, data):
        if data.includePeers.peers.isEmpty {
            if data.categories == .all {
                if data.excludeRead {
                    filterType = .unread
                } else if data.excludeMuted {
                    filterType = .unmuted
                } else {
                    filterType = .generic
                }
            } else {
                if data.categories == .channels {
                    filterType = .channels
                } else if data.categories == .groups {
                    filterType = .groups
                } else if data.categories == .bots {
                    filterType = .bots
                } else if data.categories == .contacts {
                    filterType = .contacts
                } else if data.categories == .nonContacts {
                    filterType = .nonContacts
                } else {
                    filterType = .generic
                }
            }
        } else {
            filterType = .generic
        }
    }
    
    return filterType
}

private extension ChatListFilter {
    var additionIncludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        if data?.isShared == false {
            items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
            items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
            items.append(.init(peer: TelegramFilterCategory(category: .groups), status: ""))
            items.append(.init(peer: TelegramFilterCategory(category: .channels), status: ""))
            items.append(.init(peer: TelegramFilterCategory(category: .bots), status: ""))
        }
        return items
    }
    var includeCustom: [PeerId] {
        var items: [PeerId] = []
        if let data = data {
            if data.categories.contains(.contacts) {
                items.append(TelegramFilterCategory(category: .contacts).id)
            }
            if data.categories.contains(.nonContacts) {
                items.append(TelegramFilterCategory(category: .nonContacts).id)
            }
            if data.categories.contains(.groups) {
                items.append(TelegramFilterCategory(category: .groups).id)
            }
            if data.categories.contains(.channels) {
                items.append(TelegramFilterCategory(category: .channels).id)
            }
            if data.categories.contains(.bots) {
                items.append(TelegramFilterCategory(category: .bots).id)
            }
        }
        return items
    }

    var includeAllPeerIds: [PeerId] {
        var items: [PeerId] = []
        if let data = data {
            if data.categories.contains(.contacts) {
                items.append(TelegramFilterCategory(category: .contacts).id)
            }
            if data.categories.contains(.nonContacts) {
                items.append(TelegramFilterCategory(category: .nonContacts).id)
            }
            if data.categories.contains(.groups) {
                items.append(TelegramFilterCategory(category: .groups).id)
            }
            if data.categories.contains(.channels) {
                items.append(TelegramFilterCategory(category: .channels).id)
            }
            if data.categories.contains(.bots) {
                items.append(TelegramFilterCategory(category: .bots).id)
            }
            items.append(contentsOf: data.includePeers.peers)
        }
        return items
    }
    var excludeAllPeers: [PeerId] {
        var items:[PeerId] = []
        if let data = data {
            if data.excludeMuted {
                items.append(TelegramFilterCategory(category: .excludeMuted).id)
            }
            if data.excludeRead {
                items.append(TelegramFilterCategory(category: .excludeRead).id)
            }
            if data.excludeArchived {
                items.append(TelegramFilterCategory(category: .excludeArchived).id)
            }
            items.append(contentsOf: data.excludePeers)
        }
        return items
    }
    
    var selectedIncludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        switch self {
        case .allChats:
            break
        case let .filter(_, _, _, data):
            if data.categories.contains(.contacts) {
                items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
            }
            if data.categories.contains(.nonContacts) {
                items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
            }
            if data.categories.contains(.groups) {
                items.append(.init(peer: TelegramFilterCategory(category: .groups), status: ""))
            }
            if data.categories.contains(.channels) {
                items.append(.init(peer: TelegramFilterCategory(category: .channels), status: ""))
            }
            if data.categories.contains(.bots) {
                items.append(.init(peer: TelegramFilterCategory(category: .bots), status: ""))
            }
        }
        
        return items
    }
    var additionExcludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        items.append(.init(peer: TelegramFilterCategory(category: .excludeMuted), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .excludeRead), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .excludeArchived), status: ""))
        return items
    }
    
    
    var selectedExcludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        switch self {
        case .allChats:
            break
        case let .filter(_, _, _, data):
            if data.excludeMuted {
                items.append(.init(peer: TelegramFilterCategory(category: .excludeMuted), status: ""))
            }
            if data.excludeRead {
                items.append(.init(peer: TelegramFilterCategory(category: .excludeRead), status: ""))
            }
            if data.excludeArchived {
                items.append(.init(peer: TelegramFilterCategory(category: .excludeArchived), status: ""))
            }
        }
        
        return items
    }
}

//extension ChatListFiltersState {
//    mutating func withAddedFilter(_ filter: ChatListFilter, onlyReplace: Bool = false) {
//        if let index = filters.firstIndex(where: {$0.id == filter.id}) {
//            filters[index] = filter
//        } else if !onlyReplace {
//            filters.append(filter)
//        }
//    }
//
//    mutating func withRemovedFilter(_ filter: ChatListFilter) {
//        filters.removeAll(where: {$0.id == filter.id })
//    }
//
//    mutating func withMoveFilter(_ from: Int, _ to: Int)  {
//        filters.insert(filters.remove(at: from), at: to)
//    }
//}

class SelectCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    private let limitReachedText: String
    init(_ context: AccountContext, defaultSelectedIds: Set<PeerId>, additionTopItems: ShareAdditionItems?, limit: Int?, limitReachedText: String, callback:@escaping([PeerId])->Signal<Never, NoError>, excludePeerIds: Set<PeerId> = Set()) {
        self.callback = callback
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
    
    
    override func perform(to peerIds:[PeerId], threadId: Int64?, comment: ChatTextInputState? = nil, sendPaidMessageStars: [PeerId: StarsAmount] = [:]) -> Signal<Never, String> {
        return callback(peerIds) |> castError(String.self)
    }
    override func limitReached() {
        if !context.isPremium {
            showModal(with: PremiumLimitController(context: context, type: .chatInFolders), for: context.window)
        } else {
            alert(for: context.window, info: limitReachedText)
        }
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
        return true
    }
    
}

private struct State: Equatable {
    var filter: ChatListFilter
    var initialFilter: ChatListFilter
    var showAllInclude: Bool
    var showAllExclude: Bool
    var isNew: Bool
    var changedName: Bool
    var inviteLinks: [ExportedChatFolderLink]?
    var creatingLink: Bool
    var linkSaving: String?
    var inputState: Updated_ChatTextInputState
    var nameAnimation: Bool
    init(filter: ChatListFilter, isNew: Bool, showAllInclude: Bool, showAllExclude: Bool, changedName: Bool, inviteLinks: [ExportedChatFolderLink]?, creatingLink: Bool, linkSaving: String?, inputState: Updated_ChatTextInputState, nameAnimation: Bool) {
        self.filter = filter
        self.initialFilter = filter
        self.isNew = isNew
        self.showAllInclude = showAllInclude
        self.showAllExclude = showAllExclude
        self.changedName = changedName
        self.inviteLinks = inviteLinks
        self.creatingLink = creatingLink
        self.linkSaving = linkSaving
        self.inputState = inputState
        self.nameAnimation = nameAnimation
    }
    
    mutating func withUpdatedFilter(_ f:(ChatListFilter)->ChatListFilter) {
        self.filter = f(self.filter)
    }
}

private final class ChatListPresetArguments {
    let context: AccountContext
    let toggleOption:(ChatListFilterPeerCategories)->Void
    let toggleExcludeMuted:(Bool)->Void
    let toggleExcludeRead:(Bool)->Void
    let addInclude:()->Void
    let addExclude:()->Void
    let removeIncluded:(PeerId)->Void
    let removeExcluded:(PeerId)->Void
    let openInfo:(PeerId)->Void
    let showAllInclude: ()->Void
    let showAllExclude: ()->Void
    let updateIcon:(FolderIcon)->Void
    let shareFolder:(ExportedChatFolderLink?)->Void
    let copy:(String)->Void
    let deleteLink:(ExportedChatFolderLink)->Void
    let toggleColor:(Int32?)->Void
    let updateState:(Updated_ChatTextInputState)->Void
    let toggleNameAnimation:()->Void
    init(context: AccountContext, toggleOption:@escaping(ChatListFilterPeerCategories)->Void, addInclude: @escaping()->Void, addExclude: @escaping()->Void, removeIncluded: @escaping(PeerId)->Void, removeExcluded: @escaping(PeerId)->Void, openInfo: @escaping(PeerId)->Void, toggleExcludeMuted:@escaping(Bool)->Void, toggleExcludeRead: @escaping(Bool)->Void, showAllInclude:@escaping()->Void, showAllExclude:@escaping()->Void, updateIcon: @escaping(FolderIcon)->Void, shareFolder:@escaping(ExportedChatFolderLink?)->Void, copy: @escaping(String)->Void, deleteLink:@escaping(ExportedChatFolderLink)->Void, toggleColor:@escaping(Int32?)->Void, updateState:@escaping(Updated_ChatTextInputState)->Void, toggleNameAnimation:@escaping()->Void) {
        self.context = context
        self.toggleOption = toggleOption
        self.toggleExcludeMuted = toggleExcludeMuted
        self.toggleExcludeRead = toggleExcludeRead
        self.addInclude = addInclude
        self.addExclude = addExclude
        self.removeIncluded = removeIncluded
        self.removeExcluded = removeExcluded
        self.openInfo = openInfo
        self.showAllInclude = showAllInclude
        self.showAllExclude = showAllExclude
        self.updateIcon = updateIcon
        self.shareFolder = shareFolder
        self.copy = copy
        self.deleteLink = deleteLink
        self.toggleColor = toggleColor
        self.updateState = updateState
        self.toggleNameAnimation = toggleNameAnimation
    }
}

private let _id_name_input = InputDataIdentifier("_id_name_input")
private let _id_private_chats = InputDataIdentifier("_id_private_chats")

private let _id_public_groups = InputDataIdentifier("_id_public_groups")
private let _id_private_groups = InputDataIdentifier("_id_private_groups")
private let _id_secret_chats = InputDataIdentifier("_id_secret_chats")


private let _id_channels = InputDataIdentifier("_id_channels")
private let _id_bots = InputDataIdentifier("_id_bots")
private let _id_exclude_muted = InputDataIdentifier("_id_exclude_muted")
private let _id_exclude_read = InputDataIdentifier("_id_exclude_read")

private let _id_add_include = InputDataIdentifier("_id_add_include")
private let _id_add_exclude = InputDataIdentifier("_id_add_exclude")

private let _id_show_all_include = InputDataIdentifier("_id_show_all_include")
private let _id_show_all_exclude = InputDataIdentifier("_id_show_all_exclude")
private let _id_header = InputDataIdentifier("_id_header")
private let _id_loading_links = InputDataIdentifier("_id_loading_links")
private let _id_share_invite = InputDataIdentifier("_id_share_invite")

private let _id_color = InputDataIdentifier("_id_color")
private let _id_reset_color = InputDataIdentifier("_id_color")
private func _id_invite_link(_ string: String) -> InputDataIdentifier {
    return InputDataIdentifier("_id_invite_link\(string)")
}

private func _id_include(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_include_\(peerId)")
}
private func _id_exclude(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_exclude_\(peerId)")
}
private func chatListFilterEntries(state: State, includePeers: [Peer], excludePeers: [Peer], arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    
    let maximumPeers = arguments.context.isPremium ? arguments.context.premiumLimits.dialog_filters_chats_limit_premium : arguments.context.premiumLimits.dialog_filters_chats_limit_default
    
    var includePeers:[Peer] = includePeers
    var excludePeers:[Peer] = excludePeers

    switch state.filter {
    case .allChats:
        break
    case let .filter(id, title, emoticon, data):
        if data.categories.contains(.groups) {
            includePeers.insert(TelegramFilterCategory(category: .groups), at: 0)
        }
        if data.categories.contains(.channels) {
            includePeers.insert(TelegramFilterCategory(category: .channels), at: 0)
        }
        if data.categories.contains(.contacts) {
            includePeers.insert(TelegramFilterCategory(category: .contacts), at: 0)
        }
        if data.categories.contains(.nonContacts) {
            includePeers.insert(TelegramFilterCategory(category: .nonContacts), at: 0)
        }
        if data.categories.contains(.bots) {
            includePeers.insert(TelegramFilterCategory(category: .bots), at: 0)
        }
        
        
        if data.excludeMuted {
            excludePeers.insert(TelegramFilterCategory(category: .excludeMuted), at: 0)
        }
        if data.excludeRead {
            excludePeers.insert(TelegramFilterCategory(category: .excludeRead), at: 0)
        }
        if data.excludeArchived {
            excludePeers.insert(TelegramFilterCategory(category: .excludeArchived), at: 0)
        }
        
        var sectionId:Int32 = 0
        var index: Int32 = 0
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        if state.isNew {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
                let attributedString = NSMutableAttributedString()
                return ChatListFiltersHeaderItem(initialSize, context: arguments.context, stableId: stableId, sticker: LocalAnimatedSticker.new_folder, text: attributedString)
            }))
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterNameHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem, rightItem: .init(isLoading: false, text: .initialize(string: state.nameAnimation ? strings().chatListFolderDisableAnimations : strings().chatListFolderEnableAnimations, color: theme.colors.accent, font: .normal(.text)), action: arguments.toggleNameAnimation))))
        index += 1
        
        //InputTextDataRowItem
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_name_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return InputTextDataRowItem(initialSize, stableId: stableId, context: arguments.context, state: state.inputState, viewType: .singleItem, placeholder: nil, inputPlaceholder: strings().chatListFilterNamePlaceholder, rightItem: InputDataRightItem.action(FolderIcon(state.filter).icon(for: .settings), .custom{ item, control in
                showPopover(for: control, with: ChatListFilterFolderIconController(arguments.context, select: arguments.updateIcon), edge: .minX, inset: NSMakePoint(0,-45))
            }), filter: { $0 }, updateState: arguments.updateState, limit: 12, hasEmoji: true, playAnimation: state.nameAnimation)
        }))
        
        index += 1
        
//        entries.append(.sectionId(sectionId, type: .normal))
//        sectionId += 1
//        
//        entries.append(.input(sectionId: sectionId, index: index, value: .string(title), error: nil, identifier: _id_name_input, mode: .plain, data: .init(viewType: .singleItem, rightItem: InputDataRightItem.action(FolderIcon(state.filter).icon(for: .settings), .custom{ item, control in
//            showPopover(for: control, with: ChatListFilterFolderIconController(arguments.context, select: arguments.updateIcon), edge: .minX, inset: NSMakePoint(0,-45))
//        })), placeholder: nil, inputPlaceholder: strings().chatListFilterNamePlaceholder, filter: { $0 }, limit: 12))
//        index += 0
       
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterIncludeHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        let hasAddInclude = data.includePeers.peers.count < maximumPeers || data.categories != .all
        
        if hasAddInclude  {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_include, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().chatListFilterIncludeAddChat, nameStyle: blueActionButton, type: .none, viewType: includePeers.isEmpty ? .singleItem : .firstItem, action: arguments.addInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 4), context: arguments.context)
            }))
            index += 0
        }
       
        
        
        var fake:[Int] = []
        fake.append(0)
        for (i, _) in includePeers.enumerated() {
            if hasAddInclude {
                fake.append(i + 1)
            } else {
                fake.append(i)
            }
        }
        
        for (i, peer) in includePeers.enumerated() {
            
            struct E : Equatable {
                let viewType: GeneralViewType
                let peer: PeerEquatable
            }
            
            if i > 10, !state.showAllInclude {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_show_all_include, equatable: InputDataEquatable(includePeers.count), comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().chatListFilterShowMoreCountable(includePeers.count - i), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.showAllInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                }))
                index += 0
                break
            } else {
                var viewType = bestGeneralViewType(fake, for: hasAddInclude ? i + 1 : i)
                
                if excludePeers.count > 10, i == includePeers.count - 1, state.showAllInclude {
                    viewType = .innerItem
                }
                
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_include(peer.id), equatable: InputDataEquatable(E(viewType: viewType, peer: PeerEquatable(peer))), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), inset: NSEdgeInsets(left: 20, right: 20), viewType: viewType, action: {
                        arguments.openInfo(peer.id)
                    }, contextMenuItems: {
                        return .single([ContextMenuItem(strings().chatListFilterIncludeRemoveChat, handler: {
                            arguments.removeIncluded(peer.id)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
                    })
                }))
                index += 0
            }
        }
        
        if includePeers.count > 10, state.showAllInclude {
            struct T: Equatable {
                let a: Bool
                let b: Int
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_show_all_include, equatable: InputDataEquatable(T(a: state.showAllInclude, b: includePeers.count)), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().chatListFilterHideCountable(includePeers.count - 11), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.showAllInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchDown, textInset: 52, thumbInset: 4))
            }))
            index += 0
        }
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterIncludeDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        if !data.isShared {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterExcludeHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
            index += 1
            
            let hasAddExclude = (data.excludePeers.count < maximumPeers || !data.excludeRead || !data.excludeMuted || !data.excludeArchived)

            
            if hasAddExclude {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_exclude, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().chatListFilterExcludeAddChat, nameStyle: blueActionButton, type: .none, viewType: excludePeers.isEmpty ? .singleItem : .firstItem, action: arguments.addExclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 2))
                }))
                index += 0
            }
            fake = []
            fake.append(0)
            for (i, _) in excludePeers.enumerated() {
                if hasAddExclude {
                    fake.append(i + 1)
                } else {
                    fake.append(i)
                }
            }
            
            for (i, peer) in excludePeers.enumerated() {
                struct E : Equatable {
                    let viewType: GeneralViewType
                    let peer: PeerEquatable
                }
                if i > 10, !state.showAllExclude {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_show_all_exclude, equatable: InputDataEquatable(excludePeers.count), comparable: nil, item: { initialSize, stableId in
                        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().chatListFilterShowMoreCountable(excludePeers.count - i), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.showAllExclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                    }))
                    index += 0
                    break
                } else {
                    var viewType = bestGeneralViewType(fake, for: hasAddExclude ? i + 1 : i)
                    
                    if excludePeers.count > 10, i == excludePeers.count - 1, state.showAllExclude {
                        viewType = .innerItem
                    }
                    
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_exclude(peer.id), equatable: InputDataEquatable(E(viewType: viewType, peer: PeerEquatable(peer))), comparable: nil, item: { initialSize, stableId in
                        return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), inset: NSEdgeInsets(left: 20, right: 20), viewType: viewType, action: {
                            arguments.openInfo(peer.id)
                        }, contextMenuItems: {
                            return .single([ContextMenuItem.init(strings().chatListFilterExcludeRemoveChat, handler: {
                                arguments.removeExcluded(peer.id)
                            })])
                        })
                    }))
                    index += 0
                }
                
            }
            
            if excludePeers.count > 10, state.showAllExclude {
                
                struct T: Equatable {
                    let a: Bool
                    let b: Int
                }
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_show_all_exclude, equatable: InputDataEquatable(T(a: state.showAllExclude, b: excludePeers.count)), comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().chatListFilterHideCountable(excludePeers.count - 11), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.showAllExclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchDown, textInset: 52, thumbInset: 4))
                }))
                index += 0
            }
            
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterExcludeDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1
        }
            
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let colors = [theme.colors.peerColors(0).bottom,
                      theme.colors.peerColors(1).bottom,
                      theme.colors.peerColors(2).bottom,
                      theme.colors.peerColors(3).bottom,
                      theme.colors.peerColors(4).bottom,
                      theme.colors.peerColors(5).bottom,
                      theme.colors.peerColors(6).bottom]
        
        let currentColor = state.filter.data?.color
        let selected: NSColor? = currentColor != nil ? colors[Int(currentColor!.rawValue)] : nil

        let rightText: NSAttributedString?
        if state.filter.data?.color != nil {
            let attr = NSMutableAttributedString()
            attr.append(string: state.filter.title, color: selected, font: .bold(11))
            InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: state.filter.entities, isPremium: true)
            rightText = attr
        } else {
            rightText = nil
        }
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFolderColorTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, rightItem: .init(isLoading: false, text: rightText, action: nil, update: nil, alignToText: true, wrap: selected?.withAlphaComponent(0.1)), context: arguments.context)))
        index += 1
        
      
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_color, equatable: InputDataEquatable(state.filter.data), comparable: nil, item: { initialSize, stableId in
            return FolderColorRowItem(initialSize, stableId: stableId, context: arguments.context, colors: colors, selected: selected, viewType: state.filter.data?.color == nil ? .singleItem : .firstItem, action: { color in
                arguments.toggleColor(colors.firstIndex(of: color).flatMap { Int32($0) })
            })
        }))
        
        if state.filter.data?.color != nil {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset_color, data: .init(name: strings().chatListFolderColorReset, color: theme.colors.redUI, viewType: .lastItem, action: {
                arguments.toggleColor(nil)
            })))
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFolderColorInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        if true {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterInviteLinkHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
            index += 1
            
            let viewType: GeneralViewType
            
            if let invite = state.inviteLinks, !invite.isEmpty {
                viewType = .firstItem
            } else if state.inviteLinks == nil {
                viewType = .singleItem
            } else {
                viewType = .singleItem
            }
            
            let text: String
            if let invite = state.inviteLinks, !invite.isEmpty {
                text = strings().chatListFilterInviteLink
            } else {
                text = strings().chatListFilterInviteLinkShare
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_share_invite, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: blueActionButton, type: state.creatingLink || state.inviteLinks == nil ? .loading : .none, viewType: viewType, action: {
                    arguments.shareFolder(nil)
                }, thumb: GeneralThumbAdditional(thumb: theme.icons.group_invite_via_link, textInset: 52, thumbInset: 4))
            }))
            index += 0
            
           
            
            if let links = state.inviteLinks {
                struct Tuple : Equatable {
                    let link:ExportedChatFolderLink
                    let viewType: GeneralViewType
                    let saving: Bool
                }
                var items: [Tuple] = []
                for (i, link) in links.enumerated() {
                    items.append(.init(link: link, viewType: bestGeneralViewTypeAfterFirst(links, for: i), saving: state.linkSaving == link.link))
                }
                
                for item in items {
                    
                    let info: String
                    info = strings().chatListFilterInviteLinkDescCountable(item.link.peerIds.count)

                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_invite_link(item.link.slug), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                        return GeneralInteractedRowItem(initialSize, name: item.link.title.isEmpty ? item.link.link : item.link.title, description: info, type: item.saving ? .loading : .none, viewType: item.viewType, action: {
                            arguments.shareFolder(item.link)
                        }, thumb: GeneralThumbAdditional(thumb: item.link.isRevoked ? theme.icons.folder_invite_link_revoked : theme.icons.folder_invite_link, textInset: 52, thumbInset: 4), menuItems: {
                            var items: [ContextMenuItem] = []
                            
                            items.append(ContextMenuItem(strings().contextCopy, handler: {
                                arguments.copy(item.link.link)
                            }, itemImage: MenuAnimation.menu_copy.value))
                                         
                            items.append(ContextSeparatorItem())
                            
                            items.append(ContextMenuItem(strings().chatListFilterInviteLinkDelete, handler: {
                                arguments.deleteLink(item.link)
                            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))

                            
                            return items
                        })
                    }))
                    index += 0
                }
            }
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterInviteLinkInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1

            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }

    }

    return entries
}

func ChatListFilterController(context: AccountContext, filter: ChatListFilter, isNew: Bool = false) -> InputDataController {
    
    
    let title = ChatTextInputState(inputText: filter.title, selectionRange: filter.title.length..<filter.title.length, attributes: chatTextAttributes(from: TextEntitiesMessageAttribute(entities: filter.entities), associatedMedia: [:]))
    
    let initialState = State(filter: filter, isNew: isNew, showAllInclude: false, showAllExclude: false, changedName: !isNew, inviteLinks: nil, creatingLink: false, linkSaving: nil, inputState: title.textInputState(), nameAnimation: true)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let maximumPeers = context.isPremium ? context.premiumLimits.dialog_filters_chats_limit_premium : context.premiumLimits.dialog_filters_chats_limit_default
    
    
    let updateDisposable = MetaDisposable()
    
    var getController:(()->InputDataController?)? = nil
    
    let save:(Bool)->Void = { savedOnServer in
        _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
            let filter = stateValue.with { $0.filter }
            var filters = filters
            if let index = filters.firstIndex(where: {$0.id == filter.id}) {
                filters[index] = filter
            } else {
                filters.append(filter)
            }
            return filters
        }).start()
        
        if savedOnServer {
            updateState { current in
                var current = current
                current.isNew = false
                return current
            }
        }
    }
    
    let actionsDisposable = DisposableSet()

    
    let arguments = ChatListPresetArguments(context: context, toggleOption: { option in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                switch filter {
                case .allChats:
                    break
                case let .filter(id, title, emoticon, data):
                    var data = data
                    if data.categories.contains(option) {
                        data.categories.remove(option)
                    } else {
                        data.categories.insert(option)
                    }
                    filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                }
                
                return filter
            }
            return state
        }
       // save(true)
        
    }, addInclude: {
        
        let items = stateValue.with { $0.filter.additionIncludeItems }
        let additionTopItems = items.isEmpty ? nil : ShareAdditionItems(items: items, topSeparator: strings().chatListAddTopSeparator, bottomSeparator: strings().chatListAddBottomSeparator)
        
        showModal(with: ShareModalController(SelectCallbackObject(context, defaultSelectedIds: Set(stateValue.with { $0.filter.data!.includePeers.peers + $0.filter.selectedIncludeItems.map { $0.peer.id } }), additionTopItems: additionTopItems, limit: Int(maximumPeers), limitReachedText: strings().chatListFilterIncludeLimitReachedNew(Int(maximumPeers)), callback: { peerIds in
            updateState { state in
                var state = state
                
                let categories = peerIds.filter {
                    $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
                }
                let peerIds = Set(peerIds).subtracting(categories)
                
                state.withUpdatedFilter { filter in
                    var filter = filter
                    switch filter {
                    case .allChats:
                        break
                    case let .filter(id, title, emoticon, data):
                        var data = data
                        data.includePeers.setPeers(Array(peerIds.uniqueElements.prefix(Int(maximumPeers))))
                        var updatedCats: ChatListFilterPeerCategories = []
                        let cats = categories.map { ChatListFilterPeerCategories(rawValue: Int32($0.id._internalGetInt64Value())) }
                        for cat in cats {
                            updatedCats.insert(cat)
                        }
                        data.categories = updatedCats
                        filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                    }
                    
                    return filter
                }
                return state
            }
         //   save(true)
            return .complete()
        })), for: context.window)
    }, addExclude: {
        
        let items = stateValue.with { $0.filter.additionExcludeItems }
        let additionTopItems = items.isEmpty ? nil : ShareAdditionItems(items: items, topSeparator: strings().chatListAddTopSeparator, bottomSeparator: strings().chatListAddBottomSeparator)
        
        showModal(with: ShareModalController(SelectCallbackObject(context, defaultSelectedIds: Set(stateValue.with { $0.filter.data!.excludePeers + $0.filter.selectedExcludeItems.map { $0.peer.id } }), additionTopItems: additionTopItems, limit: Int(maximumPeers), limitReachedText: strings().chatListFilterExcludeLimitReachedNew(Int(maximumPeers)), callback: { peerIds in
            updateState { state in
                var state = state
                state.withUpdatedFilter { filter in
                    var filter = filter
                    switch filter {
                    case .allChats:
                        break
                    case let .filter(id, title, emoticon, data):
                        var data = data
                        let categories = peerIds.filter {
                            $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
                        }
                        let peerIds = Set(peerIds).subtracting(categories)
                        data.excludePeers = Array(peerIds.uniqueElements.prefix(Int(maximumPeers)))
                        for cat in categories {
                            if ChatListFilterPeerCategories(rawValue: Int32(cat.id._internalGetInt64Value())) == .excludeMuted {
                                data.excludeMuted = true
                            }
                            if ChatListFilterPeerCategories(rawValue: Int32(cat.id._internalGetInt64Value())) == .excludeRead {
                                data.excludeRead = true
                            }
                            if ChatListFilterPeerCategories(rawValue: Int32(cat.id._internalGetInt64Value())) == .excludeArchived {
                                data.excludeArchived = true
                            }
                        }
                        filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                    }
                    
                    
                    return filter
                }
                return state
            }
            //   save(true)
            return .complete()
        })), for: context.window)
    }, removeIncluded: { peerId in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                switch filter {
                case .allChats:
                    break
                case let .filter(id, title, emoticon, data):
                    var data = data
                    var peers = data.includePeers.peers
                    peers.removeAll(where: { $0 == peerId })
                    data.includePeers.setPeers(peers)
                    if peerId.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace  {
                        data.categories.remove(ChatListFilterPeerCategories(rawValue: Int32(peerId.id._internalGetInt64Value())))
                    }
                    return .filter(id: id, title: title, emoticon: emoticon, data: data)
                }
                
                return filter
            }
            return state
        }
        //save(true)
    }, removeExcluded: { peerId in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                switch filter {
                case .allChats:
                    break
                case let .filter(id, title, emoticon, data):
                    var data = data
                    var peers = data.excludePeers
                    peers.removeAll(where: { $0 == peerId })
                    data.excludePeers = peers
                    if peerId.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace  {
                        if ChatListFilterPeerCategories(rawValue: Int32(peerId.id._internalGetInt64Value())) == .excludeMuted {
                            data.excludeMuted = false
                        }
                        if ChatListFilterPeerCategories(rawValue: Int32(peerId.id._internalGetInt64Value())) == .excludeRead {
                            data.excludeRead = false
                        }
                        if ChatListFilterPeerCategories(rawValue: Int32(peerId.id._internalGetInt64Value())) == .excludeArchived {
                            data.excludeArchived = false
                        }
                    }
                    filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                }
                
                return filter
            }
            return state
        }
        //save(true)
    }, openInfo: { peerId in
        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
    }, toggleExcludeMuted: { updated in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                switch filter {
                case .allChats:
                    break
                case let .filter(id, title, emoticon, data):
                    var data = data
                    data.excludeMuted = updated
                    filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                }
                return filter
            }
            return state
        }
       // save(true)
    }, toggleExcludeRead: { updated in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                switch filter {
                case .allChats:
                    break
                case let .filter(id, title, emoticon, data):
                    var data = data
                    data.excludeRead = updated
                    filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                }
                return filter
            }
            return state
        }
        //save(true)
    }, showAllInclude: {
        updateState { state in
            var state = state
            state.showAllInclude = !state.showAllInclude
            return state
        }
    }, showAllExclude: {
        updateState { state in
            var state = state
            state.showAllExclude = !state.showAllExclude
            return state
        }
    }, updateIcon: { icon in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                switch filter {
                case .allChats:
                    break
                case let .filter(id, title, _, data):
                    filter = .filter(id: id, title: title, emoticon: icon.emoticon.emoji, data: data)
                }
                return filter
            }
            return state
        }
    }, shareFolder: { link in
        let filter = stateValue.with { $0.filter }
        let initialFilter = stateValue.with { $0.initialFilter }
        let isLoading = stateValue.with { $0.creatingLink }
        
        let updateLink:(ExportedChatFolderLink, ExportedChatFolderLink?)->Void = { link, updated in
            updateState { current in
                var current = current
                current.creatingLink = false
                if let index = current.inviteLinks?.firstIndex(where: { $0.link == link.link }) {
                    current.inviteLinks?.remove(at: index)
                    if let updated = updated {
                        current.inviteLinks?.insert(updated, at: index)
                    }
                }
                return current
            }
        }
        
        if let data = filter.data, !isLoading {
            if link == nil {
                updateState { current in
                    var current = current
                    current.creatingLink = true
                    return current
                }
                let emptyTitle = stateValue.with { value -> Bool in
                    switch value.filter {
                    case .allChats:
                        return true
                    case let .filter(_, title, _, _):
                        return title.text.isEmpty
                    }
                }
                let emptyPeers = stateValue.with { value -> Bool in
                    switch value.filter {
                    case .allChats:
                        return true
                    case let .filter(_, _, _, data):
                        return data.includePeers.peers.isEmpty
                    }
                }
                let exclude = stateValue.with {
                    $0.filter.excludeAllPeers
                }
                let wrongInclude = stateValue.with {
                    return $0.filter.includeCustom
                }
                if emptyTitle || emptyPeers || !exclude.isEmpty || !wrongInclude.isEmpty {
                    updateState { current in
                        var current = current
                        current.creatingLink = false
                        return current
                    }
                    var fail: [InputDataIdentifier : InputDataValidationFailAction] = [:]
                    if emptyTitle {
                        fail[_id_name_input] = .shake
                    } else if !wrongInclude.isEmpty {
                        for id in wrongInclude {
                            fail[_id_include(id)] = .shake
                        }
                        showModalText(for: context.window, text: strings().chatListFilterInviteLinkIncludeExcludeError)
                    } else if emptyPeers {
                        showModalText(for: context.window, text: strings().chatListFilterErrorEmpty)
                        fail[_id_add_include] = .shake
                    } else if !exclude.isEmpty {
                        for id in exclude {
                            fail[_id_exclude(id)] = .shake
                        }
                        showModalText(for: context.window, text: strings().chatListFilterInviteLinkIncludeExcludeError)
                    }
  
                    getController?()?.proccessValidation(.fail(.fields(fail)))
                    return
                }
                
                let signal: Signal<Never, RequestUpdateChatListFilterError>
                if initialFilter == filter {
                    signal = .complete()
                } else {
                    signal = context.engine.peers.requestUpdateChatListFilter(id: filter.id, filter: filter) |> deliverOnMainQueue
                }
                                
                actionsDisposable.add(signal.start(error: { error in
                    alert(for: context.window, info: strings().unknownError)
                    
                    updateState { current in
                        var current = current
                        current.creatingLink = false
                        return current
                    }
                }, completed: {
                    
                    updateState { current in
                        var current = current
                        current.initialFilter = filter
                        return current
                    }
                    
                    save(true)
                    
                    let folderLimits = shareFolderPremiumLimits(context: context, current: filter, links: stateValue.with { $0.inviteLinks })
                                        
                    let canCreateLink: Signal<Bool, NoError> = context.account.postbox.transaction { transaction -> Bool in
                        var peers:[Peer] = []
                                                
                        for peerId in data.includePeers.peers {
                            if let peer = transaction.getPeer(peerId) {
                                peers.append(peer)
                            }
                        }
                        return !peers.filter( { peerCanBeSharedInFolder($0) }).isEmpty
                    } |> deliverOnMainQueue
                    
                    _ = combineLatest(folderLimits, canCreateLink).start(next: { limits, canCreateLink in
                        if canCreateLink {
                            
                            if limits.limitInvites || limits.limitFilters {
                                if limits.limitFilters {
                                    showPremiumLimit(context: context, type: .sharedFolders)
                                } else if limits.limitInvites {
                                    showPremiumLimit(context: context, type: .sharedInvites)
                                }
                                updateState { current in
                                    var current = current
                                    current.creatingLink = false
                                    return current
                                }
                                return
                            }
                            
                            let makeUrl = context.engine.peers.exportChatFolder(filterId: filter.id, title: "", peerIds: data.includePeers.peers) |> deliverOnMainQueue
                            actionsDisposable.add(makeUrl.start(next: { link in
                                updateState { current in
                                    var current = current
                                    current.creatingLink = false
                                    current.inviteLinks?.append(link)
                                    var filter = current.filter
                                    var data = data
                                    data.isShared = true
                                    for peerId in link.peerIds.reversed() {
                                        _ = data.includePeers.addPeer(peerId)
                                    }
                                    filter = filter.withUpdatedData(data)
                                    current.filter = filter
                                    current.initialFilter = filter
                                    return current
                                }
                                save(false)
                                showModal(with: ShareCloudFolderController(context: context, filter: stateValue.with { $0.filter }, link: link, updated: updateLink), for: context.window)
                            }, error: { error in
                                
                                switch error {
                                case .limitExceeded:
                                    showPremiumLimit(context: context, type: .sharedInvites)
                                case .sharedFolderLimitExceeded:
                                    showPremiumLimit(context: context, type: .sharedFolders)
                                case .tooManyChannels:
                                    showInactiveChannels(context: context, source: .join)
                                case .tooManyChannelsInAccount:
                                    showPremiumLimit(context: context, type: .channels)
                                case .someUserTooManyChannels:
                                    alert(for: context.window, info: strings().sharedFolderErrorSomeUserTooMany)
                                case .generic:
                                    alert(for: context.window, info: strings().unknownError)
                                }
                                
                                updateState { current in
                                    var current = current
                                    current.creatingLink = false
                                    return current
                                }
                            }))
                        } else {
                            updateState { current in
                                var current = current
                                current.creatingLink = false
                                return current
                            }
                            showModal(with: ShareCloudFolderController(context: context, filter: filter, link: nil, updated: updateLink), for: context.window)
                        }
                    })
                }))
                
                
            } else {
                
                let signal: Signal<Never, RequestUpdateChatListFilterError>
                if initialFilter == filter {
                    signal = .complete()
                } else {
                    updateState { current in
                        var current = current
                        current.linkSaving = link?.link
                        return current
                    }
                    signal = context.engine.peers.requestUpdateChatListFilter(id: filter.id, filter: filter) |> deliverOnMainQueue
                }
                
                actionsDisposable.add(signal.start(error: { error in
                    alert(for: context.window, info: strings().unknownError)
                    updateState { current in
                        var current = current
                        current.linkSaving = nil
                        return current
                    }
                }, completed: {
                    updateState { current in
                        var current = current
                        current.linkSaving = nil
                        current.initialFilter = filter
                        return current
                    }
                    
                    save(true)
                    
                    showModal(with: ShareCloudFolderController(context: context, filter: filter, link: link, updated: updateLink), for: context.window)
                }))
                
            }
        }
    }, copy: { link in
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
        copyToClipboard(link)
    }, deleteLink: { link in
        verifyAlert_button(for: context.window, information: strings().chatListFilterInviteLinkDeleteConfirm, ok: strings().chatListFilterInviteLinkDelete, successHandler: { _ in
            
            var index: Int? = nil
            updateState { current in
                var current = current
                index = current.inviteLinks?.firstIndex(of: link)
                if let index = index {
                    current.inviteLinks?.remove(at: index)
                }
                return current
            }
            let signal = context.engine.peers.deleteChatFolderLink(filterId: filter.id, link: link) |> deliverOnMainQueue
            
            actionsDisposable.add(signal.start(error: { error in
                alert(for: context.window, info: strings().unknownError)
                updateState { current in
                    var current = current
                    if let index = index {
                        current.inviteLinks?.insert(link, at: index)
                    }
                    return current
                }
            }))
            
        })
    }, toggleColor: { color in
        if let _ = color, !context.isPremium {
            showModalText(for: context.window, text: strings().chatListFolderPremiumAlert, button: strings().alertLearnMore, callback: { _ in
                prem(with: PremiumBoardingController(context: context, source: .folder_tags, openFeatures: true), for: context.window)
            })
        } else {
            updateState { current in
                var current = current
                switch current.filter {
                case .allChats:
                    current.filter = .allChats
                case .filter(let id, let title, let emoticon, var data):
                    data.color = color.flatMap { .init(rawValue: $0) }
                    current.filter = .filter(id: id, title: title, emoticon: emoticon, data: data)
                }
                return current
            }
        }
    }, updateState: { state in
        updateState { current in
            var current = current
            current.inputState = state
            current.changedName = true
            current.filter = current.filter.withUpdatedTitle(string: current.inputState.string, entities: current.inputState.textInputState().messageTextEntities(), enableAnimations: current.nameAnimation)
            return current
        }
    }, toggleNameAnimation: {
        updateState { current in
            var current = current
            current.nameAnimation = !current.nameAnimation
            current.filter = current.filter.withUpdatedTitle(string: current.inputState.string, entities: current.inputState.textInputState().messageTextEntities(), enableAnimations: current.nameAnimation)
            return current
        }
    })
    
    
    let inviteLinks: Signal<[ExportedChatFolderLink]?, NoError>
    
    if isNew {
        inviteLinks = .single([])
    } else {
        inviteLinks = .single(nil) |> then(context.engine.peers.getExportedChatFolderLinks(id: filter.id) |> map {
            $0 ?? []
        })
    }
    
    
    actionsDisposable.add(inviteLinks.start(next: { links in
        updateState { current in
            var current = current
            current.inviteLinks = links
            return current
        }
    }))
    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, statePromise.get()) |> mapToSignal { _, state -> Signal<(State, ([Peer], [Peer])), NoError> in
        return context.account.postbox.transaction { transaction -> ([Peer], [Peer]) in
            switch state.filter {
            case .allChats:
                return ([], [])
            case let .filter(_, _, _, data):
                return (data.includePeers.peers.compactMap { transaction.getPeer($0) }, data.excludePeers.compactMap { transaction.getPeer($0) })
            }
        } |> map {
            (state, $0)
        }
    } |> map {
        return chatListFilterEntries(state: $0, includePeers: $1.0, excludePeers: $1.1, arguments: arguments)
    } |> map {
          return InputDataSignalValue(entries: $0)
    }

    
    let controller = InputDataController(dataSignal: dataSignal, title: isNew ? strings().chatListFilterNewTitle : strings().chatListFilterTitle, removeAfterDisappear: false)
    
    
    controller.backInvocation = { data, f in
        if stateValue.with({ $0.filter != $0.initialFilter }) {
            verifyAlert_button(for: context.window, header: strings().chatListFilterDiscardHeader, information: strings().chatListFilterDiscardText, ok: strings().chatListFilterDiscardOK, cancel: strings().chatListFilterDiscardCancel, successHandler: { _ in
                f(true)
            })
        } else {
            f(true)
        }
        
    }
    
    controller.updateDoneValue = { data in
        return { f in
            if stateValue.with({ $0.isNew }) {
                f(.enabled(strings().chatListFilterDone))
            } else {
                f(.enabled(strings().navigationDone))
            }
        }
    }
    
    controller.onDeinit = {
        updateDisposable.dispose()
        actionsDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.afterTransaction = { controller in
        let type = stateValue.with { chatListFilterType($0.filter) }
        let nameIsUpdated = stateValue.with { $0.changedName }
        
        
        if !nameIsUpdated {
            switch type {
            case .generic:
                break
            case .unmuted:
                //state.name = presentationData.strings.ChatListFolder_NameNonMuted
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultUnmuted, entities: [], enableAnimations: false)
                  //  emoticon =
                    return state
                }
            case .unread:
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultUnread, entities: [], enableAnimations: false)
                    return state
                }
            case .channels:
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultChannels, entities: [], enableAnimations: false)
                    return state
                }
            case .groups:
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultGroups, entities: [], enableAnimations: false)
                    return state
                }
            case .bots:
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultBots, entities: [], enableAnimations: false)
                    return state
                }
            case .contacts:
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultContacts, entities: [], enableAnimations: false)
                    return state
                }
            case .nonContacts:
                updateState { state in
                    var state = state
                    state.filter = state.filter.withUpdatedTitle(string: strings().chatListFilterTilteDefaultNonContacts, entities: [], enableAnimations: false)
                    return state
                }
            }

        }
    }
    
    controller.validateData = { data in
        
        return .fail(.doSomething(next: { f in
            let titleLength = stateValue.with { value -> Int in
                switch value.filter {
                case .allChats:
                    return 1
                case .filter:
                    return value.inputState.inputText.string.length
                }
            }
            if titleLength == 0 || titleLength > 12 {
                f(.fail(.fields([_id_name_input : .shake])))
                return
            }
            
            let filter = stateValue.with { $0.filter }
            
            if filter.isFullfilled {
                showModalText(for: context.window, text: strings().chatListFilterErrorLikeChats)
            } else if filter.isEmpty {
                showModalText(for: context.window, text: strings().chatListFilterErrorEmpty)
                f(.fail(.fields([_id_add_include : .shake])))
            } else {
                if stateValue.with({ $0.initialFilter != filter }) {
                    _ = showModalProgress(signal: context.engine.peers.requestUpdateChatListFilter(id: filter.id, filter: filter), for: context.window).start(error: { error in
                        switch error {
                        case .generic:
                            alert(for: context.window, info: strings().unknownError)
                        }
                    }, completed: {
                        save(true)
                        f(.success(.navigationBack))
                    })
                } else {
                    save(false)
                    f(.success(.navigationBack))
                }
            }            
        }))
    }
    
    return controller
    
}



