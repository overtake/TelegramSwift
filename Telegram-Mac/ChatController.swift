//
//  ChatController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


enum ChatMode {
    case history
    case scheduled
}

extension ChatHistoryLocation {
    var isAtUpperBound: Bool {
        switch self {
        case .Navigation(index: .upperBound, anchorIndex: .upperBound, count: _, side: _):
            return true
        case .Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: _, scrollPosition: _, count: _, animated: _):
            return true
        default:
            return false
        }
    }

}


private var temporaryTouchBar: Any?


final class ChatWrapperEntry : Comparable, Identifiable {
    let appearance: AppearanceWrapperEntry<ChatHistoryEntry>
    let automaticDownload: AutomaticMediaDownloadSettings
    init(appearance: AppearanceWrapperEntry<ChatHistoryEntry>, automaticDownload: AutomaticMediaDownloadSettings) {
        self.appearance = appearance
        self.automaticDownload = automaticDownload
    }
    var stableId: AnyHashable {
        return appearance.entry.stableId
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    var entry: ChatHistoryEntry {
        return appearance.entry
    }
}

func ==(lhs:ChatWrapperEntry, rhs: ChatWrapperEntry) -> Bool {
    return lhs.appearance == rhs.appearance && lhs.automaticDownload == rhs.automaticDownload
}
func <(lhs:ChatWrapperEntry, rhs: ChatWrapperEntry) -> Bool {
    return lhs.appearance.entry < rhs.appearance.entry
}


final class ChatHistoryView {
    let originalView: MessageHistoryView?
    let filteredEntries: [ChatWrapperEntry]
    
    init(originalView:MessageHistoryView?, filteredEntries: [ChatWrapperEntry]) {
        self.originalView = originalView
        self.filteredEntries = filteredEntries
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

enum ChatControllerViewState {
    case visible
    case progress
    //case IsNotAccessible
}

final class ChatHistoryState : Equatable {
    let isDownOfHistory:Bool
    fileprivate let replyStack:[MessageId]
    init (isDownOfHistory:Bool = true, replyStack:[MessageId] = []) {
        self.isDownOfHistory = isDownOfHistory
        self.replyStack = replyStack
    }
    
    func withUpdatedStateOfHistory(_ isDownOfHistory:Bool) -> ChatHistoryState {
        return ChatHistoryState(isDownOfHistory: isDownOfHistory, replyStack: self.replyStack)
    }
    
    func withAddingReply(_ messageId:MessageId) -> ChatHistoryState {
        var stack = replyStack
        stack.append(messageId)
        return ChatHistoryState(isDownOfHistory: isDownOfHistory, replyStack: stack)
    }
    
    func withClearReplies() -> ChatHistoryState {
        return ChatHistoryState(isDownOfHistory: isDownOfHistory, replyStack: [])
    }
    
    func reply() -> MessageId? {
        return replyStack.last
    }
    
    func withRemovingReplies(max: MessageId) -> ChatHistoryState {
        var copy = replyStack
        for i in stride(from: replyStack.count - 1, to: -1, by: -1) {
            if replyStack[i] <= max {
                copy.remove(at: i)
            }
        }
        return ChatHistoryState(isDownOfHistory: isDownOfHistory, replyStack: copy)
    }
}

func ==(lhs:ChatHistoryState, rhs:ChatHistoryState) -> Bool {
    return lhs.isDownOfHistory == rhs.isDownOfHistory && lhs.replyStack == rhs.replyStack
}


class ChatControllerView : View, ChatInputDelegate {

    
    let tableView:TableView
    let inputView:ChatInputView
    let inputContextHelper:InputContextHelper
    private(set) var state:ChatControllerViewState = .visible
    private var searchInteractions:ChatSearchInteractions!
    private let scroller:ChatNavigateScroller
    private var mentions:ChatNavigationMention?
    private var failed:ChatNavigateFailed?
    private var progressView:ProgressIndicator?
    private let header:ChatHeaderController
    private var historyState:ChatHistoryState?
    private let chatInteraction: ChatInteraction
    
    private let gradientMaskView = BackgroundGradientView(frame: NSZeroRect)
    
    var headerState: ChatHeaderState {
        return header.state
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    
    required init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        header = ChatHeaderController(chatInteraction)
        scroller = ChatNavigateScroller(chatInteraction.context, chatInteraction.chatLocation)
        inputContextHelper = InputContextHelper(chatInteraction: chatInteraction)
        tableView = TableView(frame:NSMakeRect(0,0,frameRect.width,frameRect.height - 50), isFlipped:false)
        inputView = ChatInputView(frame: NSMakeRect(0,tableView.frame.maxY, frameRect.width,50), chatInteraction: chatInteraction)
        //inputView.autoresizingMask = [.width]
        super.init(frame: frameRect)
        
//        self.layer = CAGradientLayer()
//        self.layer?.disableActions()
        
        addSubview(tableView)
        addSubview(inputView)
        inputView.delegate = self
        self.autoresizesSubviews = false
        tableView.autoresizingMask = []
        scroller.set(handler:{ control in
            chatInteraction.scrollToLatest(false)
        }, for: .Click)
        scroller.forceHide()
        tableView.addSubview(scroller)
        
        let context = chatInteraction.context
        

        searchInteractions = ChatSearchInteractions(jump: { message in
            chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
        }, results: { query in
            chatInteraction.modalSearch(query)
        }, calendarAction: { date in
            chatInteraction.jumpToDate(date)
        }, cancel: {
            chatInteraction.update({$0.updatedSearchMode((false, nil, nil))})
        }, searchRequest: { query, fromId, state in
            let location: SearchMessagesLocation
            switch chatInteraction.chatLocation {
            case let .peer(peerId):
                location = .peer(peerId: peerId, fromId: fromId, tags: nil)
            }
            return searchMessages(account: context.account, location: location, query: query, state: state) |> map {($0.0.messages.filter({ !($0.media.first is TelegramMediaAction) }), $0.1)}
        })
        
        
        tableView.addScroll(listener: TableScrollListener { [weak self] position in
            if let state = self?.historyState {
                self?.updateScroller(state)
            }
        })
        
        tableView.backgroundColor = .clear
        tableView.layer?.backgroundColor = .clear

       // updateLocalizationAndTheme(theme: theme)
        
        tableView.set(stickClass: ChatDateStickItem.self, handler: { stick in
            
        })
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {
                return
            }
            self.tableView.enumerateVisibleViews(with: { view in
                if let view = view as? ChatRowView {
                    view.updateBackground(animated: false)
                }
            })
        }))
        
    }
    
    
    func updateScroller(_ historyState:ChatHistoryState) {
        self.historyState = historyState
        let isHidden = (tableView.documentOffset.y < 150 && historyState.isDownOfHistory) || tableView.isEmpty
        if !isHidden {
            scroller.isHidden = false
        }
        
        scroller.change(opacity: isHidden ? 0 : 1, animated: true) { [weak scroller] completed in
            if completed {
                scroller?.isHidden = isHidden
            }
        }
        
        if let mentions = mentions {
            mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: true )
        }
        if let failed = failed {
            var offset = (scroller.controlIsHidden ? 0 : scroller.frame.height)
            if let mentions = mentions {
                offset += (mentions.frame.height + 6)
            }
            failed.change(pos: NSMakePoint(frame.width - failed.frame.width - 6, tableView.frame.maxY - failed.frame.height - 6 - offset), animated: true )
        }
    }
    
    
    func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void {
        if let view = header.currentView {
//            view.layer?.animatePosition(from: NSMakePoint(0, -current), to: NSMakePoint(0, previous), duration: 0.2, removeOnCompletion: false)
//            return { [weak view] in
//               view?.layer?.removeAllAnimations()
//            }
        }
        return {}
    }
    
    
    private var previousHeight:CGFloat = 50
    func inputChanged(height: CGFloat, animated: Bool) {
        if previousHeight != height {
            let header:CGFloat
            if let currentView = self.header.currentView {
                header = currentView.frame.height
            } else {
                header = 0
            }
            let size = NSMakeSize(frame.width, frame.height - height - header)
            let resizeAnimated = animated && tableView.contentOffset.y < height
            //(previousHeight < height || tableView.contentOffset.y < height)
            
            tableView.change(size: size, animated: animated)
            
            
            if tableView.contentOffset.y > height {
               // tableView.clipView.scroll(to: NSMakePoint(0, tableView.contentOffset.y - (previousHeight - height)))
            }
            
            inputView.change(pos: NSMakePoint(0, tableView.frame.maxY), animated: animated)
            if let view = inputContextHelper.accessoryView {
                view._change(pos: NSMakePoint(0, frame.height - inputView.frame.height - view.frame.height), animated: animated)
            }
            
            scroller.change(pos: NSMakePoint(frame.width - scroller.frame.width - 6, size.height - scroller.frame.height - 6), animated: animated)
            
            if let mentions = mentions {
                mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: animated )
            }
            if let failed = failed {
                var offset = (scroller.controlIsHidden ? 0 : scroller.frame.height)
                if let mentions = mentions {
                    offset += (mentions.frame.height + 6)
                }
                failed.change(pos: NSMakePoint(frame.width - failed.frame.width - 6, tableView.frame.maxY - failed.frame.height - 6 - offset), animated: animated)
            }
            
            previousHeight = height

            self.tableView.enumerateVisibleViews(with: { view in
                if let view = view as? ChatRowView {
                    view.updateBackground(animated: animated)
                }
            })
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        
        self.tableView.enumerateVisibleViews(with: { view in
            if let view = view as? ChatRowView {
                view.updateBackground(animated: false)
            }
        })
    }

    
    override func layout() {
        super.layout()
        updateFrame(frame, animated: false)
    }
    
    func updateFrame(_ frame: NSRect, animated: Bool) {
        if let view = inputContextHelper.accessoryView {
            (animated ? view.animator() : view).frame = NSMakeRect(0, frame.height - inputView.frame.height - view.frame.height, frame.width, view.frame.height)
        }
        if let currentView = header.currentView {
            (animated ? currentView.animator() : currentView).frame = NSMakeRect(0, 0, frame.width, currentView.frame.height)
            (animated ? tableView.animator() : tableView).frame = NSMakeRect(0, currentView.frame.height, frame.width, frame.height - inputView.frame.height - currentView.frame.height)
            
            currentView.needsDisplay = true
        } else {
            (animated ? tableView.animator() : tableView).frame = NSMakeRect(0, 0, frame.width, frame.height - inputView.frame.height)
        }
        (animated ? inputView.animator() : inputView).setFrameSize(NSMakeSize(frame.width, inputView.frame.height))
        (animated ? gradientMaskView.animator() : gradientMaskView).frame = tableView.frame
        
        
        (animated ? inputView.animator() : inputView).setFrameOrigin(NSMakePoint(0, tableView.frame.maxY))
        if let indicator = progressView?.subviews.first {
            (animated ? indicator.animator() : indicator).center()
        }
        
        (animated ? progressView?.animator() : progressView)?.center()
        
        (animated ? scroller.animator() : scroller).setFrameOrigin(NSMakePoint(frame.width - scroller.frame.width - 6, tableView.frame.height - 6 - scroller.frame.height))
        
        if let mentions = mentions {
            (animated ? mentions.animator() : mentions).setFrameOrigin(NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)))
        }
        if let failed = failed {
            var offset = (scroller.controlIsHidden ? 0 : scroller.frame.height)
            if let mentions = mentions {
                offset += (mentions.frame.height + 6)
            }
            (animated ? failed.animator() : failed).setFrameOrigin(NSMakePoint(frame.width - failed.frame.width - 6, tableView.frame.maxY - failed.frame.height - 6 - offset))
        }
    }

    override var responder: NSResponder? {
        return inputView.responder
    }
    
    func change(state:ChatControllerViewState, animated:Bool) {
        let state = chatInteraction.presentation.isNotAccessible ? .visible : state
        if state != self.state {
            self.state = state
            
            switch state {
            case .progress:
                if progressView == nil {
                    self.progressView = ProgressIndicator(frame: NSMakeRect(0,0,30,30))
                    self.progressView?.innerInset = 6
                    progressView!.animates = true
                    addSubview(progressView!)
                    progressView!.center()
                }
                progressView?.backgroundColor = theme.colors.background.withAlphaComponent(0.7)
                progressView?.layer?.cornerRadius = 15
            case .visible:
                if animated {
                    progressView?.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] (completed) in
                        self?.progressView?.removeFromSuperview()
                        self?.progressView?.animates = false
                        self?.progressView = nil
                    })
                } else {
                    progressView?.removeFromSuperview()
                    progressView = nil
                }
            }
        }
        if chatInteraction.presentation.isNotAccessible {
            tableView.updateEmpties()
        }
    }
    
    func updateHeader(_ interfaceState:ChatPresentationInterfaceState, _ animated:Bool) {
        

        
        let state:ChatHeaderState
        if let initialAction = interfaceState.initialAction, case let .ad(kind) = initialAction {
            state = .promo(kind)
        } else if interfaceState.isSearchMode.0 {
            state = .search(searchInteractions, interfaceState.isSearchMode.1, interfaceState.isSearchMode.2)
        }else if let peerStatus = interfaceState.peerStatus, let settings = peerStatus.peerStatusSettings, !settings.flags.isEmpty {
            if peerStatus.canAddContact && settings.contains(.canAddContact) {
                state = .addContact(block: settings.contains(.canReport) || settings.contains(.canBlock), autoArchived: settings.contains(.autoArchived))
            } else if settings.contains(.canReport) {
                state = .report(autoArchived: settings.contains(.autoArchived))
            } else if settings.contains(.canShareContact) {
                state = .shareInfo
            } else {
                state = .none
            }
        } else if let pinnedMessageId = interfaceState.pinnedMessageId, pinnedMessageId != interfaceState.interfaceState.dismissedPinnedMessageId {
            state = .pinned(pinnedMessageId)
        } else if let canAdd = interfaceState.canAddContact, canAdd {
           state = .none
        } else {
            state = .none
        }
        
        CATransaction.begin()
        header.updateState(state, animated: animated, for: self)
        
        
        tableView.change(size: NSMakeSize(frame.width, frame.height - state.height - inputView.frame.height), animated: animated)
        tableView.change(pos: NSMakePoint(0, state.height), animated: animated)
        
        scroller.change(pos: NSMakePoint(frame.width - scroller.frame.width - 6, frame.height - state.height - inputView.frame.height - 6 - scroller.frame.height), animated: animated)

        
        if let mentions = mentions {
            mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: animated)
        }
        if let failed = failed {
            var offset = (scroller.controlIsHidden ? 0 : scroller.frame.height)
            if let mentions = mentions {
                offset += (mentions.frame.height + 6)
            }
            failed.change(pos: NSMakePoint(frame.width - failed.frame.width - 6, tableView.frame.maxY - failed.frame.height - 6 - offset), animated: animated)
        }
        
        if let view = inputContextHelper.accessoryView {
            view._change(pos: NSMakePoint(0, frame.height - view.frame.height - inputView.frame.height), animated: animated)
        }
        CATransaction.commit()
    }
    
    private(set) fileprivate var failedIds: Set<MessageId> = Set()
    private var hasOnScreen: Bool = false
    func updateFailedIds(_ ids: Set<MessageId>, hasOnScreen: Bool, animated: Bool) {
        if hasOnScreen != self.hasOnScreen || self.failedIds != ids {
            self.failedIds = ids
            self.hasOnScreen = hasOnScreen
            if !ids.isEmpty && !hasOnScreen {
                if failed == nil {
                    failed = ChatNavigateFailed(chatInteraction.context)
                    if let failed = failed {
                        var offset = (scroller.controlIsHidden ? 0 : scroller.frame.height)
                        if let mentions = mentions {
                            offset += (mentions.frame.height + 6)
                        }
                        failed.setFrameOrigin(NSMakePoint(frame.width - failed.frame.width - 6, tableView.frame.maxY - failed.frame.height - 6 - offset))
                        addSubview(failed)
                    }
                    if animated {
                        failed?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                failed?.removeAllHandlers()
                failed?.set(handler: { [weak self] _ in
                    if let id = ids.min() {
                        self?.chatInteraction.focusMessageId(nil, id, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                    }
                    }, for: .Click)
            } else {
                if animated {
                    if let failed = self.failed {
                        self.failed = nil
                        failed.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak failed] _ in
                            failed?.removeFromSuperview()
                        })
                    }
                } else {
                    failed?.removeFromSuperview()
                    failed = nil
                }
                
            }
            needsLayout = true
        }
    }
    
    func updateMentionsCount(_ count: Int32, animated: Bool) {
        if count > 0 {
            if mentions == nil {
                mentions = ChatNavigationMention()
                mentions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.mentionPressed()
                }, for: .Click)
                
                mentions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.clearMentions()
                }, for: .LongMouseDown)
                
                if let mentions = mentions {
                    mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: animated )
                    addSubview(mentions)
                }             
            }
            mentions?.updateCount(count)
        } else {
            mentions?.removeFromSuperview()
            mentions = nil
        }
        needsLayout = true
    }
    
    func applySearchResponder() {
        (header.currentView as? ChatSearchHeader)?.applySearchResponder()
    }

    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        progressView?.backgroundColor = theme.colors.background
        (progressView?.subviews.first as? NSProgressIndicator)?.set(color: theme.colors.indicatorColor)
        scroller.updateLocalizationAndTheme(theme: theme)
        tableView.emptyItem = ChatEmptyPeerItem(tableView.frame.size, chatInteraction: chatInteraction)
    }

    
}




fileprivate func prepareEntries(from fromView:ChatHistoryView?, to toView:ChatHistoryView, timeDifference: TimeInterval, initialSize:NSSize, interaction:ChatInteraction, animated:Bool, scrollPosition:ChatHistoryViewScrollPosition?, reason:ChatHistoryViewUpdateType, animationInterface:TableAnimationInterface?, side: TableSavingSide?) -> Signal<TableUpdateTransition, NoError> {
    return Signal { subscriber in
    
//        subscriber.putNext(TableUpdateTransition(deleted: [], inserted: [], updated: [], animated: animated, state: .none(nil), grouping: true))
//        subscriber.putCompletion()
        
        var scrollToItem:TableScrollState? = nil
        var animated = animated
        
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .unread(unreadIndex):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case .UnreadEntry = entry.appearance.entry {
                        scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: -6)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    scrollToItem = .none(animationInterface)
                }
                
                if scrollToItem == nil {
//                    var index = 0
//                    for entry in toView.filteredEntries.reversed() {
//                        if entry.appearance.entry.index < unreadIndex {
//                            scrollToItem = .top(id: entry.stableId, animated: false, focus: .init(focus: false), inset: 0)
//                            break
//                        }
//                        index += 1
//                    }
                }
            case let .positionRestoration(scrollIndex, relativeOffset):
                
                let timestamp = Int32(min(TimeInterval(scrollIndex.timestamp) - timeDifference, TimeInterval(Int32.max)))

                
                let scrollIndex = scrollIndex.withUpdatedTimestamp(timestamp)
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if entry.appearance.entry.index >= scrollIndex {
                        scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: relativeOffset)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.appearance.entry.index < scrollIndex {
                            scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: relativeOffset)
                            break
                        }
                        index += 1
                    }
                }
            case let .index(scrollIndex, position, directionHint, animated):
                let scrollIndex = scrollIndex.withSubstractedTimestamp(Int32(timeDifference))

                for entry in toView.filteredEntries {
                    if scrollIndex.isLessOrEqual(to: entry.appearance.entry.index) {
                        if case let .groupedPhotos(entries, _) = entry.appearance.entry {
                            for inner in entries {
                                if case let .MessageEntry(values) = inner {
                                    
                                    //                                    if !scrollIndex.isLess(than: MessageIndex(values.0.withUpdatedTimestamp(values.0.timestamp - Int32(timeDifference)))) && scrollIndex.isLessOrEqual(to: MessageIndex(values.0.withUpdatedTimestamp(values.0.timestamp - Int32(timeDifference)))) {

                                    
                                    let timestamp = Int32(min(TimeInterval(values.0.timestamp) - timeDifference, TimeInterval(Int32.max)))

                                    let messageIndex = MessageIndex(values.0.withUpdatedTimestamp(timestamp))
                                    
                                    if !scrollIndex.isLess(than: messageIndex) && scrollIndex.isLessOrEqual(to: messageIndex) {
                                        scrollToItem = position.swap(to: entry.appearance.entry.stableId, innerId: inner.stableId)
                                    }
                                }
                            }
                        } else {
                            scrollToItem = position.swap(to: entry.appearance.entry.stableId)
                        }
                        break
                    }
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if MessageHistoryAnchorIndex.message(entry.appearance.entry.index) < scrollIndex {
                            scrollToItem = position.swap(to: entry.appearance.entry.stableId)
                            break
                        }
                        index += 1
                    }
                }
            }
        }
        
        if scrollToItem == nil {
            scrollToItem = .saveVisible(side ?? .upper)
            
            switch reason {
            case let .Generic(type):
                switch type {
                case .Generic:
                    scrollToItem = .none(animationInterface)
                default:
                    break
                }
            default:
                break
            }
        } else {
            var bp:Int = 0
            bp += 1
        }
        
        
        func makeItem(_ entry: ChatWrapperEntry) -> TableRowItem {
            let item:TableRowItem = ChatRowItem.item(initialSize, from: entry.appearance.entry, interaction: interaction, downloadSettings: entry.automaticDownload, theme: theme)
            _ = item.makeSize(initialSize.width)
            return item;
        }
        
        let firstTransition = Queue.mainQueue().isCurrent()
        var cancelled = false
        
        if fromView == nil && firstTransition, let state = scrollToItem {
                        
            var initialIndex:Int = 0
            var height:CGFloat = 0
            var firstInsertion:[(Int, TableRowItem)] = []
            let entries = Array(toView.filteredEntries.reversed())
            
            switch state {
            case let .top(stableId, _, _, _, relativeOffset):
                var index:Int? = nil
                height = relativeOffset
                for k in 0 ..< entries.count {
                    if entries[k].stableId == stableId {
                        index = k
                        break
                    }
                }
                
                if let index = index {
                    var success:Bool = false
                    var j:Int = index
                    for i in stride(from: index, to: -1, by: -1) {
                        let item = makeItem(entries[i])
                        height += item.height
                        firstInsertion.append((index - j, item))
                        j -= 1
                        if initialSize.height < height {
                            success = true
                            break
                        }
                    }
                    
                    if !success {
                        for i in (index + 1) ..< entries.count {
                            let item = makeItem(entries[i])
                            height += item.height
                            firstInsertion.insert((0, item), at: 0)
                            if initialSize.height < height {
                                success = true
                                break
                            }
                        }
                    }
                    
                    var reversed:[(Int, TableRowItem)] = []
                    var k:Int = 0
                    
                    for f in firstInsertion.reversed() {
                        reversed.append((k, f.1))
                        k += 1
                    }
                
                    firstInsertion = reversed
                    

                    
                    if success {
                        initialIndex = (j + 1)
                    } else {
                        let alreadyInserted = firstInsertion.count
                        for i in alreadyInserted ..< entries.count {
                            let item = makeItem(entries[i])
                            height += item.height
                            firstInsertion.append((i, item))
                            if initialSize.height < height {
                                break
                            }
                        }
                    }
                    
                    
                }
            case let .center(stableId, _, _, _, _):
                
                var index:Int? = nil
                for k in 0 ..< entries.count {
                    if entries[k].stableId == stableId {
                        index = k
                        break
                    }
                }
                if let index = index {
                    let item = makeItem(entries[index])
                    height += item.height
                    firstInsertion.append((index, item))
                    
                    
                    var low: Int = index + 1
                    var high: Int = index - 1
                    var lowHeight: CGFloat = 0
                    var highHeight: CGFloat = 0
                    
                    var lowSuccess: Bool = low > entries.count - 1
                    var highSuccess: Bool = high < 0
                    
                    while !lowSuccess || !highSuccess {
                        
                        if  (initialSize.height / 2) >= lowHeight && !lowSuccess {
                            let item = makeItem(entries[low])
                            lowHeight += item.height
                            firstInsertion.append((low, item))
                        }
                        
                        if (initialSize.height / 2) >= highHeight && !highSuccess  {
                            let item = makeItem(entries[high])
                            highHeight += item.height
                            firstInsertion.append((high, item))
                        }
                        
                        if (((initialSize.height / 2) <= lowHeight ) || low == entries.count - 1) {
                            lowSuccess = true
                        } else if !lowSuccess {
                            low += 1
                        }
                        
                        
                        if (((initialSize.height / 2) <= highHeight) || high == 0) {
                            highSuccess = true
                        } else if !highSuccess {
                            high -= 1
                        }
                        
                        
                    }
                    
                    initialIndex = max(high, 0)
   
                    
                    firstInsertion.sort(by: { lhs, rhs -> Bool in
                        return lhs.0 < rhs.0
                    })
                    
                    var copy = firstInsertion
                    firstInsertion.removeAll()
                    for i in 0 ..< copy.count {
                        firstInsertion.append((i, copy[i].1))
                    }
                }
                
                
                break
            default:

                for i in 0 ..< entries.count {
                    let item = makeItem(entries[i])
                    firstInsertion.append((i, item))
                    height += item.height
                    
                    if initialSize.height < height {
                        break
                    }
                }
            }
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state:state))
             
            
            messagesViewQueue.async {
                if !cancelled {
                    
                    var firstInsertedRange:NSRange = NSMakeRange(0, 0)
                    
                    if !firstInsertion.isEmpty {
                        firstInsertedRange = NSMakeRange(initialIndex, firstInsertion.count)
                    }
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    for i in 0 ..< entries.count {
                        let item:TableRowItem
                        
                        if firstInsertedRange.indexIn(i) {
                            //item = firstInsertion[i - initialIndex].1
                            //updates.append((i, item))
                        } else {
                            item = makeItem(entries[i])
                            insertions.append((i, item))
                        }
                        
                    }
                    subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .saveVisible(.upper)))
                    subscriber.putCompletion()
                }
            }
            
        } else if let state = scrollToItem {
            let (removed,inserted,updated) = proccessEntries(fromView?.filteredEntries, right: toView.filteredEntries, { entry -> TableRowItem in
               return makeItem(entry)
            })
            let grouping: Bool
            if case .none = state {
                grouping = false
            } else {
                grouping = true
            }
            
            
            subscriber.putNext(TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated, state: state, grouping: grouping))
            subscriber.putCompletion()
        }
        


        return ActionDisposable {
            cancelled = true
        }
    }
}



private func maxIncomingMessageIndexForEntries(_ entries: [ChatHistoryEntry], indexRange: (Int, Int)) -> MessageIndex? {
    if !entries.isEmpty {
        for i in (indexRange.0 ... indexRange.1).reversed() {
            if case let .MessageEntry(message, _, _, _, _, _, _) = entries[i], message.flags.contains(.Incoming) {
                return MessageIndex(message)
            }
        }
    }
    
    return nil
}

enum ChatHistoryViewTransitionReason {
    case Initial(fadeIn: Bool)
    case InteractiveChanges
    case HoleReload    
    case Reload
}


class ChatController: EditableViewController<ChatControllerView>, Notifable, TableViewDelegate {
    
    private var chatLocation:ChatLocation
    private let peerView = Promise<PostboxView?>()
    
    private let undoTooltipControl: UndoTooltipControl
    
    private let historyDisposable:MetaDisposable = MetaDisposable()
    private let peerDisposable:MetaDisposable = MetaDisposable()
    private let updatedChannelParticipants:MetaDisposable = MetaDisposable()
    private let sentMessageEventsDisposable = MetaDisposable()
    private let messageActionCallbackDisposable:MetaDisposable = MetaDisposable()
    private let shareContactDisposable:MetaDisposable = MetaDisposable()
    private let peerInputActivitiesDisposable:MetaDisposable = MetaDisposable()
    private let connectionStatusDisposable:MetaDisposable = MetaDisposable()
    private let messagesActionDisposable:MetaDisposable = MetaDisposable()
    private let unblockDisposable:MetaDisposable = MetaDisposable()
    private let updatePinnedDisposable:MetaDisposable = MetaDisposable()
    private let reportPeerDisposable:MetaDisposable = MetaDisposable()
    private let focusMessageDisposable:MetaDisposable = MetaDisposable()
    private let updateFontSizeDisposable:MetaDisposable = MetaDisposable()
    private let loadFwdMessagesDisposable:MetaDisposable = MetaDisposable()
    private let chatUnreadMentionCountDisposable:MetaDisposable = MetaDisposable()
    private let navigationActionDisposable:MetaDisposable = MetaDisposable()
    private let messageIndexDisposable: MetaDisposable = MetaDisposable()
    private let dateDisposable:MetaDisposable = MetaDisposable()
    private let interactiveReadingDisposable: MetaDisposable = MetaDisposable()
    private let showRightControlsDisposable: MetaDisposable = MetaDisposable()
    private let deleteChatDisposable: MetaDisposable = MetaDisposable()
    private let loadSelectionMessagesDisposable: MetaDisposable = MetaDisposable()
    private let updateMediaDisposable = MetaDisposable()
    private let editCurrentMessagePhotoDisposable = MetaDisposable()
    private let failedMessageEventsDisposable = MetaDisposable()
    private let selectMessagePollOptionDisposables: DisposableDict<MessageId> = DisposableDict()
    private let updateReqctionsDisposable: DisposableDict<MessageId> = DisposableDict()
    private let failedMessageIdsDisposable = MetaDisposable()
    private let hasScheduledMessagesDisposable = MetaDisposable()
    private let onlineMemberCountDisposable = MetaDisposable()
    private let chatUndoDisposable = MetaDisposable()
    private let discussionDataLoadDisposable = MetaDisposable()
    private let slowModeDisposable = MetaDisposable()
    private let slowModeInProgressDisposable = MetaDisposable()
    private let forwardMessagesDisposable = MetaDisposable()
    private let shiftSelectedDisposable = MetaDisposable()
    private let updateUrlDisposable = MetaDisposable()
    private let loadSharedMediaDisposable = MetaDisposable()
    private let applyMaxReadIndexDisposable = MetaDisposable()
    private let peekDisposable = MetaDisposable()
    private let searchState: ValuePromise<SearchMessagesResultState> = ValuePromise(SearchMessagesResultState("", []), ignoreRepeated: true)
    
    private let pollAnswersLoading: ValuePromise<[MessageId : ChatPollStateData]> = ValuePromise([:], ignoreRepeated: true)
    private let pollAnswersLoadingValue: Atomic<[MessageId : ChatPollStateData]> = Atomic(value: [:])

    private var pollAnswersLoadingSignal: Signal<[MessageId : ChatPollStateData], NoError> {
        return pollAnswersLoading.get()
    }
    private func update(_ f:([MessageId : ChatPollStateData])-> [MessageId : ChatPollStateData]) -> Void {
        pollAnswersLoading.set(pollAnswersLoadingValue.modify(f))
    }
    
    var chatInteraction:ChatInteraction
    
    var nextTransaction:TransactionHandler = TransactionHandler()
    
    private let _historyReady = Promise<Bool>()
    private var didSetHistoryReady = false

    
    private let location:Promise<ChatHistoryLocation> = Promise()
    private let _locationValue:Atomic<ChatHistoryLocation?> = Atomic(value: nil)
    private var locationValue:ChatHistoryLocation? {
        return _locationValue.with { $0 }
    }

    private func setLocation(_ location: ChatHistoryLocation) {
        _ = _locationValue.swap(location)
        self.location.set(.single(location))
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    private let readHistoryDisposable = MetaDisposable()
    
    
    private let initialDataHandler:Promise<ChatHistoryCombinedInitialData> = Promise()

    let previousView = Atomic<ChatHistoryView?>(value: nil)
    
    
    private let botCallbackAlertMessage = Promise<(String?, Bool)>((nil, false))
    private var botCallbackAlertMessageDisposable: Disposable?
    
    private var selectTextController:ChatSelectText!
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?

    
    let layoutDisposable:MetaDisposable = MetaDisposable()
    
    private var afterNextTransaction:(()->Void)?
    
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let unsupportedMessageProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    var historyState:ChatHistoryState = ChatHistoryState() {
        didSet {
            //if historyState != oldValue {
                genericView.updateScroller(historyState) // updateScroller()
            //}
        }
    }
    
    func clearReplyStack() {
        self.historyState = historyState.withClearReplies()
    }

    override var navigationController: NavigationViewController? {
        didSet {
            updateSidebar()
        }
    }

    override func scrollup(force: Bool = false) -> Void {
        if let reply = historyState.reply() {
            chatInteraction.focusMessageId(nil, reply, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
            historyState = historyState.withRemovingReplies(max: reply)
        } else {
            let laterId = previousView.with { $0?.originalView?.laterId }
            if laterId != nil {
                setLocation(.Scroll(index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, sourceIndex: MessageHistoryAnchorIndex.lowerBound, scrollPosition: .down(true), count: requestCount, animated: true))
            } else {
                genericView.tableView.scroll(to: .down(true))
            }

        }
        
    }
    
    private var requestCount: Int {
        return Int(round(genericView.tableView.frame.height / 28)) + 10
    }
    
    func readyHistory() {
        if !didSetHistoryReady {
            didSetHistoryReady = true
            _historyReady.set(.single(true))
        }
    }
    
    override var sidebar:ViewController? {
        return context.sharedContext.bindings.entertainment()
    }
    
    func updateSidebar() {
        if FastSettings.sidebarShown && FastSettings.sidebarEnabled {
            (navigationController as? MajorNavigationController)?.genericView.setProportion(proportion: SplitProportion(min:380, max:730), state: .single)
            (navigationController as? MajorNavigationController)?.genericView.setProportion(proportion: SplitProportion(min:380+350, max:.greatestFiniteMagnitude), state: .dual)
        } else {
            (navigationController as? MajorNavigationController)?.genericView.removeProportion(state: .dual)
            (navigationController as? MajorNavigationController)?.genericView.setProportion(proportion: SplitProportion(min:380, max: .greatestFiniteMagnitude), state: .single)
        }
    }
    

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        self.undoTooltipControl.getYInset = { [weak self] in
            guard let `self` = self else {
                return 10
            }
            return self.genericView.inputView.frame.height + 10
        }
        
        weak var previousView = self.previousView
        let context = self.context
        let atomicSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        let nextTransaction = self.nextTransaction
        
        let peerId = self.chatInteraction.peerId
        
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.CloudChannel {
            slowModeInProgressDisposable.set((context.account.postbox.unsentMessageIdsView() |> mapToSignal { view -> Signal<[MessageId], NoError> in
                return context.account.postbox.messagesAtIds(Array(view.ids)) |> map { messages in
                    return messages.filter { $0.flags.contains(.Unsent) }.map { $0.id }
                }
            } |> deliverOnMainQueue).start(next: { [weak self] ids in
                self?.chatInteraction.update({ $0.updateSlowMode {
                    $0?.withUpdatedSendingIds(ids)
                }})
            }))
        }
        
        
        genericView.tableView.emptyChecker = { [weak self] items in
            
            let filtred = items.filter { item in
                if let item = item as? ChatRowItem, let message = item.message {
                    if let action = message.media.first as? TelegramMediaAction {
                        switch action.action {
                        case .groupCreated:
                            return messageMainPeer(message)?.groupAccess.isCreator == false
                        case .groupMigratedToChannel:
                            return false
                        case .channelMigratedFromGroup:
                            return false
                        case .photoUpdated:
                            return true
                        default:
                            return true
                        }
                    }
                    return true
                }
                return false
            }
            
            return filtred.isEmpty && self?.genericView.state != .progress
        }

        
        genericView.tableView.delegate = self
        
        
        switch chatLocation {
        case let .peer(peerId):
            self.peerView.set(context.account.viewTracker.peerView(peerId, updateData: true) |> map {Optional($0)})
            let _ = checkPeerChatServiceActions(postbox: context.account.postbox, peerId: peerId).start()
        }
        

//        context.globalPeerHandler.set(.single(chatLocation))
        

        let layout:Atomic<SplitViewState> = Atomic(value:context.sharedContext.layout)
        layoutDisposable.set(context.sharedContext.layoutHandler.get().start(next: {[weak self] (state) in
            let previous = layout.swap(state)
            if previous != state, let navigation = self?.navigationController {
                self?.requestUpdateBackBar()
                if let modalAction = navigation.modalAction {
                    navigation.set(modalAction: modalAction, state != .single)
                }
            }
        }))
        
        selectTextController = ChatSelectText(genericView.tableView)
        
        let maxReadIndex:ValuePromise<MessageIndex?> = ValuePromise()
        var didSetReadIndex: Bool = false

        let historyViewUpdate1 = location.get() |> deliverOnMainQueue
            |> mapToSignal { [weak self] location -> Signal<(ChatHistoryViewUpdate, TableSavingSide?), NoError> in
                guard let `self` = self else { return .never() }
                
                
                let peerId = self.chatInteraction.peerId
                
                var additionalData: [AdditionalMessageHistoryViewData] = []
                additionalData.append(.cachedPeerData(peerId))
                additionalData.append(.cachedPeerDataMessages(peerId))
                additionalData.append(.peerNotificationSettings(peerId))
                additionalData.append(.preferencesEntry(PreferencesKeys.limitsConfiguration))
                additionalData.append(.preferencesEntry(ApplicationSpecificPreferencesKeys.autoplayMedia))
                additionalData.append(.preferencesEntry(ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings))
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: peerId)))
                    additionalData.append(.peer(peerId))
                }
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
                    additionalData.append(.peerIsContact(peerId))
                }
                
                
                return chatHistoryViewForLocation(location, account: context.account, chatLocation: self.chatLocation, fixedCombinedReadStates: { nil }, tagMask: nil, mode: self.mode, additionalData: additionalData) |> beforeNext { viewUpdate in
                    switch viewUpdate {
                    case let .HistoryView(view, _, _, _):
                        if !didSetReadIndex {
                            maxReadIndex.set(view.maxReadIndex)
                            didSetReadIndex = true
                        }
                    default:
                        maxReadIndex.set(nil)
                    }
                    } |> map { view in
                        return (view, location.side)
                }
        }
        let historyViewUpdate = historyViewUpdate1

        
        let animatedEmojiStickers = loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: .animatedEmoji, forceActualized: false)
            |> map { result -> [String: StickerPackItem] in
                switch result {
                case let .result(_, items, _):
                    var animatedEmojiStickers: [String: StickerPackItem] = [:]
                    for case let item as StickerPackItem in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji] = item
                        }
                    }
                    return animatedEmojiStickers
                default:
                    return [:]
                }
        }

        
        
        let previousAppearance:Atomic<Appearance> = Atomic(value: appAppearance)
        let firstInitialUpdate:Atomic<Bool> = Atomic(value: true)
        
        let applyHole:() -> Void = { [weak self] in
            guard let `self` = self else { return }
            
            let visibleRows = self.genericView.tableView.visibleRows()
            var messageIndex: MessageIndex?
            for i in stride(from: visibleRows.max - 1, to: -1, by: -1) {
                if let item = self.genericView.tableView.item(at: i) as? ChatRowItem, let message = item.message  {
                    messageIndex = MessageIndex(message)
                    break
                }
            }
            
            if let messageIndex = messageIndex {
                self.setLocation(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: self.requestCount, side: .upper))
            } else if let location = self.locationValue {
                self.setLocation(location)
            }
        
        }
        
        let clearHistoryUndoSignal = context.chatUndoManager.status(for: chatInteraction.peerId, type: .clearHistory)
        
        let _searchState: Atomic<SearchMessagesResultState> = Atomic(value: SearchMessagesResultState("", []))
        
        let historyViewTransition = combineLatest(queue: messagesViewQueue, historyViewUpdate, appearanceSignal, combineLatest(maxReadIndex.get() |> deliverOnMessagesViewQueue, pollAnswersLoadingSignal), clearHistoryUndoSignal, searchState.get(), animatedEmojiStickers) |> mapToQueue { update, appearance, readIndexAndPollAnswers, clearHistoryStatus, searchState, animatedEmojiStickers -> Signal<(TableUpdateTransition, MessageHistoryView?, ChatHistoryCombinedInitialData, Bool), NoError> in
            
            //NSLog("get history")
            
            let maxReadIndex = readIndexAndPollAnswers.0
            let pollAnswersLoading = readIndexAndPollAnswers.1
            
            let searchStateUpdated = _searchState.swap(searchState) != searchState
            
            let isLoading: Bool
            let view: MessageHistoryView?
            let initialData: ChatHistoryCombinedInitialData
            let updateType: ChatHistoryViewUpdateType
            let scrollPosition: ChatHistoryViewScrollPosition?
            switch update.0 {
            case let .Loading(data, ut):
                view = nil
                initialData = data
                isLoading = true
                updateType = ut
                scrollPosition = nil
            case let .HistoryView(values):
                initialData = values.initialData
                view = values.view
                isLoading = values.view.isLoading
                updateType = values.type
                scrollPosition = searchStateUpdated ? nil : values.scrollPosition
            }
            
            switch updateType {
            case let .Generic(type: type):
                switch type {
                case .FillHole:
                    Queue.mainQueue().async {
                         applyHole()
                    }
                    return .complete()
                default:
                    break
                }
            default:
                break
            }
            
            
            let pAppearance = previousAppearance.swap(appearance)
            var prepareOnMainQueue = pAppearance.presentation != appearance.presentation
            switch updateType {
            case .Initial:
                prepareOnMainQueue = firstInitialUpdate.swap(false) || prepareOnMainQueue
            default:
                break
            }
            let animationInterface: TableAnimationInterface = TableAnimationInterface(nextTransaction.isExutable && view?.laterId == nil)
            let timeDifference = context.timeDifference
            let bigEmojiEnabled = context.sharedContext.baseSettings.bigEmoji

            
            var ranks: CachedChannelAdminRanks?
            if let view = view {
                for additionalEntry in view.additionalData {
                    if case let .cacheEntry(id, data) = additionalEntry {
                        if id == cachedChannelAdminRanksEntryId(peerId: chatInteraction.peerId), let data = data as? CachedChannelAdminRanks {
                            ranks = data
                        }
                        break
                    }
                }
            }
           
            
            let proccesedView:ChatHistoryView
            if let view = view {
                if let peer = chatInteraction.peer, peer.isRestrictedChannel(context.contentSettings) {
                    proccesedView = ChatHistoryView(originalView: view, filteredEntries: [])
                } else if let clearHistoryStatus = clearHistoryStatus, clearHistoryStatus != .cancelled {
                    proccesedView = ChatHistoryView(originalView: view, filteredEntries: [])
                } else {
                    let entries = messageEntries(view.entries, maxReadIndex: maxReadIndex, dayGrouping: true, renderType: appearance.presentation.bubbled ? .bubble : .list, includeBottom: true, timeDifference: timeDifference, ranks: ranks, pollAnswersLoading: pollAnswersLoading, groupingPhotos: true, autoplayMedia: initialData.autoplayMedia, searchState: searchState, animatedEmojiStickers: bigEmojiEnabled ? animatedEmojiStickers : [:]).map({ChatWrapperEntry(appearance: AppearanceWrapperEntry(entry: $0, appearance: appearance), automaticDownload: initialData.autodownloadSettings)})
                    proccesedView = ChatHistoryView(originalView: view, filteredEntries: entries)
                }
            } else {
                proccesedView = ChatHistoryView(originalView: nil, filteredEntries: [])
            }
            
            
            return prepareEntries(from: previousView?.swap(proccesedView), to: proccesedView, timeDifference: timeDifference, initialSize: atomicSize.modify({$0}), interaction: chatInteraction, animated: false, scrollPosition:scrollPosition, reason: updateType, animationInterface: animationInterface, side: update.1) |> map { transition in
                return (transition, view, initialData, isLoading)
            } |> runOn(prepareOnMainQueue ? Queue.mainQueue(): messagesViewQueue)
            
        } |> deliverOnMainQueue
        
        
        let appliedTransition = historyViewTransition |> map { [weak self] transition, view, initialData, isLoading  in
            self?.applyTransition(transition, view: view, initialData: initialData, isLoading: isLoading)
        }
        
        
        self.historyDisposable.set(appliedTransition.start())
        
        let previousMaxIncomingMessageIdByNamespace = Atomic<[MessageId.Namespace: MessageIndex]>(value: [:])
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), self.isKeyWindow.get())
            |> map { [weak self] messageIndex, canRead in
                guard let `self` = self else {return}
                if canRead {
                    var apply = false
                    let _ = previousMaxIncomingMessageIdByNamespace.modify { dict in
                        let previousIndex = dict[messageIndex.id.namespace]
                        if previousIndex == nil || previousIndex! < messageIndex {
                            apply = true
                            var dict = dict
                            dict[messageIndex.id.namespace] = messageIndex
                            return dict
                        }
                        return dict
                    }
                    if apply {
                        switch self.chatLocation {
                        case let .peer(peerId):
                            if !hasModals() {
                                clearNotifies(peerId, maxId: messageIndex.id)
                                let signal = applyMaxReadIndexInteractively(postbox: context.account.postbox, stateManager: context.account.stateManager, index: messageIndex)
                                self.applyMaxReadIndexDisposable.set(signal.start())
                            }
                        }
                    }
                }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        

        
        chatInteraction.setupReplyMessage = { [weak self] messageId in
            guard let `self` = self, self.mode == .history else { return }
            
            self.chatInteraction.focusInputField()
            let signal:Signal<Message?, NoError> = messageId == nil ? .single(nil) : self.chatInteraction.context.account.postbox.messageAtId(messageId!)
            _ = (signal |> deliverOnMainQueue).start(next: { [weak self] message in
                self?.chatInteraction.update({ current in
                    var current = current.updatedInterfaceState({$0.withUpdatedReplyMessageId(messageId).withUpdatedReplyMessage(message)})
                    if messageId == current.keyboardButtonsMessage?.replyAttribute?.messageId {
                        current = current.updatedInterfaceState({$0.withUpdatedDismissedForceReplyId(messageId)})
                    }
                    return current
                })
            })
            
            
        }
        
        chatInteraction.startRecording = { [weak self] hold, view in
            guard let chatInteraction = self?.chatInteraction else {return}
            if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                if let last = slowMode.sendingIds.last {
                    chatInteraction.focusMessageId(nil, last, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                }
                if let view = self?.genericView.inputView.currentActionView {
                    showSlowModeTimeoutTooltip(slowMode, for: view)
                    return
                }
            }
            if chatInteraction.presentation.recordingState != nil || chatInteraction.presentation.state != .normal {
                NSSound.beep()
                return
            }
            if let peer = chatInteraction.presentation.peer {
                if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                    alert(for: context.window, info: permissionText)
                    return
                }
                if chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                    
                    
                    
                    switch FastSettings.recordingState {
                    case .voice:
                        let permission: Signal<Bool, NoError> = requestMediaPermission(.audio) |> deliverOnMainQueue
                       _ = permission.start(next: { [weak chatInteraction] access in
                            guard let chatInteraction = chatInteraction else {
                                return
                            }
                            if access {
                                let state = ChatRecordingAudioState(account: chatInteraction.context.account, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                                state.start()
                                delay(0.1, closure: { [weak chatInteraction] in
                                    chatInteraction?.update({$0.withRecordingState(state)})
                                })
                            } else {
                                confirm(for: mainWindow, information: L10n.requestAccesErrorHaveNotAccessVoiceMessages, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
                                   switch result {
                                   case .thrid:
                                       openSystemSettings(.none)
                                   default:
                                       break
                                   }
                               })
                            }
                        })
                    case .video:
                        let permission: Signal<Bool, NoError> = combineLatest(requestMediaPermission(.video), requestMediaPermission(.audio)) |> map { $0 && $1 } |> deliverOnMainQueue
                        _ = permission.start(next: { [weak chatInteraction] access in
                            guard let chatInteraction = chatInteraction else {
                                return
                            }
                            if access {
                                let state = ChatRecordingVideoState(account: chatInteraction.context.account, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                                showModal(with: VideoRecorderModalController(chatInteraction: chatInteraction, pipeline: state.pipeline), for: context.window)
                                chatInteraction.update({$0.withRecordingState(state)})
                            } else {
                                confirm(for: mainWindow, information: L10n.requestAccesErrorHaveNotAccessVideoMessages, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
                                    switch result {
                                    case .thrid:
                                        openSystemSettings(.none)
                                    default:
                                        break
                                    }
                                })
                            }
                           
                        })
                    }
                    
                   
                }
            }
        }
        
        let scrollAfterSend:()->Void = { [weak self] in
            guard let `self` = self else { return }
            self.chatInteraction.scrollToLatest(true)
            self.context.sharedContext.bindings.entertainment().closePopover()
            self.context.cancelGlobalSearch.set(true)
        }
        
        
        let afterSentTransition = { [weak self] in
           self?.chatInteraction.update({ presentation in
            return presentation.updatedInputQueryResult({_ in return nil}).updatedInterfaceState { current in
                
                var value: ChatInterfaceState = current.withUpdatedReplyMessageId(nil).withUpdatedInputState(ChatTextInputState()).withUpdatedForwardMessageIds([]).withUpdatedComposeDisableUrlPreview(nil)
            
            
                if let message = presentation.keyboardButtonsMessage, let replyMarkup = message.replyMarkup {
                    if replyMarkup.flags.contains(.setupReply) {
                        value = value.withUpdatedDismissedForceReplyId(message.id)
                    }
                }
                return value
            }.updatedUrlPreview(nil)
            
           })
            self?.chatInteraction.saveState(scrollState: self?.immediateScrollState())
        }
        
        chatInteraction.jumpToDate = { [weak self] date in
            if let strongSelf = self, let window = self?.window, let peerId = self?.chatInteraction.peerId {
                
                
                switch strongSelf.mode {
                case .history:
                    let signal = searchMessageIdByTimestamp(account: context.account, peerId: peerId, timestamp: Int32(date.timeIntervalSince1970))
                    
                    self?.dateDisposable.set(showModalProgress(signal: signal, for: window).start(next: { messageId in
                        if let messageId = messageId {
                            self?.chatInteraction.focusMessageId(nil, messageId, .top(id: 0, innerId: nil, animated: true, focus: .init(focus: false), inset: 30))
                        }
                    }))
                case .scheduled:
                    var previousItem: ChatRowItem?
                    strongSelf.genericView.tableView.enumerateItems(with: { item -> Bool in
                        
                        if let item = item as? ChatDateStickItem {
                            var calendar = NSCalendar.current
                            
                            calendar.timeZone = TimeZone(abbreviation: "UTC")!
                            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp + 86400))
                            let components = calendar.dateComponents([.year, .month, .day], from: date)
                            
                            if CalendarUtils.monthDay(components.day!, date: date) == date {
                                return false
                            }
                        } else if let item = item as? ChatRowItem {
                            previousItem = item
                        }
                        
                        return true
                    })
                    
                    if let previousItem = previousItem {
                        self?.genericView.tableView.scroll(to: .top(id: previousItem.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 30))
                    }
                }
                
                
            }
        }
       
        let editMessage:(ChatEditState, Date?)->Void = { [weak self] state, atDate in
            guard let `self` = self else {return}
            let presentation = self.chatInteraction.presentation
            let inputState = state.inputState.subInputState(from: NSMakeRange(0, state.inputState.inputText.length))
            self.urlPreviewQueryState?.1.dispose()
            self.chatInteraction.update({$0.updatedUrlPreview(nil).updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedLoadingState(state.editMedia == .keep ? .loading : .progress(0.2))})})})
            
            let scheduleTime:Int32? = atDate != nil ? Int32(atDate!.timeIntervalSince1970) : nil
            self.chatInteraction.editDisposable.set((requestEditMessage(account: context.account, messageId: state.message.id, text: inputState.inputText, media: state.editMedia, entities: TextEntitiesMessageAttribute(entities: inputState.messageTextEntities()), disableUrlPreview: presentation.interfaceState.composeDisableUrlPreview != nil, scheduleTime: scheduleTime)
            |> deliverOnMainQueue).start(next: { [weak self] progress in
                    guard let `self` = self else {return}
                    switch progress {
                    case let .progress(progress):
                        if state.editMedia != .keep {
                            self.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedLoadingState(.progress(max(progress, 0.2)))})})})
                        }
                    default:
                        break
                    }
                    
            }, completed: { [weak self] in
                guard let `self` = self else {return}
                self.chatInteraction.beginEditingMessage(nil)
                self.chatInteraction.update({
                    $0.updatedInterfaceState({
                        $0.withUpdatedComposeDisableUrlPreview(nil).updatedEditState({
                            $0?.withUpdatedLoadingState(.none)
                        })
                    })
                })
            }))
        }
        
        chatInteraction.sendMessage = { [weak self] silent, atDate in
            if let strongSelf = self {
                let presentation = strongSelf.chatInteraction.presentation
                let peerId = strongSelf.chatInteraction.peerId
                
                if presentation.abilityToSend {
                    func apply(_ controller: ChatController, atDate: Date?) {
                        var invokeSignal:Signal<Never, NoError> = .complete()
                        
                        var setNextToTransaction = false
                        if let state = presentation.interfaceState.editState {
                            editMessage(state, atDate)
                            return
                        } else  if !presentation.effectiveInput.inputText.trimmed.isEmpty {
                            setNextToTransaction = true
                            invokeSignal = Sender.enqueue(input: presentation.effectiveInput, context: context, peerId: controller.chatInteraction.peerId, replyId: presentation.interfaceState.replyMessageId, disablePreview: presentation.interfaceState.composeDisableUrlPreview != nil, silent: silent, atDate: atDate, secretMediaPreview: presentation.urlPreview?.1) |> deliverOnMainQueue |> ignoreValues
                            
                        }
                        
                        let fwdIds: [MessageId] = presentation.interfaceState.forwardMessageIds
                        if !fwdIds.isEmpty {
                            setNextToTransaction = true
                            
                            
                            let fwd = combineLatest(queue: .mainQueue(), context.account.postbox.messagesAtIds(fwdIds), context.account.postbox.loadedPeerWithId(peerId)) |> mapToSignal { messages, peer -> Signal<[MessageId?], NoError> in
                                let errors:[String] = messages.compactMap { message in
                                    
                                    for attr in message.attributes {
                                        if let _ = attr as? InlineBotMessageAttribute, peer.hasBannedRights(.banSendInline) {
                                            return permissionText(from: peer, for: .banSendInline)
                                        }
                                    }
                                    
                                    if let media = message.media.first {
                                        switch media {
                                        case _ as TelegramMediaPoll:
                                            return permissionText(from: peer, for: .banSendPolls)
                                        case _ as TelegramMediaImage:
                                            return permissionText(from: peer, for: .banSendMedia)
                                        case let file as TelegramMediaFile:
                                            if file.isAnimated && file.isVideo {
                                                return permissionText(from: peer, for: .banSendGifs)
                                            } else if file.isStaticSticker {
                                                return permissionText(from: peer, for: .banSendStickers)
                                            } else {
                                                return permissionText(from: peer, for: .banSendMedia)
                                            }
                                        case _ as TelegramMediaGame:
                                            return permissionText(from: peer, for: .banSendGames)
                                        default:
                                            return nil
                                        }
                                    }
                                    
                                    return nil
                                }
                                
                                if !errors.isEmpty {
                                    alert(for: context.window, info: errors.joined(separator: "\n\n"))
                                    return .complete()
                                }
                                
                                return Sender.forwardMessages(messageIds: messages.map {$0.id}, context: context, peerId: peerId, silent: silent, atDate: atDate)
                            }
                            
                            invokeSignal = invokeSignal |> then( fwd |> ignoreValues)
                            
                        }
                        
                        _ = (invokeSignal |> deliverOnMainQueue).start(completed: scrollAfterSend)
                        
                        if setNextToTransaction {
                            if atDate != nil {
                                afterSentTransition()
                            } else {
                                controller.nextTransaction.set(handler: afterSentTransition)
                            }
                        }
                    }
                    
                    switch strongSelf.mode {
                    case .scheduled:
                        if let atDate = atDate {
                            apply(strongSelf, atDate: atDate)
                        } else if presentation.state != .editing, let peer = chatInteraction.peer {
                            DispatchQueue.main.async {
                                showModal(with: ScheduledMessageModalController(context: context, peerId: peer.id, scheduleAt: { [weak strongSelf] date in
                                    if let strongSelf = strongSelf {
                                        apply(strongSelf, atDate: date)
                                    }
                                }), for: context.window)
                            }
                        } else {
                             apply(strongSelf, atDate: nil)
                        }
                    case .history:
                        delay(0.1, closure: {
                            if atDate != nil {
                                strongSelf.openScheduledChat()
                            }
                        })
                        apply(strongSelf, atDate: atDate)
                    }
                    
                } else {
                    if let editState = presentation.interfaceState.editState, editState.inputState.inputText.isEmpty {
                        if editState.message.media.isEmpty || editState.message.media.first is TelegramMediaWebpage {
                            strongSelf.chatInteraction.deleteMessages([editState.message.id])
                            return
                        }
                    }
                    let actionView = strongSelf.genericView.inputView.currentActionView
                    if let slowMode = presentation.slowMode {
                        if let errorText = presentation.slowModeErrorText {
                            if let slowMode = presentation.slowMode, slowMode.timeout != nil {
                                showSlowModeTimeoutTooltip(slowMode, for: actionView)
                            } else {
                                tooltip(for: actionView, text: errorText)
                            }
                            if let last = slowMode.sendingIds.last {
                                strongSelf.chatInteraction.focusMessageId(nil, last, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                            } else {
                                strongSelf.genericView.inputView.textView.shake()
                            }
                        } else {
                            strongSelf.genericView.inputView.textView.shake()
                        }
                       
                    } else {
                        strongSelf.genericView.inputView.textView.shake()
                    }
                }
            }
        }
        
        chatInteraction.updateEditingMessageMedia = { [weak self] exts, asMedia in
            guard let `self` = self else {return}
            
            filePanel(with: exts, allowMultiple: false, for: context.window, completion: { [weak self] files in
                guard let `self` = self else {return}
                if let file = files?.first {
                    self.updateMediaDisposable.set((Sender.generateMedia(for: MediaSenderContainer(path: file, isFile: !asMedia), account: context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) |> deliverOnMainQueue).start(next: { [weak self] media, _ in
                        self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                    }))
                }
            })
        }
        
        
        chatInteraction.addContact = { [weak self] in
            if let peerId = self?.chatInteraction.presentation.mainPeer?.id {
                showModal(with: NewContactController(context: context, peerId: peerId), for: context.window)
            }
        }
        chatInteraction.blockContact = { [weak self] in
            if let chatInteraction = self?.chatInteraction, let peer = chatInteraction.presentation.mainPeer {
                if peer.isUser || peer.isBot {
                    let options: [ModalOptionSet] = [ModalOptionSet(title: L10n.blockContactOptionsReport, selected: true, editable: true), ModalOptionSet(title: L10n.blockContactOptionsDeleteChat, selected: true, editable: true)]
                    
                    showModal(with: ModalOptionSetController(context: chatInteraction.context, options: options, actionText: (L10n.blockContactOptionsAction(peer.compactDisplayTitle), theme.colors.redUI), desc: L10n.blockContactTitle(peer.compactDisplayTitle), title: L10n.blockContactOptionsTitle, result: { result in
                        
                        var signals:[Signal<Never, NoError>] = []
                        
                        signals.append(context.blockedPeersContext.add(peerId: peer.id) |> `catch` { _ in return .complete() })
                        
                        if result[1] == .selected {
                            signals.append(removePeerChat(account: context.account, peerId: chatInteraction.peerId, reportChatSpam: result[0] == .selected) |> ignoreValues)
                        } else if result[0] == .selected {
                            signals.append(reportPeer(account: context.account, peerId: peer.id) |> ignoreValues)
                        }
                        let closeChat = result[1] == .selected
                        
                        _ = showModalProgress(signal: combineLatest(signals), for: context.window).start(completed: {
                            if closeChat {
                                context.sharedContext.bindings.rootNavigation().back()
                            }
                        })
                        
                    }), for: context.window)
                } else {
                    chatInteraction.reportSpamAndClose()
                }
               
            }
            
        }
        
        chatInteraction.unarchive = {
            _ = updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: .root).start()
            _ = context.account.postbox.transaction { transaction in
                transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, cachedData in
                    if let cachedData = cachedData as? CachedUserData {
                        let current = cachedData.peerStatusSettings
                        var flags = current?.flags ?? []
                        flags.remove(.autoArchived)
                        flags.remove(.canBlock)
                        flags.remove(.canReport)
                        return cachedData.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: flags, geoDistance: current?.geoDistance))
                    }
                    if let cachedData = cachedData as? CachedChannelData {
                        let current = cachedData.peerStatusSettings
                        var flags = current?.flags ?? []
                        flags.remove(.autoArchived)
                        flags.remove(.canBlock)
                        flags.remove(.canReport)
                        return cachedData.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: flags, geoDistance: current?.geoDistance))
                    }
                    if let cachedData = cachedData as? CachedGroupData {
                        let current = cachedData.peerStatusSettings
                        var flags = current?.flags ?? []
                        flags.remove(.autoArchived)
                        flags.remove(.canBlock)
                        flags.remove(.canReport)
                        return cachedData.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: flags, geoDistance: current?.geoDistance))
                    }
                    return cachedData
                })
            }.start()
        }
        
        chatInteraction.sendPlainText = { [weak self] text in
            if let strongSelf = self, let peer = self?.chatInteraction.presentation.peer, peer.canSendMessage {
                let _ = (Sender.enqueue(input: ChatTextInputState(inputText: text), context: context, peerId: strongSelf.chatInteraction.peerId, replyId: strongSelf.chatInteraction.presentation.interfaceState.replyMessageId) |> deliverOnMainQueue).start(completed: scrollAfterSend)
            }
        }
        
        chatInteraction.sendLocation = { [weak self] coordinate, venue in
            let media = TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: venue, liveBroadcastingTimeout: nil)
            self?.chatInteraction.sendMedias([media], ChatTextInputState(), false, nil, false, nil)
        }
        
        chatInteraction.scrollToLatest = { [weak self] removeStack in
            if let strongSelf = self {
                if removeStack {
                    strongSelf.historyState = strongSelf.historyState.withClearReplies()
                }
                strongSelf.scrollup()
            }
        }
        
        chatInteraction.forwardMessages = { forwardMessages in
            showModal(with: ShareModalController(ForwardMessagesObject(context, messageIds: forwardMessages)), for: context.window)
        }
        
        chatInteraction.deleteMessages = { [weak self] messageIds in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {
                
                let channelAdmin:Promise<[ChannelParticipant]?> = Promise()
                    
                if peer.isSupergroup {
                    let disposable: MetaDisposable = MetaDisposable()
                    let result = context.peerChannelMemberCategoriesContextsManager.admins(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: peer.id, updated: { state in
                        switch state.loadingState {
                        case .ready:
                            channelAdmin.set(.single(state.list.map({$0.participant})))
                            disposable.dispose()
                        default:
                            break
                        }
                    })
                    disposable.set(result.0)
                } else {
                    channelAdmin.set(.single(nil))
                }
            
                
                self?.messagesActionDisposable.set(combineLatest(context.account.postbox.messagesAtIds(messageIds) |> deliverOnMainQueue, channelAdmin.get() |> deliverOnMainQueue).start( next:{ [weak strongSelf] messages, admins in
                    if let strongSelf = strongSelf, let peer = strongSelf.chatInteraction.peer {
                        var canDelete:Bool = true
                        var canDeleteForEveryone = true
                        var otherCounter:Int32 = 0
                        let peerId = peer.id
                        var _mustDeleteForEveryoneMessage: Bool = true
                        for message in messages {
                            if !canDeleteMessage(message, account: context.account) {
                                canDelete = false
                            }
                            if !mustDeleteForEveryoneMessage(message) {
                                _mustDeleteForEveryoneMessage = false
                            }
                            if !canDeleteForEveryoneMessage(message, context: context) {
                                canDeleteForEveryone = false
                            } else {
                                if message.effectiveAuthor?.id != context.peerId && !(context.limitConfiguration.canRemoveIncomingMessagesInPrivateChats && message.peers[message.id.peerId] is TelegramUser)  {
                                    if let peer = message.peers[message.id.peerId] as? TelegramGroup {
                                        inner: switch peer.role {
                                        case .member:
                                            otherCounter += 1
                                        default:
                                            break inner
                                        }
                                    } else {
                                        otherCounter += 1
                                    }
                                }
                            }
                        }
                        
                        if otherCounter > 0 || peer.id == context.peerId {
                            canDeleteForEveryone = false
                        }
                        if messages.isEmpty {
                            strongSelf.chatInteraction.update({$0.withoutSelectionState()})
                            return
                        }
                        
                        if canDelete {
                            if mustManageDeleteMessages(messages, for: peer, account: context.account), let memberId = messages[0].author?.id {
                                
                                var options:[ModalOptionSet] = []
                                
                                options.append(ModalOptionSet(title: L10n.supergroupDeleteRestrictionDeleteMessage, selected: true, editable: true))
                                
                                var hasRestrict: Bool = false
                                
                                if let channel = peer as? TelegramChannel {
                                    if channel.hasPermission(.banMembers) {
                                        options.append(ModalOptionSet(title: L10n.supergroupDeleteRestrictionBanUser, selected: false, editable: true))
                                        hasRestrict = true
                                    }
                                }
                                options.append(ModalOptionSet(title: L10n.supergroupDeleteRestrictionReportSpam, selected: false, editable: true))
                                options.append(ModalOptionSet(title: L10n.supergroupDeleteRestrictionDeleteAllMessages, selected: false, editable: true))
                                
                                
                                
                                showModal(with: ModalOptionSetController(context: context, options: options, actionText: (L10n.modalOK, theme.colors.accent), title: L10n.supergroupDeleteRestrictionTitle, result: { [weak strongSelf] result in
                                    
                                    var signals:[Signal<Void, NoError>] = []
                                    
                                    var index:Int = 0
                                    if result[index] == .selected {
                                        signals.append(deleteMessagesInteractively(account: context.account, messageIds: messageIds, type: .forEveryone))
                                    }
                                    index += 1
                                    
                                    if hasRestrict {
                                        if result[index] == .selected {
                                            signals.append(context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)))
                                        }
                                        index += 1
                                    }
                                    
                                    if result[index] == .selected {
                                        signals.append(reportSupergroupPeer(account: context.account, peerId: memberId, memberId: memberId, messageIds: messageIds))
                                    }
                                    index += 1

                                    if result[index] == .selected {
                                        signals.append(clearAuthorHistory(account: context.account, peerId: peerId, memberId: memberId))
                                    }
                                    index += 1

                                    _ = showModalProgress(signal: combineLatest(signals), for: context.window).start()
                                    strongSelf?.chatInteraction.update({$0.withoutSelectionState()})
                                }), for: context.window)
                                
                            } else if let `self` = self {
                                let thrid:String? = self.mode == .scheduled ? nil : (canDeleteForEveryone ? peer.isUser ? L10n.chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : L10n.chatConfirmDeleteMessagesForEveryone : nil)
                                
                                modernConfirm(for: context.window, account: context.account, peerId: nil, header: thrid == nil ? L10n.chatConfirmActionUndonable : L10n.chatConfirmDeleteMessagesCountable(messages.count), information: thrid == nil ? _mustDeleteForEveryoneMessage ? L10n.chatConfirmDeleteForEveryoneCountable(messages.count) : L10n.chatConfirmDeleteMessagesCountable(messages.count) : nil, okTitle: L10n.confirmDelete, thridTitle: thrid, successHandler: { [weak strongSelf] result in
                                    
                                    guard let strongSelf = strongSelf else {return}
                                    
                                    let type:InteractiveMessagesDeletionType
                                    switch result {
                                    case .basic:
                                        type = .forLocalPeer
                                    case .thrid:
                                        type = .forEveryone
                                    }
                                    if let editingState = strongSelf.chatInteraction.presentation.interfaceState.editState {
                                        if messageIds.contains(editingState.message.id) {
                                            strongSelf.chatInteraction.cancelEditing()
                                        }
                                    }
                                    _ = deleteMessagesInteractively(account: context.account, messageIds: messageIds, type: type).start()
                                    strongSelf.chatInteraction.update({$0.withoutSelectionState()})
                                })
                            }
                        }
                    }
                }))
            }
        }
        
        chatInteraction.openInfo = { [weak self] (peerId, toChat, postId, action) in
            if let strongSelf = self {
                if toChat {
                    if peerId == strongSelf.chatInteraction.peerId {
                        if let postId = postId {
                            
                            var fromId: MessageId? = nil
                            if let action = action {
                                switch action {
                                case let .source(id):
                                    fromId = id
                                default:
                                    break
                                }
                            }
                            
                            strongSelf.chatInteraction.focusMessageId(fromId, postId, TableScrollState.center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                        }
                        if let action = action {
                            strongSelf.chatInteraction.update({ $0.updatedInitialAction(action) })
                        }
                    } else {
                       strongSelf.navigationController?.push(ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: postId, initialAction: action))
                    }
                } else {
                   strongSelf.navigationController?.push(PeerInfoController(context: context, peerId: peerId))
                }
            }
        }
        
        chatInteraction.showNextPost = { [weak self] in
            guard let `self` = self else {return}
            if let bottomVisibleRow = self.genericView.tableView.bottomVisibleRow {
                if bottomVisibleRow > 0 {
                    var item = self.genericView.tableView.item(at: bottomVisibleRow - 1)
                    if item.view?.visibleRect.height != item.view?.frame.height {
                        item = self.genericView.tableView.item(at: bottomVisibleRow)
                    }
                    self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets(), true)
                }
                
            }
        }
        
        chatInteraction.openFeedInfo = { [weak self] groupId in
            guard let `self` = self else {return}
            self.navigationController?.push(ChatListController(context, groupId: groupId))
        }
        
        chatInteraction.openProxySettings = { [weak self] in
            let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, pushController: { [weak self] controller in
                 self?.navigationController?.push(controller)
            })
            self?.navigationController?.push(controller)
        }
        
        chatInteraction.inlineAudioPlayer = { [weak self] controller in
            if let navigation = self?.navigationController {
                if let header = navigation.header, let strongSelf = self {
                    header.show(true)
                    if let view = header.view as? InlineAudioPlayerView {
                        view.update(with: controller, context: context, tableView: strongSelf.genericView.tableView)
                    }
                }
            }
        }
        chatInteraction.searchPeerMessages = { [weak self] peer in
            guard let `self` = self else { return }
            self.chatInteraction.update({$0.updatedSearchMode((false, nil, nil))})
            self.chatInteraction.update({$0.updatedSearchMode((true, peer, nil))})
        }
        chatInteraction.movePeerToInput = { [weak self] (peer) in
            if let strongSelf = self {
                let textInputState = strongSelf.chatInteraction.presentation.effectiveInput
                if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                    let inputText = textInputState.inputText
                    
                    let name:String = peer.addressName ?? peer.compactDisplayTitle
                    
                    let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                    let replacementText = name + " "
                    
                    let atLength = peer.addressName != nil ? 0 : 1
                    
                    let range = strongSelf.chatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                    
                    if peer.addressName == nil {
                        let state = strongSelf.chatInteraction.presentation.effectiveInput
                        var attributes = state.attributes
                        attributes.append(.uid(range.lowerBound ..< range.upperBound - 1, peer.id.id))
                        let updatedState = ChatTextInputState(inputText: state.inputText, selectionRange: state.selectionRange, attributes: attributes)
                        strongSelf.chatInteraction.update({$0.withUpdatedEffectiveInputState(updatedState)})
                    }
                }
            }
        }
        
        
        chatInteraction.sendInlineResult = { [weak self] (results,result) in
            if let strongSelf = self {
                func apply(_ controller: ChatController, atDate: Int32?) {
                    let chatInteraction = controller.chatInteraction
                    if let message = outgoingMessageWithChatContextResult(to: chatInteraction.peerId, results: results, result: result, scheduleTime: atDate) {
                        _ = (Sender.enqueue(message: message.withUpdatedReplyToMessageId(chatInteraction.presentation.interfaceState.replyMessageId), context: context, peerId: chatInteraction.peerId) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                        controller.nextTransaction.set(handler: afterSentTransition)
                    }
                }
                switch strongSelf.mode {
                case .history:
                    apply(strongSelf, atDate: nil)
                case .scheduled:
                    if let peer = strongSelf.chatInteraction.peer {
                        showModal(with: ScheduledMessageModalController(context: context, peerId: peer.id, scheduleAt: { [weak strongSelf] date in
                            if let strongSelf = strongSelf {
                                apply(strongSelf, atDate: Int32(date.timeIntervalSince1970))
                            }
                        }), for: context.window)
                    }
                }
                
            }
            
        }
        
        chatInteraction.beginEditingMessage = { [weak self] (message) in
            if let message = message {
                self?.chatInteraction.update({$0.withEditMessage(message)})
            } else {
                self?.chatInteraction.cancelEditing(true)
            }
            self?.chatInteraction.focusInputField()
        }
        
        chatInteraction.mentionPressed = { [weak self] in
            if let strongSelf = self {
                let signal = earliestUnseenPersonalMentionMessage(account: context.account, peerId: strongSelf.chatInteraction.peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak strongSelf] result in
                    if let strongSelf = strongSelf {
                        switch result {
                        case .loading:
                            break
                        case .result(let messageId):
                            if let messageId = messageId {
                                strongSelf.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                            }
                        }
                    }
                }))
            }
        }
        
        chatInteraction.clearMentions = { [weak self] in
            guard let `self` = self else {return}
            _ = clearPeerUnseenPersonalMessagesInteractively(account: context.account, peerId: self.chatInteraction.peerId).start()
        }
        
        chatInteraction.editEditingMessagePhoto = { [weak self] media in
            guard let `self` = self else {return}
            if let resource = media.representationForDisplayAtSize(PixelDimensions(1280, 1280))?.resource {
                _ = (context.account.postbox.mediaBox.resourceData(resource) |> deliverOnMainQueue).start(next: { [weak self] resource in
                    guard let `self` = self else {return}
                    let url = URL(fileURLWithPath: link(path:resource.path, ext:kMediaImageExt)!)
                    let controller = EditImageModalController(url, defaultData: self.chatInteraction.presentation.interfaceState.editState?.editedData)
                    self.editCurrentMessagePhotoDisposable.set((controller.result |> deliverOnMainQueue).start(next: { [weak self] (new, data) in
                        guard let `self` = self else {return}
                        self.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedEditedData(data)})})})
                        if new != url {
                            self.updateMediaDisposable.set((Sender.generateMedia(for: MediaSenderContainer(path: new.path, isFile: false), account: context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) |> deliverOnMainQueue).start(next: { [weak self] media, _ in
                                self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                            }))
                        } else {
                            self.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                        }
                        
                    }))
                    showModal(with: controller, for: context.window, animationType: .scaleCenter)
                })
            }
        }
        
        chatInteraction.requestMessageActionCallback = { [weak self] messageId, isGame, data in
            if let strongSelf = self {
                switch strongSelf.mode {
                case .history:
                    strongSelf.botCallbackAlertMessage.set(.single((L10n.chatInlineRequestLoading, false)))
                    strongSelf.messageActionCallbackDisposable.set((requestMessageActionCallback(account: context.account, messageId: messageId, isGame:isGame, data: data) |> deliverOnMainQueue).start(next: { [weak strongSelf] (result) in
                        
                        if let strongSelf = strongSelf {
                            switch result {
                            case .none:
                                strongSelf.botCallbackAlertMessage.set(.single(("", false)))
                            case let .toast(text):
                                strongSelf.botCallbackAlertMessage.set(.single((text, false)))
                            case let .alert(text):
                                strongSelf.botCallbackAlertMessage.set(.single((text, true)))
                            case let .url(url):
                                if isGame {
                                    strongSelf.navigationController?.push(WebGameViewController(context, strongSelf.chatInteraction.peerId, messageId, url))
                                } else {
                                    execute(inapp: .external(link: url, !(strongSelf.chatInteraction.peer?.isVerified ?? false)))
                                }
                            }
                        }
                    }))
                case .scheduled:
                    break
                }
                
            }
        }
        
        chatInteraction.updateSearchRequest = { [weak self] state in
            self?.searchState.set(state)
        }
        
        
        chatInteraction.focusMessageId = { [weak self] fromId, toId, state in
            
            if let strongSelf = self {
                
                switch strongSelf.mode {
                case .history:
                    if let fromId = fromId {
                        strongSelf.historyState = strongSelf.historyState.withAddingReply(fromId)
                    }
                    
                    var fromIndex: MessageIndex?
                    
                    if let fromId = fromId, let message = strongSelf.messageInCurrentHistoryView(fromId) {
                        fromIndex = MessageIndex(message)
                    } else {
                        if let message = strongSelf.anchorMessageInCurrentHistoryView() {
                            fromIndex = MessageIndex(message)
                        }
                    }
                    if let fromIndex = fromIndex {
                        //                    if let message = strongSelf.messageInCurrentHistoryView(toId) {
                        //                        strongSelf.genericView.tableView.scroll(to: state.swap(to: ChatHistoryEntryId.message(message)))
                        //                    } else {
                        let historyView = chatHistoryViewForLocation(.InitialSearch(location: .id(toId), count: strongSelf.requestCount), account: context.account, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                        
                        struct FindSearchMessage {
                            let message:Message?
                            let loaded:Bool
                        }
                        
                        let signal = historyView
                            |> mapToSignal { historyView -> Signal<(Message?, Bool), NoError> in
                                switch historyView {
                                case .Loading:
                                    return .single((nil, true))
                                case let .HistoryView(view, _, _, _):
                                    for entry in view.entries {
                                        if entry.message.id == toId {
                                            return .single((entry.message, false))
                                        }
                                    }
                                    return .single((nil, false))
                                }
                            } |> take(until: { index in
                                return SignalTakeAction(passthrough: index.0 != nil, complete: !index.1)
                            }) |> map { $0.0 }
                        
                        strongSelf.chatInteraction.loadingMessage.set(.single(true) |> delay(0.2, queue: Queue.mainQueue()))
                        strongSelf.messageIndexDisposable.set(showModalProgress(signal: signal, for: context.window).start(next: { [weak strongSelf] message in
                            self?.chatInteraction.loadingMessage.set(.single(false))
                            if let strongSelf = strongSelf, let message = message {
                                let message = message
                                let toIndex = MessageIndex(message)
                                strongSelf.setLocation(.Scroll(index: MessageHistoryAnchorIndex.message(toIndex), anchorIndex: MessageHistoryAnchorIndex.message(toIndex), sourceIndex: MessageHistoryAnchorIndex.message(fromIndex), scrollPosition: state.swap(to: ChatHistoryEntryId.message(message)), count: strongSelf.requestCount, animated: state.animated))
                            }
                        }, completed: {
                                
                        }))
                        //  }
                    }
                case .scheduled:
                    strongSelf.navigationController?.back()
                    (strongSelf.navigationController?.controller as? ChatController)?.chatInteraction.focusMessageId(fromId, toId, state)
                }
            }
            
        }
        
        chatInteraction.vote = { [weak self] messageId, opaqueIdentifiers, submit in
            guard let `self` = self else {return}
            
            self.update { data -> [MessageId : ChatPollStateData] in
                var data = data
                data[messageId] = ChatPollStateData(identifiers: opaqueIdentifiers, isLoading: submit && !opaqueIdentifiers.isEmpty)
                return data
            }
            
            let signal:Signal<TelegramMediaPoll?, RequestMessageSelectPollOptionError>

            if submit {
                if opaqueIdentifiers.isEmpty {
                    signal = showModalProgress(signal: (requestMessageSelectPollOption(account: context.account, messageId: messageId, opaqueIdentifiers: []) |> deliverOnMainQueue), for: context.window)
                } else {
                    signal = (requestMessageSelectPollOption(account: context.account, messageId: messageId, opaqueIdentifiers: opaqueIdentifiers) |> deliverOnMainQueue)
                }
                
                self.selectMessagePollOptionDisposables.set(signal.start(next: { [weak self] poll in
                    if let poll = poll {
                        self?.update { data -> [MessageId : ChatPollStateData] in
                            var data = data
                            data.removeValue(forKey: messageId)
                            return data
                        }
                        self?.afterNextTransaction = { [weak self] in
                            if let tableView = self?.genericView.tableView {
                                tableView.enumerateVisibleItems(with: { item -> Bool in
                                    if let item = item as? ChatRowItem, item.message?.id == messageId {
                                        let view = item.view as? ChatPollItemView
                                        view?.doAfterAnswer()
                                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                                        return false
                                    }
                                    return true
                                })
                            }
                        }
                    }
                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: L10n.unknownError)
                    }
                    self?.update { data -> [MessageId : ChatPollStateData] in
                        var data = data
                        data.removeValue(forKey: messageId)
                        return data
                    }
                    
                }), forKey: messageId)
            }
            
        }
        chatInteraction.closePoll = { [weak self] messageId in
            guard let `self` = self else {return}
            self.selectMessagePollOptionDisposables.set(requestClosePoll(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, messageId: messageId).start(), forKey: messageId)
        }
        
        
        chatInteraction.sendMedia = { [weak self] media in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                
                switch strongSelf.mode {
                case .scheduled:
                    showModal(with: ScheduledMessageModalController(context: strongSelf.context, peerId: peer.id, scheduleAt: { [weak strongSelf] date in
                        if let strongSelf = strongSelf {
                            let _ = (Sender.enqueue(media: media, context: context, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction, atDate: date) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                            strongSelf.nextTransaction.set(handler: {})
                        }
                    }), for: strongSelf.context.window)
                case .history:
                    let _ = (Sender.enqueue(media: media, context: context, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    strongSelf.nextTransaction.set(handler: {})
                }
            }
        }
        
        chatInteraction.attachFile = { [weak self] asMedia in
            if let `self` = self, let window = self.window {
                if let slowMode = self.chatInteraction.presentation.slowMode, let errorText = slowMode.errorText {
                    tooltip(for: self.genericView.inputView.attachView, text: errorText)
                    if let last = slowMode.sendingIds.last {
                        self.chatInteraction.focusMessageId(nil, last, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                    }
                } else {
                    filePanel(canChooseDirectories: true, for: window, completion:{ result in
                        if let result = result {
                            
                            let previous = result.count
                            
                            let result = result.filter { path -> Bool in
                                if let size = fs(path) {
                                    return size <= 2000 * 1024 * 1024
                                }
                                return false
                            }
                            
                            let afterSizeCheck = result.count
                            
                            if afterSizeCheck == 0 && previous != afterSizeCheck {
                                alert(for: context.window, info: L10n.appMaxFileSize1)
                            } else {
                                self.chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, asMedia, nil)
                            }
                            
                        }
                    })
                }
            }
            
        }
        chatInteraction.attachPhotoOrVideo = { [weak self] in
            if let `self` = self, let window = self.window {
                if let slowMode = self.chatInteraction.presentation.slowMode, let errorText = slowMode.errorText {
                    tooltip(for: self.genericView.inputView.attachView, text: errorText)
                    if let last = slowMode.sendingIds.last {
                        self.chatInteraction.focusMessageId(nil, last, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                    }
                } else {
                    filePanel(with: mediaExts, canChooseDirectories: true, for: window, completion:{ [weak self] result in
                        if let result = result {
                            let previous = result.count
                            
                            let result = result.filter { path -> Bool in
                                if let size = fs(path) {
                                    return size <= 2000 * 1024 * 1024
                                }
                                return false
                            }
                            
                            let afterSizeCheck = result.count
                            
                            if afterSizeCheck == 0 && previous != afterSizeCheck {
                                alert(for: context.window, info: L10n.appMaxFileSize1)
                            } else {
                                self?.chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, true, nil)
                            }
                        }
                    })
                }
            }
        }
        chatInteraction.attachPicture = { [weak self] in
            guard let `self` = self else {return}
            if let window = self.window {
                pickImage(for: window, completion: { [weak self] image in
                    if let image = image {
                        self?.chatInteraction.mediaPromise.set(putToTemp(image: image) |> map({[MediaSenderContainer(path:$0)]}))
                    }
                })
            }
        }
        chatInteraction.attachLocation = { [weak self] in
            guard let `self` = self else {return}
            showModal(with: LocationModalController(self.chatInteraction), for: context.window)
        }
        
        chatInteraction.sendAppFile = { [weak self] file, silent in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                func apply(_ controller: ChatController, atDate: Date?) {
                    let _ = (Sender.enqueue(media: file, context: context, peerId: controller.chatInteraction.peerId, chatInteraction: controller.chatInteraction, silent: silent, atDate: atDate) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    controller.nextTransaction.set(handler: {})
                }
                switch strongSelf.mode {
                case .scheduled:
                    showModal(with: ScheduledMessageModalController(context: context, peerId: peer.id, scheduleAt: { [weak strongSelf] date in
                        if let controller = strongSelf {
                            apply(controller, atDate: date)
                        }
                    }), for: context.window)
                default:
                    apply(strongSelf, atDate: nil)
                }
            }
        }
        
        chatInteraction.sendMedias = { [weak self] medias, caption, isCollage, additionText, silent, atDate in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                func apply(_ controller: ChatController, atDate: Date?) {
                    let _ = (Sender.enqueue(media: medias, caption: caption, context: context, peerId: controller.chatInteraction.peerId, chatInteraction: controller.chatInteraction, isCollage: isCollage, additionText: additionText, silent: silent, atDate: atDate) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    controller.nextTransaction.set(handler: {})
                }
                switch strongSelf.mode {
                case .history:
                    DispatchQueue.main.async {
                        if let _ = atDate {
                            strongSelf.openScheduledChat()
                        }
                    }
                    apply(strongSelf, atDate: atDate)
                case .scheduled:
                    if let atDate = atDate {
                        apply(strongSelf, atDate: atDate)
                    } else {
                        showModal(with: ScheduledMessageModalController(context: context, peerId: peer.id, scheduleAt: { [weak strongSelf] date in
                            if let strongSelf = strongSelf {
                                apply(strongSelf, atDate: date)
                            }
                        }), for: context.window)
                    }
                }
            }
        }
        
        chatInteraction.shareSelfContact = { [weak self] replyId in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                strongSelf.shareContactDisposable.set((context.account.viewTracker.peerView(context.account.peerId) |> take(1)).start(next: { [weak strongSelf] peerView in
                    if let strongSelf = strongSelf, let peer = peerViewMainPeer(peerView) as? TelegramUser {
                        _ = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)), replyToMessageId: replyId, localGroupingKey: nil), context: context, peerId: strongSelf.chatInteraction.peerId).start()
                    }
                }))
            }
        }
        
        chatInteraction.modalSearch = { [weak self] query in
            if let strongSelf = self {
                strongSelf.chatInteraction.update({$0.updatedSearchMode((true, nil, query))})

//                let apply = showModalProgress(signal: searchMessages(account: context.account, location: .peer(peerId: strongSelf.chatInteraction.peerId, fromId: nil, tags: nil), query: query, state: nil), for: context.window)
//                showModal(with: SearchResultModalController(context, request: apply |> map {$0.0.messages}, query: query, chatInteraction:strongSelf.chatInteraction), for: context.window)
            }
        }
        
        chatInteraction.sendCommand = { [weak self] command in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                func apply(_ controller: ChatController, atDate: Date?) {
                    var commandText = "/" + command.command.text
                    if controller.chatInteraction.peerId.namespace != Namespaces.Peer.CloudUser {
                        commandText += "@" + (command.peer.username ?? "")
                    }
                    _ = Sender.enqueue(input: ChatTextInputState(inputText: commandText), context: context, peerId: controller.chatLocation.peerId, replyId: controller.chatInteraction.presentation.interfaceState.replyMessageId, atDate: atDate).start(completed: scrollAfterSend)
                    controller.chatInteraction.updateInput(with: "")
                    controller.nextTransaction.set(handler: afterSentTransition)
                }
                switch strongSelf.mode {
                case .scheduled:
                    DispatchQueue.main.async {
                        showModal(with: ScheduledMessageModalController(context: context, peerId: peer.id, scheduleAt: { [weak strongSelf] date in
                            if let strongSelf = strongSelf {
                                apply(strongSelf, atDate: date)
                            }
                        }), for: context.window)
                    }
                case .history:
                    apply(strongSelf, atDate: nil)
                }
            }
        }
        
        chatInteraction.switchInlinePeer = { [weak self] switchId, initialAction in
            if let strongSelf = self {
                strongSelf.navigationController?.push(ChatSwitchInlineController(context: context, peerId: switchId, fallbackId:strongSelf.chatInteraction.peerId, fallbackMode: strongSelf.mode, initialAction: initialAction))
            }
        }
        
        chatInteraction.setNavigationAction = { [weak self] action in
            self?.navigationController?.set(modalAction: action)
        }
        
        chatInteraction.showPreviewSender = { [weak self] urls, asMedia, attributedString in
            if let `self` = self {
                if let slowMode = self.chatInteraction.presentation.slowMode, let errorText = slowMode.errorText {
                    tooltip(for: self.genericView.inputView.attachView, text: errorText)
                    if !slowMode.sendingIds.isEmpty {
                        self.chatInteraction.focusMessageId(nil, slowMode.sendingIds.last!, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
                    }
                } else {
                    showModal(with: PreviewSenderController(urls: urls, chatInteraction: self.chatInteraction, asMedia: asMedia, attributedString: attributedString), for: context.window)
                }
            }
        }
        
        chatInteraction.setSecretChatMessageAutoremoveTimeout = { [weak self] seconds in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                _ = setSecretChatMessageAutoremoveTimeoutInteractively(account: context.account, peerId: strongSelf.chatInteraction.peerId, timeout:seconds).start()
            }
            scrollAfterSend()
        }
        
        chatInteraction.toggleNotifications = { [weak self] isMuted in
            if let strongSelf = self {
                if isMuted == nil || isMuted == true {
                    _ = togglePeerMuted(account: context.account, peerId: strongSelf.chatInteraction.peerId).start()
                } else {
                    var options:[ModalOptionSet] = []
                    
                    options.append(ModalOptionSet(title: L10n.chatListMute1Hour, selected: false, editable: true))
                    options.append(ModalOptionSet(title: L10n.chatListMute4Hours, selected: false, editable: true))
                    options.append(ModalOptionSet(title: L10n.chatListMute8Hours, selected: false, editable: true))
                    options.append(ModalOptionSet(title: L10n.chatListMute1Day, selected: false, editable: true))
                    options.append(ModalOptionSet(title: L10n.chatListMute3Days, selected: false, editable: true))
                    options.append(ModalOptionSet(title: L10n.chatListMuteForever, selected: true, editable: true))
                    
                    var intervals:[Int32] = [60 * 60, 60 * 60 * 4, 60 * 60 * 8, 60 * 60 * 24, 60 * 60 * 24 * 3, Int32.max]
                    
                    showModal(with: ModalOptionSetController(context: context, options: options, selectOne: true, actionText: (L10n.chatInputMute, theme.colors.accent), title: L10n.peerInfoNotifications, result: { result in
                        
                        for (i, option) in result.enumerated() {
                            inner: switch option {
                            case .selected:
                                _ = updatePeerMuteSetting(account: context.account, peerId: strongSelf.chatInteraction.peerId, muteInterval: intervals[i]).start()
                                break
                            default:
                                break inner
                            }
                        }
                        
                    }), for: context.window)
                }
            }
        }
        
        chatInteraction.openDiscussion = { [weak self] in
            guard let `self` = self else { return }
            let signal = showModalProgress(signal: context.account.viewTracker.peerView(self.chatLocation.peerId) |> filter { $0.cachedData is CachedChannelData } |> map { $0.cachedData as! CachedChannelData } |> take(1) |> deliverOnMainQueue, for: context.window)
            self.discussionDataLoadDisposable.set(signal.start(next: { [weak self] cachedData in
                if let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                    self?.chatInteraction.openInfo(linkedDiscussionPeerId, true, nil, nil)
                }
            }))
        }
        
        chatInteraction.removeAndCloseChat = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: removePeerChat(account: context.account, peerId: strongSelf.chatInteraction.peerId, reportChatSpam: false), for: window).start(next: { [weak strongSelf] in
                    strongSelf?.navigationController?.close()
                })
            }
        }
        
        chatInteraction.removeChatInteractively = { [weak self] in
            if let strongSelf = self {
                let signal = removeChatInteractively(context: context, peerId: strongSelf.chatInteraction.peerId, userId: strongSelf.chatInteraction.peer?.id) |> filter {$0} |> mapToSignal { _ -> Signal<ChatLocation?, NoError> in
                    return context.globalPeerHandler.get() |> take(1)
                   } |> deliverOnMainQueue
                
                strongSelf.deleteChatDisposable.set(signal.start(next: { [weak strongSelf] location in
                    if location == strongSelf?.chatInteraction.chatLocation {
                        strongSelf?.context.sharedContext.bindings.rootNavigation().close()
                    }
                }))
            }
        }
        
        chatInteraction.joinChannel = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: joinChannel(account: context.account, peerId: strongSelf.chatInteraction.peerId) |> deliverOnMainQueue, for: window).start(error: { error in
                    let text: String
                    switch error {
                    case .generic:
                        text = L10n.unknownError
                    case .tooMuchJoined:
                        showInactiveChannels(context: context, source: .join)
                        return
                    }
                    alert(for: context.window, info: text)
                })
            }
        }
        
        chatInteraction.returnGroup = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: returnGroup(account: context.account, peerId: strongSelf.chatInteraction.peerId), for: window).start()
            }
        }
        
        chatInteraction.openScheduledMessages = { [weak self] in
            self?.openScheduledChat()
        }
        
        chatInteraction.openBank = { card in
            
            _ = showModalProgress(signal: getBankCardInfo(account: context.account, cardNumber: card), for: context.window).start(next: { info in
                if let info = info {
                    
                    let values: [ValuesSelectorValue<String>] = info.urls.map {
                        return ValuesSelectorValue(localized: $0.title, value: $0.url)
                    }
                    
                    showModal(with: ValuesSelectorModalController(values: values, selected: nil, title: info.title, onComplete: { selected in
                        execute(inapp: .external(link: selected.value, false))
                    }), for: context.window)
                 
                }
            })
        }
        
        chatInteraction.shareContact = { [weak self] peer in
            if let strongSelf = self, let main = strongSelf.chatInteraction.peer, main.canSendMessage {
                _ = Sender.shareContact(context: context, peerId: strongSelf.chatInteraction.peerId, contact: peer).start()
            }
        }
        
        chatInteraction.unblock = { [weak self] in
            if let strongSelf = self {
                strongSelf.unblockDisposable.set(context.blockedPeersContext.remove(peerId: strongSelf.chatInteraction.peerId).start())
            }
        }
        
        chatInteraction.updatePinned = { [weak self] pinnedId, dismiss, silent in
            if let `self` = self {
                
                let pinnedUpdate: PinnedMessageUpdate = dismiss ? .clear : .pin(id: pinnedId, silent: silent)
                let peerId = self.chatInteraction.peerId
                if let peer = self.chatInteraction.peer as? TelegramChannel {
                    if peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
                        
                        self.updatePinnedDisposable.set(((dismiss ? confirmSignal(for: context.window, header: L10n.chatConfirmUnpinHeader, information: L10n.chatConfirmUnpin, okTitle: L10n.chatConfirmUnpinOK) : Signal<Bool, NoError>.single(true)) |> filter {$0} |> mapToSignal { _ in return
                            showModalProgress(signal: requestUpdatePinnedMessage(account: context.account, peerId: peerId, update: pinnedUpdate) |> `catch` {_ in .complete()
                        }, for: context.window)}).start())
                    } else {
                        self.chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedDismissedPinnedId(pinnedId)})})
                    }
                } else if self.chatInteraction.peerId == context.peerId {
                    if dismiss {
                        confirm(for: context.window, header: L10n.chatConfirmUnpinHeader, information: L10n.chatConfirmUnpin, okTitle: L10n.chatConfirmUnpinOK, successHandler: { _ in
                            self.updatePinnedDisposable.set(showModalProgress(signal: requestUpdatePinnedMessage(account: context.account, peerId: peerId, update: pinnedUpdate), for: context.window).start())
                        })
                    } else {
                        self.updatePinnedDisposable.set(showModalProgress(signal: requestUpdatePinnedMessage(account: context.account, peerId: peerId, update: pinnedUpdate), for: context.window).start())
                    }
                } else if let peer = self.chatInteraction.peer as? TelegramGroup, peer.canPinMessage {
                    if dismiss {
                        confirm(for: context.window, header: L10n.chatConfirmUnpinHeader, information: L10n.chatConfirmUnpin, okTitle: L10n.chatConfirmUnpinOK, successHandler: { _ in
                            self.updatePinnedDisposable.set(showModalProgress(signal: requestUpdatePinnedMessage(account: context.account, peerId: peerId, update: pinnedUpdate), for: context.window).start())
                        })
                    } else {
                        self.updatePinnedDisposable.set(showModalProgress(signal: requestUpdatePinnedMessage(account: context.account, peerId: peerId, update: pinnedUpdate), for: context.window).start())
                    }
                }
            }
        }
        
        chatInteraction.reportSpamAndClose = { [weak self] in
            if let strongSelf = self {
                
                let title: String
                if let peer = strongSelf.chatInteraction.peer {
                    if peer.isUser {
                        title = L10n.chatConfirmReportSpamUser
                    } else if peer.isChannel {
                        title = L10n.chatConfirmReportSpamChannel
                    } else if peer.isGroup || peer.isSupergroup {
                        title = L10n.chatConfirmReportSpamGroup
                    } else {
                        title = L10n.chatConfirmReportSpam
                    }
                } else {
                    title = L10n.chatConfirmReportSpam
                }
                
                strongSelf.reportPeerDisposable.set((confirmSignal(for: context.window, header: L10n.chatConfirmReportSpamHeader, information: title, okTitle: L10n.messageContextReport, cancelTitle: L10n.modalCancel) |> filter {$0} |> mapToSignal { _ in
                    return reportPeer(account: context.account, peerId: strongSelf.chatInteraction.peerId) |> deliverOnMainQueue |> mapToSignal { [weak self] _ -> Signal<Void, NoError> in
                        if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {
                            if peer.id.namespace == Namespaces.Peer.CloudUser {
                                return removePeerChat(account: context.account, peerId: strongSelf.chatInteraction.peerId, reportChatSpam: false) |> deliverOnMainQueue
                                |> mapToSignal { _ in
                                    return context.blockedPeersContext.add(peerId: peer.id) |> `catch` { _ in return .complete() } |> mapToSignal { _ in
                                        return .complete()
                                    }
                                }
                            } else {
                                return removePeerChat(account: context.account, peerId: strongSelf.chatInteraction.peerId, reportChatSpam: true)
                            }
                        }
                        return .complete()
                    }
                    |> deliverOnMainQueue
                }).start(completed: { [weak self] in
                    self?.navigationController?.back()
                }))
            }
        }
        
        chatInteraction.dismissPeerStatusOptions = { [weak self] in
            if let strongSelf = self {
                _ = dismissPeerStatusOptions(account: context.account, peerId: strongSelf.chatInteraction.peerId).start()
            }
        }
        
        chatInteraction.toggleSidebar = { [weak self] in
            FastSettings.toggleSidebarShown(!FastSettings.sidebarShown)
            self?.updateSidebar()
            (self?.navigationController as? MajorNavigationController)?.genericView.update()
        }
        
        chatInteraction.focusInputField = { [weak self] in
            _ = self?.context.window.makeFirstResponder(self?.firstResponder())
        }
        
        chatInteraction.updateReactions = { [weak self] messageId, reaction, loading in
            guard let `self` = self else {
                return
            }
            self.updateReqctionsDisposable.set((updateMessageReactionsInteractively(postbox: self.context.account.postbox, messageId: messageId, reaction: reaction) |> deliverOnMainQueue).start(), forKey: messageId)
        }
        chatInteraction.withToggledSelectedMessage = { [weak self] f in
            guard let `self` = self else {
                return
            }
            let previous = self.chatInteraction.presentation.selectionState?.selectedIds
            self.chatInteraction.update(f)
            
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                if let selectionState = self.chatInteraction.presentation.selectionState, let lastMessageId = selectionState.lastSelectedId, let previous = previous {
                    if let messageId = selectionState.selectedIds.subtracting(previous).first {
                        let minId = min(lastMessageId.id, messageId.id)
                        let maxId = max(lastMessageId.id, messageId.id)
                        let cloudNamespace = self.mode == .scheduled ? Namespaces.Message.ScheduledCloud : Namespaces.Message.Cloud
                        let localNamespace = self.mode == .scheduled ? Namespaces.Message.ScheduledLocal : Namespaces.Message.Local
                        let selectMessages = context.account.postbox.transaction { transaction -> [Message] in
                            var messages:[Message] = []
                            for id in minId ..< maxId {
                                let cloudId = MessageId(peerId: lastMessageId.peerId, namespace: cloudNamespace, id: id)
                                let localId = MessageId(peerId: lastMessageId.peerId, namespace: localNamespace, id: id)
                                let message = transaction.getMessage(cloudId) ?? transaction.getMessage(localId)
                                if let message = message {
                                    if minId > maxId {
                                        messages.append(message)
                                    } else {
                                        messages.insert(message, at: 0)
                                    }
                                }
                            }
                            return messages
                        } |> deliverOnMainQueue
                        
                        self.shiftSelectedDisposable.set(selectMessages.start(next: { [weak self] messages in
                            guard let `self` = self else {
                                return
                            }
                            self.chatInteraction.update({ current in
                                var current = current
                                if let selectionState = current.selectionState, selectionState.selectedIds.count >= 100 {
                                    return current
                                }
                                for message in messages {
                                    current = current.withUpdatedSelectedMessage(message.id)
                                }
                                
                                return current
                            })
                        }))
                    }
                }
            }
        }
        
        chatInteraction.getGradientOffsetRect = { [weak self] in
            guard let `self` = self else {
                return .zero
            }
            let point = self.genericView.tableView.scrollPosition().current.rect.origin
            return CGRect(origin: point, size: self.frame.size)
        }
        
        chatInteraction.closeAfterPeek = { [weak self] peek in
            
            let showConfirm:()->Void = {
                confirm(for: context.window, header: L10n.privateChannelPeekHeader, information: L10n.privateChannelPeekText, okTitle: L10n.privateChannelPeekOK, cancelTitle: L10n.privateChannelPeekCancel, successHandler: { _ in
                    self?.chatInteraction.joinChannel()
                }, cancelHandler: {
                    self?.navigationController?.back()
                })
            }
            
            let timeout = TimeInterval(peek) - Date().timeIntervalSince1970
            if timeout > 0 {
                let signal = Signal<NoValue, NoError>.complete() |> delay(timeout, queue: .mainQueue())
                self?.peekDisposable.set(signal.start(completed: showConfirm))
            } else {
                showConfirm()
            }
        }

        let initialData = initialDataHandler.get() |> take(1) |> beforeNext { [weak self] (combinedInitialData) in
            
            if let `self` = self {
                if let initialData = combinedInitialData.initialData {
                    if let interfaceState = initialData.chatInterfaceState as? ChatInterfaceState {
                        self.chatInteraction.update(animated:false,{$0.updatedInterfaceState({_ in return interfaceState})})
                    }
                    switch self.chatInteraction.mode {
                    case .history:
                        self.chatInteraction.update(animated:false,{ present in
                            var present = present
                            if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                                present = present
                                    .withUpdatedBlocked(cachedData.isBlocked)
                                    .withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
//                                    .withUpdatedHasScheduled(cachedData.hasScheduledMessages)
                            } else if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                                present = present
                                    .withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
                                    .withUpdatedIsNotAccessible(cachedData.isNotAccessible)
//                                    .withUpdatedHasScheduled(cachedData.hasScheduledMessages)
                                if let peer = present.peer as? TelegramChannel {
                                    switch peer.info {
                                    case let .group(info):
                                        if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator) {
                                            present = present.updateSlowMode({ value in
                                                var value = value ?? SlowMode()
                                                value = value.withUpdatedValidUntil(cachedData.slowModeValidUntilTimestamp)
                                                if let timeout = cachedData.slowModeValidUntilTimestamp {
                                                    if timeout > context.timestamp {
                                                        value = value.withUpdatedTimeout(timeout - context.timestamp)
                                                    }
                                                }
                                                return value
                                            })
                                        } else {
                                            present = present.updateSlowMode { _ in return nil }
                                        }
                                    default:
                                        present = present.updateSlowMode { _ in return nil }
                                    }
                                }
                                
                                
                            } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                                present = present
                                    .withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
//                                    .withUpdatedHasScheduled(cachedData.hasScheduledMessages)
                            } else {
                                present = present.withUpdatedPinnedMessageId(nil)
                            }
                            if let messageId = present.pinnedMessageId {
                                present = present.withUpdatedCachedPinnedMessage(combinedInitialData.cachedDataMessages?[messageId])
                            }
                            return present.withUpdatedLimitConfiguration(combinedInitialData.limitsConfiguration)
                        })
                    case .scheduled:
                        break
                    }
                    
                    if let modalAction = self.navigationController?.modalAction {
                        self.invokeNavigation(action: modalAction)
                    }
                    
                    
                    self.state = self.chatInteraction.presentation.state == .selecting ? .Edit : .Normal
                    self.notify(with: self.chatInteraction.presentation, oldValue: ChatPresentationInterfaceState(self.chatInteraction.chatLocation), animated: false, force: true)
                    
                    self.genericView.inputView.updateInterface(with: self.chatInteraction)
                    
                }
            }
            
            } |> map {_ in}
        
        let first:Atomic<Bool> = Atomic(value: true)
        

        
        peerDisposable.set((peerView.get()
            |> deliverOnMainQueue |> beforeNext  { [weak self] postboxView in
                
                guard let `self` = self else {return}
                
                (self.centerBarView as? ChatTitleBarView)?.postboxView = postboxView
                
                switch self.chatLocation {
                case .peer:
                    let peerView = postboxView as? PeerView
                    
                    if let cachedData = peerView?.cachedData as? CachedChannelData {
                        let onlineMemberCount:Signal<Int32?, NoError>
                        if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                            onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: self.chatInteraction.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                        } else {
                            onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: self.chatInteraction.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                        }
                        
                        self.onlineMemberCountDisposable.set(onlineMemberCount.start(next: { [weak self] count in
                            (self?.centerBarView as? ChatTitleBarView)?.onlineMemberCount = count
                        }))
                    }
                    
                    switch self.chatInteraction.mode {
                    case .history:
                        
                        
                        var wasGroupChannel: Bool?
                        if let peer = self.chatInteraction.presentation.mainPeer as? TelegramChannel  {
                            if case .group = peer.info {
                                wasGroupChannel = true
                            } else {
                                wasGroupChannel = false
                            }
                        }
                        var isGroupChannel: Bool?
                        if let peerView = peerView, let info = (peerView.peers[peerView.peerId] as? TelegramChannel)?.info {
                            if case .group = info {
                                isGroupChannel = true
                            } else {
                                isGroupChannel = false
                            }
                        }
 
                        if wasGroupChannel != isGroupChannel {
                            if let isGroupChannel = isGroupChannel, isGroupChannel {
                                let (recentDisposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: chatInteraction.peerId, updated: { _ in })
                                let (adminsDisposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: chatInteraction.peerId, updated: { _ in })
                                let disposable = DisposableSet()
                                disposable.add(recentDisposable)
                                disposable.add(adminsDisposable)
                                
                                self.updatedChannelParticipants.set(disposable)
                            } else {
                                self.updatedChannelParticipants.set(nil)
                            }
                           
                        }
                        
                        self.chatInteraction.update(animated: !first.swap(false), { [weak peerView] presentation in
                            if let peerView = peerView {
                                var present = presentation.updatedPeer { [weak peerView] _ in
                                    if let peerView = peerView {
                                        return peerView.peers[peerView.peerId]
                                    }
                                    return nil
                                }.updatedMainPeer(peerViewMainPeer(peerView))
                                
                                var discussionGroupId:PeerId? = nil
                                if let cachedData = peerView.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                                    if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                                        switch peer.info {
                                        case let .broadcast(info):
                                            if info.flags.contains(.hasDiscussionGroup) {
                                                discussionGroupId = linkedDiscussionPeerId
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                                
                                present = present.withUpdatedDiscussionGroupId(discussionGroupId)
                                
                                var contactStatus: ChatPeerStatus?
                                if let cachedData = peerView.cachedData as? CachedUserData {
                                    contactStatus = ChatPeerStatus(canAddContact: !peerView.peerIsContact, peerStatusSettings: cachedData.peerStatusSettings)
                                } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                    contactStatus = ChatPeerStatus(canAddContact: false, peerStatusSettings: cachedData.peerStatusSettings)
                                } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                    contactStatus = ChatPeerStatus(canAddContact: false, peerStatusSettings: cachedData.peerStatusSettings)
                                } else if let cachedData = peerView.cachedData as? CachedSecretChatData {
                                    contactStatus = ChatPeerStatus(canAddContact: !peerView.peerIsContact, peerStatusSettings: cachedData.peerStatusSettings)
                                }
                                if let cachedData = peerView.cachedData as? CachedUserData {
                                    present = present
                                        .withUpdatedBlocked(cachedData.isBlocked)
                                        .withUpdatedPeerStatusSettings(contactStatus)
                                        .withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
//                                        .withUpdatedHasScheduled(cachedData.hasScheduledMessages && !(present.peer is TelegramSecretChat))
                                } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                    present = present
                                        .withUpdatedPeerStatusSettings(contactStatus)
                                        .withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
                                        .withUpdatedIsNotAccessible(cachedData.isNotAccessible)
//                                        .withUpdatedHasScheduled(cachedData.hasScheduledMessages)
                                    if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                                        switch peer.info {
                                        case let .group(info):
                                            if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator) {
                                                present = present.updateSlowMode({ value in
                                                    var value = value ?? SlowMode()
                                                    value = value.withUpdatedValidUntil(cachedData.slowModeValidUntilTimestamp)
                                                    if let timeout = cachedData.slowModeValidUntilTimestamp {
                                                        value = value.withUpdatedTimeout(timeout - context.timestamp)
                                                    }
                                                    return value
                                                })
                                            } else {
                                                present = present.updateSlowMode { _ in return nil }
                                            }
                                        default:
                                            present = present.updateSlowMode { _ in return nil }
                                        }
                                    }
                                } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                    present = present
                                        .withUpdatedPeerStatusSettings(contactStatus)
                                        .withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
//                                        .withUpdatedHasScheduled(cachedData.hasScheduledMessages)
                                } else if let _ = peerView.cachedData as? CachedSecretChatData {
                                    present = present
                                        .withUpdatedPeerStatusSettings(contactStatus)
                                }
                                if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                    present = present.updatedNotificationSettings(notificationSettings)
                                }
                                return present
                            }
                            return presentation
                        })
                    case .scheduled:
                        self.chatInteraction.update(animated: !first.swap(false), {  presentation in
                            return presentation.updatedPeer { _ in
                                if let peerView = peerView {
                                    return peerView.peers[peerView.peerId]
                                }
                                return nil
                            }.updatedMainPeer(peerView != nil ? peerViewMainPeer(peerView!) : nil)
                        })
                    }
                }
                
                
            }).start())
        
        
    
        
        let updating: Signal<Bool, NoError> = context.account.stateManager.isUpdating |> mapToSignal { isUpdating in
            return isUpdating ? .single(isUpdating) |> delay(1.0, queue: .mainQueue()) : .single(isUpdating)
        }
        
        let connecting: Signal<ConnectionStatus, NoError> = context.account.network.connectionStatus |> mapToSignal { status in
            switch status {
            case .online:
                return .single(status)
            default:
                return .single(status) |> delay(1.0, queue: .mainQueue())
            }
        }
        
        
        let connectionStatus = combineLatest(queue: .mainQueue(), connecting, updating) |> deliverOnMainQueue |> beforeNext { [weak self] status, isUpdating -> Void in
            var status = status
            switch status {
            case let .online(proxyAddress):
                if isUpdating {
                    status = .updating(proxyAddress: proxyAddress)
                }
            default:
                break
            }
            
            (self?.centerBarView as? ChatTitleBarView)?.connectionStatus = status
        }
        
        let combine = combineLatest(_historyReady.get() |> deliverOnMainQueue , peerView.get() |> deliverOnMainQueue |> take(1) |> map {_ in} |> then(initialData), genericView.inputView.ready.get())
        
        
        //self.ready.set(.single(true))
        
        self.ready.set(combine |> map { (hReady, _, iReady) in
            return hReady && iReady
        })
        
        
        connectionStatusDisposable.set((connectionStatus).start())
        
        
        var beginPendingTime:CFAbsoluteTime?
        
        
        switch chatLocation {
        case let .peer(peerId):
            self.sentMessageEventsDisposable.set((context.account.pendingMessageManager.deliveredMessageEvents(peerId: peerId) |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { _ in
                
                if FastSettings.inAppSounds {
                    let afterSentSound:NSSound? = {
                        
                        let p = Bundle.main.path(forResource: "sent", ofType: "caf")
                        var sound:NSSound?
                        if let p = p {
                            sound = NSSound(contentsOfFile: p, byReference: true)
                            sound?.volume = 1.0
                        }
                        
                        return sound
                    }()
                    
                    if let beginPendingTime = beginPendingTime {
                        if CFAbsoluteTimeGetCurrent() - beginPendingTime < 0.5 {
                            return
                        }
                    }
                    beginPendingTime = CFAbsoluteTimeGetCurrent()
                    afterSentSound?.play()
                }
            }))
            
            botCallbackAlertMessageDisposable = (self.botCallbackAlertMessage.get()
                |> deliverOnMainQueue).start(next: { [weak self] (message, isAlert) in
                   
                    if let strongSelf = self, let message = message {
                        if !message.isEmpty {
                            if isAlert {
                                alert(for: context.window, info: message)
                            } else {
                                strongSelf.show(toaster: ControllerToaster(text:.initialize(string: message.fixed, color: theme.colors.text, font: .normal(.text))))
                            }
                        } else {
                            strongSelf.removeToaster()
                        }
                    }
                    
                })
            
            
            self.chatUnreadMentionCountDisposable.set((context.account.viewTracker.unseenPersonalMessagesCount(peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] count in
                self?.genericView.updateMentionsCount(count, animated: true)
            }))
            
            let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
            self.peerInputActivitiesDisposable.set((context.account.peerInputActivities(peerId: peerId)
                |> mapToSignal { activities -> Signal<[(Peer, PeerInputActivity)], NoError> in
                    var foundAllPeers = true
                    var cachedResult: [(Peer, PeerInputActivity)] = []
                    previousPeerCache.with { dict -> Void in
                        for (peerId, activity) in activities {
                            if let peer = dict[peerId] {
                                cachedResult.append((peer, activity))
                            } else {
                                foundAllPeers = false
                                break
                            }
                        }
                    }
                    if foundAllPeers {
                        return .single(cachedResult)
                    } else {
                        return context.account.postbox.transaction { transaction -> [(Peer, PeerInputActivity)] in
                            var result: [(Peer, PeerInputActivity)] = []
                            var peerCache: [PeerId: Peer] = [:]
                            for (peerId, activity) in activities {
                                if let peer = transaction.getPeer(peerId) {
                                    result.append((peer, activity))
                                    peerCache[peerId] = peer
                                }
                            }
                            _ = previousPeerCache.swap(peerCache)
                            return result
                        }
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] activities in
                    if let strongSelf = self, strongSelf.chatInteraction.peerId != strongSelf.context.peerId {
                        (strongSelf.centerBarView as? ChatTitleBarView)?.inputActivities = (strongSelf.chatInteraction.peerId, activities)
                    }
                }))
        }
        
        
       
        
        
        
       // var beginHistoryTime:CFAbsoluteTime?

        genericView.tableView.setScrollHandler({ [weak self] scroll in
            guard let `self` = self else {return}
            let view = self.previousView.with {$0?.originalView}
            if let view = view {
                var messageIndex:MessageIndex?

                
                let visible = self.genericView.tableView.visibleRows()

                
                
                switch scroll.direction {
                case .top:
                    if view.laterId != nil {
                        for i in visible.min ..< visible.max {
                            if let item = self.genericView.tableView.item(at: i) as? ChatRowItem {
                                messageIndex = item.entry.index
                                break
                            }
                        }
                    } else if view.laterId == nil, !view.holeLater, let locationValue = self.locationValue, !locationValue.isAtUpperBound, view.anchorIndex != .upperBound {
                        messageIndex = .upperBound(peerId: self.chatInteraction.peerId)
                    }
                case .bottom:
                    if view.earlierId != nil {
                        for i in stride(from: visible.max - 1, to: -1, by: -1) {
                            if let item = self.genericView.tableView.item(at: i) as? ChatRowItem {
                                messageIndex = item.entry.index
                                break
                            }
                        }
                    }
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    let location: ChatHistoryLocation = .Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 100, side: scroll.direction == .bottom ? .upper : .lower)
                    guard location != self.locationValue else {
                        return
                    }
                    self.setLocation(location)
                }
            }
            
        })
        
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {return}
            self.updateInteractiveReading()
        }))
        
        genericView.tableView.addScroll(listener: TableScrollListener { [weak self] position in
            let tableView = self?.genericView.tableView
            
            if let strongSelf = self, let tableView = tableView {
            
                if let row = tableView.topVisibleRow, let item = tableView.item(at: row) as? ChatRowItem, let id = item.message?.id {
                    strongSelf.historyState = strongSelf.historyState.withRemovingReplies(max: id)
                }
                
                var message:Message? = nil
                
                var messageIdsWithViewCount: [MessageId] = []
                var messageIdsWithUnseenPersonalMention: [MessageId] = []
                var unsupportedMessagesIds: [MessageId] = []

                var hasFailed: Bool = false
                
                tableView.enumerateVisibleItems(with: { item in
                    if let item = item as? ChatRowItem {
                        if message == nil {
                            message = item.messages.last
                        }
                        
                        if let message = message, message.flags.contains(.Failed) {
                            hasFailed = !(message.media.first is TelegramMediaAction)
                        }
                        
                        for message in item.messages {
                            var hasUncocumedMention: Bool = false
                            var hasUncosumedContent: Bool = false
                            
                            if !hasFailed, message.flags.contains(.Failed) {
                                hasFailed = !(message.media.first is TelegramMediaAction)
                            }
                            
                            if message.tags.contains(.unseenPersonalMessage) {
                                for attribute in message.attributes {
                                    if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                                        hasUncosumedContent = true
                                    }
                                    if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                                        hasUncocumedMention = true
                                    }
                                }
                                if hasUncocumedMention && !hasUncosumedContent {
                                    messageIdsWithUnseenPersonalMention.append(message.id)
                                }
                            }
                            inner: for attribute in message.attributes {
                                if attribute is ViewCountMessageAttribute {
                                    messageIdsWithViewCount.append(message.id)
                                    break inner
                                }
                            }
                            if message.media.first is TelegramMediaUnsupported {
                                unsupportedMessagesIds.append(message.id)
                            }
                        }
                        
                        if let msg = message, let currentMsg = item.messages.last {
                            if msg.id.namespace == Namespaces.Message.Local && currentMsg.id.namespace == Namespaces.Message.Local {
                                if msg.id < currentMsg.id {
                                    message = currentMsg
                                }
                            }
                        }
                    }
                    return true
                })
                
                strongSelf.genericView.updateFailedIds(strongSelf.genericView.failedIds, hasOnScreen: hasFailed, animated: true)
                
                if !messageIdsWithViewCount.isEmpty {
                    strongSelf.messageProcessingManager.add(messageIdsWithViewCount)
                }
                
                if !messageIdsWithUnseenPersonalMention.isEmpty {
                    strongSelf.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention)
                }
                if !unsupportedMessagesIds.isEmpty {
                    strongSelf.unsupportedMessageProcessingManager.add(unsupportedMessagesIds)
                }
                
                if let message = message {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(MessageIndex(message))
                }
                
               
            }
        })
        
        switch self.mode {
        case .history:
            let failed = context.account.postbox.failedMessageIdsView(peerId: peerId) |> deliverOnMainQueue
            
            var failedAnimate: Bool = true
            failedMessageIdsDisposable.set(failed.start(next: { [weak self] view in
                var hasFailed: Bool = false
                
                self?.genericView.tableView.enumerateVisibleItems(with: { item in
                    if let item = item as? ChatRowItem {
                        if let message = item.message, message.flags.contains(.Failed) {
                            hasFailed = !(message.media.first is TelegramMediaAction)
                        }
                        for message in item.messages {
                            if !hasFailed, message.flags.contains(.Failed) {
                                hasFailed = !(message.media.first is TelegramMediaAction)
                            }
                        }
                    }
                    return !hasFailed
                })
                
                self?.genericView.updateFailedIds(view.ids, hasOnScreen: hasFailed, animated: !failedAnimate)
                failedAnimate = true
            }))
            
            
            
            let hasScheduledMessages = peerView.get()
            |> take(1)
            |> mapToSignal { view -> Signal<Bool, NoError> in
                if let view = view as? PeerView, let peer = peerViewMainPeer(view) as? TelegramChannel, !peer.hasPermission(.sendMessages) {
                    return .single(false)
                } else {
                    return context.account.viewTracker.scheduledMessagesViewForLocation(.peer(peerId))
                        |> map { view, _, _ in
                            return !view.entries.isEmpty
                    }
                }
            } |> deliverOnMainQueue
            
            hasScheduledMessagesDisposable.set(hasScheduledMessages.start(next: { [weak self] hasScheduledMessages in
                self?.chatInteraction.update({
                    $0.withUpdatedHasScheduled(hasScheduledMessages)
                })
            }))
            
        default:
            break
        }
        
        
        
       
        
        let undoSignals = combineLatest(queue: .mainQueue(), context.chatUndoManager.status(for: chatInteraction.peerId, type: .deleteChat), context.chatUndoManager.status(for: chatInteraction.peerId, type: .leftChat), context.chatUndoManager.status(for: chatInteraction.peerId, type: .leftChannel), context.chatUndoManager.status(for: chatInteraction.peerId, type: .deleteChannel))
        
        chatUndoDisposable.set(undoSignals.start(next: { [weak self] statuses in
            let result: [ChatUndoActionStatus?] = [statuses.0, statuses.1, statuses.2, statuses.3]
            for status in result {
                if let status = status, status != .cancelled {
                    self?.navigationController?.close()
                    break
                }
            }
        }))
        
    }
    
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        return genericView.navigationHeaderDidNoticeAnimation(current, previous, animated)
    }

    override func updateFrame(_ frame: NSRect, animated: Bool) {
        super.updateFrame(frame, animated: animated)
        self.genericView.updateFrame(frame, animated: animated)
    }
    
    private func openScheduledChat() {
        self.chatInteraction.saveState(scrollState: self.immediateScrollState())
        self.navigationController?.push(ChatScheduleController(context: context, chatLocation: self.chatLocation))
    }
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        if let temporaryTouchBar = temporaryTouchBar as? ChatTouchBar {
            temporaryTouchBar.updateChatInteraction(self.chatInteraction, textView: self.genericView.inputView.textView.inputView)
        } else {
            temporaryTouchBar = ChatTouchBar(chatInteraction: self.chatInteraction, textView: self.genericView.inputView.textView.inputView)
        }
        return temporaryTouchBar as? NSTouchBar
    }
    
    override func windowDidBecomeKey() {
        super.windowDidBecomeKey()
        if #available(OSX 10.12.2, *) {
            (temporaryTouchBar as? ChatTouchBar)?.updateByKeyWindow()
        }
        updateInteractiveReading()
        chatInteraction.saveState(scrollState: immediateScrollState())
    }
    override func windowDidResignKey() {
        super.windowDidResignKey()
        if #available(OSX 10.12.2, *) {
            (temporaryTouchBar as? ChatTouchBar)?.updateByKeyWindow()
        }
        updateInteractiveReading()
        chatInteraction.saveState(scrollState:immediateScrollState())
    }
    
    private func anchorMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.previousView.with({$0}) {
            let visibleRange = self.genericView.tableView.visibleRows()
            var index = 0
            for entry in historyView.filteredEntries.reversed() {
                if index >= visibleRange.min && index <= visibleRange.max {
                    if case let .MessageEntry(message, _, _, _, _, _, _) = entry.entry {
                        return message
                    }
                }
                index += 1
            }
            
            for entry in historyView.filteredEntries {
                if let message = entry.appearance.entry.message {
                    return message
                }
            }
        }
        return nil
    }
    
    private func updateInteractiveReading() {
        let scroll = genericView.tableView.scrollPosition().current
        let hasEntries = (self.previousView.with { $0 }?.filteredEntries.count ?? 0) > 1
        if let window = window, window.isKeyWindow, self.historyState.isDownOfHistory && scroll.rect.minY == genericView.tableView.frame.height, hasEntries {
            self.interactiveReadingDisposable.set(installInteractiveReadMessagesAction(postbox: context.account.postbox, stateManager: context.account.stateManager, peerId: chatInteraction.peerId))
        } else {
            self.interactiveReadingDisposable.set(nil)
        }
    }
    
    
    
    private func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.previousView.with({$0}) {
            for entry in historyView.filteredEntries {
                if let message = entry.appearance.entry.message, message.id == id {
                    return message
                }
            }
        }
        return nil
    }
    
    private var firstLoad: Bool = true

    func applyTransition(_ transition:TableUpdateTransition, view: MessageHistoryView?, initialData:ChatHistoryCombinedInitialData, isLoading: Bool) {
        
        let wasEmpty = genericView.tableView.isEmpty

        initialDataHandler.set(.single(initialData))
        
        historyState = historyState.withUpdatedStateOfHistory(view?.laterId == nil)
        
        let oldState = genericView.state
        
        genericView.change(state: isLoading ? .progress : .visible, animated: view != nil)
        
      
        genericView.tableView.merge(with: transition)
        
        let _ = nextTransaction.execute()

        
        if oldState != genericView.state {
            genericView.tableView.updateEmpties(animated: view != nil)
        }
        
        genericView.tableView.notifyScrollHandlers()
        
        if !transition.isEmpty, let afterNextTransaction = self.afterNextTransaction {
            delay(0.1, closure: afterNextTransaction)
            self.afterNextTransaction = nil
        }
        
        
        if let view = view, !view.entries.isEmpty {
            
           let tableView = genericView.tableView
//            if !tableView.isEmpty {
//                
//                var earliest:Message?
//                var latest:Message?
//                self.genericView.tableView.enumerateVisibleItems(reversed: true, with: { item -> Bool in
//                    
//                    if let item = item as? ChatRowItem {
//                        earliest = item.message
//                    }
//                    return earliest == nil
//                })
//                
//                self.genericView.tableView.enumerateVisibleItems { item -> Bool in
//                    
//                    if let item = item as? ChatRowItem {
//                        latest = item.message
//                    }
//                    return latest == nil
//                }
//            }
            
        } else if let peer = chatInteraction.peer, peer.isBot {
            if chatInteraction.presentation.initialAction == nil && self.genericView.state == .visible {
                chatInteraction.update(animated: false, {$0.updatedInitialAction(ChatInitialAction.start(parameter: "", behavior: .none))})
            }
        }
        chatInteraction.update(animated: !wasEmpty, { current in
            var current = current.updatedHistoryCount(genericView.tableView.count - 1).updatedKeyboardButtonsMessage(initialData.buttonKeyboardMessage)
            
            if let message = initialData.buttonKeyboardMessage {
                if message.requestsSetupReply {
                    if message.id != current.interfaceState.dismissedForceReplyId {
                        current = current.updatedInterfaceState({$0.withUpdatedReplyMessageId(message.id)})
                    }
                }
            }
            
            return current
        })
        
        readyHistory()
        
        updateInteractiveReading()
        
        
        self.centerBarView.animates = true
        
        self.chatInteraction.invokeInitialAction(includeAuto: true, animated: false)
        
        
        genericView.tableView.enumerateVisibleViews(with: { view in
            if let view = view as? ChatRowView {
                view.updateBackground(animated: transition.animated)
            }
        })
        
        
        if firstLoad {
            firstLoad = false
            
            let peerId = self.chatLocation.peerId
            
            let tags: [MessageTags] = [.photoOrVideo, .file, .webPage, .music, .voiceOrInstantVideo]
            
            let tabItems: [Signal<Never, NoError>] = tags.map { tags -> Signal<Never, NoError> in
                return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(peerId), count: 20, tagMask: tags)
                    |> ignoreValues
            }
//
            loadSharedMediaDisposable.set(combineLatest(tabItems).start())
        }
    }
    
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return ChatTitleBarView(controller: self, chatInteraction)
    }
    
    private var editButton:ImageButton? = nil
    private var doneButton:TitleButton? = nil
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        editButton?.style = navigationButtonStyle
        editButton?.set(image: theme.icons.chatActions, for: .Normal)
        editButton?.set(image: theme.icons.chatActionsActive, for: .Highlight)

        
        editButton?.setFrameSize(70, 50)
        editButton?.center()
        doneButton?.set(color: theme.colors.accent, for: .Normal)
        doneButton?.style = navigationButtonStyle
    }
    
    
    override func getRightBarViewOnce() -> BarView {
        let back = BarView(70, controller: self) //MajorBackNavigationBar(self, account: account, excludePeerId: peerId)
        
        let editButton = ImageButton()
       // editButton.disableActions()
        back.addSubview(editButton)
        
        self.editButton = editButton
//        
        let doneButton = TitleButton()
      //  doneButton.disableActions()
        doneButton.set(font: .medium(.text), for: .Normal)
        doneButton.set(text: tr(L10n.navigationDone), for: .Normal)
        
        
        _ = doneButton.sizeToFit()
        back.addSubview(doneButton)
        doneButton.center()
        
        self.doneButton = doneButton

        
        doneButton.isHidden = true
        
        doneButton.userInteractionEnabled = false
        editButton.userInteractionEnabled = false
        
        back.set(handler: { [weak self] _ in
            if let window = self?.window {
                self?.showRightControls()
            }
        }, for: .Click)
        requestUpdateRightBar()
        return back
    }

    private func showRightControls() {
        switch state {
        case .Normal:
            if let button = editButton {
                let context = self.context
                showRightControlsDisposable.set((peerView.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] view in
                    guard let `self` = self else {return}
                    var items:[SPopoverItem] = []
                    let peerId = self.chatLocation.peerId
                    switch self.mode {
                    case .scheduled:
                        items.append(SPopoverItem(L10n.chatContextClearScheduled, {
                            confirm(for: context.window, header: L10n.chatContextClearScheduledConfirmHeader, information: L10n.chatContextClearScheduledConfirmInfo, okTitle: L10n.chatContextClearScheduledConfirmOK, successHandler: { _ in
                                _ = clearHistoryInteractively(postbox: context.account.postbox, peerId: peerId, type: .scheduledMessages).start()
                            })
                        }, theme.icons.chatActionClearHistory))
                    case .history:
                        switch self.chatLocation {
                        case let .peer(peerId):
                            guard let peerView = view as? PeerView else {return}
                            
                            items.append(SPopoverItem(tr(L10n.chatContextEdit1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(L10n.chatContextEditHelp))" : ""),  { [weak self] in
                                self?.changeState()
                            }, theme.icons.chatActionEdit))
                            
                            
//                            items.append(SPopoverItem(L10n.chatContextSharedMedia,  { [weak self] in
//                                guard let `self` = self else {return}
//                                self.navigationController?.push(PeerMediaController(context: self.context, peerId: self.chatInteraction.peerId))
//                            }, theme.icons.chatAttachPhoto))
                            
                            items.append(SPopoverItem(L10n.chatContextInfo,  { [weak self] in
                                self?.chatInteraction.openInfo(peerId, false, nil, nil)
                                }, theme.icons.chatActionInfo))
                            
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, !self.isAdChat  {
                                if self.chatInteraction.peerId != context.peerId {
                                    items.append(SPopoverItem(!notificationSettings.isMuted ? L10n.chatContextEnableNotifications : L10n.chatContextDisableNotifications, { [weak self] in
                                        self?.chatInteraction.toggleNotifications(notificationSettings.isMuted)
                                    }, !notificationSettings.isMuted ? theme.icons.chatActionUnmute : theme.icons.chatActionMute))
                                }
                            }
                            
                            if let peer = peerViewMainPeer(peerView) {
                                
                                if let groupId = peerView.groupId, groupId != .root {
                                    items.append(SPopoverItem(L10n.chatContextUnarchive, {
                                        _ = updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: .root).start()
                                    }, theme.icons.chatUnarchive))
                                } else {
                                    items.append(SPopoverItem(L10n.chatContextArchive, {
                                        _ = updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: Namespaces.PeerGroup.archive).start()
                                    }, theme.icons.chatArchive))
                                }
                                
                                if peer.canSendMessage, peerView.peerId.namespace != Namespaces.Peer.SecretChat {
                                    let text: String
                                    if peer.id != context.peerId {
                                        text = L10n.chatRightContextScheduledMessages
                                    } else {
                                        text = L10n.chatRightContextReminder
                                    }
                                    items.append(SPopoverItem(text, { [weak self] in
                                        self?.openScheduledChat()
                                    }, theme.icons.scheduledInputAction))
                                }
                                
                                if peer.isGroup || peer.isUser || (peer.isSupergroup && peer.addressName == nil) {
                                    if let peer = peer as? TelegramChannel, peer.flags.contains(.hasGeo) {} else {
                                        items.append(SPopoverItem(L10n.chatContextClearHistory, { [weak self] in
                                            
                                            var thridTitle: String? = nil
                                            
                                            var canRemoveGlobally: Bool = false
                                            if peerId.namespace == Namespaces.Peer.CloudUser && peerId != context.account.peerId && !peer.isBot {
                                                if context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                                                    canRemoveGlobally = true
                                                }
                                            }
                                            
                                            if canRemoveGlobally {
                                                thridTitle = L10n.chatMessageDeleteForMeAndPerson(peer.displayTitle)
                                            }
                                            
                                            modernConfirm(for: context.window, account: context.account, peerId: peer.id, information: peer is TelegramUser ? peer.id == context.peerId ? L10n.peerInfoConfirmClearHistorySavedMesssages : canRemoveGlobally || peerId.namespace == Namespaces.Peer.SecretChat ? L10n.peerInfoConfirmClearHistoryUserBothSides : L10n.peerInfoConfirmClearHistoryUser : L10n.peerInfoConfirmClearHistoryGroup, okTitle: L10n.peerInfoConfirmClear, thridTitle: thridTitle, thridAutoOn: false, successHandler: { result in
                                                self?.addUndoAction(ChatUndoAction(peerId: peerId, type: .clearHistory, action: { status in
                                                    switch status {
                                                    case .success:
                                                        context.chatUndoManager.clearHistoryInteractively(postbox: context.account.postbox, peerId: peerId, type: result == .thrid ? .forEveryone : .forLocalPeer)
                                                        break
                                                    default:
                                                        break
                                                    }
                                                }))
                                            })
                                        }, theme.icons.chatActionClearHistory))
                                    }
                                }
                                
                                let deleteChat = { [weak self] in
                                    guard let `self` = self else {return}
                                    let signal = removeChatInteractively(context: context, peerId: self.chatInteraction.peerId, userId: self.chatInteraction.peer?.id) |> filter {$0} |> mapToSignal { _ -> Signal<ChatLocation?, NoError> in
                                        return context.globalPeerHandler.get() |> take(1)
                                        } |> deliverOnMainQueue
                                    
                                    self.deleteChatDisposable.set(signal.start(next: { [weak self] location in
                                        if location == self?.chatInteraction.chatLocation {
                                            self?.context.sharedContext.bindings.rootNavigation().close()
                                        }
                                    }))
                                }
                                
                                let text: String
                                if peer.isGroup {
                                    text = L10n.chatListContextDeleteAndExit
                                } else if peer.isChannel {
                                    text = L10n.chatListContextLeaveChannel
                                } else if peer.isSupergroup {
                                    text = L10n.chatListContextLeaveGroup
                                } else {
                                    text = L10n.chatListContextDeleteChat
                                }
                                
                                
                                items.append(SPopoverItem(text, deleteChat, theme.icons.chatActionDeleteChat))
                                
                            }
                        }
                    }
                    if !items.isEmpty {
                        if let popover = button.popover {
                            popover.hide()
                        } else {
                            showPopover(for: button, with: SPopoverViewController(items: items, visibility: 10), edge: .maxY, inset: NSMakePoint(0, -65))
                        }
                    }
                }))
            }
        case .Edit:
            changeState()
        case .Some:
            break
        }
    }
    
    private func addUndoAction(_ action: ChatUndoAction) {
        
        self.context.chatUndoManager.add(action: action)
        
        self.undoTooltipControl.add(controller: self)

    }
    
    override func getLeftBarViewOnce() -> BarView {
        let back = BarView(20, controller: self) //MajorBackNavigationBar(self, account: account, excludePeerId: peerId)
        back.set(handler: { [weak self] _ in
            self?.navigationController?.back()
        }, for: .Click)
        return back
    }
    
//    override func invokeNavigationBack() -> Bool {
//        return !context.closeFolderFirst
//    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        
//
//        if context.closeFolderFirst {
//            return .rejected
//        }
        
        if genericView.inputView.textView.inputView.hasMarkedText() {
            return .invokeNext
        }
        
        var result:KeyHandlerResult = .rejected
        if chatInteraction.presentation.state == .selecting {
            self.changeState()
            result = .invoked
        } else if chatInteraction.presentation.state == .editing {
            chatInteraction.cancelEditing()
            result = .invoked
        } else if case let .contextRequest(request) = chatInteraction.presentation.inputContext {
            if request.query.isEmpty {
                chatInteraction.clearInput()
            } else {
                chatInteraction.clearContextQuery()
            }
            result = .invoked
        } else if chatInteraction.presentation.isSearchMode.0 {
            chatInteraction.update({$0.updatedSearchMode((false, nil, nil))})
            result = .invoked
        } else if chatInteraction.presentation.recordingState != nil {
            chatInteraction.update({$0.withoutRecordingState()})
            return .invoked
        } else if chatInteraction.presentation.interfaceState.replyMessageId != nil {
            chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil)})})
            return .invoked
        }
        
        return result
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        
        if hasModals() {
            return .invokeNext
        }
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            if !selectManager.isEmpty {
                _ = selectManager.selectPrevChar()
                return .invoked
            }
        }
        
        return !self.chatInteraction.presentation.isSearchMode.0 && self.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .rejected : .invokeNext
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let recordingState = chatInteraction.presentation.recordingState {
            recordingState.stop()
            chatInteraction.mediaPromise.set(recordingState.data)
            closeAllModals()
            chatInteraction.update({$0.withoutRecordingState()})
            return .invoked
        }
        return super.returnKeyAction()
    }
    
    override func nextKeyAction() -> KeyHandlerResult {
        
        if hasModals() {
            return .invokeNext
        }
        
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            if !selectManager.isEmpty {
                _ = selectManager.selectNextChar()
                return .invoked
            }
        }
        
        if !self.chatInteraction.presentation.isSearchMode.0 && chatInteraction.presentation.effectiveInput.inputText.isEmpty {
            chatInteraction.openInfo(chatInteraction.peerId, false, nil, nil)
            return .invoked
        }
        return .rejected
    }
    
    
    deinit {
        failedMessageEventsDisposable.dispose()
        historyDisposable.dispose()
        peerDisposable.dispose()
        updatedChannelParticipants.dispose()
        readHistoryDisposable.dispose()
        messageActionCallbackDisposable.dispose()
        sentMessageEventsDisposable.dispose()
        chatInteraction.remove(observer: self)
        contextQueryState?.1.dispose()
        self.urlPreviewQueryState?.1.dispose()
        botCallbackAlertMessageDisposable?.dispose()
        layoutDisposable.dispose()
        shareContactDisposable.dispose()
        peerInputActivitiesDisposable.dispose()
        connectionStatusDisposable.dispose()
        messagesActionDisposable.dispose()
        unblockDisposable.dispose()
        updatePinnedDisposable.dispose()
        reportPeerDisposable.dispose()
        focusMessageDisposable.dispose()
        updateFontSizeDisposable.dispose()
        context.addRecentlyUsedPeer(peerId: chatInteraction.peerId)
        loadFwdMessagesDisposable.dispose()
        chatUnreadMentionCountDisposable.dispose()
        navigationActionDisposable.dispose()
        messageIndexDisposable.dispose()
        dateDisposable.dispose()
        interactiveReadingDisposable.dispose()
        showRightControlsDisposable.dispose()
        deleteChatDisposable.dispose()
        loadSelectionMessagesDisposable.dispose()
        updateMediaDisposable.dispose()
        editCurrentMessagePhotoDisposable.dispose()
        selectMessagePollOptionDisposables.dispose()
        onlineMemberCountDisposable.dispose()
        chatUndoDisposable.dispose()
        chatInteraction.clean()
        discussionDataLoadDisposable.dispose()
        slowModeDisposable.dispose()
        slowModeInProgressDisposable.dispose()
        forwardMessagesDisposable.dispose()
        updateReqctionsDisposable.dispose()
        shiftSelectedDisposable.dispose()
        failedMessageIdsDisposable.dispose()
        hasScheduledMessagesDisposable.dispose()
        updateUrlDisposable.dispose()
        loadSharedMediaDisposable.dispose()
        applyMaxReadIndexDisposable.dispose()
        peekDisposable.dispose()
        _ = previousView.swap(nil)
        
        context.closeFolderFirst = false
    }
    
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        
        peekDisposable.set(nil)
        
        genericView.inputContextHelper.viewWillRemove()
        self.chatInteraction.remove(observer: self)
        chatInteraction.saveState(scrollState: immediateScrollState())
        
        context.window.removeAllHandlers(for: self)
        
        if let window = window {
            selectTextController.removeHandlers(for: window)
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        chatInteraction.clean()
    }
    
    private var splitStateFirstUpdate: Bool = true
    override func viewDidChangedNavigationLayout(_ state: SplitViewState) -> Void {
        super.viewDidChangedNavigationLayout(state)
        chatInteraction.update(animated: false, {$0.withUpdatedLayout(state).withToggledSidebarEnabled(FastSettings.sidebarEnabled).withToggledSidebarShown(FastSettings.sidebarShown)})
        if !splitStateFirstUpdate {
            Queue.mainQueue().justDispatch { [weak self] in
                self?.genericView.tableView.layoutItems()
            }
        }
        splitStateFirstUpdate = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let initialAction = self.chatInteraction.presentation.initialAction {
            switch initialAction {
            case let .closeAfter(peek):
                 self.chatInteraction.closeAfterPeek(peek)
            default:
                break
            }
        }

        let context = self.context
        context.closeFolderFirst = false

        self.context.sharedContext.bindings.entertainment().update(with: self.chatInteraction)
        
        chatInteraction.update(animated: false, {$0.withToggledSidebarEnabled(FastSettings.sidebarEnabled).withToggledSidebarShown(FastSettings.sidebarShown)})
        //NSLog("chat apeeared")
        
         self.failedMessageEventsDisposable.set((context.account.pendingMessageManager.failedMessageEvents(peerId: chatInteraction.peerId)
         |> deliverOnMainQueue).start(next: { [weak self] reason in
            if let strongSelf = self {
                let text: String
                switch reason {
                case .flood:
                    text = L10n.chatSendMessageErrorFlood
                case .publicBan:
                    text = L10n.chatSendMessageErrorGroupRestricted
                case .mediaRestricted:
                    text = L10n.chatSendMessageErrorGroupRestricted
                case .slowmodeActive:
                    text = L10n.chatSendMessageSlowmodeError
                case .tooMuchScheduled:
                    text = L10n.chatSendMessageErrorTooMuchScheduled
                }
                confirm(for: context.window, information: text, cancelTitle: "", thridTitle: L10n.genericErrorMoreInfo, successHandler: { [weak strongSelf] confirm in
                    guard let strongSelf = strongSelf else {return}
                    
                    switch confirm {
                    case .thrid:
                        execute(inapp: inAppLink.followResolvedName(link: "@spambot", username: "spambot", postId: nil, context: context, action: nil, callback: { [weak strongSelf] peerId, openChat, postid, initialAction in
                            strongSelf?.chatInteraction.openInfo(peerId, openChat, postid, initialAction)
                        }))
                    default:
                        break
                    }
                })
            }
         }))
 
        
        if let peer = chatInteraction.peer {
            if peer.isRestrictedChannel(context.contentSettings), let reason = peer.restrictionText {
                alert(for: context.window, info: reason, completion: { [weak self] in
                    self?.dismiss()
                })
            } else if chatInteraction.presentation.isNotAccessible {
                alert(for: context.window, info: peer.isChannel ? L10n.chatChannelUnaccessible : L10n.chatGroupUnaccessible, completion: { [weak self] in
                    self?.dismiss()
                })
            }
        }
        
       
        
        self.context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self, !hasModals() {
                let result:KeyHandlerResult = strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty && strongSelf.chatInteraction.presentation.state == .normal ? .invoked : .rejected
                
                if result == .invoked {
                    let setup = strongSelf.findAndSetEditableMessage()
                    if !setup {
                        strongSelf.genericView.tableView.scrollUp()
                    }
                } else {
                    if strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                        strongSelf.genericView.tableView.scrollUp()
                    }
                }
                
                return result
            }
            return .rejected
        }, with: self, for: .UpArrow, priority: .low)
        
        
        self.context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self, !hasModals() {
                let result:KeyHandlerResult = strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .invoked : .invokeNext
                
                
                if result == .invoked {
                    strongSelf.genericView.tableView.scrollDown()
                }
                
                return result
            }
            return .rejected
        }, with: self, for: .DownArrow, priority: .low)
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let `self` = self, !hasModals(), self.chatInteraction.presentation.interfaceState.editState == nil, self.chatInteraction.presentation.interfaceState.inputState.inputText.isEmpty {
                var currentReplyId = self.chatInteraction.presentation.interfaceState.replyMessageId
                self.genericView.tableView.enumerateItems(with: { item in
                    if let item = item as? ChatRowItem, let message = item.message {
                        if canReplyMessage(message, peerId: self.chatInteraction.peerId), currentReplyId == nil || (message.id < currentReplyId!) {
                            currentReplyId = message.id
                            self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsetsZero, timingFunction: .linear)
                            return false
                        }
                    }
                    return true
                })
                
                let result:KeyHandlerResult = currentReplyId != nil ? .invoked : .rejected
                self.chatInteraction.setupReplyMessage(currentReplyId)
                
                return result
            }
            return .rejected
        }, with: self, for: .UpArrow, priority: .low, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let `self` = self, !hasModals(), self.chatInteraction.presentation.interfaceState.editState == nil, self.chatInteraction.presentation.interfaceState.inputState.inputText.isEmpty {
                var currentReplyId = self.chatInteraction.presentation.interfaceState.replyMessageId
                self.genericView.tableView.enumerateItems(reversed: true, with: { item in
                    if let item = item as? ChatRowItem, let message = item.message {
                        if canReplyMessage(message, peerId: self.chatInteraction.peerId), currentReplyId != nil && (message.id > currentReplyId!) {
                            currentReplyId = message.id
                            self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsetsZero, timingFunction: .linear)
                            return false
                        }
                    }
                    return true
                })
                
                let result:KeyHandlerResult = currentReplyId != nil ? .invoked : .rejected
                self.chatInteraction.setupReplyMessage(currentReplyId)
                
                return result
            }
            return .rejected
        }, with: self, for: .DownArrow, priority: .low, modifierFlags: [.command])
        
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self, !hasModals() else {return .rejected}
            
            if let selectionState = self.chatInteraction.presentation.selectionState, !selectionState.selectedIds.isEmpty {
                self.chatInteraction.deleteSelectedMessages()
                return .invoked
            }
            
            return .rejected
        }, with: self, for: .Delete, priority: .low)
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if let selectionState = self.chatInteraction.presentation.selectionState, !selectionState.selectedIds.isEmpty {
                self.chatInteraction.deleteSelectedMessages()
                return .invoked
            }
            
            return .rejected
        }, with: self, for: .ForwardDelete, priority: .low)
        
        

        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self, strongSelf.context.window.firstResponder != strongSelf.genericView.inputView.textView.inputView {
                _ = strongSelf.context.window.makeFirstResponder(strongSelf.genericView.inputView)
                return .invoked
            } else if (self?.navigationController as? MajorNavigationController)?.genericView.state == .single {
                return .invoked
            }
            return .rejected
        }, with: self, for: .Tab, priority: .high)
        
      
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if !self.chatInteraction.presentation.isSearchMode.0 {
                self.chatInteraction.update({$0.updatedSearchMode((true, nil, nil))})
            } else {
                self.genericView.applySearchResponder()
            }

            return .invoked
        }, with: self, for: .F, priority: .medium, modifierFlags: [.command])
        
    
        
//        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
//            guard let `self` = self else {return .rejected}
//            if let editState = self.chatInteraction.presentation.interfaceState.editState, let media = editState.originalMedia as? TelegramMediaImage {
//                self.chatInteraction.editEditingMessagePhoto(media)
//            }
//            return .invoked
//        }, with: self, for: .E, priority: .medium, modifierFlags: [.command])
        
      
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeBold()
            return .invoked
        }, with: self, for: .B, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeUrl()
            return .invoked
        }, with: self, for: .U, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeItalic()
            return .invoked
        }, with: self, for: .I, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else { return .rejected }
            self.chatInteraction.startRecording(true, nil)
            return .invoked
        }, with: self, for: .R, priority: .medium, modifierFlags: [.command])
        
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeMonospace()
            return .invoked
        }, with: self, for: .K, priority: .medium, modifierFlags: [.command, .shift])
        
        
        #if BETA || ALPHA || DEBUG
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let `self` = self {
                addAudioToSticker(context: self.context)
            }
            return .invoked
        }, with: self, for: .Y, priority: .medium, modifierFlags: [.command, .shift])
        #endif
        
        self.context.window.add(swipe: { [weak self] direction, _ -> SwipeHandlerResult in
            guard let `self` = self, let window = self.window, self.chatInteraction.presentation.state == .normal else {return .failed}
            let swipeState: SwipeState?
            switch direction {
            case .left:
               return .failed
            case let .right(_state):
                swipeState = _state
            case .none:
                swipeState = nil
            }
            
            guard let state = swipeState else {return .failed}
            

            
            switch state {
            case .start:
                let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
                if row != -1 {
                    guard let item = self.genericView.tableView.item(at: row) as? ChatRowItem, let message = item.message, canReplyMessage(message, peerId: self.chatInteraction.peerId) else {return .failed}
                    self.removeRevealStateIfNeeded(message.id)
                    (item.view as? RevealTableView)?.initRevealState()
                    return .success(RevealTableItemController(item: item))
                } else {
                    return .failed
                }
                
            case let .swiping(_delta, controller):
                let controller = controller as! RevealTableItemController
                
                guard let view = controller.item.view as? RevealTableView else {return .nothing}
                
                var delta:CGFloat
                switch direction {
                case .left:
                    delta = _delta//max(0, _delta)
                case .right:
                    delta = -_delta//min(-_delta, 0)
                default:
                    delta = _delta
                }
                
                let newDelta = min(min(300, view.width) * log2(abs(delta) + 1) * log2(min(300, view.width)) / 100.0, abs(delta))
                
                if delta < 0 {
                    delta = -newDelta
                } else {
                    delta = newDelta
                }

                
                view.moveReveal(delta: delta)

            case let .success(_, controller), let .failed(_, controller):
                let controller = controller as! RevealTableItemController
                guard let view = (controller.item.view as? RevealTableView) else {return .nothing}
                
                
                view.completeReveal(direction: direction)
            }
            
            //  return .success()
            
            return .nothing
        }, with: self.genericView.tableView, identifier: "chat-reply-swipe")
        
        
        
        if !(context.window.firstResponder is NSTextView) {
            self.genericView.inputView.makeFirstResponder()
        }

        if let window = window {
            selectTextController.initializeHandlers(for: window, chatInteraction:chatInteraction)
        }
        
        _ = context.window.makeFirstResponder(genericView.inputView.textView.inputView)
        
    }
    
    private func removeRevealStateIfNeeded(_ messageId: MessageId) -> Void {
        
    }
    
    func findAndSetEditableMessage(_ bottom: Bool = false) -> Bool {
        let view = self.previousView.with { $0 }
        if let view = view?.originalView, view.laterId == nil {
            for entry in (!bottom ? view.entries.reversed() : view.entries) {
                if let messageId = chatInteraction.presentation.interfaceState.editState?.message.id {
                    if (messageId <= entry.message.id && !bottom) || (messageId >= entry.message.id && bottom) {
                        continue
                    }
                }
                if canEditMessage(entry.message, context: context)  {
                    chatInteraction.beginEditingMessage(entry.message)
                    return true
                }
            }
        }
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        return self.genericView.responder
    }
    
    override var responderPriority: HandlerPriority {
        return .medium
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.chatInteraction.add(observer: self)
        self.context.globalPeerHandler.set(.single(chatLocation))

        if let controller = globalAudio {
            (self.navigationController?.header?.view as? InlineAudioPlayerView)?.update(with: controller, context: context, tableView: genericView.tableView)
        }
        
    }
    
    private func updateMaxVisibleReadIncomingMessageIndex(_ index: MessageIndex) {
        self.maxVisibleIncomingMessageIndex.set(index)
    }
    
    
    override func invokeNavigation(action:NavigationModalAction) {
        super.invokeNavigation(action: action)
        chatInteraction.applyAction(action: action)
    }
    
    private let isAdChat: Bool
    private let messageId: MessageId?
    let mode: ChatMode
    
    public init(context: AccountContext, chatLocation:ChatLocation, mode: ChatMode = .history, messageId:MessageId? = nil, initialAction:ChatInitialAction? = nil) {
        self.chatLocation = chatLocation
        self.messageId = messageId
        self.mode = mode
        self.undoTooltipControl = UndoTooltipControl(context: context)
        self.chatInteraction = ChatInteraction(chatLocation: chatLocation, context: context, mode: mode)
        if let action = initialAction {
            switch action {
            case .ad:
                isAdChat = true
            default:
                isAdChat = false
            }
        } else {
            isAdChat = false
        }
        super.init(context)
        
        
        //NSLog("init chat controller")
        self.chatInteraction.update(animated: false, {$0.updatedInitialAction(initialAction)})
        context.checkFirstRecentlyForDuplicate(peerId: chatInteraction.peerId)
        
        self.messageProcessingManager.process = { messageIds in
            context.account.viewTracker.updateViewCountForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}))
        }

        self.unsupportedMessageProcessingManager.process = { messageIds in
            context.account.viewTracker.updateUnsupportedMediaForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}))
        }
        self.messageMentionProcessingManager.process = { messageIds in
            context.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}))
        }
        
        
        self.location.set(peerView.get() |> take(1) |> deliverOnMainQueue |> map { [weak self] view -> ChatHistoryLocation in
            
            if let strongSelf = self {
                let count = Int(round(strongSelf.view.frame.height / 28)) + 2
                let location:ChatHistoryLocation
                if let messageId = messageId {
                    location = .InitialSearch(location: .id(messageId), count: count + 10)
                } else {
                    location = .Initial(count: count)
                }
                
                return location
            }
            return .Initial(count: 30)
        })
        _ = (self.location.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] location in
            _ = self?._locationValue.swap(location)
        })
    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        notify(with: value, oldValue: oldValue, animated: animated, force: false)
    }
    
    private var isPausedGlobalPlayer: Bool = false
    
    func notify(with value: Any, oldValue: Any, animated:Bool, force:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            let context = self.context
            
            
            if value.selectionState != oldValue.selectionState {
                if let selectionState = value.selectionState {
                    let ids = Array(selectionState.selectedIds)
                    loadSelectionMessagesDisposable.set((context.account.postbox.messagesAtIds(ids) |> deliverOnMainQueue).start( next:{ [weak self] messages in
                        var canDelete:Bool = !ids.isEmpty
                        var canForward:Bool = !ids.isEmpty
                        for message in messages {
                            if !canDeleteMessage(message, account: context.account) {
                                canDelete = false
                            }
                            if !canForwardMessage(message, account: context.account) {
                                canForward = false
                            }
                        }
                        self?.chatInteraction.update({$0.withUpdatedBasicActions((canDelete, canForward))})
                    }))
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.chatInteraction.update({$0.withUpdatedBasicActions((false, false))})
                    }
                }
                if value.selectionState != nil {
                    _ = window?.makeFirstResponder(selectManager)
                } else {
                    _ = window?.makeFirstResponder(self.firstResponder())
                }
            }
            
//            if #available(OSX 10.12.2, *) {
//                self.context.window.touchBar = self.context.window.makeTouchBar()
//            }
            
            if oldValue.recordingState == nil && value.recordingState != nil {
                if let pause = globalAudio?.pause() {
                    isPausedGlobalPlayer = pause
                }
            } else if value.recordingState == nil && oldValue.recordingState != nil {
                if isPausedGlobalPlayer {
                    _ = globalAudio?.play()
                }
            }
            if let until = value.slowMode?.validUntil, until > self.context.timestamp {
                let signal = Signal<Void, NoError>.single(Void()) |> then(.single(Void()) |> delay(0.2, queue: .mainQueue()) |> restart)
                slowModeDisposable.set(signal.start(next: { [weak self] in
                    if let `self` = self {
                        if until < self.context.timestamp {
                            self.chatInteraction.update({$0.updateSlowMode({ $0?.withUpdatedTimeout(nil) })})
                        } else {
                            self.chatInteraction.update({$0.updateSlowMode({ $0?.withUpdatedTimeout(until - self.context.timestamp) })})
                        }
                    }
                }))
                
            } else {
                self.slowModeDisposable.set(nil)
                if let slowMode = value.slowMode, slowMode.timeout != nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.chatInteraction.update({$0.updateSlowMode({ $0?.withUpdatedTimeout(nil) })})
                    }
                }
            }
            
            if value.inputQueryResult != oldValue.inputQueryResult {
                genericView.inputContextHelper.context(with: value.inputQueryResult, for: genericView, relativeView: genericView.inputView, animated: animated)
            }
            if value.interfaceState.inputState != oldValue.interfaceState.inputState {
                chatInteraction.saveState(false, scrollState: immediateScrollState())
                
            }
            
            if value.interfaceState.forwardMessageIds != oldValue.interfaceState.forwardMessageIds {
                let signal = (context.account.postbox.messagesAtIds(value.interfaceState.forwardMessageIds)) |> deliverOnMainQueue
                forwardMessagesDisposable.set(signal.start(next: { [weak self] messages in
                    self?.chatInteraction.update(animated: animated, {
                        $0.updatedInterfaceState {
                            $0.withUpdatedForwardMessages(messages)
                        }
                    })
                }))
            }
            
            if value.selectionState != oldValue.selectionState {
                doneButton?.isHidden = value.selectionState == nil
                editButton?.isHidden = value.selectionState != nil
            }
            
            if value.effectiveInput != oldValue.effectiveInput || force {
                if let (updatedContextQueryState, updatedContextQuerySignal) = contextQueryResultStateForChatInterfacePresentationState(chatInteraction.presentation, context: self.context, currentQuery: self.contextQueryState?.0) {
                    self.contextQueryState?.1.dispose()
                    var inScope = true
                    var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                    self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let strongSelf = self {
                            if Thread.isMainThread && inScope {
                                inScope = false
                                inScopeResult = result
                            } else {
                                strongSelf.chatInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return result(previousResult)
                                    }
                                })
                                
                            }
                        }
                    }))
                    inScope = false
                    if let inScopeResult = inScopeResult {
                        
                        chatInteraction.update(animated: animated, {
                            $0.updatedInputQueryResult { previousResult in
                                return inScopeResult(previousResult)
                            }
                        })
                        
                    }
                    
                    
                    let updateUrl = urlPreviewStateForChatInterfacePresentationState(chatInteraction.presentation, context: context, currentQuery: self.urlPreviewQueryState?.0) |> delay(value.effectiveInput.inputText.isEmpty ? 0.0 : 0.1, queue: .mainQueue()) |> deliverOnMainQueue
                    
                    updateUrlDisposable.set(updateUrl.start(next: { [weak self] result in
                        if let `self` = self, let (updatedUrlPreviewUrl, updatedUrlPreviewSignal) = result {
                            self.urlPreviewQueryState?.1.dispose()
                            var inScope = true
                            var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
                            self.urlPreviewQueryState = (updatedUrlPreviewUrl, (updatedUrlPreviewSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                                if let strongSelf = self {
                                    if Thread.isMainThread && inScope {
                                        inScope = false
                                        inScopeResult = result
                                    } else {
                                        strongSelf.chatInteraction.update(animated: true, {
                                            if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = result($0.urlPreview?.1) {
                                                return $0.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                                            } else {
                                                return $0.updatedUrlPreview(nil)
                                            }
                                        })
                                    }
                                }
                            }))
                            inScope = false
                            if let inScopeResult = inScopeResult {
                                self.chatInteraction.update(animated: true, {
                                    if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = inScopeResult($0.urlPreview?.1) {
                                        return $0.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                                    } else {
                                        return $0.updatedUrlPreview(nil)
                                    }
                                })
                            }
                        }
                    }))

                    
                }
            }
            
            if value.isSearchMode.0 != oldValue.isSearchMode.0 || value.pinnedMessageId != oldValue.pinnedMessageId || value.peerStatus != oldValue.peerStatus || value.interfaceState.dismissedPinnedMessageId != oldValue.interfaceState.dismissedPinnedMessageId || value.initialAction != oldValue.initialAction || value.restrictionInfo != oldValue.restrictionInfo {
                genericView.updateHeader(value, animated)
            }
            
            if value.peer != nil && oldValue.peer == nil {
                genericView.tableView.emptyItem = ChatEmptyPeerItem(genericView.tableView.frame.size, chatInteraction: chatInteraction)
            }
            
            var upgradedToPeerId: PeerId?
            if let previous = oldValue.peer, let group = previous as? TelegramGroup, group.migrationReference == nil, let updatedGroup = value.peer as? TelegramGroup, let migrationReference = updatedGroup.migrationReference {
                upgradedToPeerId = migrationReference.peerId
            }


            self.state = value.selectionState != nil ? .Edit : .Normal
            
            if let upgradedToPeerId = upgradedToPeerId {
                let controller = ChatController(context: context, chatLocation: .peer(upgradedToPeerId))
                navigationController?.removeAll()
                navigationController?.push(controller, false, style: .none)
            }
           
        }
    }
    
    
    func immediateScrollState() -> ChatInterfaceHistoryScrollState? {
        
        var message:Message?
        var index:Int?
        self.genericView.tableView.enumerateVisibleItems(reversed: true, with: { item -> Bool in
            
            if let item = item as? ChatRowItem {
                message = item.message
                index = item.index
            }
            return message == nil
        })
        
        if let visibleIndex = index, let message = message {
            let rect = genericView.tableView.rectOf(index: visibleIndex)
            let top = genericView.tableView.documentOffset.y + genericView.tableView.frame.height
            if genericView.tableView.frame.height >= genericView.tableView.documentOffset.y && historyState.isDownOfHistory {
                return nil
            } else {
                let relativeOffset: CGFloat = top - rect.maxY
                return ChatInterfaceHistoryScrollState(messageIndex: MessageIndex(message), relativeOffset: Double(relativeOffset))
            }
        }
        
        return nil
    }
  

    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ChatController {
            return other == self
        }
        return false
    }
    
    
    public override func draggingExited() {
        super.draggingExited()
        genericView.inputView.isHidden = false
    }
    public override func draggingEntered() {
        super.draggingEntered()
        genericView.inputView.isHidden = true
    }
    
    public override func draggingItems(for pasteboard:NSPasteboard) -> [DragItem] {
        
        if hasModals() {
            return []
        }
        
        let peerId = self.chatInteraction.peerId
        
        if let types = pasteboard.types, types.contains(.kFilenames) {
            let list = pasteboard.propertyList(forType: .kFilenames) as? [String]
            
            if let list = list, list.count > 0, let peer = chatInteraction.peer, peer.canSendMessage {
                
                if let text = permissionText(from: peer, for: .banSendMedia) {
                    return [DragItem(title: "", desc: text, handler: {
                        
                    })]
                }
                
                var items:[DragItem] = []
                
                let list = list.filter { path -> Bool in
                    if let size = fs(path) {
                        return size <= 2000 * 1024 * 1024
                    }

                    return false
                }
                
                if list.count == 1, let editState = chatInteraction.presentation.interfaceState.editState, editState.canEditMedia {
                    return [DragItem(title: L10n.chatDropEditTitle, desc: L10n.chatDropEditDesc, handler: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        _ = (Sender.generateMedia(for: MediaSenderContainer(path: list[0], isFile: false), account: strongSelf.chatInteraction.context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) |> deliverOnMainQueue).start(next: { media, _ in
                            self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                        })
                    })]
                }
                
                
                if !list.isEmpty {
                    
                    
                    let asMediaItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropQuickDesc), handler:{ [weak self] in
                        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                        if shift {
                            self?.chatInteraction.sendMedia(list.map{MediaSenderContainer(path: $0, caption: "", isFile: false)})
                        } else {
                            self?.chatInteraction.showPreviewSender(list.map { URL(fileURLWithPath: $0) }, true, nil)
                        }
                    })
                    let fileTitle: String
                    let fileDesc: String
                    
                    if list.count == 1, list[0].isDirectory {
                        fileTitle = L10n.chatDropFolderTitle
                        fileDesc = L10n.chatDropFolderDesc
                    } else {
                        fileTitle = L10n.chatDropTitle
                        fileDesc = L10n.chatDropAsFilesDesc
                    }
                    let asFileItem = DragItem(title: fileTitle, desc: fileDesc, handler: { [weak self] in
                        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                        if shift {
                            self?.chatInteraction.sendMedia(list.map{MediaSenderContainer(path: $0, caption: "", isFile: true)})
                        } else {
                            self?.chatInteraction.showPreviewSender(list.map { URL(fileURLWithPath: $0) }, false, nil)
                        }
                    })
                    
                    items.append(asFileItem)
                    
                    
                    var asMedia:Bool = false
                    for path in list {
                        if mediaExts.contains(path.nsstring.pathExtension.lowercased()) {
                            asMedia = true
                            break
                        }
                    }
                    
                    if asMedia {
                        items.append(asMediaItem)
                    } 
    
                }

                return items
            }
            //NSTIFFPboardType
        } else if let types = pasteboard.types, types.contains(.tiff) {
            let data = pasteboard.data(forType: .tiff)
            if let data = data, let image = NSImage(data: data) {
                
                if let editState = chatInteraction.presentation.interfaceState.editState, editState.canEditMedia {
                    return [DragItem(title: L10n.chatDropEditTitle, desc: L10n.chatDropEditDesc, handler: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        _ = (putToTemp(image: image) |> mapToSignal {Sender.generateMedia(for: MediaSenderContainer(path: $0, isFile: false), account: strongSelf.chatInteraction.context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) } |> deliverOnMainQueue).start(next: { media, _ in
                            self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                        })
                    })]
                }
                
                var items:[DragItem] = []

                let asMediaItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropQuickDesc), handler:{ [weak self] in
                    _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak self] path in
                        self?.chatInteraction.showPreviewSender([URL(fileURLWithPath: path)], true, nil)
                    })

                })
                
                let asFileItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropAsFilesDesc), handler:{ [weak self] in
                    _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak self] path in
                        self?.chatInteraction.showPreviewSender([URL(fileURLWithPath: path)], false, nil)
                    })
                })
                
                items.append(asFileItem)
                items.append(asMediaItem)
                
                return items
            }
        }
        
        return []
    }
    
    override public var isOpaque: Bool {
        return false
    }
    
    override func updateController() {
        genericView.tableView.enumerateVisibleViews(with: { view in
            if let view = view as? ChatRowView {
                view.updateBackground(animated: false)
            }
        }, force: true)
    }

    override open func backSettings() -> (String,CGImage?) {
        if context.sharedContext.layout == .single {
            return super.backSettings()
        }
        return (tr(L10n.navigationClose),nil)
    }

    override public func update(with state:ViewControllerState) -> Void {
        super.update(with:state)
        chatInteraction.update({state == .Normal ? $0.withoutSelectionState() : $0.withSelectionState()})
        context.window.applyResponderIfNeeded()
    }
    
    override func initializer() -> ChatControllerView {
        return ChatControllerView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - self.bar.height), chatInteraction:chatInteraction);
    }
    
    override func requestUpdateCenterBar() {
       
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        updateBackgroundColor(theme.controllerBackgroundMode)
        (centerBarView as? ChatTitleBarView)?.updateStatus()
    }
    
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        
    }
    func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        return false
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return false
    }
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        if let view = previousView.with({$0}), let stableId = stableId.base as? ChatHistoryEntryId {
            switch stableId {
            case let .message(message):
                for entry in view.filteredEntries {
                    s: switch entry.entry {
                    case let .groupedPhotos(entries, _):
                        for groupedEntry in entries {
                            if message.id == groupedEntry.message?.id {
                                return entry.stableId
                            }
                        }
                    default:
                        break s
                    }
                }
            default:
                break
            }
        }
        return nil
    }

    
}
