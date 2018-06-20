//
//  ChatController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

struct ChatWrapperEntry : Comparable, Identifiable {
    let appearance: AppearanceWrapperEntry<ChatHistoryEntry>
    let automaticDownload: AutomaticMediaDownloadSettings
    
    var stableId: AnyHashable {
        return appearance.entry.stableId
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
    let originalView: MessageHistoryView
    let filteredEntries: [ChatWrapperEntry]
    
    init(originalView:MessageHistoryView, filteredEntries: [ChatWrapperEntry]) {
        self.originalView = originalView
        self.filteredEntries = filteredEntries
    }
}

enum ChatControllerViewState {
    case visible
    case progress
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


class ChatControllerView : ChatBackgroundView, ChatInputDelegate {
    
    let tableView:TableView
    let inputView:ChatInputView
    let inputContextHelper:InputContextHelper
    private(set) var state:ChatControllerViewState = .visible
    private var searchInteractions:ChatSearchInteractions!
    private let scroller:ChatNavigateScroller
    private var mentions:ChatNavigationMention?
    private var progressView:ProgressIndicator?
    private let header:ChatHeaderController
    private var historyState:ChatHistoryState?
    private let chatInteraction: ChatInteraction
    var headerState: ChatHeaderState {
        return header.state
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    
    required init(frame frameRect: NSRect, chatInteraction:ChatInteraction, account:Account) {
        self.chatInteraction = chatInteraction
        header = ChatHeaderController(chatInteraction)
        scroller = ChatNavigateScroller(account, chatInteraction.chatLocation)
        inputContextHelper = InputContextHelper(account: account, chatInteraction: chatInteraction)
        tableView = TableView(frame:NSMakeRect(0,0,frameRect.width,frameRect.height - 50), isFlipped:false)
        inputView = ChatInputView(frame: NSMakeRect(0,tableView.frame.maxY, frameRect.width,50), chatInteraction: chatInteraction)
        inputView.autoresizingMask = [.width]
        super.init(frame: frameRect)
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
        
        

        searchInteractions = ChatSearchInteractions( jump: { message in
            chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: true, inset: 0))
        }, results: { query in
            chatInteraction.modalSearch(query)
        }, calendarAction: { date in
            chatInteraction.jumpToDate(date)
        }, cancel: {
            chatInteraction.update({$0.updatedSearchMode(false)})
        }, searchRequest: { query, fromId -> Signal<[Message],Void> in
            let location: SearchMessagesLocation
            switch chatInteraction.chatLocation {
            case let .group(groupId):
                location = .group(groupId)
            case let .peer(peerId):
                location = .peer(peerId: peerId, fromId: fromId, tags: nil)
            }
            return searchMessages(account: account, location: location, query: query)
        })
        
        
        tableView.addScroll(listener: TableScrollListener { [weak self] position in
            if let state = self?.historyState {
                self?.updateScroller(state)
            }
        })
        
        tableView.backgroundColor = .clear
        tableView.layer?.backgroundColor = .clear

        updateLocalizationAndTheme()
        
        tableView.set(stickClass: ChatDateStickItem.self, handler: { stick in
            var bp:Int = 0
            bp += 1
        })
    }
    
    func updateScroller(_ historyState:ChatHistoryState) {
        self.historyState = historyState
        let isHidden = tableView.documentOffset.y < 150 && historyState.isDownOfHistory
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
    }
    
    
    func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void {
        if let view = header.currentView {
            view.layer?.animatePosition(from: NSMakePoint(0, previous), to: NSMakePoint(0, current), removeOnCompletion: false)
            return { [weak view] in
                view?.layer?.removeAllAnimations()
            }
        }
        return {}
    }
    
    
    private var previousHeight:CGFloat = 50
    func inputChanged(height: CGFloat, animated: Bool) {
        if previousHeight != height {
            previousHeight = height
            let header:CGFloat
            if let currentView = self.header.currentView {
                header = currentView.frame.height
            } else {
                header = 0
            }
            let size = NSMakeSize(frame.width, frame.height - height - header)
            tableView.change(size: size, animated: animated)
            inputView.change(pos: NSMakePoint(frame.minX, tableView.frame.maxY), animated: animated)
            if let view = inputContextHelper.accessoryView {
                view._change(pos: NSMakePoint(0, size.height - view.frame.height), animated: animated)
            }
            if let mentions = mentions {
                mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: animated )
            }
            scroller.change(pos: NSMakePoint(frame.width - scroller.frame.width - 6, size.height - scroller.frame.height - 6), animated: animated)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        if let view = inputContextHelper.accessoryView {
            view.setFrameSize(NSMakeSize(newSize.width, view.frame.height))
        }
        
        if let currentView = header.currentView {
            currentView.setFrameSize(NSMakeSize(newSize.width, currentView.frame.height))
            tableView.setFrameSize(NSMakeSize(newSize.width, newSize.height - inputView.frame.height - currentView.frame.height))
        } else {
            tableView.setFrameSize(NSMakeSize(newSize.width, newSize.height - inputView.frame.height))
        }
        inputView.setFrameSize(NSMakeSize(newSize.width, inputView.frame.height))
        
        super.setFrameSize(newSize)

    }
    
    override func layout() {
        super.layout()
        header.currentView?.setFrameOrigin(NSZeroPoint)
        if let currentView = header.currentView {
            tableView.setFrameOrigin(0, currentView.frame.height)
            currentView.needsDisplay = true

        } else {
            tableView.setFrameOrigin(0, 0)
        }
        
        if let view = inputContextHelper.accessoryView {
            view.setFrameOrigin(0, frame.height - inputView.frame.height - view.frame.height)
        }
        inputView.setFrameOrigin(NSMakePoint(0, tableView.frame.maxY))
        if let indicator = progressView?.subviews.first {
            indicator.center()
        }
        
        progressView?.center()
        
        scroller.setFrameOrigin(frame.width - scroller.frame.width - 6, tableView.frame.height - 6 - scroller.frame.height)
        
        if let mentions = mentions {
            mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: false )
        }
    }
    

    override var responder: NSResponder? {
        return inputView.responder
    }
    
    func change(state:ChatControllerViewState, animated:Bool) {
        if state != self.state {
            self.state = state
            
            switch state {
            case .progress:
                if progressView == nil {
                    self.progressView = ProgressIndicator(frame: NSMakeRect(0,0,30,30))
                    
                    progressView!.animates = true
                    addSubview(progressView!)
                    progressView!.center()
                }
                progressView?.backgroundColor = theme.colors.background.withAlphaComponent(0.7)
                progressView?.layer?.cornerRadius = 15
              //  (progressView?.subviews.first as? ProgressIndicator)?.color = theme.colors.indicatorColor
                break
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
                
                break
            }
        }
    }
    
    func updateHeader(_ interfaceState:ChatPresentationInterfaceState, _ animated:Bool) {
        
        let state:ChatHeaderState
        if let initialAction = interfaceState.initialAction, case .ad = initialAction {
            state = .sponsored
        } else if interfaceState.isSearchMode {
            state = .search(searchInteractions)
        } else if interfaceState.reportStatus == .canReport {
            state = .report
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
            mentions.change(pos: NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)), animated: animated )
        }
        
        if let view = inputContextHelper.accessoryView {
            view._change(pos: NSMakePoint(0, frame.height - view.frame.height - inputView.frame.height), animated: animated)
        }
        CATransaction.commit()
    }
    
    func updateMentionsCount(_ count: Int32, animated: Bool) {
        if count > 0 {
            if mentions == nil {
                mentions = ChatNavigationMention()
                mentions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.mentionPressed()
                }, for: .Click)
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
    
    override func updateBackgroundColor() {
       super.updateBackgroundColor()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        updateBackgroundColor()
        self.backgroundColor = theme.colors.background
        progressView?.backgroundColor = theme.colors.background
        (progressView?.subviews.first as? ProgressIndicator)?.set(color: theme.colors.indicatorColor)
        scroller.updateLocalizationAndTheme()
        tableView.emptyItem = ChatEmptyPeerItem(tableView.frame.size, chatInteraction: chatInteraction)
    }

    
}




fileprivate func prepareEntries(from fromView:ChatHistoryView?, to toView:ChatHistoryView, account:Account, initialSize:NSSize, interaction:ChatInteraction, animated:Bool, scrollPosition:ChatHistoryViewScrollPosition?, reason:ChatHistoryViewUpdateType, animationInterface:TableAnimationInterface?) -> Signal<TableUpdateTransition,Void> {
    return Signal { subscriber in
    
        
        var scrollToItem:TableScrollState? = nil
        var animated = animated
        
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .unread(unreadIndex):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case .UnreadEntry = entry.appearance.entry {
                        scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: false, inset: 0)
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
//                            scrollToItem = .top(id: entry.stableId, animated: false, focus: false, inset: 0)
//                            break
//                        }
//                        index += 1
//                    }
                }
            case let .positionRestoration(scrollIndex, relativeOffset):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if entry.appearance.entry.index >= scrollIndex {
                        scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: false, inset: relativeOffset)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.appearance.entry.index < scrollIndex {
                            scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: false, inset: relativeOffset)
                            break
                        }
                        index += 1
                    }
                }
            case let .index(scrollIndex, position, directionHint, animated):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if scrollIndex.isLessOrEqual(to: entry.appearance.entry.index) {
                        if case let .groupedPhotos(entries, _) = entry.appearance.entry {
                            for inner in entries {
                                if case let .MessageEntry(values) = inner {
                                    if !scrollIndex.isLess(than: MessageIndex(values.0)) && scrollIndex.isLessOrEqual(to: MessageIndex(values.0)) {
                                        scrollToItem = position.swap(to: entry.appearance.entry.stableId, innerId: inner.stableId)
                                    }
                                }
                            }
                        } else {
                            scrollToItem = position.swap(to: entry.appearance.entry.stableId)
                        }
                        break
                    }
                    index -= 1
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
            scrollToItem = .saveVisible(.upper)
            
            switch reason {
            case let .Generic(type):
                switch type {
                case .Generic:
                    scrollToItem = .none(animationInterface)
                case let .FillHole(_, deletions):
                    if let (_, removeDirection) = deletions.first {
                        switch removeDirection {
                        case .LowerToUpper:
                            scrollToItem = .saveVisible(.upper)
                        case .UpperToLower:
                            scrollToItem = .saveVisible(.lower)
                        case let .AroundId(id, _, _):
                            for entry in toView.filteredEntries {
                                if entry.appearance.entry.index.id == id {
                                    scrollToItem = .saveVisible(.aroundIndex(entry.stableId))
                                    break
                                }
                            }
                        case let .AroundIndex(index, lowerComplete, upperComplete, clippingMinIndex, clippingMaxIndex):
                            for entry in toView.filteredEntries {
                                if entry.appearance.entry.index == index {
                                    scrollToItem = .saveVisible(.aroundIndex(entry.stableId))
                                    break
                                }
                            }
                        }
                    }
                default:
                    break
                }
            default:
                break
            }
        }
        
        
        func makeItem(_ entry: ChatWrapperEntry) -> TableRowItem {
            var item:TableRowItem;
            switch entry.appearance.entry {
            case .HoleEntry:
                item = ChatHoleRowItem(initialSize, interaction, account, entry.appearance.entry, entry.automaticDownload)
            case .UnreadEntry:
                item = ChatUnreadRowItem(initialSize, interaction, account, entry.appearance.entry, entry.automaticDownload)
            case .MessageEntry:
                item = ChatRowItem.item(initialSize, from: entry.appearance.entry, with:account, interaction: interaction, downloadSettings: entry.automaticDownload)
            case .groupedPhotos:
                item = ChatGroupedItem(initialSize, interaction, account, entry.appearance.entry, entry.automaticDownload)
            case .DateEntry:
                item = ChatDateStickItem(initialSize, entry.appearance.entry, interaction: interaction)
            case .bottom:
                item = GeneralRowItem(initialSize, height: theme.bubbled ? 10 : 20, stableId: entry.stableId)
            }
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
                        
                        if high == 0 {
                            var bp:Int = 0
                            bp += 1
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
            if case let .MessageEntry(message, _, _, _, _, _) = entries[i], message.flags.contains(.Incoming) {
                return MessageIndex(message)
            }
        }
    }
    
    return nil
}

enum ChatHistoryViewTransitionReason {
    case Initial(fadeIn: Bool)
    case InteractiveChanges
    case HoleChanges(filledHoleDirections: [MessageIndex: HoleFillDirection], removeHoleDirections: [MessageIndex: HoleFillDirection])
    case Reload
}


class ChatController: EditableViewController<ChatControllerView>, Notifable, TableViewDelegate {
    
    private var chatLocation:ChatLocation
    private let peerView = Promise<PostboxView?>()
    
    private let historyDisposable:MetaDisposable = MetaDisposable()
    private let peerDisposable:MetaDisposable = MetaDisposable()
    private let updatedChannelParticipants:MetaDisposable = MetaDisposable()
    private let sentMessageEventsDisposable = MetaDisposable()
    private let messageActionCallbackDisposable:MetaDisposable = MetaDisposable()
    private let shareContactDisposable:MetaDisposable = MetaDisposable()
    private let peerInputActivitiesDisposable:MetaDisposable = MetaDisposable()
    private let connectionStatusDisposable:MetaDisposable = MetaDisposable()
    private let messagesActionDisposable:MetaDisposable = MetaDisposable()
    private let openPeerInfoDisposable:MetaDisposable = MetaDisposable()
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
    private let editMessageDisposable: MetaDisposable = MetaDisposable()
    var chatInteraction:ChatInteraction
    
    var nextTransaction:TransactionHandler = TransactionHandler()
    
    private let _historyReady = Promise<Bool>()
    private var didSetHistoryReady = false

    
    private let location:Promise<ChatHistoryLocation> = Promise()
    private func setLocation(_ location: ChatHistoryLocation) {
        self.location.set(.single(location))
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    private let readHistoryDisposable = MetaDisposable()
    
    
    private let initialDataHandler:Promise<ChatHistoryCombinedInitialData> = Promise()
    private let autoremovingUnreadMark:Promise<Bool?> = Promise(nil)

    let previousView = Atomic<ChatHistoryView?>(value: nil)
    
    
    private let botCallbackAlertMessage = Promise<(String?, Bool)>((nil, false))
    private var botCallbackAlertMessageDisposable: Disposable?
    
    private var selectTextController:ChatSelectText!
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?

    
    let layoutDisposable:MetaDisposable = MetaDisposable()
    
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    var historyState:ChatHistoryState = ChatHistoryState() {
        didSet {
            //if historyState != oldValue {
                genericView.updateScroller(historyState) // updateScroller()
            //}
        }
    }


    override func scrollup() -> Void {
        if let reply = historyState.reply() {
            
            if let message = messageInCurrentHistoryView(reply) {
                let stableId = ChatHistoryEntryId.message(message) //TODO
                genericView.tableView.scroll(to: .center(id: stableId, innerId: nil, animated: true, focus: true, inset: 0))
            } else {
                chatInteraction.focusMessageId(nil, reply, .center(id: 0, innerId: nil, animated: true, focus: true, inset: 0))
            }
            historyState = historyState.withRemovingReplies(max: reply)
        } else {
            if previousView.modify({$0})?.originalView.laterId != nil {
                setLocation(.Scroll(index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, sourceIndex: MessageHistoryAnchorIndex.lowerBound, scrollPosition: .down(true), count: requestCount, animated: true))
            } else {
                genericView.tableView.scroll(to: .down(true))
            }
        }
        
    }
    
    private var requestCount: Int {
        return Int(round(genericView.tableView.frame.height / 28)) + 30
    }
    
    func readyHistory() {
        if !didSetHistoryReady {
            didSetHistoryReady = true
            _historyReady.set(.single(true))
        }
    }
    
    override var sidebar:ViewController? {
        return account.context.entertainment
    }
    
    func updateSidebar() {
        if FastSettings.sidebarShown && FastSettings.sidebarEnabled {
            (navigationController as? MajorNavigationController)?.genericView.setProportion(proportion: SplitProportion(min:380, max:800), state: .single)
            (navigationController as? MajorNavigationController)?.genericView.setProportion(proportion: SplitProportion(min:380+350, max:700), state: .dual)
        } else {
            (navigationController as? MajorNavigationController)?.genericView.removeProportion(state: .dual)
            (navigationController as? MajorNavigationController)?.genericView.setProportion(proportion: SplitProportion(min:380, max: .greatestFiniteMagnitude), state: .single)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.tableView.delegate = self
        updateSidebar()
        
        
        switch chatLocation {
        case let .peer(peerId):
            self.peerView.set(account.viewTracker.peerView(peerId) |> map {Optional($0)})
            let _ = checkPeerChatServiceActions(postbox: self.account.postbox, peerId: peerId).start()
        case .group:
            self.peerView.set(account.postbox.combinedView(keys: [chatLocation.postboxViewKey]) |> map { combined in
                return combined.views.first?.value
            })
        }
        

        globalPeerHandler.set(.single(chatLocation))
        

        let layout:Atomic<SplitViewState> = Atomic(value:account.context.layout)
        let fixedCombinedReadState = Atomic<MessageHistoryViewReadState?>(value: nil)
        layoutDisposable.set(account.context.layoutHandler.get().start(next: {[weak self] (state) in
            let previous = layout.swap(state)
            if previous != state, let navigation = self?.navigationController {
                self?.requestUpdateBackBar()
                if let modalAction = navigation.modalAction {
                    navigation.set(modalAction: modalAction, state != .single)
                }
            }
        }))
        
        selectTextController = ChatSelectText(genericView.tableView)
        

        let historyViewUpdate = location.get() |> distinctUntilChanged
            |> mapToSignal { [weak self] location -> Signal<ChatHistoryViewUpdate, Void> in
                if let strongSelf = self {
                    return chatHistoryViewForLocation(location, account: strongSelf.account, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: fixedCombinedReadState.with { $0 }, tagMask: nil, additionalData: []) |> beforeNext { viewUpdate in
                        switch viewUpdate {
                        case let .HistoryView(view, _, _, _):
                            let _ = fixedCombinedReadState.swap(view.combinedReadStates)
                        default:
                            break
                        }
                    }
                }
                return .never()
        }
        
        
        //let autoremovingUnreadRemoved:Atomic<Bool> = Atomic(value: false)
        let previousAppearance:Atomic<Appearance> = Atomic(value: appAppearance)
        let firstInitialUpdate:Atomic<Bool> = Atomic(value: true)
        
        let historyViewTransition = combineLatest(historyViewUpdate |> deliverOnMainQueue, autoremovingUnreadMark.get() |> deliverOnMainQueue, appearanceSignal |> deliverOnMainQueue, account.context.cachedAdminIds.ids(postbox: account.postbox, network: account.network, peerId: chatInteraction.peerId) |> deliverOnMainQueue, automaticDownloadSettings(postbox: account.postbox) |> deliverOnMainQueue) |> mapToQueue { [weak self] update, autoremoving, appearance, adminIds, downloadSettings -> Signal<(TableUpdateTransition, ChatHistoryCombinedInitialData, TelegramWallpaper), NoError> in
            if let strongSelf = self {
                switch update {
                case let .Loading(initialData):
                    strongSelf.initialDataHandler.set(.single(initialData) |> deliverOnMainQueue)
                    strongSelf.readyHistory()
                    strongSelf.genericView.change(state: .progress, animated: true)
                    strongSelf.applyWallpaper(appearance.presentation.wallpaper)
                    return .complete()
                case let .HistoryView(view, updateType, scrollPosition, initialData):
                    
                    if view.isLoading {
                        strongSelf.initialDataHandler.set(.single(initialData) |> deliverOnMainQueue)
                        strongSelf.readyHistory()
                        strongSelf.genericView.change(state: .progress, animated: true)
                        strongSelf.applyWallpaper(appearance.presentation.wallpaper)
                        return .complete()
                    }
                    let pAppearance = previousAppearance.swap(appearance)
                    var prepareOnMainQueue = pAppearance.presentation != appearance.presentation
                    switch updateType {
                    case .Initial:
                        prepareOnMainQueue = firstInitialUpdate.swap(false) || prepareOnMainQueue
                    default:
                        break
                    }
                    
                    let animated = autoremoving == nil ? false : autoremoving!
                    
                    if view.maxReadIndex != nil, autoremoving == nil {
                        strongSelf.autoremovingUnreadMark.set(.single(true) |> delay(5.0, queue: Queue.mainQueue()) |> then(.single(false)))
                        
                    }
                    
                    let animationInterface: TableAnimationInterface = TableAnimationInterface(strongSelf.nextTransaction.isExutable && view.laterId == nil)
                    
                    
                    let proccesedView:ChatHistoryView
                    if let peer = strongSelf.chatInteraction.peer, peer.isRestrictedChannel {
                        proccesedView = ChatHistoryView(originalView: view, filteredEntries: [])
                    } else {
                        let entries = messageEntries(view.entries, maxReadIndex: autoremoving == nil ? view.maxReadIndex : nil, dayGrouping: true, renderType: appearance.presentation.bubbled ? .bubble : .list, includeBottom: true, timeDifference: strongSelf.account.context.timeDifference, adminIds: adminIds, groupingPhotos: true).map({ChatWrapperEntry(appearance: AppearanceWrapperEntry(entry: $0, appearance: appearance), automaticDownload: downloadSettings)})
                        proccesedView = ChatHistoryView(originalView: view, filteredEntries: entries)
                    }
                    
                    
                    return prepareEntries(from: strongSelf.previousView.swap(proccesedView), to: proccesedView, account: strongSelf.account, initialSize: strongSelf.atomicSize.modify({$0}), interaction:strongSelf.chatInteraction, animated: animated, scrollPosition:scrollPosition, reason:updateType, animationInterface:animationInterface) |> map { transition in
                        return (transition,initialData, appearance.presentation.wallpaper)
                    } |> runOn(prepareOnMainQueue ? Queue.mainQueue(): messagesViewQueue)
                }
            }
            
            return .never()
            
        } |> deliverOnMainQueue
        
        
        let appliedTransition = historyViewTransition |> map { [weak self] transition, initialData, wallpaper in
            self?.applyTransition(transition, initialData: initialData, wallpaper: wallpaper)
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
                        case let .group(groupId):
                            _ = self.account.postbox.transaction { transaction in
                                transaction.applyGroupFeedInteractiveReadMaxIndex(groupId: groupId, index: messageIndex)
                            }.start()
                        case let .peer(peerId):
                            clearNotifies(peerId, maxId: messageIndex.id)
                            _ = applyMaxReadIndexInteractively(postbox: self.account.postbox, stateManager: self.account.stateManager, index: messageIndex).start()
                        }
                    }
                }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        

        
        chatInteraction.setupReplyMessage = { [weak self] messageId in
            self?.chatInteraction.focusInputField()
            self?.chatInteraction.update({ current in
                
                var current = current.updatedInterfaceState({$0.withUpdatedReplyMessageId(messageId)})
                if messageId == current.keyboardButtonsMessage?.replyAttribute?.messageId {
                    current = current.updatedInterfaceState({$0.withUpdatedDismissedForceReplyId(messageId)})
                }
                
                return current
            })
            
        }
        
        chatInteraction.startRecording = { [weak self] hold in
            guard let chatInteraction = self?.chatInteraction else {return}
            if chatInteraction.presentation.recordingState != nil || chatInteraction.presentation.state != .normal {
                NSSound.beep()
                return
            }
            if let peer = chatInteraction.presentation.peer {
                if peer.mediaRestricted {
                    return alertForMediaRestriction(peer)
                }
                if chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                    let state: ChatRecordingState
                    
                    switch FastSettings.recordingState {
                    case .voice:
                        state = ChatRecordingAudioState(account: chatInteraction.account, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                        state.start()
                    case .video:
                        state = ChatRecordingVideoState(account: chatInteraction.account, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                        showModal(with: VideoRecorderModalController(chatInteraction: chatInteraction, pipeline: (state as! ChatRecordingVideoState).pipeline), for: mainWindow)
                    }
                    
                    chatInteraction.update({$0.withRecordingState(state)})
                }
            }
        }
        
        let scrollAfterSend:()->Void = { [weak self] in
            self?.chatInteraction.scrollToLatest(true)
            self?.account.context.entertainment.closePopover()
            self?.account.context.cancelGlobalSearch.set(true)
        }
        
        
        let afterSentTransition = { [weak self] in
           self?.chatInteraction.update({ presentation in
            return presentation.updatedInterfaceState { current in
                
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
            if let window = self?.window, let account = self?.account, let peerId = self?.chatInteraction.peerId {
                let signal = searchMessageIdByTimestamp(account: account, peerId: peerId, timestamp: Int32(date.timeIntervalSince1970) - Int32(NSTimeZone.local.secondsFromGMT())) |> mapToSignal { messageId -> Signal<Message?, Void> in
                    if let messageId = messageId {
                        return downloadMessage(account: account, messageId: messageId)
                    }
                    return .single(nil)
                }
                
                self?.dateDisposable.set(showModalProgress(signal: signal, for: window).start(next: { message in
                    if let message = message {
                        self?.chatInteraction.focusMessageId(nil, message.id, .top(id: 0, innerId: nil, animated: true, focus: false, inset: 50))
                    }
                }))
            }
        }
       
        let editMessage:(ChatEditState)->Void = { [weak self] state in
            guard let `self` = self else {return}
            let presentation = self.chatInteraction.presentation
            let inputState = state.inputState.subInputState(from: NSMakeRange(0, state.inputState.inputText.length))
            self.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedLoadingState(state.editMedia == .keep ? .loading : .progress(0.2))})})})
            self.editMessageDisposable.set((requestEditMessage(account: self.account, messageId: state.message.id, text: inputState.inputText, media: state.editMedia, entities: TextEntitiesMessageAttribute(entities: inputState.messageTextEntities), disableUrlPreview: presentation.interfaceState.composeDisableUrlPreview != nil)
            |> deliverOnMainQueue |> afterDisposed { [weak self] in
                self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedLoadingState(.none)})})})
            }).start(next: { [weak self] progress in
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
                self.chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedComposeDisableUrlPreview(nil)})})
            }))
        }
        
        chatInteraction.sendMessage = { [weak self] in
            if let strongSelf = self {
                let presentation = strongSelf.chatInteraction.presentation
                if presentation.abilityToSend {
                    var setNextToTransaction = false
                    if let state = presentation.interfaceState.editState {
                       editMessage(state)
                    } else  if !presentation.effectiveInput.inputText.trimmed.isEmpty {
                        setNextToTransaction = true
                        let _ = (Sender.enqueue(input: presentation.effectiveInput, account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, replyId: presentation.interfaceState.replyMessageId, disablePreview: presentation.interfaceState.composeDisableUrlPreview != nil) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    }
                    
                    let fwdIds: [MessageId] = presentation.interfaceState.forwardMessageIds
                    if !fwdIds.isEmpty {
                        setNextToTransaction = true
                        _ = (strongSelf.account.postbox.messagesAtIds(fwdIds) |> deliverOnMainQueue |> mapToSignal { [weak strongSelf] messages -> Signal<([MessageId?], Bool), NoError> in
                            if let strongSelf = strongSelf, let peer = strongSelf.chatInteraction.peer {
                                let messageIds = messages.filter {$0.possibilityForwardTo(peer)}.map {$0.id}
                                return Sender.forwardMessages(messageIds: messageIds,account: strongSelf.account,peerId: strongSelf.chatInteraction.peerId) |> map { ($0, messageIds.count != fwdIds.count) }
                            }
                            return .complete()
                        } |> deliverOnMainQueue).start(next: { [weak strongSelf] (ids, alert) in
                            if let peer = strongSelf?.chatInteraction.peer {
                                alertForMediaRestriction(peer)
                                scrollAfterSend()
                            }
                        })
                    }
                    
                    if setNextToTransaction {
                        strongSelf.nextTransaction.set(handler: afterSentTransition)
                    }
                } else {
                    if let editState = presentation.interfaceState.editState, editState.inputState.inputText.isEmpty {
                        if editState.message.media.isEmpty || editState.message.media.first is TelegramMediaWebpage {
                            strongSelf.chatInteraction.deleteMessages([editState.message.id])
                            return
                        }
                    }
                    NSSound.beep()
                }
            }
        }
        
        chatInteraction.forceSendMessage = { [weak self] input in
            if let strongSelf = self, let peer = self?.chatInteraction.presentation.peer, peer.canSendMessage {
                let _ = (Sender.enqueue(input: input, account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, replyId: strongSelf.chatInteraction.presentation.interfaceState.replyMessageId) |> deliverOnMainQueue).start(completed: scrollAfterSend)
            }
        }
        
        chatInteraction.sendPlainText = { [weak self] text in
            if let strongSelf = self, let peer = self?.chatInteraction.presentation.peer, peer.canSendMessage {
                let _ = (Sender.enqueue(input: ChatTextInputState(inputText: text), account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, replyId: strongSelf.chatInteraction.presentation.interfaceState.replyMessageId) |> deliverOnMainQueue).start(completed: scrollAfterSend)
            }
        }
        
        chatInteraction.sendLocation = { [weak self] coordinate, venue in
            guard let `self` = self else {return}
            _ = Sender.enqueue(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: venue, liveBroadcastingTimeout: nil), account: self.account, peerId: self.chatInteraction.peerId, chatInteraction: self.chatInteraction).start(completed: scrollAfterSend)
        }
        
        chatInteraction.scrollToLatest = { [weak self] removeStack in
            if let strongSelf = self {
                if removeStack {
                    strongSelf.historyState = strongSelf.historyState.withClearReplies()
                }
                strongSelf.scrollup()
            }
        }
        
        chatInteraction.forwardMessages = { [weak self] forwardMessages in
            if let strongSelf = self, let navigation = strongSelf.navigationController {
                
                strongSelf.loadFwdMessagesDisposable.set((strongSelf.account.postbox.messagesAtIds(forwardMessages) |> deliverOnMainQueue).start(next: { [weak strongSelf] messages in
                    if let strongSelf = strongSelf {
                        
                        let displayName:String = strongSelf.chatInteraction.peer?.compactDisplayTitle ?? "Unknown"
                        let action = FWDNavigationAction(messages: messages, displayName: displayName)
                        navigation.set(modalAction: action, strongSelf.account.context.layout != .single)
                        
                        if strongSelf.account.context.layout == .single {
                            navigation.push(ForwardChatListController(strongSelf.account))
                        }
                        
                        action.afterInvoke = { [weak strongSelf] in
                            strongSelf?.chatInteraction.update(animated: false, {$0.withoutSelectionState()})
                            strongSelf?.chatInteraction.saveState(scrollState: strongSelf?.immediateScrollState())
                        }
                        
                    }
                }))
            }
        }
        
        chatInteraction.deleteMessages = { [weak self] messageIds in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {
                let channelAdmin:Signal<[ChannelParticipant]?, Void> = peer.isSupergroup ? channelAdmins(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId)
                    |> mapError {_ in return} |> map { admins -> [ChannelParticipant]? in
                    return admins.map({$0.participant})
                } : .single(nil)
                
                
                self?.messagesActionDisposable.set(combineLatest(strongSelf.account.postbox.messagesAtIds(messageIds) |> deliverOnMainQueue, channelAdmin |> deliverOnMainQueue).start( next:{ [weak strongSelf] messages, admins in
                    if let strongSelf = strongSelf, let peer = strongSelf.chatInteraction.peer {
                        var canDelete:Bool = true
                        var canDeleteForEveryone = true
                        
                        for message in messages {
                            if !canDeleteMessage(message, account: strongSelf.account) {
                                canDelete = false
                            }
                            if !canDeleteForEveryoneMessage(message, account: strongSelf.account) {
                                canDeleteForEveryone = false
                            }
                        }
                        if messages.isEmpty {
                            strongSelf.chatInteraction.update({$0.withoutSelectionState()})
                            return
                        }
                        
                        if canDelete {
                            let isAdmin = admins?.filter({$0.peerId == messages[0].author?.id}).first != nil
                            if mustManageDeleteMessages(messages, for: peer, account: strongSelf.account), let memberId = messages[0].author?.id, !isAdmin {
                                showModal(with: DeleteSupergroupMessagesModalController(account: strongSelf.account, messageIds: messages.map {$0.id}, peerId: peer.id, memberId: memberId, onComplete: { [weak strongSelf] in
                                    strongSelf?.chatInteraction.update({$0.withoutSelectionState()})
                                }), for: mainWindow)
                            } else {
                                let thrid:String? = canDeleteForEveryone ? peer.isUser ? tr(L10n.chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle)) : tr(L10n.chatConfirmDeleteMessagesForEveryone) : nil
                           
                               
                              
                                if let window = self?.window {
                                    modernConfirm(for: window, account: strongSelf.account, peerId: nil, accessory: theme.icons.confirmDeleteMessagesAccessory, header: thrid == nil ? L10n.chatConfirmActionUndonable : L10n.chatConfirmDeleteMessages, information: thrid == nil ? L10n.chatConfirmDeleteMessages : nil, okTitle: tr(L10n.confirmDelete), thridTitle: thrid, successHandler: { [weak strongSelf] result in
                                        
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
                                                strongSelf.chatInteraction.update({$0.withoutEditMessage()})
                                            }
                                        }
                                        _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: messageIds, type: type).start()
                                        strongSelf.chatInteraction.update({$0.withoutSelectionState()})
                                    })
//                                    confirm(for: window, header: tr(L10n.chatConfirmActionUndonable), information: tr(L10n.chatConfirmDeleteMessages), okTitle: okTitle, thridTitle:thrid, swapColors: true, successHandler: { [weak strongSelf] result in
//                                        guard let strongSelf = strongSelf else {return}
//
//                                        let type:InteractiveMessagesDeletionType
//                                        switch result {
//                                        case .basic:
//                                            type = .forLocalPeer
//                                        case .thrid:
//                                            type = .forEveryone
//                                        }
//                                        _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: messageIds, type: type).start()
//                                        strongSelf.chatInteraction.update({$0.withoutSelectionState()})
//                                    })
                                }
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
                            strongSelf.chatInteraction.focusMessageId(nil, postId, TableScrollState.center(id: 0, innerId: nil, animated: true, focus: true, inset: 0))
                        }
                    } else {
                       strongSelf.navigationController?.push(ChatAdditionController(account: strongSelf.account, chatLocation: .peer(peerId), messageId: postId, initialAction: action))
                    }
                } else {
                    strongSelf.openPeerInfoDisposable.set((strongSelf.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak strongSelf] peer in
                        if let strongSelf = strongSelf {
                            strongSelf.navigationController?.push(PeerInfoController(account: strongSelf.account, peer: peer))
                        }
                    }))
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
                    self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: true, inset: 0), inset: NSEdgeInsets(), true)
                }
                
            }
        }
        
        chatInteraction.openFeedInfo = { [weak self] groupId in
            guard let `self` = self else {return}
            self.navigationController?.push(ChatListController(self.account, groupId: groupId))
        }
        
        chatInteraction.openProxySettings = { [weak self] in
            guard let `self` = self else {return}
            let f = proxyListController(postbox: self.account.postbox, network: self.account.network)
            f({ [weak self] controller in
                self?.navigationController?.push(controller)
            })
        }
        
        chatInteraction.inlineAudioPlayer = { [weak self] controller in
            if let navigation = self?.navigationController {
                if let header = navigation.header, let strongSelf = self {
                    header.show(true)
                    if let view = header.view as? InlineAudioPlayerView {
                        view.update(with: controller, tableView: strongSelf.genericView.tableView)
                    }
                }
            }
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
                if let message = outgoingMessageWithChatContextResult(results, result) {
                    _ = (Sender.enqueue(message: message.withUpdatedReplyToMessageId(strongSelf.chatInteraction.presentation.interfaceState.replyMessageId), account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    strongSelf.nextTransaction.set(handler: afterSentTransition)
                }
            }
            
        }
        
        chatInteraction.beginEditingMessage = { [weak self] (message) in
            if let message = message {
                self?.chatInteraction.update({$0.withEditMessage(message)})
            } else {
                self?.chatInteraction.update({$0.withoutEditMessage()})
            }
        }
        
        chatInteraction.mentionPressed = { [weak self] in
            if let strongSelf = self {
                let signal = earliestUnseenPersonalMentionMessage(postbox: strongSelf.account.postbox, network: strongSelf.account.network, peerId: strongSelf.chatInteraction.peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak strongSelf] result in
                    if let strongSelf = strongSelf {
                        switch result {
                        case .loading:
                            break
                        case .result(let messageId):
                            if let messageId = messageId {
                                strongSelf.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, innerId: nil, animated: true, focus: true, inset: 0))
                            }
                        }
                    }
                }))
            }
        }
        
        chatInteraction.requestMessageActionCallback = { [weak self] messageId, isGame, data in
            if let strongSelf = self {
                strongSelf.botCallbackAlertMessage.set(.single((L10n.chatInlineRequestLoading, false)))
                self?.messageActionCallbackDisposable.set((requestMessageActionCallback(account: strongSelf.account, messageId: messageId, isGame:isGame, data: data) |> deliverOnMainQueue).start(next: { [weak strongSelf] (result) in
                    
                    if let strongSelf = strongSelf {
                        switch result {
                        case .none:
                            break
                        case let .toast(text):
                            strongSelf.botCallbackAlertMessage.set(.single((text, false)))
                        case let .alert(text):
                            strongSelf.botCallbackAlertMessage.set(.single((text, true)))
                        case let .url(url):
                            if isGame {
                                strongSelf.navigationController?.push(WebGameViewController(strongSelf.account, strongSelf.chatInteraction.peerId, messageId, url))
                            } else {
                                execute(inapp: .external(link: url, !(strongSelf.chatInteraction.peer?.isVerified ?? false)))
                            }
                        }
                    }
                }))
            }
        }
        
        
        chatInteraction.focusMessageId = { [weak self] fromId, toId, state in
            
            if let strongSelf = self {
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
                    if let message = strongSelf.messageInCurrentHistoryView(toId) {
                        strongSelf.genericView.tableView.scroll(to: state.swap(to: ChatHistoryEntryId.message(message)))
                    } else {
                        let historyView = chatHistoryViewForLocation(.InitialSearch(location: .id(toId), count: 50), account: strongSelf.account, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                        
                        struct FindSearchMessage {
                            let message:Message?
                            let loaded:Bool
                        }
                        
                        let signal = historyView
                            |> mapToSignal { historyView -> Signal<Message?, NoError> in
                                switch historyView {
                                case .Loading:
                                    return .complete()
                                case let .HistoryView(view, _, _, _):
                                    for entry in view.entries {
                                        if case let .MessageEntry(message, _, _, _) = entry {
                                            if message.id == toId {
                                                return .single(message)
                                            }
                                        }
                                    }
                                    return .single(nil)
                                }
                            }
                            |> take(1)
                        strongSelf.chatInteraction.loadingMessage.set(true)
                        strongSelf.messageIndexDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak strongSelf] message in
                            if let strongSelf = strongSelf, let message = message {
                                let toIndex = MessageIndex(message)
                                strongSelf.chatInteraction.loadingMessage.set(false)
                                strongSelf.setLocation(.Scroll(index: MessageHistoryAnchorIndex.message(toIndex), anchorIndex: MessageHistoryAnchorIndex.message(toIndex), sourceIndex: MessageHistoryAnchorIndex.message(fromIndex), scrollPosition: state.swap(to: ChatHistoryEntryId.message(message)), count: strongSelf.requestCount, animated: state.animated))
                            }
                        }, completed: {
                                
                        }))
                    }
                }
                
            }
            
        }
        
        chatInteraction.sendMedia = { [weak self] media in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                let _ = (Sender.enqueue(media: media, account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                strongSelf.nextTransaction.set(handler: {})
            }
        }
        
        chatInteraction.sendAppFile = { [weak self] file in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                let _ = (Sender.enqueue(media: file, account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                strongSelf.nextTransaction.set(handler: {})
                
            }
        }
        
        chatInteraction.sendMedias = { [weak self] medias, caption, isCollage in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                let _ = (Sender.enqueue(media: medias, caption: caption, account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction, isCollage: isCollage) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                strongSelf.nextTransaction.set(handler: {})
                
            }
        }
        
        chatInteraction.shareSelfContact = { [weak self] replyId in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                strongSelf.shareContactDisposable.set((strongSelf.account.viewTracker.peerView(strongSelf.account.peerId) |> take(1)).start(next: { [weak strongSelf] peerView in
                    if let strongSelf = strongSelf, let peer = peerViewMainPeer(peerView) as? TelegramUser {
                        _ = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil), replyToMessageId: replyId, localGroupingKey: nil), account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId).start()
                    }
                }))
            }
        }
        
        chatInteraction.modalSearch = { [weak self] query in
            if let strongSelf = self {
                let apply = showModalProgress(signal: searchMessages(account: strongSelf.account, location: .peer(peerId: strongSelf.chatInteraction.peerId, fromId: nil, tags: nil), query: query), for: mainWindow)
                showModal(with: SearchResultModalController(strongSelf.account, request: apply, query: query, chatInteraction:strongSelf.chatInteraction), for: mainWindow)
            }
        }
        
        chatInteraction.sendCommand = { [weak self] command in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                var commandText = "/" + command.command.text
                if strongSelf.chatInteraction.peerId.namespace != Namespaces.Peer.CloudUser {
                    commandText += "@" + (command.peer.username ?? "")
                }
                strongSelf.chatInteraction.updateInput(with: "")
                let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, messages: [EnqueueMessage.message(text: commandText, attributes:[], media: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
            }
        }
        
        chatInteraction.switchInlinePeer = { [weak self] switchId, initialAction in
            if let strongSelf = self {
                strongSelf.navigationController?.push(ChatSwitchInlineController(account: strongSelf.account, peerId: switchId, fallbackId:strongSelf.chatInteraction.peerId, initialAction: initialAction))
            }
        }
        
        chatInteraction.setNavigationAction = { [weak self] action in
            self?.navigationController?.set(modalAction: action)
        }
        
        chatInteraction.showPreviewSender = { [weak self] urls, asMedia in
            if let chatInteraction = self?.chatInteraction, let window = self?.navigationController?.window, let account = self?.account {
                showModal(with: PreviewSenderController(urls: urls, account: account, chatInteraction: chatInteraction, asMedia: asMedia), for: window)
            }
        }
        
        chatInteraction.setSecretChatMessageAutoremoveTimeout = { [weak self] seconds in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage {
                _ = setSecretChatMessageAutoremoveTimeoutInteractively(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, timeout:seconds).start()
            }
        }
        
        chatInteraction.toggleNotifications = { [weak self] in
            if let strongSelf = self {
                _ = togglePeerMuted(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId).start()
            }
        }
        
        chatInteraction.removeAndCloseChat = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: removePeerChat(postbox: strongSelf.account.postbox, peerId: strongSelf.chatInteraction.peerId, reportChatSpam: false), for: window).start(next: { [weak strongSelf] in
                    strongSelf?.navigationController?.close()
                })
            }
        }
        
        chatInteraction.joinChannel = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: joinChannel(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId), for: window).start()
            }
        }
        
        chatInteraction.returnGroup = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: returnGroup(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId), for: window).start()
            }
        }
        
        
        
        chatInteraction.shareContact = { [weak self] peer in
            if let strongSelf = self, let main = strongSelf.chatInteraction.peer, main.canSendMessage {
                _ = Sender.shareContact(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, contact: peer).start()
            }
        }
        
        chatInteraction.unblock = { [weak self] in
            if let strongSelf = self {
                self?.unblockDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, isBlocked: false).start())
            }
        }
        
        chatInteraction.updatePinned = { [weak self] pinnedId, dismiss, silent in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer as? TelegramChannel {
                if peer.hasAdminRights(.canPinMessages) || (peer.isChannel && peer.hasAdminRights(.canEditMessages)) {
                    let pinnedUpdate: PinnedMessageUpdate = dismiss ? .clear : .pin(id: pinnedId, silent: silent)
                    
                    strongSelf.updatePinnedDisposable.set(((dismiss ? confirmSignal(for: mainWindow, information: tr(L10n.chatConfirmUnpin)) : Signal<Bool,Void>.single(true)) |> filter {$0} |> mapToSignal { _ in return  showModalProgress(signal: requestUpdatePinnedMessage(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId, update: pinnedUpdate) |> mapError {_ in}, for: mainWindow)}).start())
                } else {
                    strongSelf.chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedDismissedPinnedId(pinnedId)})})
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
                
                
                
                
                strongSelf.reportPeerDisposable.set((confirmSignal(for: mainWindow, header: appName, information: title, okTitle: L10n.modalOK, cancelTitle: L10n.modalCancel) |> filter {$0} |> mapToSignal { _ in
                    return reportPeer(account: strongSelf.account, peerId: strongSelf.chatInteraction.peerId) |> deliverOnMainQueue |> mapToSignal { [weak strongSelf] () -> Signal<Void, Void> in
                        if let strongSelf = strongSelf, let peer = strongSelf.chatInteraction.peer {
                            if peer.id.namespace == Namespaces.Peer.CloudUser {
                                return requestUpdatePeerIsBlocked(account: strongSelf.account, peerId: peer.id, isBlocked: true) |> deliverOnMainQueue |> mapToSignal { [weak strongSelf] () -> Signal<Void, Void> in
                                    if let strongSelf = strongSelf {
                                        return removePeerChat(postbox: strongSelf.account.postbox, peerId: strongSelf.chatInteraction.peerId, reportChatSpam: false)
                                    }
                                    return .complete()
                                }
                            } else {
                                return removePeerChat(postbox: strongSelf.account.postbox, peerId: strongSelf.chatInteraction.peerId, reportChatSpam: true)
                            }
                        }
                        return .complete()
                    } |> map { _ in return true} |> deliverOnMainQueue
                }).start(next: { [weak strongSelf] result in
                    if let strongSelf = strongSelf, result {
                        strongSelf.navigationController?.back()
                    }
                }))
            }
        }
        
        chatInteraction.dismissPeerReport = { [weak self] in
            if let strongSelf = self {
                _ = dismissReportPeer(account:strongSelf.account, peerId: strongSelf.chatInteraction.peerId).start()
            }
        }
        
        chatInteraction.toggleSidebar = { [weak self] in
            FastSettings.toggleSidebarShown(!FastSettings.sidebarShown)
            self?.updateSidebar()
            (self?.navigationController as? MajorNavigationController)?.genericView.update()
        }
        
        chatInteraction.focusInputField = { [weak self] in
            self?.window?.makeFirstResponder(self?.firstResponder())
        }

        let initialData = initialDataHandler.get() |> take(1) |> beforeNext { [weak self] (combinedInitialData) in
            
            if let strongSelf = self {
                if let initialData = combinedInitialData.initialData {
                    if let interfaceState = initialData.chatInterfaceState as? ChatInterfaceState {
                        strongSelf.chatInteraction.update(animated:false,{$0.updatedInterfaceState({_ in return interfaceState})})
                        strongSelf.chatInteraction.invokeInitialAction(includeAuto: true)
                    }
                    
                    if let modalAction = strongSelf.navigationController?.modalAction {
                        strongSelf.invokeNavigation(action: modalAction)
                    }
                    
                    strongSelf.state = strongSelf.chatInteraction.presentation.state == .selecting ? .Edit : .Normal
                    strongSelf.notify(with: strongSelf.chatInteraction.presentation, oldValue: ChatPresentationInterfaceState(strongSelf.chatInteraction.chatLocation), animated: false, force: true)
                    
                    strongSelf.genericView.inputView.updateInterface(with: strongSelf.chatInteraction, account: strongSelf.account)
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
                    self.chatInteraction.update(animated: !first.swap(false), { [weak peerView] presentation in
                        if let peerView = peerView {
                            var present = presentation.updatedPeer { [weak peerView] _ in
                                if let peerView = peerView {
                                    return peerView.peers[peerView.peerId]
                                }
                                return nil
                            }
                            
                            if let cachedData = peerView.cachedData as? CachedUserData {
                                present = present.withUpdatedBlocked(cachedData.isBlocked).withUpdatedReportStatus(cachedData.reportStatus)
                            } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                present = present.withUpdatedReportStatus(cachedData.reportStatus).withUpdatedPinnedMessageId(cachedData.pinnedMessageId)
                            } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                present = present.withUpdatedReportStatus(cachedData.reportStatus)
                            } else if let cachedData = peerView.cachedData as? CachedSecretChatData {
                                present = present.withUpdatedReportStatus(cachedData.reportStatus)
                            }
                            
                            var canAddContact:Bool? = nil
                            if let peer = peerViewMainPeer(peerView) as? TelegramUser {
                                if let _ = peer.phone, !peerView.peerIsContact {
                                    canAddContact = true
                                }
                            }
                            present = present.withUpdatedContactAdding(canAddContact)
                            
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                present = present.updatedNotificationSettings(notificationSettings)
                            }
                            return present
                        }
                        return presentation
                    })
                case .group:
                    break
                }
                
                
            }).start())
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.CloudChannel {
            let fetchParticipants = peerView.get() |> filter { view in
                
               return (view as? PeerView)?.cachedData != nil
                
            } |> take(1) |> deliverOnMainQueue |> mapToSignal { [weak self] _ -> Signal<Void, Void> in
                if let account = self?.account, let peerId = self?.chatInteraction.peerId {
                    return account.viewTracker.updatedCachedChannelParticipants(peerId, forceImmediateUpdate: true)
                }
                return .complete()
                
            }
            
            updatedChannelParticipants.set(fetchParticipants.start())
        }
        
        
        
        
        let connectionStatus = account.network.connectionStatus |> delay(0.5, queue: Queue.mainQueue()) |> deliverOnMainQueue |> beforeNext { [weak self] status -> Void in
            
            (self?.centerBarView as? ChatTitleBarView)?.connectionStatus = status
        }
        
        let combine = combineLatest(_historyReady.get() |> deliverOnMainQueue , peerView.get() |> deliverOnMainQueue |> take(1) |> map {_ in} |> then(initialData), genericView.inputView.ready.get())
        
        self.ready.set(combine |> map { (hReady, _, iReady) in
            return hReady && iReady
        })
        
        
        connectionStatusDisposable.set((connectionStatus).start())
        
        
        var beginPendingTime:CFAbsoluteTime?
        
        
        switch chatLocation {
        case let .peer(peerId):
            self.sentMessageEventsDisposable.set((self.account.pendingMessageManager.deliveredMessageEvents(peerId: peerId)).start(next: { _ in
                
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
                   
                    if let strongSelf = self, let message = message, !message.isEmpty {
                        if isAlert {
                            alert(for: mainWindow, info: message)
                        } else {
                            strongSelf.show(toaster: ControllerToaster(text:.initialize(string: message.fixed, color: theme.colors.text, font: .normal(.text))))
                        }
                    }
                    
                })
            
            
            self.chatUnreadMentionCountDisposable.set((account.viewTracker.unseenPersonalMessagesCount(peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] count in
                self?.genericView.updateMentionsCount(count, animated: true)
            }))
            
            let postbox = self.account.postbox
            let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
            self.peerInputActivitiesDisposable.set((self.account.peerInputActivities(peerId: peerId)
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
                        return postbox.transaction { transaction -> [(Peer, PeerInputActivity)] in
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
                    if let strongSelf = self, strongSelf.chatInteraction.peerId != strongSelf.account.peerId {
                        (strongSelf.centerBarView as? ChatTitleBarView)?.inputActivities = (strongSelf.chatInteraction.peerId, activities)
                    }
                }))
            
        default:
            break
        }
        
        
       
        
        
        var currentLocation:MessageIndex? = nil
        
        
       // var beginHistoryTime:CFAbsoluteTime?

        genericView.tableView.setScrollHandler({ [weak self] scroll in
            if let strongSelf = self {
                
//                if let beginHistoryTime = beginHistoryTime {
//                    if CFAbsoluteTimeGetCurrent() - beginHistoryTime < 0.3 {
//                        return
//                    }
//                }
//                beginHistoryTime = CFAbsoluteTimeGetCurrent()

                let view = strongSelf.previousView.modify({$0})
                if let view = view {
                    var messageIndex:MessageIndex?
                    
                    if let entry = view.originalView.entries.last, case .HoleEntry = entry  {
                        return
                    } else if let entry = view.originalView.entries.first, case .HoleEntry = entry {
                        return
                    }
                    
                    switch scroll.direction {
                    case .bottom:
                        messageIndex = view.originalView.earlierId
                    case .top:
                        messageIndex = view.originalView.laterId
                       
                    case .none:
                        break
                    }
                    if let messageIndex = messageIndex {
                        strongSelf.setLocation(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: strongSelf.requestCount))
                    }
                    currentLocation = messageIndex
                }
            }
            
        })
        
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] _ in
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
                
                tableView.enumerateVisibleItems(with: { item in
                    if let item = item as? ChatRowItem {
                        if message == nil {
                            message = item.message
                        }
                        if let message = item.message {
                            var hasUncocumedMention: Bool = false
                            var hasUncosumedContent: Bool = false
                            
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
                        }
                        
                        
                    }
                    return true
                })
                
                
              
                
                if !messageIdsWithViewCount.isEmpty {
                    strongSelf.messageProcessingManager.add(messageIdsWithViewCount)
                }
                
                if !messageIdsWithUnseenPersonalMention.isEmpty {
                    strongSelf.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention)
                }
                
                if let message = message {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(MessageIndex(message))
                }
                
               
            }
        })
        
    }
    
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        return genericView.navigationHeaderDidNoticeAnimation(current, previous, animated)
    }
    
    
    override func windowDidBecomeKey() {
        super.windowDidBecomeKey()
        updateInteractiveReading()
        chatInteraction.saveState(scrollState: immediateScrollState())
    }
    override func windowDidResignKey() {
        super.windowDidResignKey()
        updateInteractiveReading()
        chatInteraction.saveState(scrollState:immediateScrollState())
    }
    
    private func anchorMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.previousView.modify({$0}) {
            let visibleRange = self.genericView.tableView.visibleRows()
            var index = 0
            for entry in historyView.filteredEntries.reversed() {
                if index >= visibleRange.min && index <= visibleRange.max {
                    if case let .MessageEntry(message, _, _, _, _, _) = entry.entry {
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
        
        if let window = window, window.isKeyWindow, self.historyState.isDownOfHistory && scroll.rect.minY == genericView.tableView.frame.height {
            self.interactiveReadingDisposable.set(installInteractiveReadMessagesAction(postbox: self.account.postbox, stateManager: account.stateManager, peerId: chatInteraction.peerId))
        } else {
            self.interactiveReadingDisposable.set(nil)
        }
    }
    
    
    
    private func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.previousView.modify({$0}) {
            for entry in historyView.filteredEntries {
                if let message = entry.appearance.entry.message, message.id == id {
                    return message
                }
            }
        }
        return nil
    }
    
    private var previousWallpaper:TelegramWallpaper? = nil
    
    
    fileprivate func applyWallpaper(_ wallpaper: TelegramWallpaper)  {
        if previousWallpaper != wallpaper || wallpaper == .none {
            previousWallpaper = wallpaper
            
            switch wallpaper {
            case .builtin:
                genericView.backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
            case let.color(color):
                genericView.backgroundMode = .color(color: NSColor(UInt32(abs(color))))
            case let .image(representation):
                if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource))) {
                    genericView.backgroundMode = .background(image: image)
                } else {
                    genericView.backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                }
            case let .custom(path):
                if  let image = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                    genericView.backgroundMode = .background(image: image)
                } else {
                    genericView.backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                }
            case .none:
                genericView.backgroundMode = .plain
            }
            
        }
    }
    
    func applyTransition(_ transition:TableUpdateTransition, initialData:ChatHistoryCombinedInitialData, wallpaper: TelegramWallpaper) {
        
      //  NSLog("\(transition.state)")
        applyWallpaper(wallpaper)
        let wasEmpty = genericView.tableView.isEmpty
        
        let view = previousView.modify({$0})!
      //  NSLog("1")
        let _ = nextTransaction.execute()
       // NSLog("2")
        initialDataHandler.set(.single(initialData))
      
        
        genericView.tableView.merge(with: transition)
        //NSLog("\(transition.description), afterCount: \(genericView.tableView.count)")

       // NSLog("4")
        genericView.tableView.notifyScrollHandlers()
       // NSLog("5")
        genericView.change(state: .visible, animated: true)
      //  NSLog("6")
        historyState = historyState.withUpdatedStateOfHistory(view.originalView.laterId == nil)
      //  NSLog("7")
        
        if !view.originalView.entries.isEmpty {
            
           let tableView = genericView.tableView
            if !tableView.isEmpty {
                
                var earliest:Message?
                var latest:Message?
                self.genericView.tableView.enumerateVisibleItems(reversed: true, with: { item -> Bool in
                    
                    if let item = item as? ChatRowItem {
                        earliest = item.message
                    }
                    return earliest == nil
                })
                
                self.genericView.tableView.enumerateVisibleItems { item -> Bool in
                    
                    if let item = item as? ChatRowItem {
                        latest = item.message
                    }
                    return latest == nil
                }

                if let earliest = earliest, let latest = latest  {
                    account.postbox.updateMessageHistoryViewVisibleRange(view.originalView.id, earliestVisibleIndex: MessageIndex(earliest), latestVisibleIndex: MessageIndex(latest))
                } 
            }
            
        } else if let peer = chatInteraction.peer, peer.isBot {
            if chatInteraction.presentation.initialAction == nil && self.genericView.state == .visible {
                chatInteraction.update(animated: false, {$0.updatedInitialAction(ChatInitialAction.start(parameter: "", behavior: .none))})
            }
        }
       // NSLog("8")
        chatInteraction.update(animated: !wasEmpty, { current in
            var current = current.updatedHistoryCount(genericView.tableView.count - 1).updatedKeyboardButtonsMessage(initialData.buttonKeyboardMessage)
            
            if let message = initialData.buttonKeyboardMessage, let replyMarkup = message.replyMarkup {
                if replyMarkup.flags.contains(.setupReply) {
                    if message.id != current.interfaceState.dismissedForceReplyId {
                        current = current.updatedInterfaceState({$0.withUpdatedReplyMessageId(message.id)})
                    }
                }
            }
            
            return current
        })
        
      //  NSLog("9")
        if !didSetHistoryReady {
            didSetHistoryReady = true
            _historyReady.set(.single(true))
        }
        
        updateInteractiveReading()
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
        doneButton?.set(color: theme.colors.blueUI, for: .Normal)
        doneButton?.style = navigationButtonStyle
    }
    
    override func getRightBarViewOnce() -> BarView {
        let back = BarView(70, controller: self) //MajorBackNavigationBar(self, account: account, excludePeerId: peerId)
        
        let editButton = ImageButton()
        editButton.disableActions()
        back.addSubview(editButton)
        
        self.editButton = editButton
//        
        let doneButton = TitleButton()
        doneButton.disableActions()
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
            self?.showRightControls()
        }, for: .Click)
        requestUpdateRightBar()
        return back
    }

    private func showRightControls() {
        switch state {
        case .Normal:
            if let button = editButton {
                
                let account = self.account
                
                showRightControlsDisposable.set((peerView.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] view in
                    guard let `self` = self else {return}
                    var items:[SPopoverItem] = []

                    switch self.chatLocation {
                    case let .peer(peerId):
                        guard let peerView = view as? PeerView else {return}
                        
                        items.append(SPopoverItem(tr(L10n.chatContextInfo),  { [weak self] in
                            self?.chatInteraction.openInfo(peerId, false, nil, nil)
                        }, theme.icons.chatActionInfo))
                        
                        
                        
                        items.append(SPopoverItem(tr(L10n.chatContextEdit1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(L10n.chatContextEditHelp))" : ""),  { [weak self] in
                            self?.changeState()
                        }, theme.icons.chatActionEdit))
                        
                        if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, !self.isAdChat  {
                            if self.chatInteraction.peerId != account.peerId {
                                items.append(SPopoverItem(!notificationSettings.isMuted ? tr(L10n.chatContextEnableNotifications) : tr(L10n.chatContextDisableNotifications), { [weak self] in
                                    self?.chatInteraction.toggleNotifications()
                                    }, !notificationSettings.isMuted ? theme.icons.chatActionUnmute : theme.icons.chatActionMute))
                            }
                        }
                        
                        if let peer = peerViewMainPeer(peerView) {
                            if peer.isGroup || peer.isUser || (peer.isSupergroup && peer.addressName == nil) {
                                items.append(SPopoverItem(tr(L10n.chatContextClearHistory), {
                                    modernConfirm(for: mainWindow, account: self.account, peerId: peer.id, accessory: theme.icons.confirmDeleteChatAccessory, information: L10n.confirmDeleteChatUser, successHandler: { _ in
                                        _ = clearHistoryInteractively(postbox: account.postbox, peerId: peerId).start()
                                    })
                                }, theme.icons.chatActionClearHistory))
                            }
                        }
                    case let .group(groupId):
                        items.append(SPopoverItem(tr(L10n.chatContextFeedInfo),  { [weak self] in
                            self?.chatInteraction.openFeedInfo(groupId)
                        }, theme.icons.chatActionInfo))
                    }
                    showPopover(for: button, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(0, -65))
                }))
                
                
            }
        case .Edit:
            changeState()
        case .Some:
            break
        }
    }
    
    override func getLeftBarViewOnce() -> BarView {
        let back = BarView(20, controller: self) //MajorBackNavigationBar(self, account: account, excludePeerId: peerId)
        back.set(handler: { [weak self] _ in
            self?.navigationController?.back()
        }, for: .Click)
        return back
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        var result:KeyHandlerResult = self.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .rejected : .invokeNext
        if chatInteraction.presentation.state == .selecting {
            self.changeState()
            result = .invoked
        } else if chatInteraction.presentation.state == .editing {
            editMessageDisposable.set(nil)
            chatInteraction.update({$0.withoutEditMessage()})
            result = .invoked
        } else if case let .contextRequest(request) = chatInteraction.presentation.inputContext {
            if request.query.isEmpty {
                chatInteraction.clearInput()
            } else {
                chatInteraction.clearContextQuery()
            }
            result = .invoked
        } else if chatInteraction.presentation.isSearchMode {
            chatInteraction.update({$0.updatedSearchMode(false)})
            result = .invoked
        } else if chatInteraction.presentation.recordingState != nil {
            chatInteraction.update({$0.withoutRecordingState()})
            return .invoked
        }
        
        return result
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            if !selectManager.isEmpty {
                _ = selectManager.selectPrevChar()
                return .invoked
            }
        }
        
        return !self.chatInteraction.presentation.isSearchMode && self.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .rejected : .invokeNext
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
        
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            if !selectManager.isEmpty {
                _ = selectManager.selectNextChar()
                return .invoked
            }
        }
        
        if !self.chatInteraction.presentation.isSearchMode && chatInteraction.presentation.effectiveInput.inputText.isEmpty {
            chatInteraction.openInfo(chatInteraction.peerId, false, nil, nil)
            return .invoked
        }
        return .rejected
    }
    
    
    deinit {
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
        openPeerInfoDisposable.dispose()
        unblockDisposable.dispose()
        updatePinnedDisposable.dispose()
        reportPeerDisposable.dispose()
        focusMessageDisposable.dispose()
        updateFontSizeDisposable.dispose()
        account.context.addRecentlyUsedPeer(peerId: chatInteraction.peerId)
        loadFwdMessagesDisposable.dispose()
        chatUnreadMentionCountDisposable.dispose()
        navigationActionDisposable.dispose()
        messageIndexDisposable.dispose()
        dateDisposable.dispose()
        account.context.cachedAdminIds.remove(for: chatInteraction.peerId)
        interactiveReadingDisposable.dispose()
        showRightControlsDisposable.dispose()
    }
    
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        genericView.inputContextHelper.viewWillRemove()
        self.chatInteraction.remove(observer: self)
        chatInteraction.saveState(scrollState: immediateScrollState())
        
        window?.removeAllHandlers(for: self)
        
        if let window = window {
            selectTextController.removeHandlers(for: window)
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        editMessageDisposable.dispose()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let peer = chatInteraction.peer {
            if peer.isRestrictedChannel, let reason = peer.restrictionText {
                alert(for: mainWindow, info: reason, completion: { [weak self] in
                    self?.dismiss()
                })
            }
        }
        
        self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
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
        
        self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self, !hasModals() {
                let result:KeyHandlerResult = strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .invoked : .invokeNext
                
                if result == .invoked {
                    strongSelf.genericView.tableView.scrollDown()
                }
                
                return result
            }
            return .rejected
        }, with: self, for: .DownArrow, priority: .low)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                strongSelf.chatInteraction.update({$0.updatedSearchMode(!$0.isSearchMode)})
            }
            return .invoked
        }, with: self, for: .F, priority: .medium, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeBold()
            return .invoked
        }, with: self, for: .B, priority: .medium, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeUrl()
            return .invoked
        }, with: self, for: .U, priority: .medium, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeItalic()
            return .invoked
        }, with: self, for: .I, priority: .medium, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.chatInteraction.startRecording(true)
            return .invoked
        }, with: self, for: .R, priority: .medium, modifierFlags: [.command])
        
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.inputView.makeMonospace()
            return .invoked
        }, with: self, for: .K, priority: .medium, modifierFlags: [.command, .shift])
        
        if !(window?.firstResponder is NSTextView) {
            self.genericView.inputView.makeFirstResponder()
        }

        if let window = window {
            selectTextController.initializeHandlers(for: window, chatInteraction:chatInteraction)
        }
        
        window?.makeFirstResponder(genericView.inputView.textView.inputView)
        
    }
    
    func findAndSetEditableMessage() -> Bool {
        let view = self.previousView.modify({$0})
        if let view = view?.originalView, view.laterId == nil {
            for entry in view.entries.reversed() {
                if case let .MessageEntry(message,_,_,_) = entry {
                    if canEditMessage(message, account:account) {
                        chatInteraction.beginEditingMessage(message)
                        return true
                    }
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
        globalPeerHandler.set(.single(chatLocation))
        chatInteraction.update(animated: false, {$0.withToggledSidebarEnabled(FastSettings.sidebarEnabled).withToggledSidebarShown(FastSettings.sidebarShown)})
        account.context.entertainment.update(with: chatInteraction)
        self.chatInteraction.add(observer: self)
    }
    
    private func updateMaxVisibleReadIncomingMessageIndex(_ index: MessageIndex) {
        self.maxVisibleIncomingMessageIndex.set(index)
    }
    
    
    override func invokeNavigation(action:NavigationModalAction) {
        super.invokeNavigation(action: action)
        chatInteraction.applyAction(action: action)
    }
    
    private let isAdChat: Bool
    
    public init(account:Account, chatLocation:ChatLocation, messageId:MessageId? = nil, initialAction:ChatInitialAction? = nil) {
        self.chatLocation = chatLocation
        self.chatInteraction = ChatInteraction(chatLocation: chatLocation, account:account)
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
        super.init(account)
        
        
        self.chatInteraction.update(animated: false, {$0.updatedInitialAction(initialAction)})
        account.context.checkFirstRecentlyForDuplicate(peerId: chatInteraction.peerId)
        
        self.messageProcessingManager.process = { [weak account] messageIds in
            account?.viewTracker.updateViewCountForMessageIds(messageIds: messageIds)
        }
        
        self.messageMentionProcessingManager.process = { [weak account] messageIds in
            account?.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
        }
        
        
        self.location.set(peerView.get() |> take(1) |> deliverOnMainQueue |> map { [weak self] view -> ChatHistoryLocation in
            
            if let strongSelf = self {
                let count = Int(round(strongSelf.view.frame.height / 28)) + 30
                let location:ChatHistoryLocation
                if let messageId = messageId {
                    location = .InitialSearch(location: .id(messageId), count: count)
                } else {
                    location = .Initial(count: count)
                }
                
                return location
            }
            return .Initial(count: 30)
        })

    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        notify(with: value, oldValue: oldValue, animated: animated, force: false)
    }
    
    private var isPausedGlobalPlayer: Bool = false
    
    func notify(with value: Any, oldValue: Any, animated:Bool, force:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            
            if oldValue.recordingState == nil && value.recordingState != nil {
                if let pause = globalAudio?.pause() {
                    isPausedGlobalPlayer = pause
                }
            } else if value.recordingState == nil && oldValue.recordingState != nil {
                if isPausedGlobalPlayer {
                    _ = globalAudio?.play()
                }
            }
            
            if value.inputQueryResult != oldValue.inputQueryResult {
                genericView.inputContextHelper.context(with: value.inputQueryResult, for: genericView, relativeView: genericView.inputView, animated: animated)
            }
            if value.interfaceState.inputState != oldValue.interfaceState.inputState {
                chatInteraction.saveState(false, scrollState: immediateScrollState())
            }
            
            if value.selectionState != oldValue.selectionState {
                doneButton?.isHidden = value.selectionState == nil
                editButton?.isHidden = value.selectionState != nil
            }
            
            if value.effectiveInput != oldValue.effectiveInput || force {
                if let (updatedContextQueryState, updatedContextQuerySignal) = contextQueryResultStateForChatInterfacePresentationState(chatInteraction.presentation, account: self.account, currentQuery: self.contextQueryState?.0) {
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
                    

                    if let (updatedUrlPreviewUrl, updatedUrlPreviewSignal) = urlPreviewStateForChatInterfacePresentationState(chatInteraction.presentation, account: self.account, currentQuery: self.urlPreviewQueryState?.0) {
                        self.urlPreviewQueryState?.1.dispose()
                        var inScope = true
                        var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
                        self.urlPreviewQueryState = (updatedUrlPreviewUrl, (updatedUrlPreviewSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                            if let strongSelf = self {
                                if Thread.isMainThread && inScope {
                                    inScope = false
                                    inScopeResult = result
                                } else {
                                    strongSelf.chatInteraction.update(animated: animated, {
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
                            chatInteraction.update(animated: animated, {
                                if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = inScopeResult($0.urlPreview?.1) {
                                    return $0.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                                } else {
                                    return $0.updatedUrlPreview(nil)
                                }
                            })
                        }
                    }
                }
            }
            
            if value.isSearchMode != oldValue.isSearchMode || value.pinnedMessageId != oldValue.pinnedMessageId || value.reportStatus != oldValue.reportStatus || value.interfaceState.dismissedPinnedMessageId != oldValue.interfaceState.dismissedPinnedMessageId || value.canAddContact != oldValue.canAddContact || value.initialAction != oldValue.initialAction {
                genericView.updateHeader(value, animated)
            }
            

            self.state = value.selectionState != nil ? .Edit : .Normal
            
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
    
    
    
    public override func draggingItems(for pasteboard:NSPasteboard) -> [DragItem] {
        
        if hasModals() {
            return []
        }
        
        if let types = pasteboard.types, types.contains(.kFilenames) {
            let list = pasteboard.propertyList(forType: .kFilenames) as? [String]
            
            if let list = list, list.count > 0, let peer = chatInteraction.peer, peer.canSendMessage {
                
                if peer.mediaRestricted {
                    return []
                }
                
                var items:[DragItem] = []
                
                let list = list.filter { path -> Bool in
                    if let size = fs(path) {
                        return size <= 1500000000
                    }

                    return false
                }
                
                if !list.isEmpty {
                    let asMediaItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropQuickDesc), handler:{ [weak self] in
                        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                        if shift {
                            self?.chatInteraction.sendMedia(list.map{MediaSenderContainer(path: $0, caption: "", isFile: false)})
                        } else {
                            self?.chatInteraction.showPreviewSender(list.map { URL(fileURLWithPath: $0) }, true)
                        }
                    })
                    
                    let asFileItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropAsFilesDesc), handler:{ [weak self] in
                        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                        if shift {
                            self?.chatInteraction.sendMedia(list.map{MediaSenderContainer(path: $0, caption: "", isFile: true)})
                        } else {
                            self?.chatInteraction.showPreviewSender(list.map { URL(fileURLWithPath: $0) }, false)
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
                
                var items:[DragItem] = []

                let asMediaItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropQuickDesc), handler:{ [weak self] in
                    _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak self] path in
                        self?.chatInteraction.sendMedia([MediaSenderContainer(path:path, isFile:false)])
                    })

                })
                
                let asFileItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropAsFilesDesc), handler:{ [weak self] in
                    _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak self] path in
                        self?.chatInteraction.sendMedia([MediaSenderContainer(path:path, isFile: true)])
                    })
                })
                
                items.append(asFileItem)
                items.append(asMediaItem)
                
                return items
            }
        }
        
        return []
    }

    override open func backSettings() -> (String,CGImage?) {
        if account.context.layout == .single {
            return super.backSettings()
        }
        return (tr(L10n.navigationClose),nil)
    }

    override public func update(with state:ViewControllerState) -> Void {
        super.update(with:state)
        chatInteraction.update({state == .Normal ? $0.withoutSelectionState() : $0.withSelectionState()})
    }
    
    override func initializer() -> ChatControllerView {
        return ChatControllerView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - self.bar.height), chatInteraction:chatInteraction, account:account);
    }
    
    override func requestUpdateCenterBar() {
       
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.centerBarView.updateLocalizationAndTheme()
        (centerBarView as? ChatTitleBarView)?.updateStatus()
    }
    
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        
    }
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        return false
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return false
    }
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        if let view = previousView.modify({$0}), let stableId = stableId.base as? ChatHistoryEntryId {
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
