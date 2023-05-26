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
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let nameLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let callback: (PeerId)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer, timestamp: Int32, presentation: TelegramPresentationTheme, callback:@escaping(PeerId)->Void) {
        self.context = context
        self.peer = peer
        self.callback = callback
        self.presentation = presentation
        
        self.nameLayout = .init(.initialize(string: peer.displayTitle, color: presentation.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        
        
        let string = stringForRelativeTimestamp(relativeTimestamp: timestamp, relativeTo: context.timestamp)

        self.dateLayout = .init(.initialize(string: string, color: presentation.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)

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
    private let avatar = AvatarControl(font: .avatar(20))
    private let title = TextView()
    private let date = TextView()
    private let stateIcon = ImageView()
    private let borderView = View()
    private let content = Control()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(content)
        content.addSubview(avatar)
        content.addSubview(date)
        content.addSubview(title)
        content.addSubview(stateIcon)
        content.addSubview(borderView)
        
        date.userInteractionEnabled = false
        date.isSelectable = false
        
        title.userInteractionEnabled = false
        title.isSelectable = false

        stateIcon.isEventLess = true
        
        avatar.frame = NSMakeRect(16, 8, 36, 36)
        
        content.set(handler: { [weak self] _ in
            if let item = self?.item as? StoryViewerRowItem {
                item.callback(item.peer.id)
            }
        }, for: .Click)
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
    }
    
    override func layout() {
        super.layout()
        
        content.frame = bounds
        
        let contentX = avatar.frame.maxX + 10
        
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
    init(context: AccountContext, presentation: TelegramPresentationTheme, callback: @escaping(PeerId)->Void) {
        self.context = context
        self.presentation = presentation
        self.callback = callback
    }
}

extension StoryViewList: Equatable {
    public static func ==(lhs: StoryViewList, rhs: StoryViewList) -> Bool {
        return lhs.items.count != rhs.items.count
    }
}

private struct State : Equatable {
    var item: EngineStoryItem
    var views: StoryViewList?
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
        let timestamp: Int32
        let viewType: GeneralViewType
    }
  
    var needToLoad: Bool = true
    
    if let list = state.views {
        var items: [Tuple] = []
        for item in list.items {
            items.append(.init(peer: .init(item.peer._asPeer()), timestamp: item.timestamp, viewType: .legacy))
        }
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                return StoryViewerRowItem(initialSize, stableId: stableId, context: arguments.context, peer: item.peer.peer, timestamp: item.timestamp, presentation: arguments.presentation, callback: arguments.callback)
            }))
            index += 1
        }
        
        
        
    } else if let views = state.item.views {
        var items: [Tuple] = []
        for item in views.seenPeers {
            items.append(.init(peer: .init(item._asPeer()), timestamp: Int32(Date().timeIntervalSince1970), viewType: .legacy))
        }
        
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                return StoryViewerRowItem(initialSize, stableId: stableId, context: arguments.context, peer: item.peer.peer, timestamp: item.timestamp, presentation: arguments.presentation, callback: arguments.callback)
            }))
            index += 1
        }
        if views.seenCount == views.seenPeers.count {
            needToLoad = false
        }
    }
    
    if state.isLoadingMore && needToLoad {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading_more, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .legacy, color: arguments.presentation.colors.text)
        }))
        index += 1
    }
    
    // entries
    return entries
}

func StoryViewersModalController(context: AccountContext, peerId: PeerId, story: EngineStoryItem, presentation: TelegramPresentationTheme, callback:@escaping(PeerId)->Void) -> InputDataModalController {
    

    let actionsDisposable = DisposableSet()

    let initialState = State(item: story, views: nil)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, presentation: presentation, callback: { peerId in
        callback(peerId)
        close?()
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
        updateState { current in
            var current = current
            current.isLoadingMore = true
            return current
        }
        
        let signal = context.engine.messages.getStoryViewList(account: context.account, id: story.id, offsetTimestamp: nil, offsetPeerId: nil, limit: 100) |> deliverOnMainQueue
        
        actionsDisposable.add(signal.start(next: { list in
            updateState { current in
                var current = current
                current.isLoadingMore = false
                current.views = list
                return current
            }
        }))
    }
    
    
    controller.didLoaded = { controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                break
                //loadMore()
            default:
                break
            }
        }
    }
    
    loadMore()
    
    return modalController
}


/*
 
 */




