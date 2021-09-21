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

import Postbox
import SwiftSignalKit

private var nextClientId: Int32 = 1


enum ReplyThreadMode : Equatable {
    case replies(origin: MessageId)
    case comments(origin: MessageId)
    
    var originId: MessageId {
        switch self {
        case let .replies(id), let .comments(id):
            return id
        }
    }
}
enum ChatMode : Equatable {
    case history
    case scheduled
    case pinned
    case preview
    case replyThread(data: ChatReplyThreadMessage, mode: ReplyThreadMode)
    var threadId: MessageId? {
        switch self {
        case let .replyThread(data, _):
            return data.messageId
        default:
            return nil
        }
    }
    
    var threadId64: Int64? {
        if let threadId = threadId {
            return makeMessageThreadId(threadId)
        } else {
            return nil
        }
    }
    
    var activityCategory: PeerActivitySpace.Category {
        let activityCategory: PeerActivitySpace.Category
        if let threadId = threadId64 {
            activityCategory = .thread(threadId)
        } else {
            activityCategory = .global
        }
        return activityCategory
    }
    
    var tagMask: MessageTags? {
        switch self {
        case .pinned:
            return .pinned
        default:
            return nil
        }
    }
    
    var isThreadMode: Bool {
        switch self {
        case .replyThread:
            return true
        default:
            return false
        }
    }
    
    var originId: MessageId? {
        switch self {
        case let .replyThread(_, mode):
            return mode.originId
        default:
            return nil
        }
    }
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
    let theme: TelegramPresentationTheme
    init(originalView:MessageHistoryView?, filteredEntries: [ChatWrapperEntry], theme: TelegramPresentationTheme) {
        self.originalView = originalView
        self.filteredEntries = filteredEntries
        self.theme = theme
    }
    
    deinit {
        
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
    
    
    var scroll: ScrollPosition {
        return self.tableView.scrollPosition().current
    }
    
    private var backgroundView: BackgroundView?
    private weak var navigationView: NSView?
    
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
    
    private var themeSelectorView: NSView?
    
    private let floatingPhotosView: View = View()
    
    private let gradientMaskView = BackgroundGradientView(frame: NSZeroRect)
    
    var headerState: ChatHeaderState {
        return header.state
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    func updateBackground(_ mode: TableBackgroundMode, navigationView: NSView?) {
        if mode != theme.controllerBackgroundMode {
            if backgroundView == nil, let navigationView = navigationView {
                let point = NSMakePoint(0, -frame.minY)
                backgroundView = BackgroundView(frame: CGRect.init(origin: point, size: navigationView.bounds.size))
                backgroundView?.useSharedAnimationPhase = false
                addSubview(backgroundView!, positioned: .below, relativeTo: self.subviews.first)
            }
            backgroundView?.backgroundMode = mode
            self.navigationView = navigationView
        } else {
            backgroundView?.removeFromSuperview()
            backgroundView = nil
        }
    }
    
    func doBackgroundAction() -> Bool {
        backgroundView?.doAction()
        return backgroundView != nil
    }
    
    
    
    func findItem(by messageId: MessageId) -> TableRowItem? {
        var found: TableRowItem? = nil
        self.tableView.enumerateVisibleItems(with: { item in
            if let item = item as? ChatRowItem, item.message?.id == messageId {
                found = item
                return false
            } else {
                return true
            }
        })
        return found
    }
    
    required init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        header = ChatHeaderController(chatInteraction)
        
        
        scroller = ChatNavigateScroller(chatInteraction.context, contextHolder: chatInteraction.contextHolder(), chatLocation: chatInteraction.chatLocation, mode: chatInteraction.mode)
        inputContextHelper = InputContextHelper(chatInteraction: chatInteraction)
        tableView = TableView(frame:NSMakeRect(0,0,frameRect.width,frameRect.height - 50), isFlipped:false)
        inputView = ChatInputView(frame: NSMakeRect(0,tableView.frame.maxY, frameRect.width,50), chatInteraction: chatInteraction)
        //inputView.autoresizingMask = [.width]
        super.init(frame: frameRect)
        
//        self.layer = CAGradientLayer()
//        self.layer?.disableActions()
        
        addSubview(tableView)
        addSubview(floatingPhotosView)
        
        floatingPhotosView.flip = false
        floatingPhotosView.isEventLess = true
//        floatingPhotosView.backgroundColor = .random
        
        addSubview(inputView)
        inputView.delegate = self
        self.autoresizesSubviews = false
        tableView.autoresizingMask = []
        scroller.set(handler:{ control in
            chatInteraction.scrollToLatest(false)
        }, for: .Click)
        scroller.forceHide()
        addSubview(scroller)
        
        let context = chatInteraction.context
        

        searchInteractions = ChatSearchInteractions(jump: { message in
            chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
        }, results: { query in
            chatInteraction.modalSearch(query)
        }, calendarAction: { date in
            chatInteraction.jumpToDate(date)
        }, cancel: {
            chatInteraction.update({$0.updatedSearchMode((false, nil, nil))})
        }, searchRequest: { [weak chatInteraction] query, fromId, state in
            guard let chatInteraction = chatInteraction else {
                return .never()
            }
            let location: SearchMessagesLocation
            switch chatInteraction.chatLocation {
            case let .peer(peerId):
                switch chatInteraction.mode {
                case .pinned:
                    location = .peer(peerId: peerId, fromId: fromId, tags: .pinned, topMsgId: chatInteraction.mode.threadId, minDate: nil, maxDate: nil)
                default:
                    location = .peer(peerId: peerId, fromId: fromId, tags: nil, topMsgId: chatInteraction.mode.threadId, minDate: nil, maxDate: nil)
                }
            case let .replyThread(data):
                location = .peer(peerId: data.messageId.peerId, fromId: fromId, tags: nil, topMsgId: data.messageId, minDate: nil, maxDate: nil)
            }
            return context.engine.messages.searchMessages(location: location, query: query, state: state) |> map {($0.0.messages.filter({ !($0.media.first is TelegramMediaAction) }), $0.1)}
        })
        
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            if let state = self?.historyState {
                self?.updateScroller(state)
            }
        }))
        
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
                    view.updateBackground(animated: false, item: view.item)
                }
            })
        }))
        
        tableView.onCAScroll = { [weak self] from, to in
            guard let strongSelf = self else {
                return
            }
            for view in strongSelf.floatingPhotosView.subviews {
                view.layer?.animatePosition(from: NSMakePoint(view.frame.minX, view.frame.minY - (from.minY - to.minY)), to: view.frame.origin, duration: 0.4, timingFunction: .spring)
            }
        }
    }
    
    func updateFloating(_ values:[ChatFloatingPhoto], animated: Bool, currentAnimationRows: [TableAnimationInterface.AnimateItem] = []) {
        CATransaction.begin()
        var added:[NSView] = []
        for value in values {
            if let view = value.photoView {
                view._change(pos: value.point, animated: animated && view.superview == floatingPhotosView, duration: 0.2, timingFunction: .easeOut)
                if view.superview != floatingPhotosView {
                    floatingPhotosView.addSubview(view)
                    if animated {
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .easeOut)
                        let moveAsNew = currentAnimationRows.first(where: {
                            $0.index == value.items.first?.index
                        })
                        if let moveAsNew = moveAsNew {
                            
                            view.layer?.animatePosition(from: value.point - (moveAsNew.to - moveAsNew.from), to: value.point, duration: 0.2, timingFunction: .easeOut)
                        }
                    }
                }
                added.append(view)
            }
        }
        let toRemove = floatingPhotosView.subviews.filter {
            !added.contains($0)
        }
        for view in toRemove {
            performSubviewRemoval(view, animated: animated, timingFunction: .easeOut)
        }
        CATransaction.commit()
    }
    
    
    func showChatThemeSelector(_ view: NSView, animated: Bool) {
        self.themeSelectorView?.removeFromSuperview()
        self.themeSelectorView = view
        addSubview(view)
        updateFrame(self.frame, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    func hideChatThemeSelector(animated: Bool) {
        if let view = self.themeSelectorView {
            self.themeSelectorView = nil
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
            self.updateFrame(self.frame, transition: transition)
            if animated {
                transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: 0, y: frame.maxY), size: view.frame.size), completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
            } else {
                view.removeFromSuperview()
            }
        }
    }
    
    func updateScroller(_ historyState:ChatHistoryState) {
        self.historyState = historyState
        let isHidden = (tableView.documentOffset.y < 80 && historyState.isDownOfHistory) || tableView.isEmpty

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
    
    
    private var previousHeight:CGFloat = 50
    func inputChanged(height: CGFloat, animated: Bool) {
        if previousHeight != height {
            let header:CGFloat = self.header.state.toleranceHeight
            
            let size = NSMakeSize(frame.width, frame.height - height - header)
            let resizeAnimated = animated && tableView.contentOffset.y < height
            //(previousHeight < height || tableView.contentOffset.y < height)
            
            tableView.change(size: size, animated: animated)
            
            floatingPhotosView.change(size: size, animated: animated)
            
            if tableView.contentOffset.y > height {
               // tableView.clipView.scroll(to: NSMakePoint(0, tableView.contentOffset.y - (previousHeight - height)))
            }
            
            inputView.change(pos: NSMakePoint(0, tableView.frame.maxY), animated: animated)
            if let view = inputContextHelper.accessoryView {
                view._change(pos: NSMakePoint(0, frame.height - inputView.frame.height - view.frame.height), animated: animated)
            }
            
            scroller.change(pos: NSMakePoint(frame.width - scroller.frame.width - 6, frame.height - height - scroller.frame.height - 6), animated: animated)
            
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
                    view.updateBackground(animated: animated, item: view.item)
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
                view.updateBackground(animated: false, item: view.item)
            }
        })
    }

    
    override func layout() {
        super.layout()
        updateFrame(frame, transition: .immediate)
    }
    
    func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
    
        if let view = inputContextHelper.accessoryView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, frame.height - inputView.frame.height - view.frame.height, frame.width, view.frame.height))
        }
        if let currentView = header.currentView {
            transition.updateFrame(view: currentView, frame: NSMakeRect(0, 0, frame.width, currentView.frame.height))
        }
        
        var tableHeight = frame.height - inputView.frame.height - header.state.toleranceHeight
        
        if let themeSelector = themeSelectorView {
            tableHeight -= themeSelector.frame.height
            tableHeight += inputView.frame.height
        }
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, header.state.toleranceHeight, frame.width, tableHeight))
        
        let inputY: CGFloat = themeSelectorView != nil ? frame.height : tableView.frame.maxY
        
        transition.updateFrame(view: inputView, frame: NSMakeRect(0, inputY, frame.width, inputView.frame.height))

        
        transition.updateFrame(view: gradientMaskView, frame: tableView.frame)
        
        if let progressView = progressView?.subviews.first {
            transition.updateFrame(view: progressView, frame: progressView.centerFrame())
        }
        if let progressView = progressView {
            transition.updateFrame(view: progressView, frame: progressView.centerFrame())
        }
        
        
        transition.updateFrame(view: scroller, frame: NSMakeRect(frame.width - scroller.frame.width - 6,  frame.height - inputView.frame.height - 6 - scroller.frame.height, scroller.frame.width, scroller.frame.height))
        
        
        if let mentions = mentions {
            transition.updateFrame(view: mentions, frame: NSMakeRect(frame.width - mentions.frame.width - 6, frame.height - inputView.frame.height - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height), mentions.frame.width, mentions.frame.height))
        }
        if let failed = failed {
            var offset = (scroller.controlIsHidden ? 0 : scroller.frame.height)
            if let mentions = mentions {
                offset += (mentions.frame.height + 6)
            }
            transition.updateFrame(view: failed, frame: NSMakeRect(frame.width - failed.frame.width - 6, frame.height - inputView.frame.height - failed.frame.height - 6 - offset, failed.frame.width, failed.frame.height))
        }
        transition.updateFrame(view: floatingPhotosView, frame: tableView.frame)

        if let backgroundView = backgroundView, let navigationView = navigationView {
            let size = NSMakeSize(navigationView.bounds.width, navigationView.bounds.height)
            transition.updateFrame(view: backgroundView, frame: NSMakeRect(0, -frame.minY, size.width, size.height))
        }
        
        tableView.enumerateVisibleViews(with: { view in
            if let view = view as? ChatRowView {
                view.updateBackground(animated: transition.isAnimated, item: view.item)
            }
        })
        
        if let themeSelectorView = self.themeSelectorView {
            transition.updateFrame(view: themeSelectorView, frame: NSMakeRect(0, frame.height - themeSelectorView.frame.height, frame.width, themeSelectorView.frame.height))
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
    
    func updateHeader(_ interfaceState:ChatPresentationInterfaceState, _ animated:Bool, _ animateOnlyHeader: Bool = false) {

    
        var voiceChat: ChatActiveGroupCallInfo?
        if interfaceState.groupCall?.data?.groupCall == nil {
            if let data = interfaceState.groupCall?.data, data.participantCount == 0 && interfaceState.groupCall?.activeCall.scheduleTimestamp == nil {
                voiceChat = nil
            } else {
                voiceChat = interfaceState.groupCall
            }
        } else {
            voiceChat = nil
        }

        var state:ChatHeaderState
        if interfaceState.reportMode != nil {
            state = .none(nil)
        } else if interfaceState.isSearchMode.0 {
            state = .search(voiceChat, searchInteractions, interfaceState.isSearchMode.1, interfaceState.isSearchMode.2)
        } else if let initialAction = interfaceState.initialAction, case let .ad(kind) = initialAction {
            state = .promo(voiceChat, kind)
        } else if let peerStatus = interfaceState.peerStatus, let settings = peerStatus.peerStatusSettings, !settings.flags.isEmpty {
            if peerStatus.canAddContact && settings.contains(.canAddContact) {
                state = .addContact(voiceChat, block: settings.contains(.canReport) || settings.contains(.canBlock), autoArchived: settings.contains(.autoArchived))
            } else if settings.contains(.canReport) {
                state = .report(voiceChat, autoArchived: settings.contains(.autoArchived))
            } else if settings.contains(.canShareContact) {
                state = .shareInfo(voiceChat)
            } else if let pinnedMessageId = interfaceState.pinnedMessageId, !interfaceState.interfaceState.dismissedPinnedMessageId.contains(pinnedMessageId.messageId), !interfaceState.hidePinnedMessage, interfaceState.chatMode != .pinned {
                if pinnedMessageId.message?.restrictedText(chatInteraction.context.contentSettings) == nil {
                    state = .pinned(voiceChat, pinnedMessageId, doNotChangeTable: interfaceState.chatMode.isThreadMode)
                } else {
                    state = .none(voiceChat)
                }
            } else {
                state = .none(voiceChat)
            }
        } else if let pinnedMessageId = interfaceState.pinnedMessageId, !interfaceState.interfaceState.dismissedPinnedMessageId.contains(pinnedMessageId.messageId), !interfaceState.hidePinnedMessage, interfaceState.chatMode != .pinned {
            if pinnedMessageId.message?.restrictedText(chatInteraction.context.contentSettings) == nil {
                state = .pinned(voiceChat, pinnedMessageId, doNotChangeTable: interfaceState.chatMode.isThreadMode)
            } else {
                state = .none(voiceChat)
            }
        } else if let canAdd = interfaceState.canAddContact, canAdd {
           state = .none(voiceChat)
        } else {
            state = .none(voiceChat)
        }
        

        header.updateState(state, animated: animated, for: self)
        
        tableView.updateStickInset(state.height - state.toleranceHeight, animated: animated)

        updateFrame(frame, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)

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
                        self?.chatInteraction.focusMessageId(nil, id, .CenterEmpty)
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
                    mentions.setFrameOrigin(NSMakePoint(frame.width - mentions.frame.width - 6, tableView.frame.maxY - mentions.frame.height - 6 - (scroller.controlIsHidden ? 0 : scroller.frame.height)))
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
        header.applySearchResponder()
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
        var offset:CGFloat = 0
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .unread(unreadIndex):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case .UnreadEntry = entry.appearance.entry {
                        if interaction.mode.isThreadMode {
                            offset = 44 - 6
                        } else {
                            offset - 6
                        }
                        scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: offset)
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
        } 
        
        
        func makeItem(_ entry: ChatWrapperEntry) -> TableRowItem {
            
            let presentation: TelegramPresentationTheme = entry.entry.additionalData.chatTheme ?? theme
            
            let item:TableRowItem = ChatRowItem.item(initialSize, from: entry.appearance.entry, interaction: interaction, downloadSettings: entry.automaticDownload, theme: presentation)
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
                        let x:Int = Int(ceil(abs(offset) / 28))
                        index = min(entries.count - 1, k + x)
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
                        if initialSize.height + offset < height {
                            success = true
                            break
                        }
                    }
                    
                    if !success {
                        for i in (index + 1) ..< entries.count {
                            let item = makeItem(entries[i])
                            height += item.height
                            firstInsertion.insert((0, item), at: 0)
                            if initialSize.height + offset < height {
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
                            if initialSize.height + offset < height {
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
                        
                        if  ((initialSize.height + offset) / 2) >= lowHeight && !lowSuccess {
                            let item = makeItem(entries[low])
                            lowHeight += item.height
                            firstInsertion.append((low, item))
                        }
                        
                        if ((initialSize.height + offset) / 2) >= highHeight && !highSuccess  {
                            let item = makeItem(entries[high])
                            highHeight += item.height
                            firstInsertion.append((high, item))
                        }
                        
                        if ((((initialSize.height + offset) / 2) <= lowHeight ) || low == entries.count - 1) {
                            lowSuccess = true
                        } else if !lowSuccess {
                            low += 1
                        }
                        
                        
                        if ((((initialSize.height + offset) / 2) <= highHeight) || high == 0) {
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

private struct ChatTopVisibleMessageRange: Equatable {
    var lowerBound: MessageId
    var upperBound: MessageId
    var isLast: Bool
}

private struct ChatDismissedPins : Equatable {
    let ids: [MessageId]
    let tempMaxId: MessageId?
}

class ChatController: EditableViewController<ChatControllerView>, Notifable, TableViewDelegate {
    
    private var chatLocation:ChatLocation
    private let peerView = Promise<PostboxView?>()
    
    private let emojiEffects: EmojiScreenEffect

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
    private let pollChannelDiscussionDisposable = MetaDisposable()
    private let peekDisposable = MetaDisposable()
    private let loadThreadDisposable = MetaDisposable()
    private let recordActivityDisposable = MetaDisposable()
    private let suggestionsDisposable = MetaDisposable()
    private let searchState: ValuePromise<SearchMessagesResultState> = ValuePromise(SearchMessagesResultState("", []), ignoreRepeated: true)
    
    private let pollAnswersLoading: ValuePromise<[MessageId : ChatPollStateData]> = ValuePromise([:], ignoreRepeated: true)
    private let pollAnswersLoadingValue: Atomic<[MessageId : ChatPollStateData]> = Atomic(value: [:])

    private let topVisibleMessageRange = ValuePromise<ChatTopVisibleMessageRange?>(nil, ignoreRepeated: true)
    private let dismissedPinnedIds = ValuePromise<ChatDismissedPins>(ChatDismissedPins(ids: [], tempMaxId: nil), ignoreRepeated: true)


    private var grouppedFloatingPhotos: [([ChatRowItem], NSView)] = []
    
    private let chatThemeValue: Promise<(String?, TelegramPresentationTheme)> = Promise()
    private let chatThemeTempValue: Promise<TelegramPresentationTheme?> = Promise(nil)

    private var pollAnswersLoadingSignal: Signal<[MessageId : ChatPollStateData], NoError> {
        return pollAnswersLoading.get()
    }
    private func updatePoll(_ f:([MessageId : ChatPollStateData])-> [MessageId : ChatPollStateData]) -> Void {
        pollAnswersLoading.set(pollAnswersLoadingValue.modify(f))
    }
    
    private let threadLoading: ValuePromise<MessageId?> = ValuePromise(nil, ignoreRepeated: true)
    private let threadLoadingValue: Atomic<MessageId?> = Atomic(value: nil)

    private var threadLoadingSignal: Signal<MessageId?, NoError> {
        return threadLoading.get()
    }
    private func updateThread(_ f:(MessageId?)-> MessageId?) -> Void {
        threadLoading.set(threadLoadingValue.modify(f))
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

    private let chatHistoryLocationPromise = ValuePromise<ChatHistoryLocationInput>()
    private var nextHistoryLocationId: Int32 = 1
    private func takeNextHistoryLocationId() -> Int32 {
        let id = self.nextHistoryLocationId
        self.nextHistoryLocationId += 5
        return id
    }

    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    private let readHistoryDisposable = MetaDisposable()
    
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>

    
    private let initialDataHandler:Promise<ChatHistoryCombinedInitialData> = Promise()

    let previousView = Atomic<ChatHistoryView?>(value: nil)
    
    
    private let botCallbackAlertMessage = Promise<(String?, Bool)>((nil, false))
    private var botCallbackAlertMessageDisposable: Disposable?
    
    private var selectTextController:ChatSelectText!
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?

    
    let layoutDisposable:MetaDisposable = MetaDisposable()
    
    private var afterNextTransaction:(()->Void)?
    
    private var currentAnimationRows:[TableAnimationInterface.AnimateItem] = []
    
    private let adMessages: AdMessagesHistoryContext?
   
    private var themeSelector: ChatThemeSelectorController? = nil
    
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
        chatInteraction.update({ $0.withUpdatedTempPinnedMaxId(nil) })
        if let reply = historyState.reply() {
            
            chatInteraction.focusMessageId(nil, reply, .CenterEmpty)
            historyState = historyState.withRemovingReplies(max: reply)
        } else {
            let laterId = previousView.with { $0?.originalView?.laterId }
            if laterId != nil {
                
                let history: ChatHistoryLocation = .Scroll(index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, sourceIndex: MessageHistoryAnchorIndex.upperBound, scrollPosition: .down(true), count: requestCount, animated: true)
                
                let historyView = chatHistoryViewForLocation(history, context: context, chatLocation: chatLocation, fixedCombinedReadStates: nil, tagMask: mode.tagMask, additionalData: [], chatLocationContextHolder: chatLocationContextHolder)

                let signal = historyView
                    |> mapToSignal { historyView -> Signal<Bool, NoError> in
                        switch historyView {
                        case .Loading:
                            return .single(true)
                        case let .HistoryView(view, _, _, _):
                            if !view.holeEarlier, view.laterId == nil, !view.isLoading {
                                return .single(false)
                            }
                            return .single(true)
                        }
                    } |> take(until: { index in
                        return SignalTakeAction(passthrough: !index, complete: !index)
                    })

                messageIndexDisposable.set(showModalProgress(signal: signal, for: context.window).start(next: { [weak self] _ in
                    self?.setLocation(history)
                }, completed: {

                }))
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
    
    private func updateFloatingPhotos(_ position: ScrollPosition, animated: Bool, currentAnimationRows: [TableAnimationInterface.AnimateItem] = []) {
        
        let offset = genericView.tableView.clipView.bounds.origin
        
        var floating: [ChatFloatingPhoto] = []
        for groupped in grouppedFloatingPhotos {
            let photoView = groupped.1
            
            let views = groupped.0.compactMap { $0.view as? ChatRowView }.filter { $0.visibleRect != .zero }
            
            guard !views.isEmpty else {
                continue
            }
            
            var point: NSPoint = .init(x: groupped.0[0].leftInset, y: 0)


            let ph: CGFloat = 36
            let gap: CGFloat = 10
            let inset: CGFloat = 3
            
            
            let lastMax = views[views.count - 1].frame.maxY - inset
            let firstMin = views[0].frame.minY + inset

            if offset.y >= lastMax - ph - gap {
                point.y = lastMax - offset.y - ph
            } else if offset.y + gap > firstMin {
                point.y = gap
            } else {
                point.y = firstMin - offset.y
            }
            
            let revealView = views.first(where: {
                $0.hasRevealState
            })
            
            if let revealView = revealView {
                
                let maxOffset = revealView.frame.maxY - offset.y
                let minOffset = revealView.frame.minY - offset.y

                let rect = NSMakeRect(0, minOffset, revealView.frame.width, maxOffset - minOffset)
                if NSPointInRect(point, rect) {
                    point.x += revealView.containerX
                } else if NSPointInRect(NSMakePoint(point.x, point.y + photoView.frame.height - 1), rect) {
                    point.x += revealView.containerX
                }

            }
            
            let value: ChatFloatingPhoto = .init(point: point, items: groupped.0, photoView: photoView)
            floating.append(value)
        }
        genericView.updateFloating(floating, animated: animated, currentAnimationRows: currentAnimationRows)
    }
    
    private func collectFloatingPhotos(animated: Bool, currentAnimationRows: [TableAnimationInterface.AnimateItem]) {
        guard let peer = self.chatInteraction.peer, let theme = self.previousView.with({ $0?.theme }) else {
            self.grouppedFloatingPhotos = []
            return
        }
        guard peer.isGroup || peer.isSupergroup || peer.id == context.peerId, theme.bubbled else {
            self.grouppedFloatingPhotos = []
            return
        }
        let cached:[MessageId : NSView] = grouppedFloatingPhotos.reduce([:], { current, value in
            var current = current
            let item = value.0[value.0.count - 1]
            let view = value.1
            current[item.message!.id] = view
            return current
        })
        
        var groupped:[[ChatRowItem]] = []
        var current:[ChatRowItem] = []
        self.genericView.tableView.enumerateItems { item in
            var skipOrFill = true
            if let item = item as? ChatRowItem {
                if item.canHasFloatingPhoto {
                    let prev = current.last
                    let sameAuthor = prev?.message?.author?.id == item.message?.author?.id
                    var canGroup = false
                    if sameAuthor {
                        if case .Short = item.itemType {
                            canGroup = true
                        }
                    }
                    if prev == nil || canGroup {
                        skipOrFill = false
                        current.append(item)
                    }
                }
            }
            if skipOrFill {
                if !current.isEmpty {
                    groupped.append(current)
                }
                current = []

                if let item = item as? ChatRowItem {
                    if item.canHasFloatingPhoto {
                        current.append(item)
                    }
                }
            }
            return true
        }
        if !current.isEmpty {
            groupped.append(current)
        }
        self.grouppedFloatingPhotos = groupped.compactMap { value in
            let item = value[value.count - 1]
            let view = cached[item.message!.id] ?? ChatRowView.makePhotoView(item)
            let control = view as? AvatarControl
            control?.removeAllHandlers()
            control?.set(handler: { [weak item] _ in
                item?.openInfo()
            }, for: .Click)
            if let control = control {
                return (value, control)
            } else {
                return nil
            }
        }
        
        self.updateFloatingPhotos(genericView.scroll, animated: animated, currentAnimationRows: currentAnimationRows)
    }

    

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        self.updateFloatingPhotos(genericView.scroll, animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.tableView.addScroll(listener: emojiEffects.scrollUpdater)
        
        
        self.genericView.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateFloatingPhotos(position, animated: false)
        }))
        
        
        let previousView = self.previousView
        let context = self.context
        let atomicSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        let nextTransaction = self.nextTransaction
        let chatLocation = self.chatLocation
        let mode = self.mode
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
            let _ = context.engine.peers.checkPeerChatServiceActions(peerId: peerId).start()
        case let .replyThread(data):
            self.peerView.set(context.account.viewTracker.peerView(data.messageId.peerId, updateData: true) |> map {Optional($0)})
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
        
        var chatLocationContextHolder = self.chatLocationContextHolder

        let historyViewUpdate1 = location.get() |> deliverOn(messagesViewQueue)
            |> mapToSignal { location -> Signal<(ChatHistoryViewUpdate, TableSavingSide?), NoError> in
                
                var additionalData: [AdditionalMessageHistoryViewData] = []
                additionalData.append(.cachedPeerData(peerId))
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
                switch chatLocation {
                case let .replyThread(data):
                    additionalData.append(.message(data.messageId))
                case .peer:
                    additionalData.append(.cachedPeerDataMessages(peerId))
                }
                
                return chatHistoryViewForLocation(location, context: context, chatLocation: chatLocation, fixedCombinedReadStates: { nil }, tagMask: mode.tagMask, mode: mode, additionalData: additionalData, chatLocationContextHolder: chatLocationContextHolder) |> beforeNext { viewUpdate in
                    switch viewUpdate {
                    case let .HistoryView(view, _, _, _):
                        if !didSetReadIndex {
                            if let index = view.maxReadIndex {
                                if let last = view.entries.last {
                                    if index.id >= last.index.id {
                                        maxReadIndex.set(nil)
                                    } else {
                                        maxReadIndex.set(index)
                                    }
                                } else {
                                    maxReadIndex.set(index)
                                }
                            } else {
                                maxReadIndex.set(view.maxReadIndex)
                            }
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

        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
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

        
        let customChannelDiscussionReadState: Signal<MessageId?, NoError>
        if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
            let cachedDataKey = PostboxViewKey.cachedPeerData(peerId: chatLocation.peerId)
            let peerKey = PostboxViewKey.basicPeer(peerId)
            customChannelDiscussionReadState = context.account.postbox.combinedView(keys: [cachedDataKey, peerKey])
                |> mapToSignal { views -> Signal<PeerId?, NoError> in
                    guard let view = views.views[cachedDataKey] as? CachedPeerDataView else {
                        return .single(nil)
                    }
                    guard let peer = (views.views[peerKey] as? BasicPeerView)?.peer as? TelegramChannel, case .broadcast = peer.info else {
                        return .single(nil)
                    }
                    guard let cachedData = view.cachedPeerData as? CachedChannelData else {
                        return .single(nil)
                    }
                    guard case let .known(value) = cachedData.linkedDiscussionPeerId else {
                        return .single(nil)
                    }
                    return .single(value)
                }
                |> distinctUntilChanged
                |> mapToSignal { discussionPeerId -> Signal<MessageId?, NoError> in
                    guard let discussionPeerId = discussionPeerId else {
                        return .single(nil)
                    }
                    let key = PostboxViewKey.combinedReadState(peerId: discussionPeerId)
                    return context.account.postbox.combinedView(keys: [key])
                        |> map { views -> MessageId? in
                            guard let view = views.views[key] as? CombinedReadStateView else {
                                return nil
                            }
                            guard let state = view.state else {
                                return nil
                            }
                            for (namespace, namespaceState) in state.states {
                                if namespace == Namespaces.Message.Cloud {
                                    switch namespaceState {
                                    case let .idBased(maxIncomingReadId, _, _, _, _):
                                        return MessageId(peerId: discussionPeerId, namespace: Namespaces.Message.Cloud, id: maxIncomingReadId)
                                    default:
                                        break
                                    }
                                }
                            }
                            return nil
                        }
                        |> distinctUntilChanged
            }
        } else {
            customChannelDiscussionReadState = .single(nil)
        }
        
        let customThreadOutgoingReadState: Signal<MessageId?, NoError>
        if case .replyThread = chatLocation {
            customThreadOutgoingReadState = context.chatLocationOutgoingReadState(for: chatLocation, contextHolder: chatLocationContextHolder)
        } else {
            customThreadOutgoingReadState = .single(nil)
        }

        let animatedRows:([TableAnimationInterface.AnimateItem])->Void = { [weak self] items in
            self?.currentAnimationRows = items
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
        
        
        let _searchState: Atomic<SearchMessagesResultState> = Atomic(value: SearchMessagesResultState("", []))
        
        let updatingMedia = context.account.pendingUpdateMessageManager.updatingMessageMedia
            |> map { value -> [MessageId: ChatUpdatingMessageMedia] in
                var result = value
                for id in value.keys {
                    if id.peerId != peerId {
                        result.removeValue(forKey: id)
                    }
                }
                return result
            }
            |> distinctUntilChanged
        
        let previousUpdatingMedia = Atomic<[MessageId: ChatUpdatingMessageMedia]?>(value: nil)
        
        
        let adMessages:Signal<[Message], NoError>
        if let ad = self.adMessages {
            adMessages = ad.state
        } else {
            adMessages = .single([])
        }
        
        let themeEmoticon: Signal<String?, NoError> = self.peerView.get() |> map {
            ($0 as? PeerView)?.cachedData
        } |> map { cachedData in
            var themeEmoticon: String? = nil
            if let cachedData = cachedData as? CachedUserData {
                themeEmoticon = cachedData.themeEmoticon
            } else if let cachedData = cachedData as? CachedGroupData {
                themeEmoticon = cachedData.themeEmoticon
            } else if let cachedData = cachedData as? CachedChannelData {
                themeEmoticon = cachedData.themeEmoticon
            }
            return themeEmoticon
        } |> distinctUntilChanged
        
        
        let chatTheme:Signal<(String?, TelegramPresentationTheme), NoError> = combineLatest(context.chatThemes, themeEmoticon, appearanceSignal) |> map { chatThemes, themeEmoticon, appearance in
            
            var theme: TelegramPresentationTheme = appearance.presentation
            if let themeEmoticon = themeEmoticon {
                let chatThemeData = chatThemes.first(where: { $0.0 == themeEmoticon})?.1
                theme = chatThemeData ?? appearance.presentation
            }
            return (themeEmoticon, theme)
        }
        
        self.chatThemeValue.set(chatTheme)
        
        
        let effectiveTheme = combineLatest(self.chatThemeValue.get() |> map { $0.1 }, chatThemeTempValue.get()) |> map {
            $1 ?? $0
        }
       
        let historyViewTransition = combineLatest(queue: messagesViewQueue,
                                                  historyViewUpdate,
                                                  appearanceSignal,
                                                  combineLatest(maxReadIndex.get() |> deliverOnMessagesViewQueue,
                                                                pollAnswersLoadingSignal, threadLoadingSignal),
                                                                searchState.get(),
                                                  animatedEmojiStickers,
                                                  customChannelDiscussionReadState,
                                                  customThreadOutgoingReadState,
                                                  updatingMedia,
                                                  adMessages,
                                                  effectiveTheme
) |> mapToQueue { update, appearance, readIndexAndOther, searchState, animatedEmojiStickers, customChannelDiscussionReadState, customThreadOutgoingReadState, updatingMedia, adMessages, chatTheme -> Signal<(TableUpdateTransition, MessageHistoryView?, ChatHistoryCombinedInitialData, Bool, ChatHistoryView), NoError> in
                        
            let maxReadIndex = readIndexAndOther.0
            let pollAnswersLoading = readIndexAndOther.1
            let threadLoading = readIndexAndOther.2

            let searchStateUpdated = _searchState.swap(searchState) != searchState
            
            let isLoading: Bool
            let view: MessageHistoryView?
            let initialData: ChatHistoryCombinedInitialData
            var updateType: ChatHistoryViewUpdateType
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
    
            if let updatedValue = previousUpdatingMedia.swap(updatingMedia), updatingMedia != updatedValue {
                updateType = .Generic(type: .Generic)
            }
            
            switch updateType {
            case let .Generic(type: type):
                switch type {
                case .FillHole:
                    Queue.mainQueue().async(applyHole)
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
            let animationInterface: TableAnimationInterface = TableAnimationInterface(nextTransaction.isExutable && view?.laterId == nil, true, animatedRows)
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
                    proccesedView = ChatHistoryView(originalView: view, filteredEntries: [], theme: chatTheme)
                } else {
                    let msgEntries = view.entries
                    let topMessages: [Message]?
                    var addTopThreadInset: CGFloat? = nil
                    switch chatInteraction.chatLocation {
                    case let .replyThread(data):
                        if view.earlierId == nil, !view.isLoading, !view.holeEarlier {
                            topMessages = initialData.cachedDataMessages?[data.messageId]
                        } else {
                            topMessages = nil
                            addTopThreadInset = 44
                        }
                    case .peer:
                        topMessages = nil
                    }
                    
                    var ads:[Message] = []
                    if !view.isLoading && view.laterId == nil {
                        ads = adMessages
                    }
                    
                    let entries = messageEntries(msgEntries, maxReadIndex: maxReadIndex, dayGrouping: true, renderType: chatTheme.bubbled ? .bubble : .list, includeBottom: true, timeDifference: timeDifference, ranks: ranks, pollAnswersLoading: pollAnswersLoading, threadLoading: threadLoading, groupingPhotos: true, autoplayMedia: initialData.autoplayMedia, searchState: searchState, animatedEmojiStickers: bigEmojiEnabled ? animatedEmojiStickers : [:], topFixedMessages: topMessages, customChannelDiscussionReadState: customChannelDiscussionReadState, customThreadOutgoingReadState: customThreadOutgoingReadState, addRepliesHeader: peerId == repliesPeerId && view.earlierId == nil, addTopThreadInset: addTopThreadInset, updatingMedia: updatingMedia, adMessages: ads, chatTheme: chatTheme).map({ChatWrapperEntry(appearance: AppearanceWrapperEntry(entry: $0, appearance: appearance), automaticDownload: initialData.autodownloadSettings)})
                    proccesedView = ChatHistoryView(originalView: view, filteredEntries: entries, theme: chatTheme)
                }
            } else {
                proccesedView = ChatHistoryView(originalView: nil, filteredEntries: [], theme: chatTheme)
            }
            

            return prepareEntries(from: previousView.swap(proccesedView), to: proccesedView, timeDifference: timeDifference, initialSize: atomicSize.modify({$0}), interaction: chatInteraction, animated: false, scrollPosition:scrollPosition, reason: updateType, animationInterface: animationInterface, side: update.1) |> map { transition in
                return (transition, view, initialData, isLoading, proccesedView)
            } |> runOn(prepareOnMainQueue ? Queue.mainQueue(): messagesViewQueue)
            
        } |> deliverOnMainQueue
        
        
        let appliedTransition = historyViewTransition |> map { [weak self] transition, view, initialData, isLoading, proccesedView in
            self?.applyTransition(transition, initialData: initialData, isLoading: isLoading, processedView: proccesedView)
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
                    if apply, let window = self.window {
                        let peerId = self.chatLocation.peerId
                        if !hasModals(window) {
                            UNUserNotifications.current?.clearNotifies(peerId, maxId: messageIndex.id)
                            
                        
                            context.applyMaxReadIndex(for: self.chatLocation, contextHolder: self.chatLocationContextHolder, messageIndex: messageIndex)
                        }
                    }
                }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        

        
        chatInteraction.setupReplyMessage = { [weak self] messageId in
            guard let `self` = self else { return }
            
            switch self.mode {
            case .scheduled, .pinned, .preview:
                return
            case .history:
                break
            case .replyThread:
                break
            }
            
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
                    chatInteraction.focusMessageId(nil, last, .CenterEmpty)
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
                                let state = ChatRecordingAudioState(context: chatInteraction.context, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                                state.start()
                                delay(0.1, closure: { [weak chatInteraction] in
                                    chatInteraction?.update({$0.withRecordingState(state)})
                                })
                            } else {
                                confirm(for: context.window, information: L10n.requestAccesErrorHaveNotAccessVoiceMessages, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
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
                                let state = ChatRecordingVideoState(context: chatInteraction.context, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                                showModal(with: VideoRecorderModalController(chatInteraction: chatInteraction, pipeline: state.pipeline), for: context.window)
                                chatInteraction.update({$0.withRecordingState(state)})
                            } else {
                                confirm(for: context.window, information: L10n.requestAccesErrorHaveNotAccessVideoMessages, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
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
                return presentation.updatedInputQueryResult {_ in
                    return nil
                }.updatedInterfaceState { current in
                
                    var value: ChatInterfaceState = current.withUpdatedReplyMessageId(nil).withUpdatedInputState(ChatTextInputState()).withUpdatedForwardMessageIds([]).withUpdatedComposeDisableUrlPreview(nil)
                
                
                    if let message = presentation.keyboardButtonsMessage, let replyMarkup = message.replyMarkup {
                        if replyMarkup.flags.contains(.setupReply) {
                            value = value.withUpdatedDismissedForceReplyId(message.id)
                        }
                    }
                    return value
                }.updatedUrlPreview(nil).updateBotMenu({ current in
                    var current = current
                    current?.revealed = false
                    return current
                })
            
            })
            self?.chatInteraction.saveState(scrollState: self?.immediateScrollState())
            if self?.genericView.doBackgroundAction() != true {
                self?.navigationController?.doBackgroundAction()
            }
        }
        
        chatInteraction.jumpToDate = { [weak self] date in
            if let strongSelf = self, let window = self?.window, let peerId = self?.chatInteraction.peerId {
                
                
                switch strongSelf.mode {
                case .history, .replyThread:
                    let signal = context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: strongSelf.mode.threadId64, timestamp: Int32(date.timeIntervalSince1970))
                    
                    self?.dateDisposable.set(showModalProgress(signal: signal, for: window).start(next: { messageId in
                        if let messageId = messageId {
                            self?.chatInteraction.focusMessageId(nil, messageId, .top(id: 0, innerId: nil, animated: true, focus: .init(focus: false), inset: 30))
                        }
                    }))
                case .pinned, .preview:
                    break
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

            let text = inputState.inputText.trimmed
            if text.length > presentation.maxInputCharacters {
                alert(for: context.window, info: L10n.chatInputErrorMessageTooLongCountable(text.length - Int(presentation.maxInputCharacters)))
                return
            }

            self.urlPreviewQueryState?.1.dispose()
            
            
            if atDate == nil {
                self.context.account.pendingUpdateMessageManager.add(messageId: state.message.id, text: inputState.inputText, media: state.editMedia, entities: TextEntitiesMessageAttribute(entities: inputState.messageTextEntities()), disableUrlPreview: presentation.interfaceState.composeDisableUrlPreview != nil)
                
                self.chatInteraction.beginEditingMessage(nil)
                self.chatInteraction.update({
                    $0.updatedInterfaceState({
                        $0.withUpdatedComposeDisableUrlPreview(nil).updatedEditState({
                            $0?.withUpdatedLoadingState(.none)
                        })
                    })
                })
                
            } else {
                let scheduleTime:Int32? = atDate != nil ? Int32(atDate!.timeIntervalSince1970) : nil

                self.chatInteraction.update({$0.updatedUrlPreview(nil).updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedLoadingState(state.editMedia == .keep ? .loading : .progress(0.2))})})})
                
                self.chatInteraction.editDisposable.set((context.engine.messages.requestEditMessage(messageId: state.message.id, text: inputState.inputText, media: state.editMedia, entities: TextEntitiesMessageAttribute(entities: inputState.messageTextEntities()), disableUrlPreview: presentation.interfaceState.composeDisableUrlPreview != nil, scheduleTime: scheduleTime) |> deliverOnMainQueue).start(next: { [weak self] progress in
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
            
        }
        
        chatInteraction.sendMessage = { [weak self] silent, atDate in
            if let strongSelf = self {
                let presentation = strongSelf.chatInteraction.presentation
                let peerId = strongSelf.chatInteraction.peerId
                let threadId = strongSelf.chatInteraction.mode.threadId
                if presentation.abilityToSend {
                    func apply(_ controller: ChatController, atDate: Date?) {
                        var invokeSignal:Signal<Never, NoError> = .complete()
                        
                        var setNextToTransaction = false
                        if let state = presentation.interfaceState.editState {
                            editMessage(state, atDate)
                            return
                        } else  if !presentation.effectiveInput.inputText.trimmed.isEmpty {
                            setNextToTransaction = true
                            invokeSignal = Sender.enqueue(input: presentation.effectiveInput, context: context, peerId: controller.chatInteraction.peerId, replyId: presentation.interfaceState.replyMessageId ?? threadId, disablePreview: presentation.interfaceState.composeDisableUrlPreview != nil, silent: silent, atDate: atDate, mediaPreview: presentation.urlPreview?.1, emptyHandler: { [weak strongSelf] in
                                _ = strongSelf?.nextTransaction.execute()
                            }) |> deliverOnMainQueue |> ignoreValues
                            
                        }
                        
                        let fwdIds: [MessageId] = presentation.interfaceState.forwardMessageIds
                        let hideNames = presentation.interfaceState.hideSendersName
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
                                
                                return Sender.forwardMessages(messageIds: messages.map {$0.id}, context: context, peerId: peerId, hideNames: hideNames, silent: silent, atDate: atDate)
                            }
                            
                            invokeSignal = invokeSignal |> then(fwd |> ignoreValues)
                            
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
                                showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                                    if let strongSelf = strongSelf {
                                        apply(strongSelf, atDate: date)
                                    }
                                }), for: context.window)
                            }
                        } else {
                             apply(strongSelf, atDate: nil)
                        }
                    case .history, .replyThread:
                        delay(0.1, closure: {
                            if atDate != nil {
                                strongSelf.openScheduledChat()
                            }
                        })
                        apply(strongSelf, atDate: atDate)
                    case .pinned, .preview:
                        break
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
                                strongSelf.chatInteraction.focusMessageId(nil, last, .CenterEmpty)
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
                            signals.append(context.engine.peers.removePeerChat(peerId: chatInteraction.peerId, reportChatSpam: result[0] == .selected) |> ignoreValues)
                        } else if result[0] == .selected {
                            
                            signals.append(context.engine.peers.reportPeer(peerId: peer.id) |> ignoreValues)
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
            let removeFlagsSignal = context.account.postbox.transaction { transaction in
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
            }
            let unmuteSignal = context.engine.peers.updatePeerMuteSetting(peerId: peerId, muteInterval: nil)
            
            _ = combineLatest(unmuteSignal, removeFlagsSignal).start()
        }
        
        chatInteraction.sendPlainText = { [weak self] text in
            if let strongSelf = self, let peer = self?.chatInteraction.presentation.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
                let _ = (Sender.enqueue(input: ChatTextInputState(inputText: text), context: context, peerId: strongSelf.chatInteraction.peerId, replyId: strongSelf.chatInteraction.presentation.interfaceState.replyMessageId) |> deliverOnMainQueue).start(completed: scrollAfterSend)
            }
        }
        
        chatInteraction.sendLocation = { [weak self] coordinate, venue in
            let media = TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: venue, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
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

        chatInteraction.reportMessages = { [weak self] value, ids in
            showModal(with: ReportDetailsController(context: context, reason: value, updated: { [weak self] value in
                _ = showModalProgress(signal: context.engine.peers.reportPeerMessages(messageIds: ids, reason: value.reason, message: value.comment), for: context.window).start(completed: { [weak self] in
                    showModalText(for: context.window, text: L10n.peerInfoChannelReported)
                    self?.changeState()
                })
            }), for: context.window)

        }
        
        chatInteraction.forwardMessages = { [weak self] ids in
            guard let strongSelf = self else {
                return
            }
            if let report = strongSelf.chatInteraction.presentation.reportMode {
                strongSelf.chatInteraction.reportMessages(report, ids)
                return
            }
            showModal(with: ShareModalController(ForwardMessagesObject(context, messageIds: ids)), for: context.window)
        }
        
        chatInteraction.deleteMessages = { [weak self] messageIds in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {

                if strongSelf.chatInteraction.presentation.reportMode != nil {
                    strongSelf.changeState()
                    return
                }

                let channelAdmin:Promise<[ChannelParticipant]?> = Promise()
                    
                if peer.isSupergroup {
                    let disposable: MetaDisposable = MetaDisposable()
                    let result = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peer.id, updated: { state in
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
                            if !canDeleteMessage(message, account: context.account, mode: strongSelf.chatInteraction.mode) {
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
                                        signals.append(context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forEveryone))
                                    }
                                    index += 1
                                    
                                    if hasRestrict {
                                        if result[index] == .selected {
                                            signals.append(context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peerId, memberId: memberId, bannedRights: .init(flags: [.banReadMessages], untilDate: Int32.max)))
                                        }
                                        index += 1
                                    }
                                    
                                    if result[index] == .selected {
                                        signals.append(context.engine.peers.reportPeerMessages(messageIds: messageIds, reason: .spam, message: ""))
                                    }
                                    index += 1

                                    if result[index] == .selected {
                                        signals.append(context.engine.messages.clearAuthorHistory(peerId: peerId, memberId: memberId))
                                    }
                                    index += 1

                                    _ = showModalProgress(signal: combineLatest(signals), for: context.window).start()
                                    strongSelf?.chatInteraction.update({$0.withoutSelectionState()})
                                }), for: context.window)
                                
                            } else if let `self` = self {
                                let thrid:String? = self.mode == .scheduled ? nil : (canDeleteForEveryone ? peer.isUser ? L10n.chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : L10n.chatConfirmDeleteMessagesForEveryone : nil)
                                
                                modernConfirm(for: context.window, account: context.account, peerId: nil, header: thrid == nil ? L10n.chatConfirmActionUndonable : L10n.chatConfirmDeleteMessages1Countable(messages.count), information: thrid == nil ? _mustDeleteForEveryoneMessage ? L10n.chatConfirmDeleteForEveryoneCountable(messages.count) : L10n.chatConfirmDeleteMessages1Countable(messages.count) : nil, okTitle: L10n.confirmDelete, thridTitle: thrid, successHandler: { [weak strongSelf] result in
                                    
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
                                    _ = context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: type).start()
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
                if toChat || action != nil {
                    
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
                            
                            strongSelf.chatInteraction.focusMessageId(fromId, postId, TableScrollState.CenterEmpty)
                        }
                        if let action = action {
                            strongSelf.chatInteraction.update({ $0.updatedInitialAction(action) })
                            strongSelf.chatInteraction.invokeInitialAction()
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
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: self?.genericView.tableView, supportTableView: nil)
            self?.navigationController?.header?.show(true, contextObject: object)
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
                        attributes.append(.uid(range.lowerBound ..< range.upperBound - 1, peer.id.id._internalGetInt64Value()))
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
                    
                    let value = context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: chatInteraction.peerId, results: results, result: result, replyToMessageId: chatInteraction.presentation.interfaceState.replyMessageId ?? chatInteraction.mode.threadId)
                    
                    if value {
                        controller.nextTransaction.set(handler: afterSentTransition)
                    }

                }
                switch strongSelf.mode {
                case .history, .replyThread:
                    apply(strongSelf, atDate: nil)
                case .scheduled:
                    if let peer = strongSelf.chatInteraction.peer {
                        showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                            if let strongSelf = strongSelf {
                                apply(strongSelf, atDate: Int32(date.timeIntervalSince1970))
                            }
                        }), for: context.window)
                    }
                case .pinned, .preview:
                    break
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
                let signal = context.engine.messages.earliestUnseenPersonalMentionMessage(peerId: strongSelf.chatInteraction.peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak strongSelf] result in
                    if let strongSelf = strongSelf {
                        switch result {
                        case .loading:
                            break
                        case .result(let messageId):
                            if let messageId = messageId {
                                strongSelf.chatInteraction.focusMessageId(nil, messageId, .CenterEmpty)
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
        
        /*
         
         let header: String
         let text: String
         if peer.isChannel {
         header = L10n.channelAdminTransferOwnershipConfirmChannelTitle
         text = L10n.channelAdminTransferOwnershipConfirmChannelText(peer.displayTitle, admin.displayTitle)
         } else {
         header = L10n.channelAdminTransferOwnershipConfirmGroupTitle
         text = L10n.channelAdminTransferOwnershipConfirmGroupText(peer.displayTitle, admin.displayTitle)
         }
         
         
 */
        
        
        chatInteraction.requestMessageActionCallback = { [weak self] messageId, isGame, data in
            if let strongSelf = self {
                switch strongSelf.mode {
                case .history, .replyThread:
                    let applyResult:(MessageActionCallbackResult) -> Void = { [weak strongSelf] result in
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
                    }
                    strongSelf.botCallbackAlertMessage.set(.single((L10n.chatInlineRequestLoading, false)))
                    strongSelf.messageActionCallbackDisposable.set((context.engine.messages.requestMessageActionCallback(messageId: messageId, isGame:isGame, password: nil, data: data?.data) |> deliverOnMainQueue).start(next: applyResult, error: { [weak strongSelf] error in
                        
                        strongSelf?.botCallbackAlertMessage.set(.single(("", false)))
                        if let data = data, data.requiresPassword {
                            var errorText: String? = nil
                            var install2Fa = false
                            switch error {
                            case .invalidPassword:
                                showModal(with: InputPasswordController(context: context, title: L10n.botTransferOwnershipPasswordTitle, desc: L10n.botTransferOwnershipPasswordDesc, checker: { pwd in
                                    return context.engine.messages.requestMessageActionCallback(messageId: messageId, isGame: isGame, password: pwd, data: data.data)
                                        |> deliverOnMainQueue
                                        |> beforeNext { result in
                                            applyResult(result)
                                        }
                                        |> ignoreValues
                                        |> `catch` { error -> Signal<Never, InputPasswordValueError> in
                                            switch error {
                                            case .generic:
                                                return .fail(.generic)
                                            case .invalidPassword:
                                                return .fail(.wrong)
                                            default:
                                                return .fail(.generic)
                                            }
                                    } 
                                }), for: context.window)
                            case .authSessionTooFresh:
                                errorText = L10n.botTransferOwnerErrorText
                            case .twoStepAuthMissing:
                                errorText = L10n.botTransferOwnerErrorText
                                install2Fa = true
                            case .twoStepAuthTooFresh:
                                errorText = L10n.botTransferOwnerErrorText
                            default:
                                break
                            }
                            if let errorText = errorText {
                                confirm(for: context.window, header: L10n.botTransferOwnerErrorTitle, information: errorText, okTitle: L10n.modalOK, cancelTitle: L10n.modalCancel, thridTitle: install2Fa ? L10n.botTransferOwnerErrorEnable2FA : nil, successHandler: { result in
                                    switch result {
                                    case .basic:
                                        break
                                    case .thrid:
                                        context.sharedContext.bindings.rootNavigation().push(twoStepVerificationUnlockController(context: context, mode: .access(nil), presentController: { (controller, isRoot, animated) in
                                            let navigation = context.sharedContext.bindings.rootNavigation()
                                            if isRoot {
                                                navigation.removeUntil(ChatController.self)
                                            }
                                            if !animated {
                                                navigation.stackInsert(controller, at: navigation.stackCount)
                                            } else {
                                                navigation.push(controller)
                                            }
                                        }))
                                    }
                                })
                            }
                        }
                        
                    }))
                case .scheduled:
                    break
                case .pinned, .preview:
                    break
                }
                
            }
        }
        
        chatInteraction.updateSearchRequest = { [weak self] state in
            self?.searchState.set(state)
        }
        
        chatInteraction.setLocation = { [weak self] location in
            self?.setLocation(location)
        }
        
        
        chatInteraction.scrollToTheFirst = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let scroll: ChatHistoryLocation = .Scroll(index: .lowerBound, anchorIndex: .lowerBound, sourceIndex: .lowerBound, scrollPosition: .up(true), count: 50, animated: true)
            
            let historyView = chatHistoryViewForLocation(scroll, context: context, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: nil, tagMask: strongSelf.mode.tagMask, additionalData: [], chatLocationContextHolder: strongSelf.chatLocationContextHolder)
            
            struct FindSearchMessage {
                let message:Message?
                let loaded:Bool
            }
            
            let signal = historyView
                |> mapToSignal { historyView -> Signal<Bool, NoError> in
                    switch historyView {
                    case .Loading:
                        return .single(true)
                    case let .HistoryView(view, _, _, _):
                        if !view.holeLater, !view.isLoading {
                            return .single(false)
                        }
                        return .single(true)
                    }
                } |> take(until: { index in
                    return SignalTakeAction(passthrough: !index, complete: !index)
                })
            
            strongSelf.chatInteraction.loadingMessage.set(.single(true) |> delay(0.2, queue: Queue.mainQueue()))
            strongSelf.messageIndexDisposable.set(showModalProgress(signal: signal, for: context.window).start(next: { [weak strongSelf] _ in
                strongSelf?.setLocation(scroll)
            }, completed: {
                    
            }))
        }
        
        chatInteraction.openFocusedMedia = { [weak self] timemark in
            if let messageId = self?.messageId {
                self?.genericView.tableView.enumerateItems(with: { item in
                    if let item = item as? ChatMediaItem, item.message?.id == messageId {
                        item.openMedia(timemark)
                        return false
                    }
                    return true
                })
            }
        }
        
        chatInteraction.focusPinnedMessageId = { [weak self] messageId in
            self?.chatInteraction.focusMessageId(nil, messageId, .CenterActionEmpty { [weak self] _ in
                self?.chatInteraction.update({$0.withUpdatedTempPinnedMaxId(messageId)})
            })
        }
        
        chatInteraction.runEmojiScreenEffect = { [weak self] emoji, messageId, mirror, isIncoming in
            guard let strongSelf = self else {
                return
            }
            strongSelf.emojiEffects.addAnimation(emoji.fixed, index: nil, mirror: mirror, isIncoming: isIncoming, messageId: messageId, animationSize: NSMakeSize(350, 350), viewFrame: context.window.bounds, for: context.window.contentView!)
        }
        
        chatInteraction.focusMessageId = { [weak self] fromId, toId, state in
            
            if let strongSelf = self {
                switch strongSelf.mode {
                case let .replyThread(data, mode):
                    if mode.originId == toId {
                        let controller = strongSelf.navigationController?.previousController as? ChatController
                        if let controller = controller, case .peer(mode.originId.peerId) = controller.chatLocation {
                            strongSelf.navigationController?.back()
                            controller.chatInteraction.focusMessageId(fromId, mode.originId, state)
                        } else {
                            strongSelf.navigationController?.push(ChatAdditionController(context: strongSelf.context, chatLocation: .peer(toId.peerId), mode: .history, messageId: toId, initialAction: nil))
                        }
                        return
                    } else if toId.peerId != peerId {
                        strongSelf.navigationController?.push(ChatAdditionController(context: strongSelf.context, chatLocation: .peer(toId.peerId), mode: .history, messageId: toId, initialAction: nil))
                    }
                default:
                    break
                }
                
                switch strongSelf.mode {
                case .history, .replyThread:
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
                        let historyView = chatHistoryViewForLocation(.InitialSearch(location: .id(toId), count: strongSelf.requestCount), context: context, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: nil, tagMask: strongSelf.mode.tagMask, additionalData: [], chatLocationContextHolder: strongSelf.chatLocationContextHolder)
                        
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
                                let requestCount = strongSelf.requestCount
                                delay(0.15, closure: { [weak strongSelf] in
                                    strongSelf?.setLocation(.Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: state.swap(to: ChatHistoryEntryId.message(message)), count: requestCount, animated: state.animated))
                                })
                            }
                        }))
                        //  }
                    }
                case .scheduled:
                    strongSelf.navigationController?.back()
                    (strongSelf.navigationController?.controller as? ChatController)?.chatInteraction.focusMessageId(fromId, toId, state)
                case .pinned, .preview:
                    break
                }
            }
            
        }
        
        chatInteraction.vote = { [weak self] messageId, opaqueIdentifiers, submit in
            guard let `self` = self else {return}
            
            self.updatePoll { data -> [MessageId : ChatPollStateData] in
                var data = data
                data[messageId] = ChatPollStateData(identifiers: opaqueIdentifiers, isLoading: submit && !opaqueIdentifiers.isEmpty)
                return data
            }
            
            let signal:Signal<TelegramMediaPoll?, RequestMessageSelectPollOptionError>

            if submit {
                if opaqueIdentifiers.isEmpty {
                    signal = showModalProgress(signal: (context.engine.messages.requestMessageSelectPollOption(messageId: messageId, opaqueIdentifiers: []) |> deliverOnMainQueue), for: context.window)
                } else {
                    signal = (context.engine.messages.requestMessageSelectPollOption(messageId: messageId, opaqueIdentifiers: opaqueIdentifiers) |> deliverOnMainQueue)
                }
                
                self.selectMessagePollOptionDisposables.set(signal.start(next: { [weak self] poll in
                    if let poll = poll {
                        self?.updatePoll { data -> [MessageId : ChatPollStateData] in
                            var data = data
                            data.removeValue(forKey: messageId)
                            return data
                        }
                        var once: Bool = true
                        self?.afterNextTransaction = { [weak self] in
                            if let tableView = self?.genericView.tableView, once {
                                tableView.enumerateItems(with: { item -> Bool in
                                    if let item = item as? ChatRowItem, let message = item.message, message.id == messageId, let `self` = self {
                                        
                                        if message.id == self.mode.threadId {
                                            let entry = item.entry.withUpdatedMessageMedia(poll)
                                            let size = self.atomicSize.with { $0 }
                                            let updatedItem = ChatRowItem.item(size, from: entry, interaction: self.chatInteraction, theme: theme)

                                            _ = updatedItem.makeSize(size.width, oldWidth: 0)

                                            tableView.merge(with: .init(deleted: [], inserted: [], updated: [(item.index, updatedItem)], animated: true))
                                            
                                            delay(0.25, closure: { [weak self] in
                                                if let location = self?._locationValue.with({$0}) {
                                                    self?.setLocation(location)
                                                }
                                            })
                                        }
                                        
                                        let view = item.view as? ChatPollItemView
                                        if let view = view, view.window != nil, view.visibleRect != .zero {
                                            view.doAfterAnswer()
                                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                                        }
                                        return false
                                    }
                                    return true
                                })
                                once = false
                            }
                        }
                        
                        if opaqueIdentifiers.isEmpty {
                            self?.afterNextTransaction?()
                        }
                    }

                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: L10n.unknownError)
                    }
                    self?.updatePoll { data -> [MessageId : ChatPollStateData] in
                        var data = data
                        data.removeValue(forKey: messageId)
                        return data
                    }
                    
                }), forKey: messageId)
            }
            
        }
        chatInteraction.closePoll = { [weak self] messageId in
            guard let `self` = self else {return}
            self.selectMessagePollOptionDisposables.set(context.engine.messages.requestClosePoll(messageId: messageId).start(), forKey: messageId)
        }
        
        
        chatInteraction.sendMedia = { [weak self] media in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
                
                switch strongSelf.mode {
                case .scheduled:
                    showModal(with: DateSelectorModalController(context: strongSelf.context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                        if let strongSelf = strongSelf {
                            let _ = (Sender.enqueue(media: media, context: context, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction, atDate: date) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                            strongSelf.nextTransaction.set(handler: {})
                        }
                    }), for: strongSelf.context.window)
                case .history, .replyThread:
                    let _ = (Sender.enqueue(media: media, context: context, peerId: strongSelf.chatInteraction.peerId, chatInteraction: strongSelf.chatInteraction) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    strongSelf.nextTransaction.set(handler: {})
                case .pinned, .preview:
                    break
                }
            }
        }
        
        chatInteraction.attachFile = { [weak self] asMedia in
            if let `self` = self, let window = self.window {
                if let slowMode = self.chatInteraction.presentation.slowMode, let errorText = slowMode.errorText {
                    tooltip(for: self.genericView.inputView.attachView, text: errorText)
                    if let last = slowMode.sendingIds.last {
                        self.chatInteraction.focusMessageId(nil, last, .CenterEmpty)
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
                        self.chatInteraction.focusMessageId(nil, last, .CenterEmpty)
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
        
        chatInteraction.sendAppFile = { [weak self] file, silent, query in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
                func apply(_ controller: ChatController, atDate: Date?) {
                    let _ = (Sender.enqueue(media: file, context: context, peerId: controller.chatInteraction.peerId, chatInteraction: controller.chatInteraction, silent: silent, atDate: atDate, query: query) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    controller.nextTransaction.set(handler: {})
                }
                switch strongSelf.mode {
                case .scheduled:
                    showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
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
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
                func apply(_ controller: ChatController, atDate: Date?) {
                    let _ = (Sender.enqueue(media: medias, caption: caption, context: context, peerId: controller.chatInteraction.peerId, chatInteraction: controller.chatInteraction, isCollage: isCollage, additionText: additionText, silent: silent, atDate: atDate) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    controller.nextTransaction.set(handler: {})
                }
                switch strongSelf.mode {
                case .history, .replyThread:
                    DispatchQueue.main.async { [weak strongSelf] in
                        if let _ = atDate {
                            strongSelf?.openScheduledChat()
                        }
                    }
                    apply(strongSelf, atDate: atDate)
                case .scheduled:
                    if let atDate = atDate {
                        apply(strongSelf, atDate: atDate)
                    } else {
                        showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                            if let strongSelf = strongSelf {
                                apply(strongSelf, atDate: date)
                            }
                        }), for: context.window)
                    }
                case .pinned, .preview:
                    break
                }
            }
        }
        
        chatInteraction.shareSelfContact = { [weak self] replyId in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
                strongSelf.shareContactDisposable.set((context.account.viewTracker.peerView(context.account.peerId) |> take(1)).start(next: { [weak strongSelf] peerView in
                    if let strongSelf = strongSelf, let peer = peerViewMainPeer(peerView) as? TelegramUser {
                        _ = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)), replyToMessageId: replyId, localGroupingKey: nil, correlationId: nil), context: context, peerId: strongSelf.chatInteraction.peerId).start()
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
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
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
                        showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                            if let strongSelf = strongSelf {
                                apply(strongSelf, atDate: date)
                            }
                        }), for: context.window)
                    }
                case .history, .replyThread:
                    apply(strongSelf, atDate: nil)
                case .pinned, .preview:
                    break
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
                        self.chatInteraction.focusMessageId(nil, slowMode.sendingIds.last!, .CenterEmpty)
                    }
                } else {
                    var updated:[URL] = []
                    for url in urls {
                        if url.path.contains("/T/TemporaryItems/") {
                            let newUrl = URL(fileURLWithPath: NSTemporaryDirectory() + url.path.nsstring.lastPathComponent)
                            try? FileManager.default.moveItem(at: url, to: newUrl)
                            if FileManager.default.fileExists(atPath: newUrl.path) {
                                updated.append(newUrl)
                            }
                        } else {
                            if FileManager.default.fileExists(atPath: url.path) {
                                updated.append(url)
                            }
                        }
                    }
                    if !updated.isEmpty {
                        if let _ = self.chatInteraction.presentation.interfaceState.editState {
                            alert(for: context.window, info: L10n.chatEditAttachError)
                        } else {
                            showModal(with: PreviewSenderController(urls: updated, chatInteraction: self.chatInteraction, asMedia: asMedia, attributedString: attributedString), for: context.window)
                        }
                    }
                }
            }
        }
        
        chatInteraction.setChatMessageAutoremoveTimeout = { [weak self] seconds in
            guard let strongSelf = self else {
                return
            }
            if let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode) {
                _ = context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peer.id, timeout: seconds).start()
            }
            scrollAfterSend()
        }

        chatInteraction.showDeleterSetup = { [weak self] control in
            guard let strongSelf = self else {
                return
            }
            if let peer = strongSelf.chatInteraction.peer {
                if !peer.canManageDestructTimer {
                    if let timeout = strongSelf.chatInteraction.presentation.messageSecretTimeout?.timeout?.effectiveValue {
                        switch timeout {
                        case .secondsInDay:
                            tooltip(for: control, text: L10n.chatInputAutoDelete1Day)
                        case .secondsInWeek:
                            tooltip(for: control, text: L10n.chatInputAutoDelete7Days)
                        default:
                            break
                        }
                    }
                } else {
                    
                    showModal(with: AutoremoveMessagesController(context: context, peer: peer, onlyDelete: true), for: context.window)
                }
            }
        }
        
        chatInteraction.toggleNotifications = { [weak self] isMuted in
            if let strongSelf = self {
                if isMuted == nil || isMuted == true {
                    _ = context.engine.peers.togglePeerMuted(peerId: strongSelf.chatInteraction.peerId).start()
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
                                _ = context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.chatInteraction.peerId, muteInterval: intervals[i]).start()
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
                if let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId.peerId {
                    self?.chatInteraction.openInfo(linkedDiscussionPeerId, true, nil, nil)
                }
            }))
        }
        
        chatInteraction.removeAndCloseChat = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: context.engine.peers.removePeerChat(peerId: strongSelf.chatInteraction.peerId, reportChatSpam: false), for: window).start(next: { [weak strongSelf] in
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
                _ = showModalProgress(signal: context.engine.peers.joinChannel(peerId: strongSelf.chatInteraction.peerId, hash: nil) |> deliverOnMainQueue, for: window).start(error: { error in
                    let text: String
                    switch error {
                    case .generic:
                        text = L10n.unknownError
                    case .tooMuchJoined:
                        showInactiveChannels(context: context, source: .join)
                        return
                    case .tooMuchUsers:
                        text = L10n.groupUsersTooMuchError
                    }
                    alert(for: context.window, info: text)
                })
            }
        }
        
        chatInteraction.joinGroupCall = { [weak self] activeCall, joinHash in
            let groupCall = self?.chatInteraction.presentation.groupCall
            var currentActiveCall = groupCall?.activeCall
            var activeCall: CachedChannelData.ActiveCall? = activeCall
            if currentActiveCall == nil {
                activeCall = nil
            }
            if activeCall != currentActiveCall {
                currentActiveCall = activeCall
            } 
            if let activeCall = currentActiveCall {
                let join:(PeerId, Date?)->Void = { joinAs, _ in
                    _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: activeCall, initialInfo: groupCall?.data?.info, joinHash: joinHash), for: context.window).start(next: { result in
                        switch result {
                        case let .samePeer(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                            if let joinHash = joinHash {
                                callContext.call.joinAsSpeakerIfNeeded(joinHash)
                            }
                        case let .success(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                        default:
                            alert(for: context.window, info: L10n.errorAnError)
                        }
                    })
                }
                if let callJoinPeerId = groupCall?.callJoinPeerId {
                    join(callJoinPeerId, nil)
                } else {
                    selectGroupCallJoiner(context: context, peerId: peerId, completion: join)
                }
            } else if let peer = self?.chatInteraction.peer {
                if peer.groupAccess.canMakeVoiceChat {
                    confirm(for: context.window, information: L10n.voiceChatChatStartNew, okTitle: L10n.voiceChatChatStartNewOK, successHandler: { _ in
                        createVoiceChat(context: context, peerId: peerId)
                    })
                }
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
            _ = showModalProgress(signal: context.engine.payments.getBankCardInfo(cardNumber: card), for: context.window).start(next: { info in
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
            if let strongSelf = self, let main = strongSelf.chatInteraction.peer, main.canSendMessage(strongSelf.mode.isThreadMode) {
                _ = Sender.shareContact(context: context, peerId: strongSelf.chatInteraction.peerId, contact: peer).start()
            }
        }
        
        chatInteraction.unblock = { [weak self] in
            if let strongSelf = self {
                strongSelf.unblockDisposable.set(context.blockedPeersContext.remove(peerId: strongSelf.chatInteraction.peerId).start())
            }
        }
        
        chatInteraction.updatePinned = { [weak self] pinnedId, dismiss, silent, forThisPeerOnlyIfPossible in
            if let `self` = self {
                
                let pinnedUpdate: PinnedMessageUpdate = dismiss ? .clear(id: pinnedId) : .pin(id: pinnedId, silent: silent, forThisPeerOnlyIfPossible: forThisPeerOnlyIfPossible)
                let peerId = self.chatInteraction.peerId
                if let peer = self.chatInteraction.peer as? TelegramChannel {
                    if peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
                        
                        self.updatePinnedDisposable.set(((dismiss ? confirmSignal(for: context.window, header: L10n.chatConfirmUnpinHeader, information: L10n.chatConfirmUnpin, okTitle: L10n.chatConfirmUnpinOK) : Signal<Bool, NoError>.single(true)) |> filter {$0} |> mapToSignal { _ in return
                                                            showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate) |> `catch` {_ in .complete()
                        }, for: context.window)}).start())
                    } else {
                        self.chatInteraction.update({$0.updatedInterfaceState({$0.withAddedDismissedPinnedIds([pinnedId])})})
                    }
                } else if self.chatInteraction.peerId.namespace == Namespaces.Peer.CloudUser {
                    if dismiss {
                        confirm(for: context.window, header: L10n.chatConfirmUnpinHeader, information: L10n.chatConfirmUnpin, okTitle: L10n.chatConfirmUnpinOK, successHandler: { [weak self] _ in
                            self?.updatePinnedDisposable.set(showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate), for: context.window).start())
                        })
                    } else {
                        self.updatePinnedDisposable.set(showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate), for: context.window).start())
                    }
                } else if let peer = self.chatInteraction.peer as? TelegramGroup, peer.canPinMessage {
                    if dismiss {
                        confirm(for: context.window, header: L10n.chatConfirmUnpinHeader, information: L10n.chatConfirmUnpin, okTitle: L10n.chatConfirmUnpinOK, successHandler: {  [weak self]_ in
                            self?.updatePinnedDisposable.set(showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate), for: context.window).start())
                        })
                    } else {
                        self.updatePinnedDisposable.set(showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate), for: context.window).start())
                    }
                }
            }
        }
        
        chatInteraction.openPinnedMessages = { [weak self, unowned context] messageId in
            guard let `self` = self else {
                return
            }
            self.navigationController?.push(ChatAdditionController(context: context, chatLocation: .peer(peerId), mode: .pinned, messageId: messageId))
        }
        
        chatInteraction.unpinAllMessages = { [weak self, unowned context] in
            guard let `self` = self else {
                return
            }
            
            guard let peer = self.chatInteraction.presentation.peer else {
                return
            }
            
            var canManagePin = false
            if let channel = peer as? TelegramChannel {
                canManagePin = channel.hasPermission(.pinMessages)
            } else if let group = peer as? TelegramGroup {
                switch group.role {
                case .creator, .admin:
                    canManagePin = true
                default:
                    if let defaultBannedRights = group.defaultBannedRights {
                        canManagePin = !defaultBannedRights.flags.contains(.banPinMessages)
                    } else {
                        canManagePin = true
                    }
                }
            } else if let _ = peer as? TelegramUser, self.chatInteraction.presentation.canPinMessage {
                canManagePin = true
            }

            if canManagePin {
                let count = self.chatInteraction.presentation.pinnedMessageId?.totalCount ?? 1
                
                confirm(for: context.window, information: L10n.chatUnpinAllMessagesConfirmationCountable(count), okTitle: L10n.chatConfirmUnpinOK, cancelTitle: L10n.modalCancel, successHandler: { [weak self] _ in
                    let _ = (context.engine.messages.requestUnpinAllMessages(peerId: peerId)
                        |> deliverOnMainQueue).start(error: { _ in
                            
                        }, completed: { [weak self] in
                            self?.navigationController?.back()
                        })
                })
            } else {
                self.chatInteraction.update({ state in
                    return state.updatedInterfaceState { $0.withAddedDismissedPinnedIds(state.pinnedMessageId?.others.map { $0 } ?? [] )}
                })
                self.navigationController?.back()
            }

            
            
        }
        
        chatInteraction.getCachedData = { [weak self] in
            return ((self?.centerBarView as? ChatTitleBarView)?.postboxView as? PeerView)?.cachedData
        }
        
        chatInteraction.reportSpamAndClose = { [weak self] in
            let title: String
            if let peer = self?.chatInteraction.peer {
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
            
            self?.reportPeerDisposable.set((confirmSignal(for: context.window, header: L10n.chatConfirmReportSpamHeader, information: title, okTitle: L10n.messageContextReport, cancelTitle: L10n.modalCancel) |> filter {$0} |> mapToSignal { [weak self] _ in
                return context.engine.peers.reportPeer(peerId: peerId) |> deliverOnMainQueue |> mapToSignal { [weak self] _ -> Signal<Void, NoError> in
                    if let peer = self?.chatInteraction.peer {
                        if peer.id.namespace == Namespaces.Peer.CloudUser {
                            return context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: true) |> deliverOnMainQueue
                                |> mapToSignal { _ in
                                    return context.blockedPeersContext.add(peerId: peer.id) |> `catch` { _ in return .complete() } |> mapToSignal { _ in
                                        return .single(Void())
                                    }
                            }
                        } else {
                            return context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: true)
                        }
                    }
                    return .complete()
                    }
                    |> deliverOnMainQueue
                }).start(next: { [weak self] in
                    self?.navigationController?.back()
                }))
        }
        
        chatInteraction.dismissPeerStatusOptions = { [weak self] in
            if let strongSelf = self {
                let peerId = strongSelf.chatInteraction.peerId
                _ = context.engine.peers.dismissPeerStatusOptions(peerId: peerId).start()
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
            let point = self.genericView.scroll.rect.origin
            return CGRect(origin: point, size: self.frame.size)
        }
        
        var currentThreadId: MessageId?
        
        chatInteraction.openReplyThread = { [weak self] messageId, isChannelPost, modalProgress, mode in
            let signal:Signal<ReplyThreadInfo, FetchChannelReplyThreadMessageError>
                
            if modalProgress {
                signal = showModalProgress(signal: fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId)) |> take(1) |> deliverOnMainQueue, for: context.window)
            } else {
                signal = fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId)) |> take(1) |> deliverOnMainQueue
            }
            
            currentThreadId = mode.originId
            
            delay(0.2, closure: {
                if currentThreadId == mode.originId {
                    self?.updateThread { _ in
                        return mode.originId
                    }
                }
            })
            
            
            self?.loadThreadDisposable.set(signal.start(next: { [weak self] result in
                let chatLocation: ChatLocation = .replyThread(result.message)
                self?.updateThread { _ in
                    return nil
                }
                currentThreadId = nil
                let updatedMode: ReplyThreadMode
                if result.isChannelPost {
                    updatedMode = .comments(origin: mode.originId)
                } else {
                    updatedMode = .replies(origin: mode.originId)
                }
                self?.navigationController?.push(ChatAdditionController(context: context, chatLocation: chatLocation, mode: .replyThread(data: result.message, mode: updatedMode), messageId: isChannelPost ? nil : mode.originId, initialAction: nil, chatLocationContextHolder: result.contextHolder))
            }, error: { error in
                self?.updateThread { _ in
                    return nil
                }
                currentThreadId = nil
                
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.chatDiscussionMessageDeleted)
                }
            }))
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
        
        
        let topPinnedMessage: Signal<ChatPinnedMessage?, NoError>
        switch mode {
        case .history:
            switch self.chatLocation {
            case let .peer(peerId):
                let replyHistory: Signal<ChatHistoryViewUpdate, NoError> = (chatHistoryViewForLocation(.Initial(count: 100), context: self.context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: MessageTags.pinned, additionalData: [])
                    |> castError(Bool.self)
                    |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
                        switch update {
                        case let .Loading(_, type):
                            if case .Generic(.FillHole) = type {
                                return .fail(true)
                            }
                        case let .HistoryView(_, type, _, _):
                            if case .Generic(.FillHole) = type {
                                return .fail(true)
                            }
                        }
                        return .single(update)
                    })
                    |> restartIfError
                
                topPinnedMessage = combineLatest(
                    replyHistory,
                    self.topVisibleMessageRange.get(), self.dismissedPinnedIds.get()
                    )
                    |> map { update, topVisibleMessageRange, dismissed -> ChatPinnedMessage? in
                        var message: ChatPinnedMessage?
                        switch update {
                        case .Loading:
                            break
                        case let .HistoryView(view, _, _, _):
                            for i in 0 ..< view.entries.count {
                                let entry = view.entries[i]
                                var matches = false
                                if message == nil {
                                    matches = !dismissed.ids.contains(entry.message.id)
                                } else if let topVisibleMessageRange = topVisibleMessageRange {
                                    if entry.message.id <= topVisibleMessageRange.lowerBound {
                                        matches = !dismissed.ids.contains(entry.message.id)
                                    }
                                }
                                if let tempMaxId = dismissed.tempMaxId {
                                    var effectiveMatches = matches && entry.message.id < tempMaxId
                                    
                                    if matches, message == nil, i == view.entries.count - 1 {
                                        effectiveMatches = true
                                    }
                                    matches = effectiveMatches
                                }
                                if matches {
                                    message = ChatPinnedMessage(messageId: entry.message.id, message: entry.message, others: view.entries.map { $0.message.id }, isLatest: i == view.entries.count - 1, index: view.entries.count - 1 - i, totalCount: view.entries.count)
                                }
                            }
                            break
                        }
                        return message
                    }
                    |> distinctUntilChanged
            default:
                topPinnedMessage = .single(nil)
            }
        case .pinned:
            let replyHistory: Signal<ChatHistoryViewUpdate, NoError> = (chatHistoryViewForLocation(.Initial(count: 100), context: self.context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: MessageTags.pinned, additionalData: [])
                |> castError(Bool.self)
                |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
                    switch update {
                    case let .Loading(_, type):
                        if case .Generic(.FillHole) = type {
                            return .fail(true)
                        }
                    case let .HistoryView(_, type, _, _):
                        if case .Generic(.FillHole) = type {
                            return .fail(true)
                        }
                    }
                    return .single(update)
                })
                |> restartIfError
            
            topPinnedMessage = replyHistory
                |> map { update -> ChatPinnedMessage? in
                    switch update {
                    case .Loading:
                        break
                    case let .HistoryView(view, _, _, _):
                        if let first = view.entries.first {
                            return ChatPinnedMessage(messageId: first.message.id, message: first.message, others: view.entries.map { $0.message.id }, isLatest: true, index: 0, totalCount: view.entries.count)
                        }
                    }
                    return nil
                }
                |> distinctUntilChanged
        default:
            topPinnedMessage = .single(nil)
        }
        

        let initialData = initialDataHandler.get() |> take(1) |> beforeNext { [weak self] (combinedInitialData) in
            
            guard let `self` = self else {
                return
            }
            guard let initialData = combinedInitialData.initialData else {
                self.genericView.inputView.updateInterface(with: self.chatInteraction)
                return
            }
                        
            let opaqueState = initialData.storedInterfaceState.flatMap(_internal_decodeStoredChatInterfaceState)
            
            let interfaceState = ChatInterfaceState.parse(opaqueState, peerId: self.chatLocation.peerId, context: context)
            
            if let interfaceState = interfaceState {
                self.chatInteraction.update(animated:false,{$0.updatedInterfaceState({_ in return interfaceState})})
            }
            switch self.chatInteraction.mode {
            case let .replyThread(data, _):
                self.chatInteraction.update(animated:false, { present in
                    var present = present
                    present = present.withUpdatedHidePinnedMessage(true)
                    if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        if let peer = present.peer as? TelegramChannel {
                            switch peer.info {
                            case let .group(info):
                                if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator) {
                                    present = present
                                        .updateSlowMode({ value in
                                            var value = value ?? SlowMode()
                                            value = value
                                                .withUpdatedValidUntil(cachedData.slowModeValidUntilTimestamp)
                                            if let timeout = cachedData.slowModeValidUntilTimestamp {
                                                if timeout > context.timestamp {
                                                    value = value.withUpdatedTimeout(timeout - context.timestamp)
                                                } else {
                                                    value = value.withUpdatedTimeout(nil)
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
                    }
                    
                    var pinnedMessage: ChatPinnedMessage?
                    pinnedMessage = ChatPinnedMessage(messageId: data.messageId, message: combinedInitialData.cachedDataMessages?[data.messageId]?.first, isLatest: true)

                    present = present.withUpdatedPinnedMessageId(pinnedMessage)
                    return present.withUpdatedLimitConfiguration(combinedInitialData.limitsConfiguration)
                })
            case .history, .preview:
                self.chatInteraction.update(animated:false, { present in
                    var present = present

                    if peerId.namespace == Namespaces.Peer.SecretChat {
                        
                    } else if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                    } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                        present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                    } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                        present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                    }
                    
                    if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                        present = present.updatedGroupCall({ currentValue in
                            if let call = cachedData.activeCall {
                                return ChatActiveGroupCallInfo(activeCall: call, data: currentValue?.data, callJoinPeerId: cachedData.callJoinPeerId, joinHash: currentValue?.joinHash)
                            } else {
                                return nil
                            }
                        })
                    }
                    if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                        present = present
                            .withUpdatedBlocked(cachedData.isBlocked)
                            .withUpdatedCanPinMessage(cachedData.canPinMessages || context.peerId == peerId)
                            .updateBotMenu { current in
                                if let botInfo = cachedData.botInfo, !botInfo.commands.isEmpty {
                                    var current = current ?? .init(commands: [], revealed: false)
                                    current.commands = botInfo.commands
                                    return current
                                }
                                return nil
                            }
//                                    .withUpdatedHasScheduled(cachedData.hasScheduledMessages)
                    } else if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        present = present
                            .withUpdatedIsNotAccessible(cachedData.isNotAccessible)
                            .updatedGroupCall({ currentValue in
                                if let call = cachedData.activeCall {
                                    return ChatActiveGroupCallInfo(activeCall: call, data: currentValue?.data, callJoinPeerId: cachedData.callJoinPeerId, joinHash: currentValue?.joinHash)
                                } else {
                                    return nil
                                }
                            })
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
                                            } else {
                                                value = value.withUpdatedTimeout(nil)
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
                    }
                    return present.withUpdatedLimitConfiguration(combinedInitialData.limitsConfiguration)
                })
            case .scheduled:
                break
            case .pinned, .preview:
                break
            }
            
            if let modalAction = self.navigationController?.modalAction {
                self.invokeNavigation(action: modalAction)
            }
            
            
            self.state = self.chatInteraction.presentation.state == .selecting ? .Edit : .Normal
            self.notify(with: self.chatInteraction.presentation, oldValue: ChatPresentationInterfaceState(chatLocation: self.chatInteraction.chatLocation, chatMode: self.chatInteraction.mode), animated: false, force: true)
            
            self.genericView.inputView.updateInterface(with: self.chatInteraction)
            
        } |> map {_ in}
        
        
        
        
        let first:Atomic<Bool> = Atomic(value: true)
        
        
        let availableGroupCall: Signal<GroupCallPanelData?, NoError> = getGroupCallPanelData(context: context, peerId: peerId)
        
        
        peerDisposable.set((combineLatest(queue: .mainQueue(), topPinnedMessage, peerView.get(), availableGroupCall) |> beforeNext  { [weak self] topPinnedMessage, postboxView, groupCallData in
                        
            guard let `self` = self else {return}
            (self.centerBarView as? ChatTitleBarView)?.postboxView = postboxView
            let peerView = postboxView as? PeerView
            
            switch self.chatInteraction.mode {
            case .history, .preview:
                
                if let cachedData = peerView?.cachedData as? CachedChannelData {
                    let onlineMemberCount:Signal<Int32?, NoError>
                    if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(peerId: self.chatInteraction.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    } else {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(peerId: self.chatInteraction.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    }
                    
                    self.onlineMemberCountDisposable.set(onlineMemberCount.start(next: { [weak self] count in
                        (self?.centerBarView as? ChatTitleBarView)?.onlineMemberCount = count
                    }))
                }
                
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
                        let (recentDisposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(peerId: chatInteraction.peerId, updated: { _ in })
                        let (adminsDisposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(peerId: chatInteraction.peerId, updated: { _ in })
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
                        
                        var discussionGroupId:CachedChannelData.LinkedDiscussionPeerId = .unknown
                        if let cachedData = peerView.cachedData as? CachedChannelData {
                            if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                                switch peer.info {
                                case let .broadcast(info):
                                    if info.flags.contains(.hasDiscussionGroup) {
                                        discussionGroupId = cachedData.linkedDiscussionPeerId
                                    }
                                case .group:
                                    discussionGroupId = cachedData.linkedDiscussionPeerId
                                }
                            }
                        }

                        if let peer = peerView.peers[peerId] {
                            if let peer = peer as? TelegramSecretChat {
                                if let value = peer.messageAutoremoveTimeout {
                                    present = present.withUpdatedMessageSecretTimeout(.known(.init(peerValue: value)))
                                } else {
                                    present = present.withUpdatedMessageSecretTimeout(.known(nil))
                                }
                            } else if let cachedData = peerView.cachedData as? CachedUserData {
                                present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                            } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                            } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                            }
                            
                        }
                        
                        present = present.withUpdatedDiscussionGroupId(discussionGroupId)
                        present = present.withUpdatedPinnedMessageId(topPinnedMessage)
                        
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
                                .withUpdatedCanPinMessage(cachedData.canPinMessages || context.peerId == peerId)
                                .updateBotMenu { current in
                                    if let botInfo = cachedData.botInfo, !botInfo.commands.isEmpty {
                                        var current = current ?? .init(commands: [], revealed: false)
                                        current.commands = botInfo.commands
                                        return current
                                    }
                                    return nil
                                }
                        } else if let cachedData = peerView.cachedData as? CachedChannelData {
                            present = present
                                .withUpdatedPeerStatusSettings(contactStatus)
                                .withUpdatedIsNotAccessible(cachedData.isNotAccessible)
                                .updatedGroupCall({ current in
                                    if let call = cachedData.activeCall {
                                        return ChatActiveGroupCallInfo(activeCall: call, data: groupCallData, callJoinPeerId: cachedData.callJoinPeerId, joinHash: current?.joinHash)
                                    } else {
                                        return nil
                                    }
                                })
                            if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                                switch peer.info {
                                case let .group(info):
                                    if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator) {
                                        present = present.updateSlowMode({ value in
                                            var value = value ?? SlowMode()
                                            value = value.withUpdatedValidUntil(cachedData.slowModeValidUntilTimestamp)
                                            if let timeout = cachedData.slowModeValidUntilTimestamp {
                                                if timeout > context.timestamp {
                                                    value = value.withUpdatedTimeout(timeout - context.timestamp)
                                                } else {
                                                    value = value.withUpdatedTimeout(nil)
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
                        } else if let cachedData = peerView.cachedData as? CachedGroupData {
                            present = present
                                .withUpdatedPeerStatusSettings(contactStatus)
                                .updatedGroupCall({ current in
                                    if let call = cachedData.activeCall {
                                        return ChatActiveGroupCallInfo(activeCall: call, data: groupCallData, callJoinPeerId: cachedData.callJoinPeerId, joinHash: current?.joinHash)
                                    } else {
                                        return nil
                                    }
                                })
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
                    return presentation.withUpdatedCanPinMessage(context.peerId == peerId).updatedPeer { _ in
                        if let peerView = peerView {
                            return peerView.peers[peerView.peerId]
                        }
                        return nil
                    }.updatedMainPeer(peerView != nil ? peerViewMainPeer(peerView!) : nil)
                })
            case .pinned:
                self.chatInteraction.update(animated: !first.swap(false), { presentation in
                    var pinnedMessage: ChatPinnedMessage?
                    pinnedMessage = topPinnedMessage
                    return presentation.withUpdatedPinnedMessageId(pinnedMessage).withUpdatedCanPinMessage((peerView?.cachedData as? CachedUserData)?.canPinMessages ?? true || context.peerId == peerId).updatedPeer { _ in
                        if let peerView = peerView {
                            return peerView.peers[peerView.peerId]
                        }
                        return nil
                    }.updatedMainPeer(peerView != nil ? peerViewMainPeer(peerView!) : nil)
                })
            case .replyThread:
                self.chatInteraction.update(animated: !first.swap(false), { [weak peerView] presentation in
                    if let peerView = peerView {
                        var present = presentation.updatedPeer { [weak peerView] _ in
                            if let peerView = peerView {
                                return peerView.peers[peerView.peerId]
                            }
                            return nil
                            }.updatedMainPeer(peerViewMainPeer(peerView))
                        
                        if let cachedData = peerView.cachedData as? CachedChannelData {
                            present = present
                                .withUpdatedIsNotAccessible(cachedData.isNotAccessible)
                            if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                                switch peer.info {
                                case let .group(info):
                                    if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator) {
                                        present = present.updateSlowMode({ value in
                                            var value = value ?? SlowMode()
                                            value = value.withUpdatedValidUntil(cachedData.slowModeValidUntilTimestamp)
                                            if let timeout = cachedData.slowModeValidUntilTimestamp {
                                                if timeout > context.timestamp {
                                                    value = value.withUpdatedTimeout(timeout - context.timestamp)
                                                } else {
                                                    value = value.withUpdatedTimeout(nil)
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
                        }
                        return present
                    }
                    return presentation
                })
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
        
        let combine = combineLatest(queue: .mainQueue(), _historyReady.get() , peerView.get() |> take(1) |> map { _ in } |> then(initialData), genericView.inputView.ready.get())
        
        
        //self.ready.set(.single(true))
        
        self.ready.set(combine |> map { (hReady, _, iReady) in
            return hReady && iReady
        })
        
        
        connectionStatusDisposable.set((connectionStatus).start())
        
        
       
        
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
        
        switch mode {
        case .history:
            self.chatUnreadMentionCountDisposable.set((context.account.viewTracker.unseenPersonalMessagesCount(peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] count in
                self?.genericView.updateMentionsCount(count, animated: true)
            }))
        default:
            self.chatUnreadMentionCountDisposable.set(nil)
        }
       
        
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        
        
        self.peerInputActivitiesDisposable.set((context.account.peerInputActivities(peerId: .init(peerId: peerId, category: mode.activityCategory))
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
                    
                    for activity in activities {
                        switch activity.1 {
                        case let .interactingWithEmoji(emoticon, messageId, interaction: interaction):
                            
                            let animations = interaction?.animations ?? []
                            
                            let item = strongSelf.genericView.findItem(by: messageId) as? ChatRowItem
                            
                            if let item = item {
                                let mirror = item.isIncoming && item.renderType == .bubble
                                for animation in animations {
                                    delay(Double(animation.timeOffset), closure: { [weak strongSelf] in
                                        guard let strongSelf = strongSelf else {
                                            return
                                        }
                                        strongSelf.emojiEffects.addAnimation(emoticon, index: animation.index, mirror: mirror, isIncoming: true, messageId: messageId, animationSize: NSMakeSize(350, 350), viewFrame: context.window.bounds, for: context.window.contentView!)
                                    })
                                }
                            }
                            
                            break
                        default:
                            break
                        }
                    }
                }
            }))
        
        
        
        
        
       // var beginHistoryTime:CFAbsoluteTime?

        genericView.tableView.setScrollHandler({ [weak self] scroll in
            guard let `self` = self else {return}
            
            let view = self.previousView.with { $0?.originalView }
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
            self.chatInteraction.update({$0.withUpdatedTempPinnedMaxId(nil)})
        })
        
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {return}
            self.updateInteractiveReading()
        }))
        
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: true, { [weak self] position in
            guard let `self` = self else {return}
            let tableView = self.genericView.tableView
            let chatInteraction = self.chatInteraction
            switch self.mode {
            case .replyThread:
                if let pinnedMessageId = chatInteraction.presentation.pinnedMessageId, position.visibleRows.location != NSNotFound {
                    var hidden: Bool = false
                    for row in position.visibleRows.min ..< position.visibleRows.max {
                        if let item = tableView.item(at: row) as? ChatRowItem, item.effectiveCommentMessage?.id == pinnedMessageId.messageId {
                            hidden = true
                            break
                        }
                    }
                    chatInteraction.update({$0.withUpdatedHidePinnedMessage(hidden)})
                }
            default:
                break
            }
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
                var topVisibleMessageRange: ChatTopVisibleMessageRange?

                var hasFailed: Bool = false
                
                var readAds:[Data] = []
                
                tableView.enumerateVisibleItems(with: { item in
                    if let item = item as? ChatRowItem {
                        if message == nil {
                            message = item.lastMessage
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
                            
                            if message.tags.contains(.unseenPersonalMessage), item.chatInteraction.mode == .history {
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
                            
                            if let topVisibleMessageRangeValue = topVisibleMessageRange {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.id, isLast: item.index == tableView.count - 1)
                            } else {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.id, upperBound: message.id, isLast: item.index == tableView.count - 1)
                            }
                            if let id = message.adAttribute?.opaqueId {
                                if item.height == item.view?.visibleRect.height {
                                    readAds.append(id)
                                }
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
                if topVisibleMessageRange != nil {
                    strongSelf.topVisibleMessageRange.set(topVisibleMessageRange)
                }

                if !readAds.isEmpty {
                    for data in readAds {
                        strongSelf.adMessages?.markAsSeen(opaqueId: data)
                    }
                }
                
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
        
    
        
        let discussion: Signal<Void, NoError> = peerView.get()
            |> map { view -> CachedChannelData? in
                return (view as? PeerView)?.cachedData as? CachedChannelData
        } |> mapToSignal { value in
            if let threadId = mode.threadId {
                return context.account.viewTracker.polledChannel(peerId: threadId.peerId)
            } else if let peerDiscussionId = value?.linkedDiscussionPeerId {
                switch peerDiscussionId {
                case let .known(peerId):
                    if let peerId = peerId {
                        return context.account.viewTracker.polledChannel(peerId: peerId)
                    }
                default:
                    break
                }
            }
            return .single(Void())
        }
        
        
        pollChannelDiscussionDisposable.set(discussion.start())
        
    }

    override func updateFrame(_ frame: NSRect, animated: Bool) {
        super.updateFrame(frame, animated: animated)
        self.genericView.updateFrame(frame, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
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
        
        let historyView = self.previousView.with { $0 }
        if let historyView = historyView {
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
        switch mode {
        case .history:
            let scroll = genericView.scroll
            let hasEntries = self.previousView.with { $0?.filteredEntries.count ?? 0 } > 1
            if let window = window, window.isKeyWindow, self.historyState.isDownOfHistory && scroll.rect.minY == genericView.tableView.frame.height, hasEntries {
                self.interactiveReadingDisposable.set(context.engine.messages.installInteractiveReadMessagesAction(peerId: chatInteraction.peerId))
            } else {
                self.interactiveReadingDisposable.set(nil)
            }
            
        default:
            self.interactiveReadingDisposable.set(nil)
        }
        
    }
    
    
    
    private func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        return self.previousView.with { view in
            if let historyView = view {
                for entry in historyView.filteredEntries {
                    if let message = entry.appearance.entry.message, message.id == id {
                        return message
                    }
                }
            }
            return nil
        }
    }
    
    func isSearchAvailable(_ presentation: ChatPresentationInterfaceState) -> Bool {
        if presentation.reportMode != nil {
            return false
        }
        var isEmpty: Bool = genericView.tableView.isEmpty
        if chatInteraction.mode.isThreadMode {
            isEmpty = genericView.tableView.count == (theme.bubbled ? 4 : 3)
        }
        if chatInteraction.mode == .scheduled || isEmpty {
            return false
        } else {
            return true
        }
    }
    
    var searchAvailable: Bool {
        isSearchAvailable(chatInteraction.presentation)
    }
    
    private var firstLoad: Bool = true
    
    override func updateBackgroundColor(_ backgroundMode: TableBackgroundMode) {
        super.updateBackgroundColor(backgroundMode)
        genericView.updateBackground(backgroundMode, navigationView: self.navigationController?.view)
    }

    func applyTransition(_ transition:TableUpdateTransition, initialData:ChatHistoryCombinedInitialData, isLoading: Bool, processedView: ChatHistoryView) {
        
        let wasEmpty = genericView.tableView.isEmpty

        initialDataHandler.set(.single(initialData))
        
        historyState = historyState.withUpdatedStateOfHistory(processedView.originalView?.laterId == nil)
        
        let oldState = genericView.state
        
        genericView.change(state: isLoading ? .progress : .visible, animated: processedView.originalView != nil)
        
      
        self.currentAnimationRows = []
        genericView.tableView.merge(with: transition)
        
        self.updateBackgroundColor(processedView.theme.controllerBackgroundMode)
        
                
        let animated: Bool
        switch transition.state {
        case let .none(interface):
            animated = interface != nil
        default:
            animated = transition.animated
        }
        
        collectFloatingPhotos(animated: animated, currentAnimationRows: currentAnimationRows)
        
        let _ = nextTransaction.execute()

        
        if oldState != genericView.state {
            genericView.tableView.updateEmpties(animated: previousView.with { $0?.originalView != nil })
        }
        
        genericView.tableView.notifyScrollHandlers()
        
        if !transition.isEmpty, let afterNextTransaction = self.afterNextTransaction {
            delay(0.1, closure: afterNextTransaction)
            self.afterNextTransaction = nil
        }
        
        
        
        (self.centerBarView as? ChatTitleBarView)?.updateSearchButton(hidden: !searchAvailable, animated: transition.animated)
        
        if genericView.tableView.isEmpty, let peer = chatInteraction.peer, peer.isBot {
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
                view.updateBackground(animated: transition.animated, item: view.item)
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
        
        switch self.mode {
        case .pinned:
            if genericView.tableView.isEmpty {
                navigationController?.back()
            }
        default:
            break
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
            self?.showRightControls()
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
                                _ = context.engine.messages.clearHistoryInteractively(peerId: peerId, type: .scheduledMessages).start()
                            })
                        }, theme.icons.chatActionClearHistory))
                    case .history:
                        switch self.chatLocation {
                        case let .peer(peerId):
                            guard let peerView = view as? PeerView else {return}
                            
                            items.append(SPopoverItem(tr(L10n.chatContextEdit1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(L10n.chatContextEditHelp))" : ""),  { [weak self] in
                                self?.changeState()
                            }, theme.icons.chatActionEdit))
                            if peerId != repliesPeerId {
                                items.append(SPopoverItem(L10n.chatContextInfo,  { [weak self] in
                                    self?.chatInteraction.openInfo(peerId, false, nil, nil)
                                }, theme.icons.chatActionInfo))
                            }
                            
                            
                            
                            
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, !self.isAdChat  {
                                if self.chatInteraction.peerId != context.peerId {
                                    items.append(SPopoverItem(!notificationSettings.isMuted ? L10n.chatContextEnableNotifications : L10n.chatContextDisableNotifications, { [weak self] in
                                        self?.chatInteraction.toggleNotifications(notificationSettings.isMuted)
                                    }, !notificationSettings.isMuted ? theme.icons.chatActionUnmute : theme.icons.chatActionMute))
                                }
                            }
                            
                            if let peer = peerView.peers[peerView.peerId], let mainPeer = peerViewMainPeer(peerView) {
                                
                                var activeCall = (peerView.cachedData as? CachedGroupData)?.activeCall
                                activeCall = activeCall ?? (peerView.cachedData as? CachedChannelData)?.activeCall
                                
                                if peer.groupAccess.canMakeVoiceChat {
                                    var isLiveStream: Bool = false
                                    if let peer = peer as? TelegramChannel {
                                        isLiveStream = peer.isChannel || peer.flags.contains(.isGigagroup)
                                    }
                                    items.append(SPopoverItem(isLiveStream ? L10n.peerInfoActionLiveStream : L10n.peerInfoActionVoiceChat, { [weak self] in
                                        self?.makeVoiceChat(activeCall, callJoinPeerId: nil)
                                    }, theme.icons.chat_info_voice_chat))
                                }
                                if peer.isUser, peer.id != context.peerId {
                                    items.append(SPopoverItem(L10n.chatContextCreateGroup, { [weak self] in
                                        self?.createGroup()
                                    }, theme.icons.chat_info_create_group))
                                    
                                    items.append(SPopoverItem(L10n.peerInfoChatColors, { [weak self] in
                                        self?.showChatThemeSelector()
                                    }, theme.icons.chat_info_change_colors))
                                }
                                
                                if let groupId = peerView.groupId, groupId != .root {
                                    items.append(SPopoverItem(L10n.chatContextUnarchive, {
                                        _ = updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: .root).start()
                                    }, theme.icons.chatUnarchive))
                                } else {
                                    items.append(SPopoverItem(L10n.chatContextArchive, {
                                        _ = updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: Namespaces.PeerGroup.archive).start()
                                    }, theme.icons.chatArchive))
                                }
                                
                                if peer.canSendMessage(self.mode.isThreadMode), peerView.peerId.namespace != Namespaces.Peer.SecretChat {
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
                                
                                if peer.canClearHistory || (peer.canManageDestructTimer && context.peerId != peer.id) {
                                    items.append(SPopoverItem(L10n.chatContextClearHistory, {
                                        clearHistory(context: context, peer: peer, mainPeer: mainPeer)
                                    }, theme.icons.chatActionClearHistory))
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
                        case .replyThread:
                            break
                        }
                    case .replyThread:
                         items.append(SPopoverItem(L10n.chatContextEdit1,  { [weak self] in
                            self?.changeState()
                         }, theme.icons.chatActionEdit))
                    case .pinned:
                        items.append(SPopoverItem(L10n.chatContextEdit1,  { [weak self] in
                            self?.changeState()
                        }, theme.icons.chatActionEdit))
                    case .preview:
                        break
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
    private func createGroup() {
        context.composeCreateGroup(selectedPeers: [self.chatLocation.peerId])
    }
    
    private func makeVoiceChat(_ current: CachedChannelData.ActiveCall?, callJoinPeerId: PeerId?) {
        let context = self.context
        let peerId = self.chatLocation.peerId
        if let activeCall = current {
            let join:(PeerId, Date?)->Void = { joinAs, _ in
                _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: activeCall, initialInfo: nil, joinHash: nil), for: context.window).start(next: { result in
                    switch result {
                    case let .samePeer(callContext):
                        applyGroupCallResult(context.sharedContext, callContext)
                    case let .success(callContext):
                        applyGroupCallResult(context.sharedContext, callContext)
                    default:
                        alert(for: context.window, info: L10n.errorAnError)
                    }
                })
            }
            if let callJoinPeerId = callJoinPeerId {
                join(callJoinPeerId, nil)
            } else {
                selectGroupCallJoiner(context: context, peerId: peerId, completion: join)
            }
        } else {
            createVoiceChat(context: context, peerId: peerId, canBeScheduled: true)
        }
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
        
        if chatInteraction.presentation.interfaceState.themeEditing {
            self.themeSelector?.close(true)
            return .invoked
        }
        
        var result:KeyHandlerResult = .rejected
        if chatInteraction.presentation.botMenu?.revealed == true {
            self.chatInteraction.update({
                $0.updateBotMenu({ current in
                    var current = current
                    current?.revealed = false
                    return current
                })
            })
            result = .invoked
        } else if chatInteraction.presentation.reportMode != nil {
            self.changeState()
            result = .invoked
        } else if chatInteraction.presentation.state == .selecting {
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
            if chatInteraction.presentation.interfaceState.inputState.inputText.isEmpty {
                chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil)})})
                return .invoked
            }
        }
        
        return result
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        
        if let window = window, hasModals(window) {
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
        
        if let window = window, hasModals(window) {
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
        pollChannelDiscussionDisposable.dispose()
        loadThreadDisposable.dispose()
        recordActivityDisposable.dispose()
        suggestionsDisposable.dispose()
        peekDisposable.dispose()
        _ = previousView.swap(nil)
        
        context.closeFolderFirst = false
    }
    
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        suggestionsDisposable.set(nil)

        sentMessageEventsDisposable.set(nil)
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
        chatInteraction.remove(observer: self)
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
        
       
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self, let window = strongSelf.window, !hasModals(window) {
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
        
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self, let window = strongSelf.window, !hasModals(window) {
                let result:KeyHandlerResult = strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .invoked : .invokeNext
                
                
                if result == .invoked {
                    strongSelf.genericView.tableView.scrollDown()
                }
                
                return result
            }
            return .rejected
        }, with: self, for: .DownArrow, priority: .low)
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let `self` = self, let window = self.window, !hasModals(window), self.chatInteraction.presentation.interfaceState.editState == nil, self.chatInteraction.presentation.interfaceState.inputState.inputText.isEmpty {
                var currentReplyId = self.chatInteraction.presentation.interfaceState.replyMessageId
                self.genericView.tableView.enumerateItems(with: { item in
                    if let item = item as? ChatRowItem, let message = item.message {
                        if canReplyMessage(message, peerId: self.chatInteraction.peerId, mode: self.chatInteraction.mode), currentReplyId == nil || (message.id < currentReplyId!) {
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
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let `self` = self, let window = self.window, !hasModals(window), self.chatInteraction.presentation.interfaceState.editState == nil, self.chatInteraction.presentation.interfaceState.inputState.inputText.isEmpty {
                var currentReplyId = self.chatInteraction.presentation.interfaceState.replyMessageId
                self.genericView.tableView.enumerateItems(reversed: true, with: { item in
                    if let item = item as? ChatRowItem, let message = item.message {
                        if canReplyMessage(message, peerId: self.chatInteraction.peerId, mode: self.chatInteraction.mode), currentReplyId != nil && (message.id > currentReplyId!) {
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
        
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self, let window = self.window, !hasModals(window) else {return .rejected}
            
            if let selectionState = self.chatInteraction.presentation.selectionState, !selectionState.selectedIds.isEmpty {
                self.chatInteraction.deleteSelectedMessages()
                return .invoked
            }
            
            return .rejected
        }, with: self, for: .Delete, priority: .low)
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if let selectionState = self.chatInteraction.presentation.selectionState, !selectionState.selectedIds.isEmpty {
                self.chatInteraction.deleteSelectedMessages()
                return .invoked
            }
            
            return .rejected
        }, with: self, for: .ForwardDelete, priority: .low)
        
        

        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self, strongSelf.context.window.firstResponder != strongSelf.genericView.inputView.textView.inputView {
                _ = strongSelf.context.window.makeFirstResponder(strongSelf.genericView.inputView)
                return .invoked
            } else if (self?.navigationController as? MajorNavigationController)?.genericView.state == .single {
                return .invoked
            }
            return .rejected
        }, with: self, for: .Tab, priority: .high)
        
      
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self, self.mode != .scheduled, self.searchAvailable else {return .rejected}
            if !self.chatInteraction.presentation.isSearchMode.0 {
                self.chatInteraction.update({$0.updatedSearchMode((true, nil, nil))})
            } else {
                self.genericView.applySearchResponder()
            }

            return .invoked
        }, with: self, for: .F, priority: .medium, modifierFlags: [.command])
        
    
//        #if DEBUG
//        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
//            guard let `self` = self else {return .rejected}
//            showModal(with: GigagroupLandingController(context: context, peerId: self.chatLocation.peerId), for: context.window)
//            return .invoked
//        }, with: self, for: .E, priority: .medium, modifierFlags: [.command])
//        #endif
      
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeBold()
            return .invoked
        }, with: self, for: .B, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.removeAllAttributes()
            return .invoked
        }, with: self, for: .Backslash, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeUrl()
            return .invoked
        }, with: self, for: .U, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeItalic()
            return .invoked
        }, with: self, for: .I, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else { return .rejected }
            self.chatInteraction.startRecording(true, nil)
            return .invoked
        }, with: self, for: .R, priority: .medium, modifierFlags: [.command])
        
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeMonospace()
            return .invoked
        }, with: self, for: .K, priority: .medium, modifierFlags: [.command, .shift])
        
        
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
                    guard let item = self.genericView.tableView.item(at: row) as? ChatRowItem, let message = item.message, canReplyMessage(message, peerId: self.chatInteraction.peerId, mode: self.chatInteraction.mode) else {return .failed}
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
                self.updateFloatingPhotos(self.genericView.scroll, animated: false)
            case let .success(_, controller), let .failed(_, controller):
                let controller = controller as! RevealTableItemController
                guard let view = (controller.item.view as? RevealTableView) else {return .nothing}
                
                view.completeReveal(direction: direction)
                self.updateFloatingPhotos(self.genericView.scroll, animated: true)
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
       // if !context.isInGlobalSearch {
            _ = context.window.makeFirstResponder(genericView.inputView.textView.inputView)
       // }
        
        var beginPendingTime:CFAbsoluteTime?
        
       self.sentMessageEventsDisposable.set((context.account.pendingMessageManager.deliveredMessageEvents(peerId: self.chatLocation.peerId) |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { _ in
           
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

        let suggestions = getPeerSpecificServerProvidedSuggestions(postbox: context.account.postbox, peerId: self.chatLocation.peerId) |> deliverOnMainQueue
        let peerId = self.chatLocation.peerId

        suggestionsDisposable.set(suggestions.start(next: { suggestions in
            for suggestion in suggestions {
                switch suggestion {
                case .convertToGigagroup:
                    confirm(for: context.window, header: L10n.broadcastGroupsLimitAlertTitle, information: L10n.broadcastGroupsLimitAlertText(Formatter.withSeparator.string(from: NSNumber(value: context.limitConfiguration.maxSupergroupMemberCount))!), okTitle: L10n.broadcastGroupsLimitAlertLearnMore, successHandler: { _ in
                        showModal(with: GigagroupLandingController(context: context, peerId: peerId), for: context.window)
                    }, cancelHandler: {
                        showModalText(for: context.window, text: L10n.broadcastGroupsLimitAlertSettingsTip)
                    })
                    _ = dismissPeerSpecificServerProvidedSuggestion(account: context.account, peerId: peerId, suggestion: suggestion).start()
                }
            }
        }))

        
    }
    
    
    func findAndSetEditableMessage(_ bottom: Bool = false) -> Bool {
        if let view = self.previousView.with({ $0?.originalView }), view.laterId == nil {
            for entry in (!bottom ? view.entries.reversed() : view.entries) {
                if let messageId = chatInteraction.presentation.interfaceState.editState?.message.id {
                    if (messageId <= entry.message.id && !bottom) || (messageId >= entry.message.id && bottom) {
                        continue
                    }
                }
                if canEditMessage(entry.message, chatInteraction: chatInteraction, context: context)  {
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
        self.genericView.tableView.notifyScrollHandlers()
        self.genericView.updateHeader(chatInteraction.presentation, false, false)
        if let controller = globalAudio, let header = self.navigationController?.header, header.needShown {
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: genericView.tableView, supportTableView: nil)
            header.view.update(with: object)
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
    
    public init(context: AccountContext, chatLocation:ChatLocation, mode: ChatMode = .history, messageId:MessageId? = nil, initialAction: ChatInitialAction? = nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?> = Atomic<ChatLocationContextHolder?>(value: nil)) {
        self.chatLocation = chatLocation
        self.messageId = messageId
        self.chatLocationContextHolder = chatLocationContextHolder
        self.mode = mode
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
        
        if chatLocation.peerId.namespace == Namespaces.Peer.CloudChannel {
            self.adMessages = context.engine.messages.adMessages(peerId: chatLocation.peerId)
        } else {
            self.adMessages = nil
        }
        
       
        var takeTableItem:((MessageId)->TableRowItem?)? = nil
        
        self.emojiEffects = EmojiScreenEffect(context: chatInteraction.context, takeTableItem: { msgId in
            return takeTableItem?(msgId)
        })
        super.init(context)
    
        self.chatInteraction.update(animated: false, {$0.updatedInitialAction(initialAction)})
        context.checkFirstRecentlyForDuplicate(peerId: chatInteraction.peerId)
        
        let clientId = nextClientId
        nextClientId += 1

        
        self.messageProcessingManager.process = { messageIds in
            context.account.viewTracker.updateViewCountForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}), clientId: clientId)
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
                switch strongSelf.mode {
                case let .replyThread(data, _):
                    switch data.initialAnchor {
                    case .automatic:
                        if let messageId = messageId {
                            location = .InitialSearch(location: .id(messageId), count: count + 10)
                        } else {
                            location = .Initial(count: count + 10)
                        }
                    case let .lowerBoundMessage(index):
                        location = .Scroll(index: .message(index), anchorIndex: .message(index), sourceIndex: .message(index), scrollPosition: .up(false), count: count + 10, animated: false)
                    }
                default:
                    if let messageId = messageId {
                        location = .InitialSearch(location: .id(messageId), count: count + 10)
                    } else {
                        location = .Initial(count: count)
                    }
                }
               
                
                return location
            }
            return .Initial(count: 30)
        })
        _ = (self.location.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] location in
            _ = self?._locationValue.swap(location)
        })
        
        chatInteraction.contextHolder = { [weak self] in
            return self?.chatLocationContextHolder ?? Atomic(value: nil)
        }
        
        takeTableItem = { [weak self] msgId in
            if self?.isLoaded() == false {
                return nil
            }
            var found: TableRowItem? = nil
            self?.genericView.tableView.enumerateVisibleItems(with: { item in
                if let item = item as? ChatRowItem, item.message?.id == msgId {
                    found = item
                    return false
                } else {
                    return true
                }
            })
            return found
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        notify(with: value, oldValue: oldValue, animated: animated, force: false)
    }
    
    private var isPausedGlobalPlayer: Bool = false
    
    func notify(with value: Any, oldValue: Any, animated:Bool, force:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            let context = self.context
            let mode = self.chatInteraction.mode
            
            if value.selectionState != oldValue.selectionState {
                if let selectionState = value.selectionState {
                    let ids = Array(selectionState.selectedIds)
                    loadSelectionMessagesDisposable.set((context.account.postbox.messagesAtIds(ids) |> deliverOnMainQueue).start( next:{ [weak self] messages in
                        var canDelete:Bool = !ids.isEmpty
                        var canForward:Bool = !ids.isEmpty
                        if let chatInteraction = self?.chatInteraction {
                            for message in messages {
                                if !canDeleteMessage(message, account: context.account, mode: mode) {
                                    canDelete = false
                                }
                                if !canForwardMessage(message, chatInteraction: chatInteraction) {
                                    canForward = false
                                }
                            }
                            chatInteraction.update({$0.withUpdatedBasicActions((canDelete, canForward))})
                        }
                        
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
            
            if value.inputQueryResult != oldValue.inputQueryResult || value.state != oldValue.state {
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
            
            if value.selectionState != oldValue.selectionState || value.reportMode != oldValue.reportMode {
                doneButton?.isHidden = value.selectionState == nil || value.reportMode != nil
                editButton?.isHidden = value.selectionState != nil || value.reportMode != nil
            }
            
            if value.effectiveInput != oldValue.effectiveInput || value.botMenu != oldValue.botMenu || force {
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
                    
                    var disableEditingPreview:((String)->Void)? = nil
                    if oldValue.interfaceState.editState == nil, value.interfaceState.editState != nil {
                        disableEditingPreview = { [weak self] value in
                            self?.chatInteraction.update({ $0.updatedInterfaceState{
                                $0.withUpdatedComposeDisableUrlPreview(value)
                            }})
                        }
                    }
                    
                    let updateUrl = urlPreviewStateForChatInterfacePresentationState(chatInteraction.presentation, context: context, currentQuery: self.urlPreviewQueryState?.0, disableEditingPreview: disableEditingPreview) |> delay(value.effectiveInput.inputText.isEmpty ? 0.0 : 0.1, queue: .mainQueue()) |> deliverOnMainQueue
                    
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
            
            if value.isSearchMode.0 != oldValue.isSearchMode.0 || value.pinnedMessageId != oldValue.pinnedMessageId || value.peerStatus != oldValue.peerStatus || value.interfaceState.dismissedPinnedMessageId != oldValue.interfaceState.dismissedPinnedMessageId || value.initialAction != oldValue.initialAction || value.restrictionInfo != oldValue.restrictionInfo || value.hidePinnedMessage != oldValue.hidePinnedMessage || value.groupCall != oldValue.groupCall || value.reportMode != oldValue.reportMode {
                genericView.updateHeader(value, animated, value.hidePinnedMessage != oldValue.hidePinnedMessage)
                (centerBarView as? ChatTitleBarView)?.updateStatus(true, presentation: value)
            }

            if value.reportMode != oldValue.reportMode {
                (self.centerBarView as? ChatTitleBarView)?.updateSearchButton(hidden: !isSearchAvailable(value), animated: animated)
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
                navigationController?.push(controller, false, style: ViewControllerStyle.none)
            }
            
            if value.recordingState != oldValue.recordingState {
                if let state = value.recordingState {
                    let activity: PeerInputActivity = state is ChatRecordingAudioState ? .recordingVoice : .recordingInstantVideo
                    
                    let recursive = (Signal<Void, NoError>.single(Void()) |> then(.single(Void()) |> suspendAwareDelay(4, queue: .mainQueue()))) |> restart
                    
                    recordActivityDisposable.set(recursive.start(next: { [weak self] in
                        guard let `self` = self else {
                            return
                        }
                        self.context.account.updateLocalInputActivity(peerId: .init(peerId: self.chatLocation.peerId, category: self.mode.activityCategory), activity: activity, isPresent: true)
                    }))
                    
                } else if let state = oldValue.recordingState {
                    let activity: PeerInputActivity = state is ChatRecordingAudioState ? .recordingVoice : .recordingInstantVideo
                    self.context.account.updateLocalInputActivity(peerId: .init(peerId: self.chatLocation.peerId, category: self.mode.activityCategory), activity: activity, isPresent: false)
                    recordActivityDisposable.set(nil)
                }
            }
            
            dismissedPinnedIds.set(ChatDismissedPins(ids: value.interfaceState.dismissedPinnedMessageId, tempMaxId: value.tempPinnedMaxId))
           
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
        
        if let window = self.window, hasModals(window) {
            return []
        }
        
        let peerId = self.chatInteraction.peerId
        
        if let types = pasteboard.types, types.contains(.kFilenames) {
            let list = pasteboard.propertyList(forType: .kFilenames) as? [String]
            
            if let list = list, list.count > 0, let peer = chatInteraction.peer, peer.canSendMessage(chatInteraction.mode.isThreadMode) {
                
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
                        NSApp.activate(ignoringOtherApps: true)
                        _ = (Sender.generateMedia(for: MediaSenderContainer(path: list[0], isFile: false), account: strongSelf.chatInteraction.context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) |> deliverOnMainQueue).start(next: { media, _ in
                            self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                        })
                    })]
                }
                
                
                if !list.isEmpty {
                    
                    
                    let asMediaItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropQuickDesc), handler:{ [weak self] in
                        NSApp.activate(ignoringOtherApps: true)
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
                        NSApp.activate(ignoringOtherApps: true)
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
                        NSApp.activate(ignoringOtherApps: true)
                        _ = (putToTemp(image: image) |> mapToSignal {Sender.generateMedia(for: MediaSenderContainer(path: $0, isFile: false), account: strongSelf.chatInteraction.context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) } |> deliverOnMainQueue).start(next: { media, _ in
                            self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                        })
                    })]
                }
                
                var items:[DragItem] = []

                let asMediaItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropQuickDesc), handler:{ [weak self] in
                    NSApp.activate(ignoringOtherApps: true)
                    _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak self] path in
                        self?.chatInteraction.showPreviewSender([URL(fileURLWithPath: path)], true, nil)
                    })

                })
                
                let asFileItem = DragItem(title:tr(L10n.chatDropTitle), desc: tr(L10n.chatDropAsFilesDesc), handler:{ [weak self] in
                    NSApp.activate(ignoringOtherApps: true)
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
                view.updateBackground(animated: false, item: view.item)
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
        chatInteraction.update({state == .Normal ? $0.withoutSelectionState().withUpdatedRepotMode(nil) : $0.withSelectionState()})
        context.window.applyResponderIfNeeded()
    }
    
    override func initializer() -> ChatControllerView {
        return ChatControllerView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - self.bar.height), chatInteraction:chatInteraction);
    }
    
    override func requestUpdateCenterBar() {
       
    }
    
    func showChatThemeSelector() {
        self.themeSelector = ChatThemeSelectorController(context, chatTheme: chatThemeValue.get(), chatInteraction: self.chatInteraction)
        self.themeSelector?.onReady = { [weak self] controller in
            self?.genericView.showChatThemeSelector(controller.view, animated: true)
        }
        self.themeSelector?.close = { [weak self] drop in
            if drop {
                self?.chatThemeTempValue.set(.single(nil))
            }
            self?.genericView.hideChatThemeSelector(animated: true)
            self?.themeSelector = nil
            self?.chatInteraction.update({ $0.updatedInterfaceState({ $0.withUpdatedThemeEditing(false) })})
        }
        
        self.themeSelector?.previewCurrent = { [weak self] theme in
            self?.chatThemeTempValue.set(.single(theme))
        }
        
        self.themeSelector?._frameRect = NSMakeRect(0, self.frame.maxY, frame.width, 160)
        self.themeSelector?.loadViewIfNeeded()
        
        self.chatInteraction.update({ $0.updatedInterfaceState({ $0.withUpdatedThemeEditing(true) })})
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        (centerBarView as? ChatTitleBarView)?.updateStatus(presentation: chatInteraction.presentation)
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
        return previousView.with { view in
            if let view = view, let stableId = stableId.base as? ChatHistoryEntryId {
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

    
}
