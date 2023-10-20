//
//  SelectColorController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppSettings

private final class EmojiSelectRowItem : GeneralRowItem {
    let getView: ()->NSView
    let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, getView: @escaping()->NSView, viewType: GeneralViewType) {
        self.getView = getView
        self.context = context
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return EmojiSelectRowView.self
    }
    
    
    
    override var height: CGFloat {
        return 300
    }
    override var instantlyResize: Bool {
        return true
    }
    override var reloadOnTableHeightChanged: Bool {
        return true
    }
}


private final class EmojiSelectRowView: GeneralContainableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? EmojiSelectRowItem else {
            return
        }
        let view = item.getView()
        view.frame = self.containerView.bounds

    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? EmojiSelectRowItem else {
            return
        }
        let view = item.getView()
        addSubview(view)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private class PreviewRowItem: GeneralRowItem {

    fileprivate let theme: TelegramPresentationTheme
    fileprivate let items:[TableRowItem]
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: Peer, nameColor: PeerNameColor, backgroundEmojiId: Int64?, context: AccountContext, theme: TelegramPresentationTheme, viewType: GeneralViewType) {
        self.theme = theme.withUpdatedBackgroundSize(WallpaperDimensions.aspectFilled(NSMakeSize(200, 200)))
        
        let peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(0))
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(peerId), context: context, isLogInteraction: true, disableSelectAbility: true, isGlobalSearchMessage: true)
        
        let previewPeer: Peer?
        if let peer = peer as? TelegramUser {
            previewPeer = TelegramUser(id: peerId, accessHash: peer.accessHash, firstName: peer.firstName, lastName: peer.lastName, username: peer.username, phone: peer.phone, photo: peer.photo, botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId)
        } else if let peer = peer as? TelegramChannel {
            previewPeer = TelegramChannel(id: peerId, accessHash: peer.accessHash, title: peer.title, username: peer.username, photo: peer.profileImageRepresentations, creationDate: peer.creationDate, version: peer.version, participationStatus: peer.participationStatus, info: peer.info, flags: peer.flags, restrictionInfo: peer.restrictionInfo, adminRights: peer.adminRights, bannedRights: peer.bannedRights, defaultBannedRights: peer.defaultBannedRights, usernames: peer.usernames, storiesHidden: peer.storiesHidden, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId)
        } else {
            previewPeer = nil
        }
      
           

        
                
        
        if let previewPeer = previewPeer {
            
            let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: previewPeer.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 18 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: previewPeer, text: strings().selectColorMessage1, attributes: [], media: [], peers:SimpleDictionary([previewPeer.id : previewPeer]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])

            
            let timestamp1: Int32 = 60 * 20 + 60 * 60 * 18
            
            let media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: TelegramMediaWebpageContent.Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: "photo", websiteName: appName, title: strings().selectColorMessage2PreviewTitle, text: strings().selectColorMessage2PreviewText, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)))

            let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: previewPeer.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: timestamp1, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: previewPeer, text: strings().selectColorMessage2, attributes: [ReplyMessageAttribute(messageId: firstMessage.id, threadMessageId: nil, quote: nil)], media: [media], peers:SimpleDictionary([previewPeer.id : previewPeer]) , associatedMessages: SimpleDictionary([firstMessage.id : firstMessage]), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
            
            let item2 = ChatRowItem.item(initialSize, from: secondEntry, interaction: chatInteraction, theme: theme)
            self.items = [item2]
        } else {
            self.items = []
        }
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        chatInteraction.getGradientOffsetRect = { [weak self] in
            guard let `self` = self else {
                return .zero
            }
            return CGRect(origin: NSMakePoint(0, self.height), size: NSMakeSize(self.width, self.height))
        }
        
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let itemWidth = self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right
        for item in items {
            _ = item.makeSize(itemWidth, oldWidth: 0)
        }
        return true
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = self.viewType.innerInset.top + self.viewType.innerInset.bottom
        
        for item in self.items {
            height += item.height
        }
        return height
    }
    
    override func viewClass() -> AnyClass {
        return PreviewRowView.self
    }
    
}

private final class PreviewRowView : GeneralContainableRowView {
    private let backgroundView: BackgroundView
    private let itemsView = View()
    required init(frame frameRect: NSRect) {
        backgroundView = BackgroundView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        backgroundView.useSharedAnimationPhase = false
        super.init(frame: frameRect)
        addSubview(self.backgroundView)
        self.backgroundView.addSubview(itemsView)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PreviewRowItem else {
            return
        }
        
        self.layout()
        
        self.itemsView.removeAllSubviews()
        
    
        var y: CGFloat = item.viewType.innerInset.top
        for item in item.items {
            let vz = item.viewClass() as! TableRowView.Type
            let view = vz.init(frame:NSMakeRect(0, y, self.backgroundView.frame.width, item.height))
            view.set(item: item, animated: false)
            self.itemsView.addSubview(view)
            
            if let view = view as? ChatRowView {
                view.updateBackground(animated: false, item: view.item, rotated: true)
            }
            
            y += item.height
        }
        
        
    }
    
    override func updateColors() {
        guard let item = item as? PreviewRowItem else {
            return
        }
        self.containerView.backgroundColor = background
        self.backgroundView.backgroundMode = item.theme.bubbled ? item.theme.backgroundMode : .color(color: item.theme.colors.chatBackground)
        self.borderView.backgroundColor = theme.colors.border
        self.backgroundColor = item.viewType.rowBackground
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? PreviewRowItem else {
            return
        }
        self.backgroundView.frame = self.containerView.bounds
        self.borderView.frame = NSMakeRect(0, self.containerView.frame.height - .borderSize, self.containerView.frame.width, .borderSize)
        itemsView.frame = backgroundView.bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private func generateRingImage(nameColor: PeerNameColor) -> CGImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setStrokeColor(nameColor.color.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
    })
}

private func generateFillImage(nameColor: PeerNameColor) -> CGImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let circleBounds = bounds
        context.addEllipse(in: circleBounds)
        context.clip()
        
        let (firstColor, secondColor) = nameColor.dashColors
        if let secondColor {
            context.setFillColor(secondColor.cgColor)
            context.fill(circleBounds)
            
            context.move(to: .zero)
            context.addLine(to: CGPoint(x: size.width, y: 0.0))
            context.addLine(to: CGPoint(x: 0.0, y: size.height))
            context.closePath()
            context.setFillColor(firstColor.cgColor)
            context.fillPath()
        } else {
            context.setFillColor(firstColor.cgColor)
            context.fill(circleBounds)
        }
    })
}


private enum PeerNameColorEntryId: Hashable {
    case color(Int32)
}

private enum PeerNameColorEntry: Comparable, Identifiable {
    case color(Int, PeerNameColor, Bool)
    
    var stableId: PeerNameColorEntryId {
        switch self {
            case let .color(_, color, _):
                return .color(color.rawValue)
        }
    }
    
    static func ==(lhs: PeerNameColorEntry, rhs: PeerNameColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, lhsAccentColor, lhsSelected):
                if case let .color(rhsIndex, rhsAccentColor, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsAccentColor == rhsAccentColor, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PeerNameColorEntry, rhs: PeerNameColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, _, _):
                switch rhs {
                    case let .color(rhsIndex, _, _):
                        return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(initialSize: NSSize, action: @escaping (PeerNameColor) -> Void) -> TableRowItem {
        switch self {
            case let .color(_, color, selected):
            return PeerNameColorIconItem(initialSize: initialSize, stableId: self.stableId,color: color, selected: selected, action: action)
        }
    }
}



private class PeerNameColorIconItem: TableRowItem {
    let color: PeerNameColor
    let selected: Bool
    let action: (PeerNameColor) -> Void
    
    public init(initialSize: NSSize, stableId: AnyHashable, color: PeerNameColor, selected: Bool, action: @escaping (PeerNameColor) -> Void) {
        self.color = color
        self.selected = selected
        self.action = action
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 55
    }
    override var width: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return PeerNameColorIconView.self
    }
}

private final class PeerNameColorIconView : TableRowView {
    
    private let fillView: SimpleLayer = SimpleLayer()
    private let ringView: SimpleLayer = SimpleLayer()
    private let control = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(ringView)
        self.layer?.addSublayer(fillView)
        addSubview(control)
        let bounds = CGRect(origin: CGPoint(x: 0, y: 10), size: CGSize(width: 40.0, height: 40.0))
        
        fillView.frame = bounds
        ringView.frame = bounds
                              
        
        control.frame = bounds
        
        
        control.set(handler: { [weak self] _ in
            guard let item = self?.item as? PeerNameColorIconItem else {
                return
            }
            item.action(item.color)
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var wasSelected: Bool = false
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerNameColorIconItem else {
            return
        }
        
        self.fillView.contents = generateFillImage(nameColor: item.color)
        self.ringView.contents = generateRingImage(nameColor: item.color)

        
//        self.fillView.opacity = item.selected ? 0 : 1

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

private final class PeerNamesRowItem : GeneralRowItem {
    fileprivate let colors: [PeerNameColor]
    fileprivate let selected: PeerNameColor
    fileprivate let selectAction:(PeerNameColor)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, colors: [PeerNameColor], selected: PeerNameColor, viewType: GeneralViewType, action: @escaping(PeerNameColor)->Void) {
        self.colors = colors
        self.selected = selected
        self.selectAction = action
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        return 50
    }
    
    override func viewClass() -> AnyClass {
        return PeerNamesRowView.self
    }
}

private final class PeerNamesRowView : GeneralContainableRowView {
    let tableView: HorizontalTableView
    required init(frame frameRect: NSRect) {
        tableView = HorizontalTableView(frame: frameRect)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    override func layout() {
        super.layout()
        tableView.frame = containerView.focus(NSMakeSize(containerView.frame.width, 40))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var previous: [PeerNameColorEntry] = []
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerNamesRowItem else {
            return
        }
        
        var entries: [PeerNameColorEntry] = []
        
        var index: Int = 0
        for color in item.colors {
            entries.append(.color(index, color, color == item.selected))
            index += 1
        }

        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previous, rightList: entries)
        
        let animation: NSTableView.AnimationOptions = animated ? .effectFade : .none
        
        for rdx in deleteIndices.reversed() {
            tableView.remove(at: rdx, animation: animation)
        }
        
        
        for (idx, entry, _) in indicesAndItems {
            _ = tableView.insert(item: entry.item(initialSize: bounds.size, action: item.selectAction), at: idx, animation: animation)
        }
        for (idx, entry, _) in updateIndices {
            let item = item
            tableView.replace(item: entry.item(initialSize: bounds.size, action: item.selectAction), at: idx, animated: animated)
        }
        

        self.previous = entries
        
    }
}


private final class Arguments {
    let context: AccountContext
    let source: SelectColorSource
    let toggleColor:(PeerNameColor) -> Void
    let getView:()->NSView
    init(context: AccountContext, source: SelectColorSource, toggleColor:@escaping(PeerNameColor) -> Void, getView:@escaping()->NSView) {
        self.context = context
        self.source = source
        self.toggleColor = toggleColor
        self.getView = getView
    }
}

private struct State : Equatable {
    var colors: [PeerNameColor] = [.blue,
        .red,
        .orange,
        .violet,
        .green,
        .cyan,
        .pink,
        .redDash,
        .orangeDash,
        .violetDash,
        .greenDash,
        .cyanDash,
        .blueDash]
    var selected: PeerNameColor = .blue
    var backgroundEmojiId: Int64? = nil
    var saving: Bool = false
}

private let _id_colors = InputDataIdentifier("_id_colors")
private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_emojies = InputDataIdentifier("_id_emojies")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().selectColorPreview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PreviewRowItem(initialSize, stableId: stableId, peer: arguments.source.peer, nameColor: state.selected, backgroundEmojiId: state.backgroundEmojiId, context: arguments.context, theme: theme, viewType: .firstItem)
    }))
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_colors, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PeerNamesRowItem(initialSize, stableId: stableId, colors: state.colors, selected: state.selected, viewType: .lastItem, action: { color in
            arguments.toggleColor(color)
        })
    }))
    
    let info: String
    switch arguments.source {
    case .account:
        info = strings().selectColorInfoUser
    case .channel:
        info = strings().selectColorInfoChannel
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(info), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emojies, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return EmojiSelectRowItem(initialSize, stableId: stableId, context: arguments.context, getView: arguments.getView, viewType: .singleItem)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum SelectColorSource {
    case account(Peer)
    case channel(Peer)
    
    var peerId: PeerId {
        switch self {
        case .account(let peer):
            return peer.id
        case .channel(let peer):
            return peer.id
        }
    }
    var peer: Peer {
        switch self {
        case .account(let peer):
            return peer
        case .channel(let peer):
            return peer
        }
    }
    
    var nameColor: PeerNameColor? {
        switch self {
        case let .account(peer):
            return peer.nameColor
        case let .channel(peer):
            return peer.nameColor
        }
    }
    var backgroundIcon:Int64? {
        switch self {
        case let .account(peer):
            return peer.backgroundEmojiId
        case let .channel(peer):
            return peer.backgroundEmojiId
        }
    }
}

func SelectColorController(context: AccountContext, source: SelectColorSource) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(selected: source.nameColor ?? .blue, backgroundEmojiId: source.backgroundIcon)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    let peerId: PeerId = source.peerId
    
    
//    actionsDisposable.add(context.account.postbox.loadedPeerWithId(peerId).start(next: { peer in
//        updateState { current in
//            var current = current
//            current.selected = peer.nameColor ?? current.selected
//            return current
//        }
//    }))
    
    let selectedBg: EmojiesSectionRowItem.SelectedItem? = source.backgroundIcon.flatMap {
        .init(source: .custom($0), type: .normal)
    }
    
    let emojis = EmojiesController(context, mode: .backgroundIcon, selectedItems: selectedBg != nil ? [selectedBg!] : [], color: source.nameColor?.color)
    emojis._frameRect = NSMakeRect(0, 0, context.bindings.rootNavigation().frame.width - 40, 250)
    emojis.loadViewIfNeeded()
    
    
    
    let interactions = EntertainmentInteractions(.emoji, peerId: peerId)

    interactions.sendAnimatedEmoji = { [weak emojis] sticker, _, _, fromRect in
        
        emojis?.setSelectedItem(.init(source: .custom(sticker.file.fileId.id), type: .normal))
        updateState { current in
            var current = current
            current.backgroundEmojiId = sticker.file.fileId.id
            return current
        }
    }
    
    emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))

    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, source: source, toggleColor: { [weak emojis] value in
        updateState { current in
            var current = current
            current.selected = value
            return current
        }
        emojis?.color = value.color
    }, getView: {
        return emojis.genericView
    })
    
    let signal = combineLatest(statePromise.get(), emojis.ready.get() |> filter { $0 }) |> deliverOnPrepareQueue |> map { state, _ in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let title: String
    switch source {
    case .account:
        title = strings().selectColorTitleUser
    case .channel:
        title = strings().selectColorTitleChannel
    }
    
    let controller = InputDataController(dataSignal: signal, title: title, hasDone: true, doneString: {
        return strings().selectColorApply
    })
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    controller.validateData = { _ in
        if case let .channel(peer) = source {
            _ = context.engine.peers.updatePeerNameColorAndEmoji(peerId: peerId, nameColor: stateValue.with { $0.selected }, backgroundEmojiId: stateValue.with { $0.backgroundEmojiId }).start()
           // execute(inapp: .boost(link: "", username: peer.addressName == nil ? "_private_\(peer.id.id._internalGetInt64Value())" : "\(peer.addressName!)", context: context))
            close?()
        } else {
            if context.isPremium {
                _ = context.engine.accountData.updateNameColorAndEmoji(nameColor: stateValue.with { $0.selected }, backgroundEmojiId: stateValue.with { $0.backgroundEmojiId }).start()
                close?()
            } else {
                showModalText(for: context.window, text: strings().selectColorPremium, callback: { _ in
                    showModal(with: PremiumBoardingController(context: context), for: context.window)
                })
            }
        }
        return .none
    }
    
    controller.updateDoneValue = { data in
        return { f in
            if stateValue.with({ $0.saving }) {
                f(.loading)
            } else {
                f(.enabled(strings().selectColorApply))
            }
        }
    }
   
    close = { [weak controller] in
        controller?.navigationController?.back()
    }
    
    return controller
    
}

