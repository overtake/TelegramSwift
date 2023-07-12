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
    fileprivate let storyStats: PeerStoryStats?
    fileprivate let avatarComponent: AvatarStoryIndicatorComponent?
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let nameLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let callback: (PeerId)->Void
    fileprivate let openStory:(PeerId)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer, storyStats: PeerStoryStats?, timestamp: Int32, presentation: TelegramPresentationTheme, callback:@escaping(PeerId)->Void, openStory:@escaping(PeerId)->Void) {
        self.context = context
        self.peer = peer
        self.openStory = openStory
        self.storyStats = storyStats
        self.callback = callback
        self.presentation = presentation
        
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
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        nameLayout.measure(width: width - 36 - 16 - 16 - 10)
        dateLayout.measure(width: width - 36 - 16 - 16 - 10 - 18)

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
    fileprivate let avatar = AvatarControl(font: .avatar(12))
    private var avatarComponent: AvatarStoryIndicatorComponent.IndicatorView?
    private let container = Control(frame: NSMakeRect(16, 8, 36, 36))
    private let title = TextView()
    private let date = TextView()
    private let stateIcon = ImageView()
    private let borderView = View()
    private let content = Control()
    
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
        
        stateIcon.image = item.presentation.icons.story_view_read
        stateIcon.sizeToFit()
        
        self.date.update(item.dateLayout)
        self.title.update(item.nameLayout)
        self.borderView.backgroundColor = item.presentation.colors.border
        
        self.avatar.setPeer(account: item.context.account, peer: item.peer)
        
        var transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        if let component = item.avatarComponent {
            let current: AvatarStoryIndicatorComponent.IndicatorView
            if let view = self.avatarComponent {
                current = view
            } else {
                current = .init(frame: container.bounds)
                container.addSubview(current)
                self.avatarComponent = current
                transition = .immediate
            }
            current.update(component: component, availableSize: container.bounds.insetBy(dx: 3, dy: 3).size, transition: transition)
            transition.updateFrame(view: avatar, frame: container.bounds.insetBy(dx: 3, dy: 3))
        } else if let view = self.avatarComponent {
            performSubviewRemoval(view, animated: animated)
            self.avatarComponent = nil
            transition.updateFrame(view: avatar, frame: container.bounds)
        }
        
        self.container.userInteractionEnabled = item.avatarComponent != nil
    }
    
    override func layout() {
        super.layout()
        
        content.frame = bounds
        
        let contentX = container.frame.maxX + 10
        
        title.setFrameOrigin(NSMakePoint(contentX, 10))
        date.setFrameOrigin(NSMakePoint(contentX + 18, frame.height - date.frame.height - 10))

        stateIcon.setFrameOrigin(NSMakePoint(contentX, frame.height - stateIcon.frame.height - 10))
        
        borderView.frame = NSMakeRect(contentX, frame.height - .borderSize, frame.width - contentX, .borderSize)
    }
}

private final class Arguments {
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    let callback:(PeerId)->Void
    let openStory:(PeerId)->Void
    init(context: AccountContext, presentation: TelegramPresentationTheme, callback: @escaping(PeerId)->Void, openStory:@escaping(PeerId)->Void) {
        self.context = context
        self.presentation = presentation
        self.callback = callback
        self.openStory = openStory
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
private let _id_loading_more = InputDataIdentifier("_id_loading_more")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    struct Tuple: Equatable {
        let peer: PeerEquatable
        let storyStats: PeerStoryStats?
        let timestamp: Int32
        let viewType: GeneralViewType
    }
  
    var needToLoad: Bool = true
    
    if let list = state.views {
        var items: [Tuple] = []
        for item in list.items {
            items.append(.init(peer: .init(item.peer._asPeer()), storyStats: item.storyStats, timestamp: item.timestamp, viewType: .legacy))
        }
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                return StoryViewerRowItem(initialSize, stableId: stableId, context: arguments.context, peer: item.peer.peer, storyStats: item.storyStats, timestamp: item.timestamp, presentation: arguments.presentation, callback: arguments.callback, openStory: arguments.openStory)
            }))
            index += 1
        }
        
    }
    
    
    // entries
    return entries
}

func StoryViewersModalController(context: AccountContext, peerId: PeerId, story: EngineStoryItem, presentation: TelegramPresentationTheme, callback:@escaping(PeerId)->Void) -> InputDataModalController {
    
    let storyViewList = context.engine.messages.storyViewList(id: story.id, views: story.views ?? .init(seenCount: 0, seenPeers: []))
    
    let actionsDisposable = DisposableSet()

    let initialState = State(item: story, views: nil)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    
    var getControl:((PeerId)->NSView?)? = nil

    let arguments = Arguments(context: context, presentation: presentation, callback: { peerId in
        callback(peerId)
        close?()
    }, openStory: { peerId in
        StoryModalController.ShowStories(context: context, isHidden: false, initialId: .init(peerId: peerId, id: nil, messageId: nil, takeControl: { [] peerId, _, _ in
            return getControl?(peerId)
        }), singlePeer: true)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "\(story.views?.seenCount ?? 0) Views")
    
    controller.getBackgroundColor = {
        presentation.colors.background
    }
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(320, 300))
    
    modalController.getModalTheme = {
        .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: presentation.colors.background, border: presentation.colors.border)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: presentation.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
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
    }))
    
    controller.didLoaded = { controller, _ in
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


/*
 
 */




