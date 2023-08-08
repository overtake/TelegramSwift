//
//  StoryViewersModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 19.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox




private final class StoryViewerRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let peer: Peer
    fileprivate let reaction: MessageReaction.Reaction?
    fileprivate let storyStats: PeerStoryStats?
    fileprivate let avatarComponent: AvatarStoryIndicatorComponent?
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let nameLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let callback: (PeerId)->Void
    fileprivate let openStory:(PeerId)->Void
    fileprivate let contextMenu:(PeerId)->Signal<[ContextMenuItem], NoError>
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer, reaction: MessageReaction.Reaction?, storyStats: PeerStoryStats?, timestamp: Int32, presentation: TelegramPresentationTheme, callback:@escaping(PeerId)->Void, openStory:@escaping(PeerId)->Void, contextMenu:@escaping(PeerId)->Signal<[ContextMenuItem], NoError>) {
        self.context = context
        self.peer = peer
        self.openStory = openStory
        self.storyStats = storyStats
        self.callback = callback
        self.presentation = presentation
        self.contextMenu = contextMenu
        self.reaction = reaction
        self.nameLayout = .init(.initialize(string: peer.displayTitle, color: presentation.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        
        
        let string = stringForRelativeTimestamp(relativeTimestamp: timestamp, relativeTo: context.timestamp)

        self.dateLayout = .init(.initialize(string: string, color: presentation.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        if let stats = storyStats {
            self.avatarComponent = .init(stats: stats, presentation: presentation)
        } else {
            self.avatarComponent = nil
        }

        super.init(initialSize, stableId: stableId, viewType: .legacy)
        
        _ = makeSize(initialSize.width)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return contextMenu(self.peer.id)
    }
    
    override var menuPresentation: AppMenu.Presentation {
        return .init(colors: storyTheme.colors)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        
        nameLayout.measure(width: width - 36 - 16 - 16 - 10 - (peer.isPremium ? 20 : 0) - (reaction != nil ? 30 : 0))
        dateLayout.measure(width: width - 36 - 16 - 16 - 10 - 18 - (reaction != nil ? 30 : 0))

        return true
    }
    
    override var height: CGFloat {
        return 52
    }
    
    override func viewClass() -> AnyClass {
        return StoryViewerRowView.self
    }
}

private final class StoryViewerRowView: GeneralRowView {
    fileprivate let avatar = AvatarStoryControl(font: .avatar(12), size: NSMakeSize(36, 36))
    private let container = Control(frame: NSMakeRect(16, 8, 36, 36))
    private let title = TextView()
    private let date = TextView()
    private let stateIcon = ImageView()
    private let borderView = View()
    private let content = Control()
    private var statusControl: PremiumStatusControl?
    private var reaction: InlineStickerItemLayer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(content)
        container.addSubview(avatar)
        content.addSubview(container)
        content.addSubview(date)
        content.addSubview(title)
        content.addSubview(stateIcon)
        content.addSubview(borderView)
        
        date.userInteractionEnabled = false
        date.isSelectable = false
        
        title.userInteractionEnabled = false
        title.isSelectable = false

        stateIcon.isEventLess = true
        
        avatar.frame = NSMakeRect(0, 0, 36, 36)
        
        content.set(handler: { [weak self] _ in
            if let item = self?.item as? StoryViewerRowItem {
                item.callback(item.peer.id)
            }
        }, for: .Click)
        
        self.container.set(handler: { [weak self] _ in
            if let item = self?.item as? StoryViewerRowItem {
                item.openStory(item.peer.id)
            }
        }, for: .Click)
        avatar.userInteractionEnabled = false
        container.scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryViewerRowItem else {
            return
        }
        
        let control = PremiumStatusControl.control(item.peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, isSelected: false, cached: self.statusControl, animated: animated)
        if let control = control {
            self.statusControl = control
            self.content.addSubview(control)
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        stateIcon.image = item.presentation.icons.story_view_read
        stateIcon.sizeToFit()
        
        self.date.update(item.dateLayout)
        self.title.update(item.nameLayout)
        self.borderView.backgroundColor = item.presentation.colors.border
        
        self.avatar.setPeer(account: item.context.account, peer: item.peer)
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        
        if let reaction = item.reaction {
            let layer = makeView(reaction, context: item.context)
            if let layer = layer {
                layer.frame = NSMakeRect(frame.width - 25 - container.frame.minX, (frame.height - 25) / 2, 25, 25)
                self.layer?.addSublayer(layer)
                layer.isPlayable = false
            }
            self.reaction = layer
        } else if let view = self.reaction {
            performSublayerRemoval(view, animated: animated)
            self.reaction = nil
        }
        
        if let component = item.avatarComponent {
            self.avatar.update(component: component, availableSize: NSMakeSize(30, 30), transition: transition)
        } else {
            self.avatar.update(component: nil, availableSize: NSMakeSize(36, 36), transition: transition)
        }
        
        self.container.userInteractionEnabled = item.avatarComponent != nil
    }
    
    private func makeView(_ reaction: MessageReaction.Reaction, context: AccountContext, appear: Bool = false) -> InlineStickerItemLayer? {
        let layer: InlineStickerItemLayer?
        let size = NSMakeSize(25, 25)
        switch reaction {
        case let .custom(fileId):
            layer = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: size, playPolicy: .onceEnd)
        case .builtin:
            if let animation = context.reactions.available?.reactions.first(where: { $0.value == reaction }) {
                let file = appear ? animation.activateAnimation : animation.selectAnimation
                layer = InlineStickerItemLayer(account: context.account, file: file, size: size, playPolicy: .onceEnd)
            } else {
                layer = nil
            }
        }
        
        return layer
    }


    
    func setOpenProgress(_ signal:Signal<Never, NoError>) {
        SetOpenStoryDisposable(self.avatar.pushLoadingStatus(signal: signal))
    }
    
    override func layout() {
        super.layout()
        
        content.frame = bounds
        
        let contentX = container.frame.maxX + 10
        
        
        title.setFrameOrigin(NSMakePoint(contentX, 10))
        date.setFrameOrigin(NSMakePoint(contentX + 18, frame.height - date.frame.height - 10))

        
        statusControl?.setFrameOrigin(NSMakePoint(title.frame.maxX + 3, 10))

        stateIcon.setFrameOrigin(NSMakePoint(contentX, frame.height - stateIcon.frame.height - 10))
        
        borderView.frame = NSMakeRect(contentX, frame.height - .borderSize, frame.width - contentX, .borderSize)
    }
}

private final class Arguments {
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    let callback:(PeerId)->Void
    let openStory:(PeerId)->Void
    let contextMenu:(PeerId)->Signal<[ContextMenuItem], NoError>
    init(context: AccountContext, presentation: TelegramPresentationTheme, callback: @escaping(PeerId)->Void, openStory:@escaping(PeerId)->Void, contextMenu:@escaping(PeerId)->Signal<[ContextMenuItem], NoError>) {
        self.context = context
        self.presentation = presentation
        self.callback = callback
        self.openStory = openStory
        self.contextMenu = contextMenu
    }
}

private struct State : Equatable {
    var item: EngineStoryItem
    var views: EngineStoryViewListContext.State?
    var isLoadingMore: Bool = false
}


private func _id_peer(_ id:PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}
private func _id_miss(_ id: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_miss\(id)")
}
private let _id_loading_more = InputDataIdentifier("_id_loading_more")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    struct Tuple: Equatable {
        let peer: PeerEquatable
        let reaction: MessageReaction.Reaction?
        let storyStats: PeerStoryStats?
        let timestamp: Int32
        let viewType: GeneralViewType
    }
  
    var needToLoad: Bool = true
    
    if let list = state.views {
        
        var items: [Tuple] = []
        for item in list.items {
            
            items.append(.init(peer: .init(item.peer._asPeer()), reaction: item.reaction, storyStats: item.storyStats, timestamp: item.timestamp, viewType: .legacy))
        }
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                return StoryViewerRowItem(initialSize, stableId: stableId, context: arguments.context, peer: item.peer.peer, reaction: item.reaction, storyStats: item.storyStats, timestamp: item.timestamp, presentation: arguments.presentation, callback: arguments.callback, openStory: arguments.openStory, contextMenu: arguments.contextMenu)
            }))
            index += 1
        }
        
        let miss = list.totalCount - items.count
        
        if miss > 0 {
            for i in 0 ..< miss {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_miss(i), equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return GeneralRowItem(initialSize, height: 52, stableId: stableId)
                }))
                index += 1
            }
        }
    }
    
    // entries
    return entries
}

private final class StoryViewersTopView : View {
    fileprivate let segmentControl: CatalinaStyledSegmentController
    fileprivate let close = ImageButton()
    fileprivate let filter = ImageButton()
    fileprivate let search: SearchView
    private let top: View
    private let bottom: View
    required init(frame frameRect: NSRect) {
        self.search = .init(frame: NSMakeRect(0, 10, frameRect.width, 30))
        search.searchTheme = storyTheme.search
        self.top = View(frame: NSMakeRect(0, 0, frameRect.width, 50))
        self.bottom = View(frame: NSMakeRect(0, 50, frameRect.width, 40))
        self.segmentControl = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 240, 30))
        super.init(frame: frameRect)
        
        segmentControl.add(segment: .init(title: strings().storyViewersAll, handler: {
            
        }))
        
        segmentControl.add(segment: .init(title: strings().storyViewersContacts, handler: {
            
        }))
        
        close.set(image: NSImage(named: "Icon_ChatAction_Close")!.precomposed(storyTheme.colors.text), for: .Normal)
        close.autohighlight = false
        close.scaleOnClick = true
        close.sizeToFit()
        
        filter.set(image: NSImage(named: "Icon_StoryViewers_Filter")!.precomposed(storyTheme.colors.text), for: .Normal)
        filter.autohighlight = false
        filter.scaleOnClick = true
        filter.sizeToFit()
        
        self.backgroundColor = storyTheme.colors.background
        self.borderColor = storyTheme.colors.border
        self.border = [.Bottom]
        
        
        segmentControl.theme = CatalinaSegmentTheme(backgroundColor: storyTheme.colors.listBackground, foregroundColor: storyTheme.colors.background, activeTextColor: storyTheme.colors.text, inactiveTextColor: storyTheme.colors.listGrayText)

        top.addSubview(close)
        top.addSubview(filter)
        top.addSubview(segmentControl.view)
        
        bottom.addSubview(search)
        
        addSubview(top)
        addSubview(bottom)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        top.frame = NSMakeRect(0, 0, frame.width, 50)
        bottom.frame = NSMakeRect(0, top.frame.maxY, frame.width, 50)
        segmentControl.view.center()
        close.centerY(x: 15)
        filter.centerY(x: top.frame.width - filter.frame.width - 15)
        search.frame = NSMakeRect(15, 0, frame.width - 30, 30)
    }
    
}

func StoryViewersModalController(context: AccountContext, list: EngineStoryViewListContext?, peerId: PeerId, story: EngineStoryItem, presentation: TelegramPresentationTheme, callback:@escaping(PeerId)->Void) -> InputDataModalController {
    
    let storyViewList = list ?? context.engine.messages.storyViewList(id: story.id, views: story.views ?? .init(seenCount: 0, reactedCount: 0, seenPeers: []))
    
    let actionsDisposable = DisposableSet()

    let initialState = State(item: story, views: nil)
    
    let statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    
    var getControl:((PeerId)->NSView?)? = nil
    var setProgress:((PeerId, Signal<Never, NoError>)->Void)? = nil

    let arguments = Arguments(context: context, presentation: presentation, callback: { peerId in
        callback(peerId)
        close?()
    }, openStory: { peerId in
        StoryModalController.ShowStories(context: context, isHidden: false, initialId: .init(peerId: peerId, id: nil, messageId: nil, takeControl: { [] peerId, _, _ in
            return getControl?(peerId)
        }, setProgress: { value in
            setProgress?(peerId, value)
        }), singlePeer: true)
    }, contextMenu: { peerId in
        return combineLatest(getCachedDataView(peerId: peerId, postbox: context.account.postbox), context.account.viewTracker.peerView(peerId)) |> take(1) |> map { cachedData, peerView in
            var items: [ContextMenuItem] = []
            if let view = cachedData as? CachedUserData, let peer = peerViewMainPeer(peerView) {
                let blockedFromStories = view.flags.contains(.isBlockedFromStories)
                items.append(ContextMenuItem(blockedFromStories ? strings().storyViewContextMenuShowMyStories(peer.compactDisplayTitle) : strings().storyViewContextMenuHideMyStories(peer.compactDisplayTitle), handler: {
                    let text: String
                    if blockedFromStories {
                        _ = context.storiesBlockedPeersContext.remove(peerId: peerId).start()
                        text = strings().storyViewTooltipShowMyStories(peer.compactDisplayTitle)
                    } else {
                        _ = context.storiesBlockedPeersContext.add(peerId: peerId).start()
                        text = strings().storyViewTooltipHideMyStories(peer.compactDisplayTitle)
                    }
                    showModalText(for: context.window, text: text)
                }, itemImage: MenuAnimation.menu_stories.value))
                
                items.append(ContextSeparatorItem())
                
                
                if peerView.peerIsContact {
                    items.append(ContextMenuItem(strings().storyViewContextMenuDeleteContact, handler: {
                        let text: String = strings().storyViewTooltipDeleteContact(peer.compactDisplayTitle)
                        _ = context.engine.contacts.deleteContactPeerInteractively(peerId: peerId).start()
                        showModalText(for: context.window, text: text)
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                } else {
                    items.append(ContextMenuItem(view.isBlocked ? strings().storyViewContextMenuUnblock : strings().storyViewContextMenuBlock, handler: {
                        let text: String
                        if view.isBlocked {
                            _ = context.blockedPeersContext.remove(peerId: peerId).start()
                            text = strings().storyViewTooltipUnblock(peer.compactDisplayTitle)
                        } else {
                            _ = context.blockedPeersContext.add(peerId: peerId).start()
                            text = strings().storyViewTooltipBlock(peer.compactDisplayTitle)
                        }
                        showModalText(for: context.window, text: text)
                    }, itemMode: !view.isBlocked ? .destruct : .normal, itemImage: view.isBlocked ? MenuAnimation.menu_unblock.value : MenuAnimation.menu_delete.value))
                }
            }
            return items
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    let view = StoryViewersTopView(frame: NSMakeRect(0, 0, controller.frame.width, (story.views?.seenCount ?? 0) > 10 ? 90 : 50))
    controller.contextObject = view

    view.search.searchInteractions = .init({ state, animated in
        
    }, { state in
        
    })
    
    
    view.filter.contextMenu = {
        let menu = ContextMenu(presentation: .current(storyTheme.colors))
        menu.addItem(ContextMenuItem(strings().storyViewersReactionsFirst, handler: {
            
        }, itemImage: MenuAnimation.menu_check_selected.value))
        
        menu.addItem(ContextMenuItem(strings().storyViewersRecentFirst, handler: {
            
        }))
        return menu
    }
    
    view.close.set(handler: { _ in
        close?()
    }, for: .Click)
    
    controller.getBackgroundColor = {
        presentation.colors.background
    }
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(350, 300))
    
    modalController.getModalTheme = {
        .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: presentation.colors.background, border: presentation.colors.border)
    }

    close = { [weak modalController] in
        modalController?.close()
    }
    
    let loadMore:()->Void = {
        storyViewList.loadMore()
    }
    
    actionsDisposable.add(storyViewList.state.start(next: { list in
        updateState { current in
            var current = current
            current.views = list
            return current
        }
        loadMore()
    }))
    
    
    controller.didLoaded = { [weak view] controller, _ in
        
        if let view = view {
            controller.genericView.set(view)
        }
        
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                loadMore()
            default:
                break
            }
        }
        
        
        getControl = { [weak controller] peerId in
            var control: NSView?
            controller?.tableView.enumerateVisibleItems(with: { item in
                if let item = item as? StoryViewerRowItem, item.peer.id == peerId {
                    control = (item.view as? StoryViewerRowView)?.avatar
                }
                return control == nil
            })
            return control
        }
        setProgress = { [weak controller] peerId, signal in
            controller?.tableView.enumerateVisibleItems(with: { item in
                if let item = item as? StoryViewerRowItem, item.peer.id == peerId {
                    (item.view as? StoryViewerRowView)?.setOpenProgress(signal)
                    return false
                }
                return true
            })
        }
    }
    
    controller.didAppear = { controller in        
        controller.window?.set(handler: { _ in
            return .invokeNext
        }, with: controller, for: .All, priority: .modal)
        
        controller.window?.set(handler: {  _ in
            close?()
            return .invoked
        }, with: controller, for: .DownArrow, priority: .modal)
        
        controller.window?.set(handler: {  _ in
            close?()
            return .invoked
        }, with: controller, for: .Escape, priority: .modal)
        
        controller.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: true, { [weak controller] scroll in
            var refreshStoryPeerIds:[PeerId] = []
            controller?.tableView.enumerateVisibleItems(with: { item in
                if let item = item as? StoryViewerRowItem {
                    refreshStoryPeerIds.append(item.peer.id)
                }
                return true
            })
            context.account.viewTracker.refreshStoryStatsForPeerIds(peerIds: refreshStoryPeerIds)
        }))
    }
    
    loadMore()
    
    return modalController
}



