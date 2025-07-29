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
import CalendarUtils
import Postbox
import SwiftSignalKit
import InAppSettings
import ObjcUtils
import ThemeSettings
import DustLayer
import CodeSyntax

private func calculateAdjustedPoint(for point: CGPoint,
                            floatingPhotosView: NSView,
                            tableView: TableView) -> CGPoint? {
    guard let tableViewDocumentView = tableView.documentView else {
        return nil
    }
    
    let floatingPhotosFrameInSuperview = floatingPhotosView.frame
    let tableViewDocumentFrameInSuperview = tableViewDocumentView.frame

    let contentOffset = tableView.contentView.bounds.origin
    let offsetX = floatingPhotosFrameInSuperview.origin.x - tableViewDocumentFrameInSuperview.origin.x + contentOffset.x
    let offsetY = floatingPhotosFrameInSuperview.origin.y - tableViewDocumentFrameInSuperview.origin.y + contentOffset.y
    let adjustedPoint = CGPoint(x: point.x + offsetX, y: point.y + offsetY)
    
    return adjustedPoint
}

struct QuoteMessageIndex : Hashable {
    let messageId: MessageId
    let index: Int
}

struct CodeSyntaxKey: Hashable {
    let messageId: MessageId
    let range: NSRange
    let language: String
    let theme: SyntaxterTheme
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(messageId)
        hasher.combine(range)
        hasher.combine(language)
        hasher.combine(theme.textColor.hexString)
    }
    
    static func ==(lhs: CodeSyntaxKey, rhs: CodeSyntaxKey) -> Bool {
        if lhs.messageId != rhs.messageId {
            return false
        }
        if lhs.range != rhs.range {
            return false
        }
        if lhs.language != rhs.language {
            return false
        }
        if lhs.theme.textFont != rhs.theme.textFont {
            return false
        }
        if lhs.theme.dark != rhs.theme.dark {
            return false
        }
        if lhs.theme.textColor != rhs.theme.textColor {
            return false
        }
        if lhs.theme.italicFont != rhs.theme.italicFont {
            return false
        }
        if lhs.theme.mediumFont != rhs.theme.mediumFont {
            return false
        }
        return true
    }
}
struct CodeSyntaxResult : Equatable {
    let resut: NSAttributedString?
}

struct ChatTitleCounters : Equatable {
    var replies: Int32?
    var online: Int32?
}

struct ChatFocusTarget {
    var messageId: MessageId
    var string: String?
    
     init?(messageId: MessageId?) {
        if let messageId = messageId {
            self.messageId = messageId
        } else {
            return nil
        }
    }
    init(messageId: MessageId, string: String?) {
        self.messageId = messageId
        self.string = string
    }
}

private var nextClientId: Int32 = 1


enum ReplyThreadMode : Equatable {
    case replies(origin: MessageId)
    case comments(origin: MessageId)
    case topic(origin: MessageId)
    case savedMessages(origin: MessageId)
    case saved(origin: MessageId)
    var originId: MessageId {
        switch self {
        case let .replies(id), let .comments(id), let .topic(id), let .savedMessages(id), let .saved(id):
            return id
        }
    }
}

public enum ChatCustomContentsKind: Equatable {
    case greetingMessageInput
    case awayMessageInput
    case quickReplyMessageInput(shortcut: String)
    case searchHashtag(hashtag: String, onlyMy: Bool)
    var text: String {
        switch self {
        case .greetingMessageInput:
            return strings().chatTitleBusinessGreetingMessages
        case .awayMessageInput:
            return strings().chatTitleBusinessAwayMessages
        case .quickReplyMessageInput(let shortcut):
            return shortcut
        case let .searchHashtag(hashtag, _):
            return "#\(hashtag)"
        }
    }
    
    var hashtag: String? {
        switch self {
        case let .searchHashtag(hashtag, _):
            return "#\(hashtag)"
        default:
            return nil
        }
    }
}


public protocol ChatCustomContentsProtocol: AnyObject {
    var kind: ChatCustomContentsKind { get }
    var messageLimit: Int? { get }
    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> { get }

    func enqueueMessages(messages: [EnqueueMessage]) -> Signal<[MessageId?],NoError>
    func deleteMessages(ids: [EngineMessage.Id])
    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool)
    
    func messagesAtIds(_ ids: [MessageId], album: Bool) -> Signal<[Message], NoError>

    
    func hashtagSearchUpdate(query: String)
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void { get set }

    func loadMore()
}

class ChatCustomLinkContent  {
    var link: String
    var text: ChatTextInputState
    var name: String {
        didSet {
            interfaceUpdate?()
        }
    }

    
    var editName: (()->Void)? = nil
    var interfaceUpdate:(()->Void)? = nil
    var saveText:((ChatTextInputState)->Void)? = nil

    init(link: String, name: String, text: ChatTextInputState) {
        self.link = link
        self.name = name
        self.text = text
    }
}

enum ChatMode : Equatable {
    static func == (lhs: ChatMode, rhs: ChatMode) -> Bool {
        switch lhs {
        case .history:
            if case .history = rhs {
                return true
            } else {
                return false
            }
        case .scheduled:
            if case .scheduled = rhs {
                return true
            } else {
                return false
            }
        case .pinned:
            if case .pinned = rhs {
                return true
            } else {
                return false
            }
        case let .thread(mode):
            if case .thread(mode) = rhs {
                return true
            } else {
                return false
            }
        case .customChatContents:
            if case .customChatContents = rhs {
                return true
            } else {
                return false
            }
        case .customLink:
            if case .customLink = rhs {
                return true
            } else {
                return false
            }
        case .preview:
            if case .preview = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    case history
    case scheduled
    case pinned
    case preview
    case thread(mode: ReplyThreadMode)
    case customChatContents(contents: ChatCustomContentsProtocol)
    case customLink(contents: ChatCustomLinkContent)
    
    var customChatContents: ChatCustomContentsProtocol? {
        switch self {
        case let .customChatContents(contents):
            return contents
        default:
            return nil
        }
    }
    
    var customChatLink: ChatCustomLinkContent? {
        switch self {
        case let .customLink(contents):
            return contents
        default:
            return nil
        }
    }

    var threadMode: ReplyThreadMode? {
        switch self {
        case let .thread(mode):
            return mode
        default:
            return nil
        }
    }
    var isSavedMessagesThread: Bool {
        switch self {
        case let .thread(mode):
            switch mode {
            case .savedMessages:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    var isSavedMode: Bool {
        switch self {
        case let .thread(mode):
            switch mode {
            case .saved:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    
    
    func activityCategory(_ threadId: Int64?) -> PeerActivitySpace.Category {
        let activityCategory: PeerActivitySpace.Category
        if let threadId {
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
        case let .thread(mode):
            switch mode {
            case .topic, .savedMessages:
                return false
            default:
                return true
            }
        default:
            return false
        }
    }
    var isTopicMode: Bool {
        switch self {
        case let .thread(mode):
            switch mode {
            case .topic:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    
    var originId: MessageId? {
        switch self {
        case let .thread(mode):
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



final class ChatWrappedEntry : Comparable, Identifiable {
    let appearance: AppearanceWrapperEntry<ChatHistoryEntry>
    let tag: HistoryViewInputTag?
    init(appearance: AppearanceWrapperEntry<ChatHistoryEntry>, tag: HistoryViewInputTag?) {
        self.appearance = appearance
        self.tag = tag
    }
    var stableId: AnyHashable {
        return appearance.entry.stableId
    }
    
    var entry: ChatHistoryEntry {
        return appearance.entry
    }
}

func ==(lhs:ChatWrappedEntry, rhs: ChatWrappedEntry) -> Bool {
    return lhs.appearance == rhs.appearance && lhs.tag == rhs.tag
}
func <(lhs:ChatWrappedEntry, rhs: ChatWrappedEntry) -> Bool {
    return lhs.appearance.entry < rhs.appearance.entry
}


final class ChatHistoryView {
    let originalView: MessageHistoryView?
    let filteredEntries: [ChatWrappedEntry]
    let theme: TelegramPresentationTheme
    init(originalView:MessageHistoryView?, filteredEntries: [ChatWrappedEntry], theme: TelegramPresentationTheme) {
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
    
    
    private var textInputSuggestionsView: InputSwapSuggestionsPanel?
    
    
    private var starUndoView: ChatStarReactionUndoView?
    
    private var videoProccesing: ChatVideoProcessingTooltip?

    
    var scroll: ScrollPosition {
        return self.tableView.scrollPosition().current
    }
    
    private var backgroundView: BackgroundView?
    private weak var navigationView: NSView?
    
    let inputView:ChatInputView
    let inputContextHelper:InputContextHelper
    private(set) var state:ChatControllerViewState = .visible
    private var searchInteractions:ChatSearchInteractions!
    private let scroller:ChatNavigationScroller
    private(set) var mentions:ChatNavigationScroller?
    private(set) var reactions:ChatNavigationScroller?
    private var progressView:ProgressIndicator?
    private let header:ChatHeaderController
    private var historyState:ChatHistoryState?
    private let chatInteraction: ChatInteraction
    
    private var monoforum_VerticalView: MonoforumVerticalView?
    private var monoforum_HorizontalView: MonoforumHorizontalView?
    private var monoforumStaticView: ImageButton?
    
    fileprivate var updateFloatingPhotos:((ScrollPosition, Bool)->Void)? = nil
    
    
    var chatTheme: TelegramPresentationTheme? {
        didSet {
            if chatTheme != oldValue {
                updateLocalizationAndTheme(theme: theme)
            }
        }
    }
    
    private var themeSelectorView: NSView?
    
    let floatingPhotosView: View = View()
    
    private let gradientMaskView = BackgroundGradientView(frame: NSZeroRect)
    
    var headerState: ChatHeaderState {
        return header.state
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    private var backgroundMode: TableBackgroundMode?
    
    func updateBackground(_ mode: TableBackgroundMode, navigationView: NSView?, isStandalone: Bool) {
        if mode != theme.controllerBackgroundMode || isStandalone {
            if let navigationView = navigationView, backgroundMode != mode, self.backgroundView == nil {
                let point = NSMakePoint(0, -frame.minY)
                let backgroundView = BackgroundView(frame: CGRect.init(origin: point, size: navigationView.bounds.size))
                backgroundView.useSharedAnimationPhase = false
                addSubview(backgroundView, positioned: .below, relativeTo: self.subviews.first)
                self.backgroundView = backgroundView
            }
            self.backgroundMode = mode
            self.backgroundView?.backgroundMode = mode
            self.navigationView = navigationView
        } else if let view = backgroundView {
            performSubviewRemoval(view, animated: true)
            self.backgroundView = nil
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
        
        
        scroller = ChatNavigationScroller(.scroller)
        inputContextHelper = InputContextHelper(chatInteraction: chatInteraction)
        tableView = TableView(frame:NSMakeRect(0,0,frameRect.width,frameRect.height - 50), isFlipped:false)
        
        inputView = ChatInputView(frame: NSMakeRect(0,tableView.frame.maxY, frameRect.width,50), chatInteraction: chatInteraction)
        //inputView.autoresizingMask = [.width]
        super.init(frame: frameRect)
        
        
        tableView.getBackgroundColor = {
            .clear
        }
        
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
        
        tableView.automaticallyAdjustsContentInsets = false
        
        addSubview(scroller, positioned: .below, relativeTo: inputView)
        
        let context = chatInteraction.context
        

        searchInteractions = ChatSearchInteractions(jump: { message in
            chatInteraction.focusMessageId(nil, .init(messageId: message.id, string: nil), .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
        }, results: { query in
            chatInteraction.modalSearch(query)
        }, calendarAction: { date in
            chatInteraction.jumpToDate(date)
        }, cancel: {
            chatInteraction.update({$0.updatedSearchMode(.init(inSearch: false))})
        }, searchRequest: { [weak chatInteraction] query, fromId, state, tags in
            guard let chatInteraction = chatInteraction else {
                return .never()
            }
            let location: SearchMessagesLocation
            switch chatInteraction.chatLocation {
            case let .peer(peerId):
                location = .peer(peerId: peerId, fromId: fromId, tags: chatInteraction.mode.tagMask, reactions: tags.map { $0.tag.reaction }, threadId: chatInteraction.chatLocation.threadId, minDate: nil, maxDate: nil)
            case let .thread(data):
                location = .peer(peerId: data.peerId, fromId: fromId, tags: nil, reactions: tags.map { $0.tag.reaction }, threadId: data.threadId, minDate: nil, maxDate: nil)
            }
            return context.engine.messages.searchMessages(location: location, query: query, state: state) |> map {($0.0.messages.filter({ !($0.extendedMedia is TelegramMediaAction) }), $0.1)}
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
        
        tableView.setSecondary(stickClass: ChatTopicSeparatorItem.self, handler: { stick in
            
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
       
    }
        
    func updateFloating(_ values:[ChatFloatingPhoto], animated: Bool, currentAnimationRows: [TableAnimationInterface.AnimateItem] = []) {
        let animated = animated && !inLiveResize && !tableView.clipView.isAnimateScrolling
        var added:[NSView] = []
        for value in values {
            if let view = value.photoView {
                let superview = value.isAnchor ? floatingPhotosView : self.tableView.documentView!

                let checker = self.tableView.documentOffset == .zero || value.point.x != view.frame.minX
                
                view.layer?.removeAnimation(forKey: "opacity")
                view._change(pos: value.point, animated: animated && view.superview == superview && checker, duration: 0.2, timingFunction: .easeOut)
                             
                let isNew = view.superview != superview
                superview.addSubview(view)

                if isNew {
                    let moveAsNew = currentAnimationRows.first(where: {
                        $0.index == value.items.first?.index
                    })
                    if let moveAsNew = moveAsNew {
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .easeOut)
                        view.layer?.animatePosition(from: value.point - (moveAsNew.to - moveAsNew.from), to: value.point, duration: 0.2, timingFunction: .easeOut)
                    }
                }
                added.append(view)
            }
        }
        let toRemove = (floatingPhotosView.subviews + self.tableView.documentView!.subviews).filter {
            !added.contains($0) && $0 is ChatAvatarView
        }
        for view in toRemove {
            performSubviewRemoval(view, animated: animated, timingFunction: .easeOut, checkCompletion: true)
        }
    }
    
    
    func showChatThemeSelector(_ view: NSView, animated: Bool) {
        self.themeSelectorView?.removeFromSuperview()
        self.themeSelectorView = view
        addSubview(view)
        updateFrame(self.frame, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    func hideChatThemeSelector(animated: Bool) {
        if let view = self.themeSelectorView {
            self.themeSelectorView = nil
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
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
    
    func updateScroller(_ historyState: ChatHistoryState) {
        let prev = self.historyState
        self.historyState = historyState
        let isHidden = (tableView.documentOffset.y < 80 && historyState.isDownOfHistory) || tableView.isEmpty

        if !isHidden {
            scroller.isHidden = false
        }
        
        let transition: ContainedViewLayoutTransition
        if prev == nil || (NSEvent.pressedMouseButtons & (1 << 0)) != 0 {
            transition = .immediate
        } else {
            transition = .animated(duration: 0.2, curve: .easeOut)
        }
        
        scroller.change(opacity: isHidden ? 0 : 1, animated: transition.isAnimated) { [weak scroller] completed in
            if completed {
                scroller?.isHidden = isHidden
            }
        }
        

        transition.updateFrame(view: scroller, frame: scrollerRect)
        
        if let mentions = mentions {
            transition.updateFrame(view: mentions, frame: mentionsRect)
        }
        if let reactions = reactions {
            transition.updateFrame(view: reactions, frame: reactionsRect)
        }
    }
    
    
    private var previousHeight:CGFloat = 50
    func inputChanged(height: CGFloat, animated: Bool) {
        if superview != nil {
            updateFrame(self.frame, transition: animated && window != nil ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        self.updateFloatingPhotos?(self.scroll, animated)
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
    
    var tableRect: NSRect {
        let inputHeight = inputView.height(for: frame.width)
        
        var tableHeight = frame.height - inputHeight - header.state.toleranceHeight
        
        if let themeSelector = themeSelectorView {
            tableHeight -= themeSelector.frame.height
            tableHeight += inputView.frame.height
        }
          
        let tableRect = NSMakeRect(0, header.state.toleranceHeight, frame.width, tableHeight)
        
        return tableRect
    }
    
    func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        
        
        var headerInset: NSPoint = NSMakePoint(0, 0)
        if let monoforum_VerticalView {
            headerInset.x += monoforum_VerticalView.frame.width
        } else if let monoforum_HorizontalView {
            headerInset.y += monoforum_HorizontalView.frame.height
        }
        
        if let view = inputContextHelper.accessoryView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, frame.height - inputView.frame.height - view.frame.height, frame.width, view.frame.height))
        }
        if let currentView = header.currentView {
            header.measure(frame.width - headerInset.x)
            
            transition.updateFrame(view: currentView, frame: NSMakeRect(headerInset.x, headerInset.y, frame.width - headerInset.x, currentView.frame.height))
            header.updateLayout(size: currentView.frame.size, transition: transition)
        }
        
        let inputHeight = inputView.height(for: frame.width)
        
        if tableRect != tableView.frame {
            transition.updateFrame(view: tableView, frame: tableRect)
        }

        
        let inputY: CGFloat = themeSelectorView != nil ? frame.height : tableView.frame.maxY
        
        let inputRect = NSMakeRect(0, inputY, frame.width, inputHeight)
        transition.updateFrame(view: inputView, frame: inputRect)
        inputView.updateLayout(size: NSMakeSize(frame.width, inputView.frame.height), transition: transition)


        
        transition.updateFrame(view: gradientMaskView, frame: tableView.frame)
        
        if let progressView = progressView {
            transition.updateFrame(view: progressView, frame: progressView.centerFrame().offsetBy(dx: headerInset.x != 0 ? headerInset.x / 2 : 0, dy: -inputView.frame.height/2))
        }
        transition.updateFrame(view: scroller, frame: scrollerRect)
        
        if let mentions = mentions {
            transition.updateFrame(view: mentions, frame: mentionsRect)
        }
        if let reactions = reactions {
            transition.updateFrame(view: reactions, frame: reactionsRect)
        }
        transition.updateFrame(view: floatingPhotosView, frame: tableView.frame)

        if let backgroundView = backgroundView, let navigationView = navigationView {
            let size = NSMakeSize(navigationView.bounds.width, navigationView.bounds.height)
            transition.updateFrame(view: backgroundView, frame: NSMakeRect(0, -(frame.minY - 50), size.width, navigationView.bounds.height))
        }
        
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            let visibleRows = self.tableView.visibleRows(frame.height)
            for i in visibleRows.lowerBound ..< visibleRows.upperBound {
                let item = self.tableView.item(at: i)
                if let view = item.view as? ChatRowView {
                    view.updateBackground(animated: transition.isAnimated, item: view.item)
                }
            }
        }
        

        if let themeSelectorView = self.themeSelectorView {
            transition.updateFrame(view: themeSelectorView, frame: NSMakeRect(0, frame.height - themeSelectorView.frame.height, frame.width, themeSelectorView.frame.height))
        }
        
        if let starUndoView {
            transition.updateFrame(view: starUndoView, frame: starUndoView.centerFrameX(y: header.state.height + 10))
        }
        
        if let videoProccesing {
            transition.updateFrame(view: videoProccesing, frame: videoProccesing.centerFrameX(y: header.state.height + 10))
        }
        
        if let monoforum_VerticalView {
            transition.updateFrame(view: monoforum_VerticalView, frame: NSMakeRect(0, 0, monoforum_VerticalView.frame.width, tableRect.height))
            monoforum_VerticalView.updateLayout(size: monoforum_VerticalView.frame.size, transition: transition)
        }
        
        if let monoforum_HorizontalView {
            transition.updateFrame(view: monoforum_HorizontalView, frame: NSMakeRect(0, 0, frame.width, monoforum_HorizontalView.frame.height))
            monoforum_HorizontalView.updateLayout(size: monoforum_HorizontalView.frame.size, transition: transition)
        }
        
        self.textInputSuggestionsView?.updateRect(transition: transition)
      //  self.updateFloatingPhotos?(self.scroll, transition.isAnimated)
        //self.chatInteraction.updateFrame(frame, transition)
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
                    
                    var leftInset: CGFloat = 0
                    if let monoforum_VerticalView {
                        leftInset += monoforum_VerticalView.frame.width / 2
                    }
                    progressView!.frame = progressView!.centerFrame().offsetBy(dx: leftInset, dy: -inputView.frame.height/2)
                }
                let currentTheme = self.chatTheme ?? theme
                if currentTheme.shouldBlurService, !isLite(.blur) {
                    progressView?.blurBackground = currentTheme.blurServiceColor
                    progressView?.backgroundColor = .clear
                } else {
                    progressView?.backgroundColor = currentTheme.chatServiceItemColor
                    progressView?.blurBackground = nil
                }
                progressView?.progressColor = currentTheme.chatServiceItemTextColor
                progressView?.layer?.cornerRadius = 15
            case .visible:
                if let view = progressView {
                    performSubviewRemoval(view, animated: animated)
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
        if interfaceState.groupCall?.data?.groupCall == nil, interfaceState.threadInfo == nil, interfaceState.chatMode != .preview {
            if let data = interfaceState.groupCall?.data {
                if data.participantCount == 0 && interfaceState.groupCall?.activeCall.scheduleTimestamp == nil {
                    voiceChat = nil
                } else {
                    voiceChat = interfaceState.groupCall
                }
            } else {
                voiceChat = nil
            }
        } else {
            voiceChat = nil
        }

        var value:ChatHeaderState.Value
        if let settings = interfaceState.peerStatus?.peerStatusSettings, let stars = settings.paidMessageStars, let peer = interfaceState.peer {
            value = .removePaidMessages(peer, stars)
        } else if let removePaidMessageFeeData = interfaceState.removePaidMessageFeeData, let peer = interfaceState.peer {
            value = .removePaidMessages(peer, removePaidMessageFeeData.amount)
        } else if interfaceState.peer?.restrictionText(interfaceState.contentSettings) != nil {
            value = .none
        } else if interfaceState.searchMode.inSearch {
            var tags: [EmojiTag]? = nil
            
            if let savedMessageTags = interfaceState.savedMessageTags {
                if interfaceState.accountPeer?.isPremium == false || !savedMessageTags.tags.isEmpty, chatInteraction.peerId == chatInteraction.context.peerId {
                    tags = []
                }
                for tag in savedMessageTags.tags {
                    switch tag.reaction {
                    case .builtin:
                        if let file = chatInteraction.context.reactions.available?.enabled.first(where: { $0.value == tag.reaction })?.activateAnimation._parse() {
                            tags?.append(.init(emoji: tag.reaction.string, tag: tag, file: file))
                        }
                    case let .custom(fileId):
                        if let file = savedMessageTags.files[fileId] {
                            tags?.append(.init(emoji: tag.reaction.string, tag: tag, file: file))
                        }
                    case .stars:
                        break
                    }
                }
            }
            
            let selected: EmojiTag?
            if let tag = interfaceState.searchMode.tag, case let .customTag(memoryBuffer, _) = tag {
                let tag = ReactionsMessageAttribute.reactionFromMessageTag(tag: memoryBuffer)
                selected = tags?.first(where: { $0.tag.reaction == tag })
            } else {
                selected = nil
            }
            
            value = .search(searchInteractions, interfaceState.searchMode.peer?._asPeer(), interfaceState.searchMode.query, tags, selected, interfaceState.chatLocation)
        } else if let threadData = interfaceState.threadInfo, threadData.isClosed, let peer = interfaceState.peer as? TelegramChannel, peer.adminRights != nil || peer.flags.contains(.isCreator) || threadData.isOwnedByMe {
            value = .restartTopic
        } else if let count = interfaceState.inviteRequestsPending, let inviteRequestsPendingPeers = interfaceState.inviteRequestsPendingPeers, !inviteRequestsPendingPeers.isEmpty, interfaceState.threadInfo == nil {
            value = .pendingRequests(Int(count), inviteRequestsPendingPeers)
        } else if interfaceState.reportMode != nil {
            value = .none
        } else if let initialAction = interfaceState.initialAction, case let .ad(kind) = initialAction {
            value = .promo(kind)
        } else if let peerStatus = interfaceState.peerStatus, let settings = peerStatus.peerStatusSettings, !settings.flags.isEmpty {
            
            if let requestChatTitle = settings.requestChatTitle, let date = settings.requestChatDate, let mainPeer = interfaceState.mainPeer {
                let text: String
                if settings.requestChatIsChannel == true {
                    text = strings().chatInviteRequestAdminChannel(mainPeer.displayTitle, requestChatTitle)
                } else {
                    text = strings().chatInviteRequestAdminGroup(mainPeer.displayTitle, requestChatTitle)
                }
                
                let formatter = DateSelectorUtil.chatFullDateFormatter
                
                let alertText = strings().chatInviteRequestInfo(requestChatTitle, formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date))))
                value = .requestChat(text, alertText)
            } else if peerStatus.canAddContact && settings.contains(.canAddContact) {
                value = .addContact(block: settings.contains(.canReport) || settings.contains(.canBlock), autoArchived: settings.contains(.autoArchived))
            } else if settings.contains(.canReport) {
                let isUser = interfaceState.peer?.isUser == true
                value = .report(autoArchived: settings.contains(.autoArchived), status: isUser ? interfaceState.peer?.emojiStatus : nil)
            } else if settings.contains(.canShareContact) {
                value = .shareInfo
            } else if let pinnedMessageId = interfaceState.pinnedMessageId, !interfaceState.interfaceState.dismissedPinnedMessageId.contains(pinnedMessageId.messageId), !interfaceState.hidePinnedMessage, interfaceState.chatMode != .pinned {
                
                let translation: ChatLiveTranslateContext.State.Result?
                if let translate = interfaceState.translateState {
                    translation = translate.result[.Key(id: pinnedMessageId.messageId, toLang: translate.to)]
                } else {
                    translation = nil
                }
                
                if pinnedMessageId.message?.restrictedText(chatInteraction.context.contentSettings) == nil {
                    value = .pinned(pinnedMessageId, translation, doNotChangeTable: interfaceState.chatLocation.threadId != nil)
                } else {
                    value = .none
                }
            } else {
                value = .none
            }
        } else if let pinnedMessageId = interfaceState.pinnedMessageId, !interfaceState.interfaceState.dismissedPinnedMessageId.contains(pinnedMessageId.messageId), !interfaceState.hidePinnedMessage, interfaceState.chatMode != .pinned {
            if pinnedMessageId.message?.restrictedText(chatInteraction.context.contentSettings) == nil {
                
                let translation: ChatLiveTranslateContext.State.Result?
                if let translate = interfaceState.translateState {
                    translation = translate.result[.Key(id: pinnedMessageId.messageId, toLang: translate.to)]
                } else {
                    translation = nil
                }
                
                value = .pinned(pinnedMessageId, translation, doNotChangeTable: interfaceState.chatLocation.threadId != nil)
            } else {
                value = .none
            }
        } else if let canAdd = interfaceState.canAddContact, canAdd {
            value = .none
        } else {
            value = .none
        }
        var translate: ChatPresentationInterfaceState.TranslateState?
        if interfaceState.peer?.restrictionText(interfaceState.contentSettings) == nil, interfaceState.chatMode != .preview {
            if let translateState = interfaceState.translateState, translateState.canTranslate {
                if case .search = value {
                    translate = nil
                } else {
                    translate = translateState
                }
            } else {
                translate = nil
            }
        } else {
            translate = nil
        }
        
        let botAd: Message? = (interfaceState.historyCount ?? 0) >= 2 ? interfaceState.adMessage : nil
        
             
        let state: ChatHeaderState = .init(main: value, voiceChat: voiceChat, translate: translate, botManager: interfaceState.chatMode == .preview ? nil : interfaceState.connectedBot, botAd: botAd.flatMap { .init(message: $0, chatInteraction: chatInteraction) })

        state.measure(frame.width - (interfaceState.monoforumState == .vertical ? 80 : 0))

        header.updateState(state, animated: animated, for: self, inset: interfaceState.monoforumState == .vertical ? 80 : 0, relativeView: self.monoforum_HorizontalView)
        
        tableView.updateStickInset(state.height - state.toleranceHeight + (interfaceState.monoforumState == .horizontal ? 40 : 0), animated: animated)

        if superview != nil {
            updateFrame(frame, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        if let count = interfaceState.historyCount, count > 0 {
            tableView.contentInsets = .init(top: state.height)
        } else {
            tableView.contentInsets = .init(top: 0)
        }
    }
    
    func updateMonoforumState(state: MonoforumUIState?, items: [MonoforumItem], threadId: Int64?, animated: Bool) {
        if let state {
            switch state {
            case .horizontal:
                if let view = monoforum_VerticalView {
                    performSubviewPosRemoval(view, pos: NSMakePoint(-view.frame.width, 0), animated: animated)
                    self.monoforum_VerticalView = nil
                }
                
                let current: MonoforumHorizontalView
                if let view = self.monoforum_HorizontalView {
                    current = view
                } else {
                    current = MonoforumHorizontalView(frame: NSMakeRect(0, 0, frame.width, 40))
                    addSubview(current, positioned: .below, relativeTo: inputView)
                    self.monoforum_HorizontalView = current
                    
                    if animated {
                        current.layer?.animateAlpha(from: 0.5, to: 1, duration: 0.2)
                        current.layer?.animatePosition(from: NSMakePoint(0, -current.frame.height), to: .zero)
                    }
                }
                                
                current.set(items: items, selected: threadId, chatInteraction: chatInteraction, animated: animated)
                
            case .vertical:
                if let view = monoforum_HorizontalView {
                    performSubviewPosRemoval(view, pos: NSMakePoint(0, -view.frame.height), animated: animated)
                    self.monoforum_HorizontalView = nil
                }
                
                let current: MonoforumVerticalView
                if let view = self.monoforum_VerticalView {
                    current = view
                } else {
                    current = MonoforumVerticalView(frame: NSMakeRect(0, 0, 80, tableRect.height))
                    addSubview(current, positioned: .below, relativeTo: inputView)
                    self.monoforum_VerticalView = current
                    
                    if animated {
                        current.layer?.animateAlpha(from: 0.5, to: 1, duration: 0.2)
                        current.layer?.animatePosition(from: NSMakePoint(-current.frame.width, 0), to: .zero)
                    }
                }
                
                current.set(items: items, selected: threadId, chatInteraction: chatInteraction, animated: animated)
            }
            
            let current: ImageButton
            if let view = self.monoforumStaticView {
                current = view
            } else {
                current = ImageButton()
                addSubview(current)
                self.monoforumStaticView = current
                current.autohighlight = false
                current.animates = false
                current.scaleOnClick = true
            }
            current.set(image: NSImage(resource: .iconMonoforumToggle).precomposed(state == .vertical ? theme.colors.accent : theme.colors.grayIcon), for: .Normal)
            current.sizeToFit(.zero, NSMakeSize(80, 40), thatFit: true)
            
            current.setSingle(handler: { [weak chatInteraction] _ in
                chatInteraction?.toggleMonoforumState()
            }, for: .Click)
        } else {
            if let view = monoforum_VerticalView {
                performSubviewPosRemoval(view, pos: NSMakePoint(-view.frame.width, 0), animated: animated)
                self.monoforum_VerticalView = nil
            }
            if let view = monoforum_HorizontalView {
                performSubviewPosRemoval(view, pos: NSMakePoint(0, -view.frame.height), animated: animated)
                self.monoforum_HorizontalView = nil
            }
            if let view = monoforumStaticView {
                performSubviewRemoval(view, animated: animated)
                self.monoforumStaticView = nil
            }
        }
        
        updateFrame(self.frame, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    private var scrollerRect: NSRect {
        return NSMakeRect(frame.width - scroller.frame.width - 6,  frame.height - inputView.frame.height - 6 - scroller.frame.height, scroller.frame.width, scroller.frame.height)
    }
    private var mentionsRect: NSRect {
        if let _ = mentions {
            if scroller.controlIsHidden {
                return scrollerRect.offsetBy(dx: 0, dy: 0)
            } else {
                return scrollerRect.offsetBy(dx: 0, dy: scroller.hasBadge ? -56 : -50)
            }
        }
        return .zero
    }
    private var reactionsRect: NSRect {
        if let _ = reactions {
            if let mentions = mentions {
                if scroller.controlIsHidden {
                    return mentionsRect.offsetBy(dx: 0, dy: 0)
                } else {
                    return mentionsRect.offsetBy(dx: 0, dy: mentions.hasBadge ? -56 : -50)
                }
            } else {
                if scroller.controlIsHidden {
                    return scrollerRect.offsetBy(dx: 0, dy: 0)
                } else {
                    return scrollerRect.offsetBy(dx: 0, dy: scroller.hasBadge ? -56 : -50)
                }
            }
        }
        return .zero
    }
        
    var hasEmojiSwap: Bool {
        return self.textInputSuggestionsView != nil
    }
    
    func updateTextInputSuggestions(_ files: [TelegramMediaFile], range: NSRange, animated: Bool) {
        if !files.isEmpty {
            let current: InputSwapSuggestionsPanel
            let isNew: Bool
            if let view = self.textInputSuggestionsView {
                current = view
                isNew = false
            } else {
                current = InputSwapSuggestionsPanel(inputView: self.inputView.textView, textContent: self.inputView.textView.scrollView.contentView, relativeView: self, window: chatInteraction.context.window, context: chatInteraction.context, highlightRect: { [weak self] range, whole in
                    return self?.inputView.textView.highlight(for: range, whole: whole) ?? .zero
                })
                self.textInputSuggestionsView = current
                isNew = true
            }
            current.apply(files, range: range, animated: animated, isNew: isNew)
        } else if let view = self.textInputSuggestionsView {
            view.close(animated: animated)
            self.textInputSuggestionsView = nil
        }
    }
    
    func updateMentionsCount(mentionsCount: Int32, reactionsCount: Int32, scrollerCount: Int32, animated: Bool) {
        if mentionsCount > 0 {
            if self.mentions == nil {
                self.mentions = ChatNavigationScroller(.mentions)
                self.mentions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.mentionPressed()
                }, for: .Click)
                
                self.mentions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.clearMentions()
                }, for: .LongMouseDown)
                
                if let mentions = self.mentions {
                    mentions.frame = mentionsRect
                    mentions.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    addSubview(mentions, positioned: .below, relativeTo: inputView)
                }             
            }
            self.mentions?.updateCount(mentionsCount)
        } else {
            if let mentions = self.mentions {
                self.mentions = nil
                performSubviewRemoval(mentions, animated: true, scale: true)
            }
        }
        if reactionsCount > 0 {
            if self.reactions == nil {
                self.reactions = ChatNavigationScroller(.reactions)
                self.reactions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.reactionPressed()
                }, for: .Click)
                
                self.reactions?.set(handler: { [weak self] _ in
                    self?.chatInteraction.clearReactions()
                }, for: .LongMouseDown)
                
                if let reactions = self.reactions {
                    reactions.frame = reactionsRect
                    reactions.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    addSubview(reactions, positioned: .below, relativeTo: inputView)
                }
            }
            self.reactions?.updateCount(reactionsCount)
        } else {
            if let reactions = self.reactions {
                self.reactions = nil
                performSubviewRemoval(reactions, animated: true, scale: true)
            }
        }
        scroller.updateCount(scrollerCount)
        needsLayout = true
    }
    
    func applySearchResponder() {
        header.applySearchResponder()
    }

    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {

        super.updateLocalizationAndTheme(theme: theme)
        
        let chatTheme = self.chatTheme ?? theme as! TelegramPresentationTheme
        
        if chatTheme.shouldBlurService, !isLite(.blur) {
            progressView?.blurBackground = chatTheme.blurServiceColor
            progressView?.backgroundColor = .clear
        } else {
            progressView?.backgroundColor = chatTheme.colors.background.withAlphaComponent(0.7)
            progressView?.blurBackground = nil
        }
        progressView?.progressColor = chatTheme.chatServiceItemTextColor
        scroller.updateLocalizationAndTheme(theme: chatTheme)
        tableView.emptyItem = ChatEmptyPeerItem(tableView.frame.size, chatInteraction: chatInteraction, theme: chatTheme)
    }

    
    func forceCancelPendingStars() {
        if let starUndoView = self.starUndoView {
            performSubviewRemoval(starUndoView, animated: true)
            self.starUndoView = nil
        }
    }
    
    func updateStars(context: AccountContext, count: Int32, messageId: MessageId) {
        let current: ChatStarReactionUndoView
        let animated: Bool
        if let view = self.starUndoView {
            current = view
            animated = true
        } else {
            current = ChatStarReactionUndoView(frame: .zero)
            addSubview(current)
            self.starUndoView = current
            animated = false
            
        }
        let size = current.update(context: context, messageId: messageId, count: count, animated: animated, complete: { [weak self] in
            if let starUndoView = self?.starUndoView {
                performSubviewRemoval(starUndoView, animated: true)
                self?.starUndoView = nil
            }
        }, undo: {
            context.engine.messages.cancelPendingSendStarsReaction(id: messageId)
        })
        
        let rect = self.frame.focusX(size, y: header.state.height + 10)
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        transition.updateFrame(view: current, frame: rect)
        
        if !animated {
            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
        }
        
        self.updateFrame(self.frame, transition: transition)
    }
    
    func showVideoProccessingTooltip(context: AccountContext, source: ChatVideoProcessingTooltip.Source, animated: Bool) {
        let current: ChatVideoProcessingTooltip
        let animated: Bool
        if let view = self.videoProccesing {
            current = view
            animated = true
        } else {
            current = ChatVideoProcessingTooltip(frame: .zero)
            addSubview(current)
            self.videoProccesing = current
            animated = false
            
        }
        let size = current.update(context: context, source: source, animated: animated, complete: { [weak self] in
            if let videoProccesing = self?.videoProccesing {
                performSubviewRemoval(videoProccesing, animated: true)
                self?.videoProccesing = nil
            }
        })
        
        let rect = self.frame.focusX(size, y: header.state.height + 10)
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        transition.updateFrame(view: current, frame: rect)
        
        if !animated {
            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
        }
        
        self.updateFrame(self.frame, transition: transition)

    }
    
}




fileprivate func prepareEntries(from fromView:ChatHistoryView?, to toView:ChatHistoryView, timeDifference: TimeInterval, initialSize:NSSize, interaction:ChatInteraction, animated:Bool, scrollPosition:ChatHistoryViewScrollPosition?, reason:ChatHistoryViewUpdateType, animationInterface:TableAnimationInterface?, side: TableSavingSide?, messagesViewQueue: Queue) -> Signal<TableUpdateTransition, NoError> {
    return Signal { subscriber in
    
//        subscriber.putNext(TableUpdateTransition(deleted: [], inserted: [], updated: [], animated: animated, state: .none(nil), grouping: true))
//        subscriber.putCompletion()
        
        var initialSize = initialSize
        initialSize.height -= 50
        
        var scrollToItem:TableScrollState? = nil
        var animated = animated
        var offset:CGFloat = 0
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .unread(unreadIndex):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case .UnreadEntry = entry.appearance.entry {
                        scrollToItem = .top(id: entry.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: offset)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    scrollToItem = .saveVisible(.upper, true)
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
            case let .scroll(state):
                scrollToItem = state
            }
        }
        
        if scrollToItem == nil {
            scrollToItem = .saveVisible(side ?? .upper, false)
            
            switch reason {
            case let .Generic(type):
                switch type {
                case .Generic:
                    scrollToItem = .none(animationInterface)
                default:
                    break
                }
            case let .Initial(fadeIn):
                if !fadeIn {
                    scrollToItem = .saveVisible(side ?? .upper, true)
                }
            }
        }  else {
            var bp = 0
            bp += 1
        }
        
        
        func makeItem(_ entry: ChatWrappedEntry) -> TableRowItem {
            
            let presentation: TelegramPresentationTheme = entry.entry.additionalData.chatTheme ?? theme
            
            let item:TableRowItem = ChatRowItem.item(initialSize, from: entry.appearance.entry, interaction: interaction, theme: presentation)
            _ = item.makeSize(initialSize.width)
            return item;
        }
        
        let firstTransition = Queue.mainQueue().isCurrent()
        let cancelled = Atomic(value: false)
        
        let prevIsLoading = fromView?.originalView == nil || fromView?.originalView?.isLoading == true 
        
        if firstTransition, let state = scrollToItem, prevIsLoading {
                        
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
                        if !item.ignoreAtInitialization {
                            height += item.height
                        }
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
                            if !item.ignoreAtInitialization {
                                height += item.height
                            }
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
                    if !item.ignoreAtInitialization {
                        height += item.height
                    }
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
                            if !item.ignoreAtInitialization {
                                lowHeight += item.height
                            }
                            firstInsertion.append((low, item))
                        }
                        
                        if ((initialSize.height + offset) / 2) >= highHeight && !highSuccess  {
                            let item = makeItem(entries[high])
                            if !item.ignoreAtInitialization {
                                highHeight += item.height
                            }
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
                    
                    let copy = firstInsertion
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
                    if !item.ignoreAtInitialization {
                        height += item.height
                    }
                    if initialSize.height < height {
                        break
                    }
                }
            }
            var scrollState = state
            var ignoreHeight: CGFloat = 0
            for (_, item) in firstInsertion.reversed() {
                if item.ignoreAtInitialization {
                    ignoreHeight += item.height
                } else {
                    if ignoreHeight > 0 {
                        scrollState = .bottom(id: item.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: ignoreHeight)
                    }
                }
            }
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: scrollState, isPartOfTransition: true))
             
            
            messagesViewQueue.async {
                if !cancelled.with({ $0 }) {
                    
                    var firstInsertedRange:NSRange = NSMakeRange(0, 0)
                    
                    if !firstInsertion.isEmpty {
                        firstInsertedRange = NSMakeRange(initialIndex, firstInsertion.count)
                    }
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    let finish:()->Void = {
                        subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .saveVisible(.upper, false)))
                        subscriber.putCompletion()
                    }
                    
                    var mustBreak = false
                    for i in 0 ..< entries.count {
                        let item:TableRowItem
                        if cancelled.with({ $0 }) || mustBreak {
                            mustBreak = true
                            subscriber.putCompletion()
                            return
                        }
                        if firstInsertedRange.indexIn(i) {
                            //item = firstInsertion[i - initialIndex].1
                            //updates.append((i, item))
                        } else {
                            item = makeItem(entries[i])
                            insertions.append((i, item))
                        }
                        if i == entries.count - 1 {
                            finish()
                        }
                    }
                }
            }
            
        } else if let state = scrollToItem {
            let (removed,inserted,updated) = proccessEntries(fromView?.filteredEntries, right: toView.filteredEntries, { entry -> TableRowItem in
                if !cancelled.with({ $0 }) {
                    return makeItem(entry)
                } else {
                    return TableRowItem(initialSize)
                }
            })

            let grouping: Bool = true
            
            var scrollState = state
            if removed.isEmpty, !inserted.isEmpty {
                var addAdded: Bool = true
                for inserted in inserted {
                    if !inserted.1.ignoreAtInitialization {
                        addAdded = false
                        break
                    }
                }
                if addAdded {
                    scrollState = .saveVisible(.lower, false)
                }
            }
                        
            subscriber.putNext(TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: scrollState.animated, state: scrollState, grouping: grouping, animateVisibleOnly: true))
            subscriber.putCompletion()
        }
        return ActionDisposable {
            _ = cancelled.swap(true)
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

private final class ChatAdData {
    var preloadAdPeerId: PeerId?
    let preloadAdPeerDisposable = MetaDisposable()
    var pendingDynamicAdMessages: [Message] = []
    var pendingDynamicAdMessageInterval: Int?
    var remainingDynamicAdMessageInterval: Int?
    var remainingDynamicAdMessageDistance: CGFloat?
    var nextPendingDynamicMessageId: Int32 = 1
    private var seenMessageIds = Set<MessageId>()
    private var height: CGFloat = 0


    private let disposable = MetaDisposable()
    let context: AdMessagesHistoryContext
    
    private var allAdMessages: (fixed: Message?, opportunistic: [Message], version: Int) = (nil, [], 0) {
            didSet {
                self.allAdMessagesPromise.set(.single(self.allAdMessages))
            }
        }
    private let allAdMessagesPromise = Promise<(fixed: Message?, opportunistic: [Message], version: Int)>((nil, [], 0))
    
    var allMessages: Signal<(fixed: Message?, opportunistic: [Message], version: Int), NoError> {
        return allAdMessagesPromise.get()
    }


    init(context: AccountContext, height: Signal<CGFloat, NoError>, peerId: PeerId) {
        self.context = context.engine.messages.adMessages(peerId: peerId)
        let signal = (combineLatest(self.context.state, height)
                      |> deliverOnMainQueue)
        
        disposable.set(signal.start(next: { [weak self] values in
            guard let `self` = self else {
                return
            }
            let (interPostInterval, messages, _, _) = values.0
            let height = values.1
            self.height = height
            
            if let interPostInterval = interPostInterval {
                self.pendingDynamicAdMessages = messages
                self.pendingDynamicAdMessageInterval = Int(interPostInterval)
                
                if self.remainingDynamicAdMessageInterval == nil {
                    self.remainingDynamicAdMessageInterval = Int(interPostInterval)
                }
                if self.remainingDynamicAdMessageDistance == nil {
                    self.remainingDynamicAdMessageDistance = height
                }
                
                self.allAdMessages = (messages.first, [], 0)
            } else {
                var adPeerId: PeerId?
                adPeerId = messages.first?.author?.id
                
                if self.preloadAdPeerId != adPeerId {
                    self.preloadAdPeerId = adPeerId
                    if let adPeerId = adPeerId {
                        let combinedDisposable = DisposableSet()
                        self.preloadAdPeerDisposable.set(combinedDisposable)
                        combinedDisposable.add(context.account.viewTracker.polledChannel(peerId: adPeerId).start())
                        combinedDisposable.add(context.account.addAdditionalPreloadHistoryPeerId(peerId: adPeerId))
                    } else {
                        self.preloadAdPeerDisposable.set(nil)
                    }
                }
                
                self.allAdMessages = (messages.first, [], 0)
            }
        }))

    }
    
    
    private func maybeInsertPendingAdMessage(tableView: TableView, position: ScrollPosition, toLaterRange: (Int, Int), toEarlierRange: (Int, Int)) {
        if self.pendingDynamicAdMessages.isEmpty {
            return
        }
        
        let currentPrefetchDirectionIsToLater = position.direction == .top

        let selectedRange: (Int, Int)
        let range:[Int]
        let reverse: Bool
        if currentPrefetchDirectionIsToLater {
            selectedRange = (toLaterRange.0, toLaterRange.1)
            reverse = true
        } else {
            selectedRange = (toEarlierRange.0, toEarlierRange.1)
            reverse = false
        }
        if selectedRange.0 <= selectedRange.1 {
            if reverse {
                range = (selectedRange.0 ... selectedRange.1).reversed()
            } else {
                range = Array((selectedRange.0 ... selectedRange.1))
            }
        } else {
            range = []
        }
        
        if !range.isEmpty {
            var insertionTimestamp: Int32?
            for i in range {
                let item = tableView.item(at: i) as? ChatRowItem
                if let message = item?.message, message.id.namespace == Namespaces.Message.Cloud, message.adAttribute == nil {
                    
                    insertionTimestamp = message.timestamp
                    break
                }
            }

            if let insertionTimestamp = insertionTimestamp {
                let initialMessage = self.pendingDynamicAdMessages.removeFirst()
                let message = Message(
                    stableId: UInt32.max - 1 - UInt32(self.nextPendingDynamicMessageId),
                    stableVersion: initialMessage.stableVersion,
                    id: MessageId(peerId: initialMessage.id.peerId, namespace: initialMessage.id.namespace, id: self.nextPendingDynamicMessageId),
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    groupInfo: nil,
                    threadId: nil,
                    timestamp: insertionTimestamp,
                    flags: initialMessage.flags,
                    tags: initialMessage.tags,
                    globalTags: initialMessage.globalTags,
                    localTags: initialMessage.localTags, 
                    customTags: initialMessage.customTags,
                    forwardInfo: initialMessage.forwardInfo,
                    author: initialMessage.author,
                    text: initialMessage.text,
                    attributes: initialMessage.attributes,
                    media: initialMessage.media,
                    peers: initialMessage.peers,
                    associatedMessages: initialMessage.associatedMessages,
                    associatedMessageIds: initialMessage.associatedMessageIds,
                    associatedMedia: initialMessage.associatedMedia,
                    associatedThreadInfo: initialMessage.associatedThreadInfo,
                    associatedStories: initialMessage.associatedStories
                )
                self.nextPendingDynamicMessageId += 1

                var allAdMessages = self.allAdMessages
                if allAdMessages.fixed?.adAttribute?.opaqueId == message.adAttribute?.opaqueId {
                    allAdMessages.fixed = self.pendingDynamicAdMessages.first?.withUpdatedStableVersion(stableVersion: UInt32(self.nextPendingDynamicMessageId))
                }
                allAdMessages.opportunistic.append(message)
                allAdMessages.version += 1
                self.allAdMessages = allAdMessages
            }
        }
    }
    
    func update(items allVisibleAnchorMessageIds: [(MessageId, Int)], tableView: TableView, position: ScrollPosition) {
        let visible = tableView.visibleRows()
        
        let toEarlierRange = (visible.upperBound + 1, tableView.count - 1)
        let toLaterRange = (0, visible.lowerBound)

        for (messageId, index) in allVisibleAnchorMessageIds {
            let itemHeight = tableView.item(at: index).height
            
            if self.seenMessageIds.insert(messageId).inserted, let remainingDynamicAdMessageIntervalValue = self.remainingDynamicAdMessageInterval, let remainingDynamicAdMessageDistanceValue = self.remainingDynamicAdMessageDistance {
                
                let remainingDynamicAdMessageInterval = remainingDynamicAdMessageIntervalValue - 1
                let remainingDynamicAdMessageDistance = remainingDynamicAdMessageDistanceValue - itemHeight
                if remainingDynamicAdMessageInterval <= 0 && remainingDynamicAdMessageDistance <= 0.0 {
                    self.remainingDynamicAdMessageInterval = self.pendingDynamicAdMessageInterval
                    self.remainingDynamicAdMessageDistance = self.height
                    self.maybeInsertPendingAdMessage(tableView: tableView, position: position, toLaterRange: toLaterRange, toEarlierRange: toEarlierRange)
                } else {
                    self.remainingDynamicAdMessageInterval = remainingDynamicAdMessageInterval
                    self.remainingDynamicAdMessageDistance = remainingDynamicAdMessageDistance
                }
            }
        }
    }
    
    func markAsSeen(opaqueId: Data) {
        for i in 0 ..< self.pendingDynamicAdMessages.count {
            if let pendingAttribute = self.pendingDynamicAdMessages[i].adAttribute, pendingAttribute.opaqueId == opaqueId {
                self.pendingDynamicAdMessages.remove(at: i)
                break
            }
        }
        self.context.markAsSeen(opaqueId: opaqueId)
    }

    func markAction(opaqueId: Data, media: Bool) {
        self.context.markAction(opaqueId: opaqueId, media: media, fullscreen: false)
    }
    
    func remove(opaqueId: Data) {
        self.context.remove(opaqueId: opaqueId)
    }
    
    deinit {
        disposable.dispose()
        preloadAdPeerDisposable.dispose()
    }
}

class ChatController: EditableViewController<ChatControllerView>, Notifable, TableViewDelegate {
    
    var chatLocation: ChatLocation {
        return chatInteraction.chatLocation
    }
    private let peerView = Promise<PostboxView?>()
    
    private let emojiEffects: EmojiScreenEffect
//    private var reactionManager:AddReactionManager?
    
    private let queue: Queue = .init(name: "messagesViewQueue", qos: .utility)


    private let historyDisposable:MetaDisposable = MetaDisposable()
    private let peerDisposable:MetaDisposable = MetaDisposable()
    private let titleUpdateDisposable:MetaDisposable = MetaDisposable()

    private let updatedChannelParticipants:MetaDisposable = MetaDisposable()
    private let sentMessageEventsDisposable = MetaDisposable()
    private let proccessingMessageEventsDisposable = MetaDisposable()
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
    private let interactiveReadReactionsDisposable: MetaDisposable = MetaDisposable()
    private let deleteChatDisposable: MetaDisposable = MetaDisposable()
    private let loadSelectionMessagesDisposable: MetaDisposable = MetaDisposable()
    private let updateMediaDisposable = MetaDisposable()
    private let editCurrentMessagePhotoDisposable = MetaDisposable()
    private let failedMessageEventsDisposable = MetaDisposable()
    private let monoforumTopicsDisposable = MetaDisposable()
    private let selectMessagePollOptionDisposables: DisposableDict<MessageId> = DisposableDict()
    private let codeSyntaxHighlightDisposables: DisposableDict<CodeSyntaxKey> = DisposableDict()

    private let hasScheduledMessagesDisposable = MetaDisposable()
    private let discussionDataLoadDisposable = MetaDisposable()
    private let slowModeDisposable = MetaDisposable()
    private let slowModeInProgressDisposable = MetaDisposable()
    private let forwardMessagesDisposable = MetaDisposable()
    private let shiftSelectedDisposable = MetaDisposable()
    private let updateUrlDisposable = MetaDisposable()
    private let pollChannelDiscussionDisposable = MetaDisposable()
    private let peekDisposable = MetaDisposable()
    private let loadThreadDisposable = MetaDisposable()
    private let recordActivityDisposable = MetaDisposable()
    private let suggestionsDisposable = MetaDisposable()
    private let sendAsPeersDisposable = MetaDisposable()
    private let startSecretChatDisposable = MetaDisposable()
    private let inputSwapDisposable = MetaDisposable()
    private let liveTranslateDisposable = MetaDisposable()
    private let presentationDisposable = DisposableSet()
    private let storiesDisposable = MetaDisposable()
    private let keepShortcutDisposable = MetaDisposable()
    
    private let preloadPersonalChannel = MetaDisposable()
    private let premiumOrStarsRequiredDisposable = MetaDisposable()
    
    private var keepMessageCountersSyncrhonizedDisposable: Disposable?
    private var keepSavedMessagesSyncrhonizedDisposable: Disposable?
    private var networkSpeedEventsDisposable: Disposable?


    private let searchState: ValuePromise<SearchMessagesResultState> = ValuePromise(SearchMessagesResultState("", []), ignoreRepeated: true)

    
    private let topVisibleMessageRange = ValuePromise<ChatTopVisibleMessageRange?>(nil, ignoreRepeated: true)
    private let dismissedPinnedIds = ValuePromise<ChatDismissedPins>(ChatDismissedPins(ids: [], tempMaxId: nil), ignoreRepeated: true)

    private let visibleMessageRange: Atomic<VisibleMessageRange> = Atomic(value: .init(lowerBound: .absoluteLowerBound(), upperBound: nil))

    private var grouppedFloatingPhotos: [([ChatRowItem], ChatAvatarView)] = []
    
    private let chatThemeValue: Promise<(String?, TelegramPresentationTheme)> = Promise((nil, theme))
    private let chatThemeTempValue: Promise<(String?, TelegramPresentationTheme)?> = Promise(nil)

   
    var chatInteraction:ChatInteraction
    
    
    var nextTransaction:TransactionHandler = TransactionHandler()
    
    private let _historyReady = Promise<Bool>()
    private var didSetHistoryReady = false

    
    private let _monoforumReady = Promise<Bool>()

    
    private var currentPeerView: PeerView? {
        didSet {
          //  self.reactionManager?.updatePeerView(currentPeerView)
        }
    }
    
    private let location:Promise<ChatHistoryLocationInput> = Promise()
    private let _locationValue:Atomic<ChatHistoryLocationInput?> = Atomic(value: nil)
    private var locationValue:ChatHistoryLocationInput? {
        return _locationValue.with { $0 }
    }

    private func setLocation(_ location: ChatHistoryLocationInput) {
        _ = _locationValue.swap(location)
        self.location.set(.single(location))
    }
    
    private func setLocation(_ location: ChatHistoryLocation, chatLocation: ChatLocation? = nil) {
        let chatLocation = chatLocation ?? self.locationValue?.chatLocation
        if let chatLocation {
            let input = ChatHistoryLocationInput(content: location, chatLocation: chatLocation, tag: self.locationValue?.tag, id: self.takeNextHistoryLocationId())
            _ = _locationValue.swap(input)
            self.location.set(.single(input))
        }
    }
    
    //    var content: ChatHistoryLocation

    
    private var chatLocationValue: Signal<ChatLocation, NoError> {
        return self.location.get() |> map { $0.chatLocation }
    }
    

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
    
    private let visibility = ValuePromise(true, ignoreRepeated: true)
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?

    
    let layoutDisposable:MetaDisposable = MetaDisposable()
    
    private var afterNextTransaction:(()->Void)?
    
    private var currentAnimationRows:[TableAnimationInterface.AnimateItem] = []
    
    private let adMessages: ChatAdData?
    
    
    private var liveTranslate: ChatLiveTranslateContext?
    private var stories: PeerExpiringStoryListContext?
    private var themeSelector: ChatThemeSelectorController? = nil
    
    private let uiState: Atomic<State> = Atomic(value: State())
    private let stateValue: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
        
    
    private var groupsInCommon: GroupsInCommonContext?
    
    private struct State : Equatable {
        
      
        
        var transribe: [MessageId: TranscribeAudioState] = [:]
        var topicCreatorId: PeerId?
        var threadLoading: MessageId?
        var pollAnswers: [MessageId : ChatPollStateData] = [:]
        var mediaRevealed: Set<MessageId> = Set()
        var translate: ChatLiveTranslateContext.State?
        var storyState: PeerExpiringStoryListContext.State?
        var presentation:TelegramPresentationTheme = theme
        var presentation_genuie:TelegramPresentationTheme = theme
        var bespoke_wallpaper: ThemeWallpaper?
        var presentation_emoticon: String? = nil
        var factCheck: Set<MessageId> = Set()
        
        var quoteRevealed: Set<QuoteMessageIndex> = Set()
        
        var answersAndOnline: ChatTitleCounters = .init()
        
        var codeSyntaxes: [CodeSyntaxKey : CodeSyntaxResult] = [:]
        
        var peerStatus: PeerStatusSettings? = nil
        
        var commonGroups: GroupsInCommonState?
        
        var monoforumState: MonoforumUIState?
    }
    private func updateState(_ f:(State)->State) -> Void {
        stateValue.set(uiState.modify(f))
    }
    
    private let transcribeDisposable = DisposableDict<MessageId>()
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let unsupportedMessageProcessingManager = ChatMessageThrottledProcessingManager()
    private let reactionsMessageProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 4.0)
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    private let messageReactionsMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    private let refreshStoriesProcessingManager = ChatMessageThrottledProcessingManager()
    private let extendedMediaProcessingManager = ChatMessageVisibleThrottledProcessingManager()
    private let seenLiveLocationProcessingManager = ChatMessageThrottledProcessingManager()
    private let refreshMediaProcessingManager = ChatMessageThrottledProcessingManager()
    private let factCheckProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 1.0)



    var historyState:ChatHistoryState = ChatHistoryState() {
        didSet {
            assertOnMainThread()
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

    func scrollUpOrToUnread() {
        self.scrollup()
    }
    
    override func scrollup(force: Bool = false) -> Void {
        
        assertOnMainThread()
        
        chatInteraction.update({ $0.withUpdatedTempPinnedMaxId(nil) })
        
        self.messageIndexDisposable.set(nil)
        
        if let reply = historyState.reply() {
            
            chatInteraction.focusMessageId(nil, .init(messageId: reply, string: nil), .CenterEmpty)
            historyState = historyState.withRemovingReplies(max: reply)
        } else {
            let laterId = previousView.with { $0?.originalView?.laterId }
            if laterId != nil {
                
                let history: ChatHistoryLocation = .Scroll(index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, sourceIndex: MessageHistoryAnchorIndex.upperBound, scrollPosition: .down(!force), count: requestCount, animated: true)
                
                let historyView = preloadedChatHistoryViewForLocation(history, context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, tag: locationValue?.tag, additionalData: [])
                

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
                genericView.tableView.scroll(to: .down(!force))
            }

        }
        
    }
    
    private var requestCount: Int {
        return 30
    }
    
    func readyHistory() {
        if !didSetHistoryReady {
            didSetHistoryReady = true
            _historyReady.set(.single(true))
        }
    }
    
    override var sidebar:ViewController? {
        return context.bindings.entertainment()
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
            
            let items = groupped.0
            
            
            guard !items.isEmpty else {
                continue
            }
            
            var point: NSPoint = .init(x: groupped.0[0].leftInset, y: 0)


            let ph: CGFloat = 36
            let gap: CGFloat = 13
            let inset: CGFloat = 3
            
            var isAnchor: Bool = false
            
            let lastMax: CGFloat = items[items.count - 1].frame.maxY - inset
            let firstMin: CGFloat = items[0].frame.minY + inset
            

            
            if offset.y >= lastMax - ph - gap {
                point.y = lastMax - offset.y - ph
            } else if offset.y + gap > firstMin {
                point.y = gap
                isAnchor = true
            } else {
                point.y = firstMin - offset.y
            }
            
            let revealView = items.compactMap {
                $0.view as? ChatRowView
            }.first(where: {
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
            if !isAnchor {
                point = calculateAdjustedPoint(for: point, floatingPhotosView: self.genericView.floatingPhotosView, tableView: self.genericView.tableView)!
            }
            

            let value: ChatFloatingPhoto = .init(point: point, items: groupped.0, photoView: photoView, isAnchor: isAnchor)
            floating.append(value)
        }
        
        
        genericView.updateFloating(floating, animated: animated, currentAnimationRows: currentAnimationRows)
    }
    
    private var hasPhotos: Bool = false
    private func updateHasPhotos(_ theme: TelegramPresentationTheme) {
        if let peer = self.chatInteraction.peer {
            let peerAccept = peer.isGroup || peer.isChannel || peer.isSupergroup || peer.id == context.peerId || peer.id == repliesPeerId || mode.isSavedMessagesThread || peer.id == verifyCodePeerId
            self.hasPhotos = peerAccept && theme.bubbled
        } else {
            self.hasPhotos = false
        }
    }
    
    
    private func collectFloatingPhotos(animated: Bool, currentAnimationRows: [TableAnimationInterface.AnimateItem]) {
        
        if !hasPhotos {
            self.grouppedFloatingPhotos = []
            return
        }
        let cached:[MessageId : ChatAvatarView] = self.grouppedFloatingPhotos.reduce([:], { current, value in
            var current = current
            for item in value.0 {
                let view = value.1
                current[item.message!.id] = view
            }
            return current
        })
        
        var groupped:[[ChatRowItem]] = []
        var current:[ChatRowItem] = []
        let visibleItems = self.genericView.tableView.visibleRows(50)
        for i in visibleItems.lowerBound ..< visibleItems.upperBound {
            let item = self.genericView.tableView.item(at: i)
            var skipOrFill = true
            if let item = item as? ChatRowItem {
                if item.canHasFloatingPhoto {
                    let prev = current.last
                    let sameAuthor = prev?.lastMessage?.author?.id == item.lastMessage?.author?.id
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
                if skipOrFill {
                    if !current.isEmpty {
                        groupped.append(current)
                    }
                    current = []
                    
                    if item.canHasFloatingPhoto {
                        current.append(item)
                    }
                }
            }
            
        }
        
        if !current.isEmpty {
            groupped.append(current)
        }
        self.grouppedFloatingPhotos = groupped.compactMap { value in
            let item = value[value.count - 1]
            var view: ChatAvatarView?
            for item in value {
                if let v = cached[item.message!.id] {
                    view = v
                    break
                }
            }
            if view == nil {
                view = ChatRowView.makePhotoView(item)
            } else if let peer = item.peer {
                view?.setPeer(item: item, peer: peer, storyStats: item.entry.additionalData.authorStoryStats, message: item.message)
            }
           
            //??
            let control = view
            
            if let control = control {
                return (value, control)
            } else {
                return nil
            }
        }
        
        self.updateFloatingPhotos(self.genericView.scroll, animated: animated, currentAnimationRows: currentAnimationRows)
        
    }
    
    private func updateVisibleRange(_ range: NSRange) -> Void {
        var lowerBound: MessageIndex?
        var upperBound: MessageIndex?
        for i in range.lowerBound ..< range.upperBound {
            let item = genericView.tableView.item(at: i) as? ChatRowItem
            if lowerBound == nil {
                if let message = item?.firstMessage {
                    lowerBound = MessageIndex(message)
                }
            }
            if let message = item?.firstMessage {
                upperBound = MessageIndex(message)
            }
        }
        if let upperBound = upperBound {
            _ = self.visibleMessageRange.swap(.init(lowerBound: upperBound, upperBound: lowerBound))
        }
    }

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        sizeValue.set(size)
        self.updateFloatingPhotos(genericView.scroll, animated: false)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        

        if let contents = mode.customChatContents as? HashtagSearchGlobalChatContents, let hashtag = contents.kind.hashtag {
            contents.hashtagSearchResultsUpdate = { [weak self] result in
                self?.searchState.set(.init(hashtag, result.0.messages))
            }
        }
        
        
        
        genericView.updateFloatingPhotos = { [weak self] scroll, animated in
            self?.updateFloatingPhotos(scroll, animated: animated)
        }
        
        keepShortcutDisposable.set(context.engine.accountData.keepShortcutMessageListUpdated().start())
        
        
        sizeValue.set(frame.size)
        self.chatInteraction.add(observer: self)
        
        genericView.inputContextHelper.didScroll = { [weak self] in
            self?.genericView.updateTextInputSuggestions([], range: NSMakeRange(0, 0), animated: true)
        }
        
        genericView.tableView.addScroll(listener: emojiEffects.scrollUpdater)
        

        
        self.genericView.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: true, { [weak self] position in
            guard let `self` = self else {
                return
            }
            self.collectFloatingPhotos(animated: false, currentAnimationRows: self.currentAnimationRows)
            
            self.updateVisibleRange(position.visibleRows)
            
        }))
        
        
        self.genericView.tableView.scrollDidUpdate = { [weak self] position in
            self?.updateFloatingPhotos(position, animated: false)
        }
        
        let previousView = self.previousView
        let context = self.context
        let atomicSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        let nextTransaction = self.nextTransaction
        let mode = self.mode
                
        let peerId = self.chatInteraction.peerId
        
        let chatLocation:()->ChatLocation = { [weak self] in
            guard let self else {
                return .peer(peerId)
            }
            return self.chatLocation
        }
        
        let makeThreadId64: (Bool)->Int64? = { [weak self] forward in
            guard let self else {
                return nil
            }
            let isMonoforum = self.chatInteraction.isMonoforum
            var threadId = self.chatLocation.threadId
            if forward, threadId == nil {
                threadId = self.chatInteraction.presentation.interfaceState.replyMessage?.threadId
            }
            
            return threadId
        }
        
        let threadId64: ()->Int64? = {
            return makeThreadId64(false)
        }
        let isThread = chatInteraction.mode.isThreadMode
        let customChatContents = chatInteraction.mode.customChatContents

        let takeReplyId:()->EngineMessageReplySubject? = { [weak self] in
            guard let self else {
                return nil
            }
            let presentation = self.chatInteraction.presentation
            var reply = presentation.interfaceState.replyMessageId
            
            if let suggest = presentation.interfaceState.suggestPost {
                switch suggest.mode {
                case let .edit(id), let .suggest(id):
                    reply = .init(messageId: id, quote: nil, todoItemId: nil)
                default:
                    break
                }
            }
            
            if reply == nil, let threadId64 = threadId64(), !presentation.isMonoforum {
                reply = .init(messageId: MessageId(peerId: chatLocation().peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId64)), quote: nil, todoItemId: nil)
            }
            return reply
        }
        let takePaidMessageStars:()->StarsAmount? = { [weak self] in
            return self?.chatInteraction.presentation.sendPaidMessageStars
        }
        if case let .thread(message) = self.chatLocation, message.isForumPost {
            if self.keepMessageCountersSyncrhonizedDisposable == nil {
                self.keepMessageCountersSyncrhonizedDisposable = self.context.engine.messages.keepMessageCountersSyncrhonized(peerId: message.peerId, threadId: message.threadId).startStrict()
            }
        } else if self.chatLocation.peerId == self.context.account.peerId {
            if self.keepMessageCountersSyncrhonizedDisposable == nil {
                if let threadId = self.chatLocation.threadId {
                    self.keepMessageCountersSyncrhonizedDisposable = self.context.engine.messages.keepMessageCountersSyncrhonized(peerId: self.context.account.peerId, threadId: threadId).startStrict()
                } else {
                    self.keepMessageCountersSyncrhonizedDisposable = self.context.engine.messages.keepMessageCountersSyncrhonized(peerId: self.context.account.peerId).startStrict()
                }
            }
            if self.keepSavedMessagesSyncrhonizedDisposable == nil {
                self.keepSavedMessagesSyncrhonizedDisposable = self.context.engine.stickers.refreshSavedMessageTags(subPeerId: self.chatLocation.threadId.flatMap(PeerId.init)).startStrict()
            }
        }



        var lastEventTimestamp: Double = 0.0
        self.networkSpeedEventsDisposable = (self.context.account.network.networkSpeedLimitedEvents
        |> deliverOnMainQueue).start(next: { event in

            let timestamp = CFAbsoluteTimeGetCurrent()
            if lastEventTimestamp + 10.0 < timestamp {
                lastEventTimestamp = timestamp
            } else {
                return
            }
            
            let title: String
            let text: String
            switch event {
            case .download:
                let speedIncreaseFactor = context.appConfiguration.getGeneralValue("upload_premium_speedup_download", orElse: 10)
                title = strings().chatDownloadLimitTitle
                text = strings().chatDownloadLimitTextCountable(Int(speedIncreaseFactor))
            case .upload:
                let speedIncreaseFactor = context.appConfiguration.getGeneralValue("upload_premium_speedup_upload", orElse: 10)
                title = strings().chatUploadLimitTitle
                text = strings().chatUploadLimitTextCountable(Int(speedIncreaseFactor))
            }
            
            showModalText(for: context.window, text: text, title: title, callback: { _ in
                prem(with: PremiumBoardingController(context: context, source: .upload_limit, openFeatures: true), for: context.window)
            })
            
        })


        
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
                    if let action = message.extendedMedia as? TelegramMediaAction {
                        switch action.action {
                        case .groupCreated:
                            return coreMessageMainPeer(message)?.groupAccess.isCreator == false
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
        
        
        switch chatLocation() {
        case let .peer(peerId):
            self.peerView.set(context.account.viewTracker.peerView(peerId, updateData: true) |> map {Optional($0)})
            let _ = context.engine.peers.checkPeerChatServiceActions(peerId: peerId).start()
        case let .thread(data):
            var peerId: PeerId = data.peerId
            if let threadMode = mode.threadMode {
                switch threadMode {
                case .savedMessages:
                    peerId = PeerId(data.threadId)
                default:
                    break
                }
            }
            self.peerView.set(context.account.viewTracker.peerView(peerId) |> map {Optional($0)})
        }
        
        
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> map { peer in
            return [SendAsPeer(peer: peer, subscribers: nil, isPremiumRequired: false)]
        }
        
        let signal: Signal<[SendAsPeer]?, NoError> = peerView.get()
        |> map { $0 as? PeerView }
        |> filter { $0?.cachedData != nil }
        |> map { $0! }
        |> map { peerView -> TelegramChannel? in
            if let channel = peerViewMainPeer(peerView) as? TelegramChannel {
                if channel.isSupergroup || channel.isGigagroup {
                    if channel.addressName != nil {
                        return channel
                    } else if let cachedData = peerView.cachedData as? CachedChannelData, cachedData.linkedDiscussionPeerId.peerId != nil {
                        return channel
                    }
                } else if case let .broadcast(info) = channel.info {
                    if info.flags.contains(.messagesShouldHaveProfiles), channel.isAdmin {
                        return channel
                    }
                }
            }
            return nil
        } |> distinctUntilChanged |> mapToSignal { channel in
            if let channel = channel {
                return combineLatest(currentAccountPeer, context.engine.peers.sendAsAvailablePeers(peerId: peerId)) |> map { current, peers in
                    var items:[SendAsPeer] = []
                    if !channel.hasPermission(.canBeAnonymous) {
                        items = current
                    }
                    items.append(contentsOf: peers)
                    if items.count == 1, items[0].peer.id == context.peerId {
                        items.removeAll()
                    }
                    return items
                }
            } else {
                return .single(nil)
            }
            
        } |> deliverOnMainQueue

        
        sendAsPeersDisposable.set(signal.start(next: { [weak self] peers in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatInteraction.update({
                $0.withUpdatedSendAsPeers(peers)
            })
        }))

        

        let layout:Atomic<SplitViewState> = Atomic(value:context.layout)
        layoutDisposable.set(context.layoutValue.start(next: {[weak self] (state) in
            let previous = layout.swap(state)
            if previous != state, let navigation = self?.navigationController {
                self?.requestUpdateBackBar()
                if let modalAction = navigation.modalAction {
                    navigation.set(modalAction: modalAction, state != .single)
                }
                DispatchQueue.main.async {
                    self?.genericView.tableView.reloadData()
                }
            }
        }))
        
        selectTextController = ChatSelectText(genericView.tableView)
        
        let maxReadIndex:ValuePromise<MessageIndex?> = ValuePromise()
        var didSetReadIndex: Bool = false
        let queue = self.queue
        
        
        let chatLocationContextHolder = self.chatLocationContextHolder
        

        let historyViewUpdate1 = location.get() |> deliverOn(queue)
        |> mapToSignal { inputLocation -> Signal<(ChatHistoryViewUpdate, TableSavingSide?, ChatHistoryLocationInput, ChatLocation), NoError> in
                
                let chatLocation = inputLocation.chatLocation
            
                let location = inputLocation.content

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
                case let .thread(data):
                    if mode.isThreadMode {
                        additionalData.append(.message(data.effectiveTopId))
                    }
                case .peer:
                    additionalData.append(.cachedPeerDataMessages(peerId))
                }
                                
                return chatHistoryViewForLocation(location, context: context, chatLocation: chatLocation, fixedCombinedReadStates: { nil }, tag: inputLocation.tag, mode: mode, additionalData: additionalData, chatLocationContextHolder: chatLocationContextHolder) |> beforeNext { viewUpdate in
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
                    return (view, location.side, inputLocation, chatLocation)
                }
        }
        let historyViewUpdate = historyViewUpdate1


        
        let animatedEmojiStickers: Signal<[String: StickerPackItem], NoError> = context.diceCache.animatedEmojies
        let messageEffects: Signal<AvailableMessageEffects?, NoError> = context.engine.stickers.availableMessageEffects()

        
        let savedMessageTags: Signal<SavedMessageTags?, NoError>
        if peerId == self.context.account.peerId {
            savedMessageTags = context.engine.stickers.savedMessageTagData()
        } else {
            savedMessageTags = .single(nil)
        }

        
        let reactions = context.reactions.stateValue

        
        let customChannelDiscussionReadState: Signal<MessageId?, NoError>
        if case let .peer(peerId) = chatLocation(), peerId.namespace == Namespaces.Peer.CloudChannel {
            let cachedDataKey = PostboxViewKey.cachedPeerData(peerId: peerId)
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
                    let key = PostboxViewKey.combinedReadState(peerId: discussionPeerId, handleThreads: false)
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
        
        
        
        let customThreadOutgoingReadState: Signal<MessageId?, NoError> = chatLocationValue |> mapToSignal { location in
            switch location {
            case .thread:
                return context.chatLocationOutgoingReadState(for: location, contextHolder: chatLocationContextHolder)
            case .peer:
                return .single(nil)
            }
        }
//        if case .thread = chatLocation {
//            customThreadOutgoingReadState =
//        } else {
//            customThreadOutgoingReadState = .single(nil)
//        }

        let animatedRows:([TableAnimationInterface.AnimateItem])->Void = { [weak self] items in
            self?.currentAnimationRows = items
        }
        
        let previousAppearance:Atomic<Appearance> = Atomic(value: appAppearance)
        let firstInitialUpdate:Atomic<Bool> = Atomic(value: true)
                
        let applyHole:(ChatHistoryLocationInput) -> Void = { [weak self] current in
            guard let `self` = self else { return }
            let locationValue = self.locationValue
            if current != locationValue {
                return
            }
            let visibleRows = self.genericView.tableView.visibleRows()
            var messageIndex: MessageIndex?
            for i in stride(from: visibleRows.max - 1, to: -1, by: -1) {
                if let item = self.genericView.tableView.item(at: i) as? ChatRowItem, !item.ignoreAtInitialization, let message = item.message, message.adAttribute == nil {
                    messageIndex = MessageIndex(message)
                    break
                }
            }
            if let messageIndex = messageIndex {
                self.setLocation(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: self.requestCount, side: .upper))
            } else if let location = self.locationValue {
                self.setLocation(location.content)
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
        
        
        let adMessages:Signal<(fixed: Message?, opportunistic: [Message], version: Int), NoError>
        if let ad = self.adMessages {
            adMessages = ad.allMessages
        } else {
            adMessages = .single((nil, [], 0))
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
        
        enum WallpaperResult : Equatable {
            case result(Wallpaper?)
            case loading 
        }
        
        
        var uploadingPeerMedia = context.account.pendingPeerMediaUploadManager.uploadingPeerMedia
        uploadingPeerMedia = .single([:]) |> then(uploadingPeerMedia)
        
        let wallpaper: Signal<TelegramWallpaper?, NoError> = combineLatest(uploadingPeerMedia, self.peerView.get()) |> map { uploading, peerView in
            if let content = uploading[peerId]?.content {
                switch content {
                case let .wallpaper(wallpaper, _):
                    return wallpaper
                }
            }
            if let peerView = peerView as? PeerView {
                if let data = peerView.cachedData as? CachedUserData {
                    return data.wallpaper
                } else if let data = peerView.cachedData as? CachedChannelData {
                    return data.wallpaper
                }
            }
            return nil
        } |> distinctUntilChanged
        
        
        let chatTheme:Signal<(String?, TelegramPresentationTheme), NoError> = combineLatest(context.chatThemes, themeEmoticon, appearanceSignal) |> map { chatThemes, themeEmoticon, appearance -> (String?, TelegramPresentationTheme) in
            
            var theme: TelegramPresentationTheme = appearance.presentation
            if let themeEmoticon = themeEmoticon {
                let chatThemeData = chatThemes.first(where: { $0.0 == themeEmoticon})?.1
                theme = chatThemeData ?? appearance.presentation
            }
            return (themeEmoticon, theme)
        }

        
        let themeWallpaper: Signal<WallpaperResult, NoError> = combineLatest(wallpaper, appearanceSignal) |> mapToSignal { wallpaper, appearance in
            if let wallpaper = wallpaper?.uiWallpaper {
                if backgroundExists(wallpaper, palette: appearance.presentation.colors) {
                    return .single(.result(wallpaper))
                } else {
                    return .single(.loading) |> then(moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wallpaper) |> map {
                        .result($0)
                    })
                }
            }
            return .single(.result(nil))
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue
        
                
        
        struct ThemeTuple : Equatable {
            let theme: TelegramPresentationTheme
            let emoticon: String?
            let genuie: TelegramPresentationTheme
        }
        
        let effectiveTheme: Signal<ThemeTuple, NoError> = combineLatest(chatTheme, chatThemeTempValue.get()) |> map { genuie, temp in
            if let temp = temp {
                return .init(theme: temp.1, emoticon: temp.0, genuie: genuie.1)
            } else {
                return .init(theme: genuie.1, emoticon: genuie.0, genuie: genuie.1)
            }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue
        
        let appearanceReady: ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
        
        if chatLocation().peerId.namespace != Namespaces.Peer.SecretChat, chatLocation().peerId != context.peerId, mode != .pinned, mode != .scheduled {
            self.liveTranslate = .init(peerId: chatLocation().peerId, context: context)
        } else {
            self.liveTranslate = nil
        }
        

        
        let translateSignal: Signal<ChatLiveTranslateContext.State?, NoError>
        if let liveTranslate = self.liveTranslate {
            translateSignal = liveTranslate.state
            |> map(Optional.init)
        } else {
            translateSignal = .single(nil)
        }
        
        
        
        
        if chatLocation().peerId.namespace == Namespaces.Peer.CloudUser || chatLocation().peerId.namespace == Namespaces.Peer.CloudChannel, chatLocation().peerId != context.peerId, mode == .history {
            self.stories = PeerExpiringStoryListContext(account: context.account, peerId: peerId)
        } else {
            self.stories = nil
        }
        
        let storiesSignal: Signal<PeerExpiringStoryListContext.State?, NoError>
        if let stories = self.stories {
            storiesSignal = .single(nil) |> then(stories.state |> map(Optional.init))
        } else {
            storiesSignal = .single(nil)
        }
        
        let recommendedChannels: Signal<RecommendedChannels?, NoError>
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            recommendedChannels = context.engine.peers.recommendedChannels(peerId: peerId)
        } else {
            recommendedChannels = .single(nil)
        }
        
        
        let counters: Signal<ChatTitleCounters, NoError> = combineLatest(peerView.get(), self.chatLocationValue) |> mapToSignal { peerView, chatLocation in
            let peerView = peerView as? PeerView
            
            let threadId = chatLocation.threadId
            
            let answersCount: Signal<Int32?, NoError>
            let onlineMemberCount:Signal<Int32?, NoError>

            
            if let threadId {
                switch chatLocation {
                case let .thread(data):
                    if mode.isSavedMessagesThread || data.isMonoforumPost {
                        let savedMessagesPeerId: PeerId = PeerId(data.threadId)
                        
                        let threadPeerId = savedMessagesPeerId
                        let basicPeerKey: PostboxViewKey = .basicPeer(threadPeerId)
                        let countViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: savedMessagesPeerId.toInt64(), namespace: Namespaces.Message.Cloud, customTag: nil)
                        answersCount = context.account.postbox.combinedView(keys: [basicPeerKey, countViewKey])
                        |> map { views -> Int32? in
                            
                            var messageCount = 0
                            if let summaryView = views.views[countViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                                messageCount += Int(count)
                            }
                            
                            return Int32(messageCount)
                        }

                    } else if isThread {
                        answersCount = context.account.postbox.messageView(data.effectiveTopId)
                            |> map {
                                $0.message?.attributes.compactMap { $0 as? ReplyThreadMessageAttribute }.first
                            }
                            |> map {
                                $0?.count
                            }
                            |> deliverOnMainQueue
                    } else {
                        let countViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, customTag: nil)
                        let localCountViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Local, customTag: nil)
                        
                        answersCount = context.account.postbox.combinedView(keys: [countViewKey, localCountViewKey])
                        |> map { views -> Int32 in
                            var messageCount = 0
                            if let summaryView = views.views[countViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                                if threadId == 1 {
                                    messageCount += Int(count)
                                } else {
                                    messageCount += max(Int(count) - 1, 0)
                                }
                            }
                            if let summaryView = views.views[localCountViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                                messageCount += Int(count)
                            }
                            return Int32(messageCount)
                        } |> map(Optional.init) |> deliverOnMainQueue
                    }
                default:
                    answersCount = .single(nil)
                }
            } else {
                answersCount = .single(nil)
            }
            
            
            if let peerView = peerView, let peer = peerViewMainPeer(peerView), peer.isSupergroup || peer.isGigagroup {
                if let cachedData = peerView.cachedData as? CachedChannelData {
                    if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(peerId: peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    } else {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(peerId: peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    }

                } else {
                    onlineMemberCount = .single(nil)
                }
            } else {
                onlineMemberCount = .single(nil)
            }
            
            return combineLatest(answersCount, onlineMemberCount) |> map {
                return .init(replies: $0, online: $1)
            }
        } |> deliverOnMainQueue
        
        
        
        let groupsInCommon = GroupsInCommonContext(account: context.account, peerId: peerId)
        self.groupsInCommon = groupsInCommon
      
        presentationDisposable.add(combineLatest(queue:.mainQueue(), effectiveTheme, themeWallpaper, translateSignal, storiesSignal, context.chatThemes, counters, context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.PeerSettings(id: peerId)), Signal<GroupsInCommonState?, NoError>.single(nil) |> then(groupsInCommon.state |> map(Optional.init))).start(next: { [weak self] presentation, wallpaper, translate, storyState, emoticonThemes, counters, peerStatus, groupsInCommon in
            let emoticon = presentation.emoticon
            let theme = presentation.theme
            let genuie = presentation.genuie
            self?.updateState { current in
                var current = current
                current.presentation_emoticon = emoticon
                current.presentation_genuie = genuie
                current.translate = translate
                current.storyState = storyState
                current.answersAndOnline = counters
                current.peerStatus = peerStatus
                current.commonGroups = groupsInCommon
                switch wallpaper {
                case let .result(result):
                    current.presentation = theme.withUpdatedEmoticonThemes(emoticonThemes)
                    if let wallpaper = result {
                        current.bespoke_wallpaper = .init(wallpaper: wallpaper, associated: nil)
                    } else {
                        current.bespoke_wallpaper = current.presentation.wallpaper
                    }
                    if current.presentation.wallpaper != current.bespoke_wallpaper {
                        if let wallpaper = current.bespoke_wallpaper {
                            current.presentation = current.presentation.withUpdatedWallpaper(wallpaper)
                        } else {
                            current.presentation = current.presentation.withUpdatedWallpaper(theme.wallpaper)
                        }
                    }
                case .loading:
                    break
                }
                return current
            }
            
            let presentation = self?.uiState.with { ($0.presentation_emoticon, $0.presentation )}
            if let presentation = presentation {
                self?.chatThemeValue.set(.single(presentation))
            }
            appearanceReady.set(true)
            if let state = translate {
                self?.chatInteraction.update({ current in
                    return current.withUpdatedTranslateState(.init(canTranslate: state.canTranslate, translate: state.translate, from: state.from, to: state.to, paywall: state.paywall, result: state.result))
                })
                self?.genericView.tableView.notifyScrollHandlers()
            }
        }))
        
        
        
       
        let historyViewTransition = combineLatest(queue: queue,
                                                  historyViewUpdate,
                                                  appearanceSignal,
                                                  maxReadIndex.get(),
                                                  searchState.get(),
                                                  animatedEmojiStickers,
                                                  messageEffects,
                                                  savedMessageTags,
                                                  customChannelDiscussionReadState,
                                                  customThreadOutgoingReadState,
                                                  updatingMedia,
                                                  adMessages,
                                                  reactions,
                                                  stateValue.get(),
                                                  peerView.get(),
                                                  recommendedChannels
    ) |> mapToQueue { update, appearance, maxReadIndex, searchState, animatedEmojiStickers, messageEffects, savedMessageTags, customChannelDiscussionReadState, customThreadOutgoingReadState, updatingMedia, adMessages, reactions, uiState, peerView, recommendedChannels -> Signal<(TableUpdateTransition, MessageHistoryView?, ChatHistoryCombinedInitialData, Bool, ChatHistoryView), NoError> in
                        
            let pollAnswersLoading = uiState.pollAnswers
            let threadLoading = uiState.threadLoading
            let chatLocation = update.3
            let chatTheme = uiState.presentation
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
            case let .HistoryView(_view, _type, _scrollPosition, _initialData):
                initialData = _initialData
                view = _view
                isLoading = _view.isLoading
                updateType = _type
                scrollPosition = searchStateUpdated ? nil : _scrollPosition

            }
    
            if let updatedValue = previousUpdatingMedia.swap(updatingMedia), updatingMedia != updatedValue {
                updateType = .Generic(type: .Generic)
            }
            
            switch updateType {
            case let .Generic(type: type):
                switch type {
                case .FillHole:
                    DispatchQueue.main.async {
                        applyHole(update.2)
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
                prepareOnMainQueue = firstInitialUpdate.swap(isLoading) || prepareOnMainQueue
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
                        if id == cachedChannelAdminRanksEntryId(peerId: peerId), let data = data?.get(CachedChannelAdminRanks.self)  {
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
                    
                    if msgEntries.count == 9 {
                        var bp = 0
                        bp += 1
                    }
                    
                    let topMessages: [Message]?
                    switch chatLocation {
                    case let .thread(data):
                        if mode.isThreadMode {
                            if view.earlierId == nil, !view.isLoading, !view.holeEarlier {
                                topMessages = initialData.cachedDataMessages?[data.effectiveTopId]
                            } else {
                                topMessages = nil
                            }
                        } else {
                            topMessages = nil
                        }
                    case .peer:
                        topMessages = nil
                    }
                    
                    var ads:(fixed: Message?, opportunistic: [Message]) = (fixed: nil, opportunistic: [])
                   
                    
                    let peerView = (peerView as? PeerView)
                    let peer = peerView != nil ? peerViewMainPeer(peerView!) : nil
                    
                    //,
                    if !view.isLoading && view.laterId == nil, peer?.isChannel == true {
                        ads = (fixed: adMessages.fixed, opportunistic: adMessages.opportunistic)
                    }
                    
                    let includeJoin: Bool
                    switch mode {
                    case .history:
                        includeJoin = true
                    default:
                        includeJoin = false
                    }
                    
                    let entries = messageEntries(msgEntries, location: chatLocation, maxReadIndex: maxReadIndex, dayGrouping: customChatContents == nil, renderType: chatTheme.bubbled ? .bubble : .list, includeBottom: true, timeDifference: timeDifference, ranks: ranks, pollAnswersLoading: pollAnswersLoading, threadLoading: threadLoading, groupingPhotos: true, autoplayMedia: initialData.autoplayMedia, searchState: searchState, animatedEmojiStickers: bigEmojiEnabled ? animatedEmojiStickers : [:], topFixedMessages: topMessages, customChannelDiscussionReadState: customChannelDiscussionReadState, customThreadOutgoingReadState: customThreadOutgoingReadState, addRepliesHeader: peerId == repliesPeerId && view.earlierId == nil, updatingMedia: updatingMedia, adMessage: ads.fixed, dynamicAdMessages: ads.opportunistic, chatTheme: chatTheme, reactions: reactions, transribeState: uiState.transribe, topicCreatorId: uiState.topicCreatorId, mediaRevealed: uiState.mediaRevealed, translate: uiState.translate, storyState: uiState.storyState, peerStoryStats: view.peerStoryStats, cachedData: peerView?.cachedData, peer: peer, holeLater: view.holeLater, holeEarlier: view.holeEarlier, recommendedChannels: recommendedChannels, includeJoin: includeJoin, earlierId: view.earlierId, laterId: view.laterId, automaticDownload: initialData.autodownloadSettings, savedMessageTags: savedMessageTags, contentSettings: context.contentSettings, codeSyntaxData: uiState.codeSyntaxes, messageEffects: messageEffects, factCheckRevealed: uiState.factCheck, quoteRevealed: uiState.quoteRevealed, peerStatus: uiState.peerStatus, commonGroups: uiState.commonGroups, monoforumState: uiState.monoforumState, accountPeerId: context.peerId, contentConfig: context.contentConfig).map { ChatWrappedEntry(appearance: AppearanceWrapperEntry(entry: $0, appearance: appearance), tag: view.tag) }
                    proccesedView = ChatHistoryView(originalView: view, filteredEntries: entries, theme: chatTheme)
                }
            } else {
                proccesedView = ChatHistoryView(originalView: nil, filteredEntries: [], theme: chatTheme)
            }
            

            return prepareEntries(from: previousView.swap(proccesedView), to: proccesedView, timeDifference: timeDifference, initialSize: atomicSize.with { $0 }, interaction: chatInteraction, animated: false, scrollPosition:scrollPosition, reason: updateType, animationInterface: animationInterface, side: update.1, messagesViewQueue: queue) |> map { transition in
                return (transition, view, initialData, isLoading, proccesedView)
            } |> runOn(prepareOnMainQueue ? Queue.mainQueue(): queue)
            
        } |> deliverOnMainQueue
        
        
        let appliedTransition = historyViewTransition |> map { [weak self] transition, view, initialData, isLoading, proccesedView in
            self?.applyTransition(transition, initialData: initialData, isLoading: isLoading, processedView: proccesedView)
        }
        
        
        self.historyDisposable.set(appliedTransition.start())
        
        var canRead: Signal<Bool, NoError>
        if let isLocked = appDelegate?.isLocked() {
            canRead = isLocked
            |> map { !$0 }
        } else {
            canRead = .single(true)
        }
        canRead = combineLatest(canRead, self.isKeyWindow.get()) |> map { $0 && $1 }
        
        
        let previousMaxIncomingMessageIdByNamespace = Atomic<[MessageId.Namespace: MessageIndex]>(value: [:])
        
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), canRead, self.chatLocationValue)
            |> map { messageIndex, canRead, chatLocation in
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
                        if !hasModals(context.window) {
                            UNUserNotifications.current?.clearNotifies(chatLocation.peerId, maxId: messageIndex.id)
                            context.applyMaxReadIndex(for: chatLocation, contextHolder: chatLocationContextHolder, messageIndex: messageIndex)
                        }
                    }
                }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        
        chatInteraction.updateFrame = { [weak self] frame, transition in
//            self?.reactionManager?.updateLayout(size: frame.size, transition: transition)
            if let tableView = self?.genericView.tableView {
                self?.updateFloatingPhotos(tableView.scrollPosition().current, animated: transition.isAnimated)
            }
        }
        
        chatInteraction.setupReplyMessage = { [weak self] message, subject in
            guard let `self` = self else { return }
            
            switch self.mode {
            case .scheduled, .pinned:
                return
            default:
                break
            }
            
            if let peer = self.chatInteraction.presentation.mainPeer {
                let threadInfo = self.chatInteraction.presentation.threadInfo
                if let subject = subject, !peer.canSendMessage(self.mode.isThreadMode, threadData: threadInfo, cachedData: self.chatInteraction.presentation.cachedData) {
                    self.chatInteraction.replyToAnother(subject, false)
                    return
                }
            }
            
            
            self.chatInteraction.focusInputField()
            let signal:Signal<Message?, NoError> = subject == nil ? .single(nil) : self.chatInteraction.context.account.postbox.messageAtId(subject!.messageId)
            _ = (signal |> deliverOnMainQueue).start(next: { [weak self] message in
                self?.chatInteraction.update({ current in
                    var current = current.updatedInterfaceState({$0.withUpdatedReplyMessageId(subject).withUpdatedReplyMessage(message)})
                    if subject?.messageId == current.keyboardButtonsMessage?.replyAttribute?.messageId {
                        current = current.updatedInterfaceState({ $0.withUpdatedDismissedForceReplyId(subject?.messageId) })
                    }
                    return current
                })
            })
            
            
        }
        
        chatInteraction.removeAd = { [weak self] opaqueId in
            self?.adMessages?.remove(opaqueId: opaqueId)
        }
        
        chatInteraction.startRecording = { [weak self] hold, view in
            guard let chatInteraction = self?.chatInteraction else {return}
            if hasModals(context.window) || hasPopover(context.window) {
                return
            }
            if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                if let last = slowMode.sendingIds.last {
                    chatInteraction.focusMessageId(nil, .init(messageId: last, string: nil), .CenterEmpty)
                }
                if let view = self?.genericView.inputView.currentActionView {
                    showSlowModeTimeoutTooltip(slowMode, for: view)
                    return
                }
            }
            
            if let cachedData = chatInteraction.presentation.cachedData as? CachedUserData, let peer = chatInteraction.presentation.mainPeer {
                if !cachedData.voiceMessagesAvailable {
                    if let view = self?.genericView.inputView.currentActionView {
                        tooltip(for: view, text: strings().chatSendVoicePrivacyError(peer.compactDisplayTitle))
                    }
                    return
                }
            }
            
            if chatInteraction.presentation.recordingState != nil || chatInteraction.presentation.state != .normal {
                NSSound.beep()
                return
            }
            if let peer = chatInteraction.presentation.peer {
                let flags: TelegramChatBannedRightsFlags
                switch FastSettings.recordingState {
                case .video:
                    flags = .banSendInstantVideos
                case .voice:
                    flags = .banSendVoice
                }
                if let permissionText = permissionText(from: peer, for: flags, cachedData: chatInteraction.presentation.cachedData) {
                    showModalText(for: context.window, text: permissionText)
                    return
                }
                
                let invoke:()->Void = { [weak chatInteraction] in
                    guard let chatInteraction else {
                        return
                    }
                    switch FastSettings.recordingState {
                    case .voice:
                        let state = ChatRecordingAudioState(context: chatInteraction.context, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                        state.start()
                        delay(0.1, closure: { [weak chatInteraction] in
                            chatInteraction?.update({$0.withRecordingState(state)})
                        })
                    case .video:
                        let state = ChatRecordingVideoState(context: chatInteraction.context, liveUpload: chatInteraction.peerId.namespace != Namespaces.Peer.SecretChat, autohold: hold)
                        showModal(with: VideoRecorderModalController(state: state, pipeline: state.pipeline, sendMedia: { [weak chatInteraction] medias in
                            chatInteraction?.sendMedia(medias)
                        }, resetState: { [weak chatInteraction] in
                            chatInteraction?.update { $0.withoutRecordingState() }
                        }), for: context.window)
                        
                        chatInteraction.update({$0.withRecordingState(state)})
                    }
                }
                
                let checkStars:()->Void = { [weak chatInteraction] in
                    guard let chatInteraction else {
                        return
                    }
                    
                    let presentation = chatInteraction.presentation
                    let messagesCount = 1
                    
                    if let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                        let starsPrice = Int(payStars.value * Int64(messagesCount))
                        let amount = strings().starListItemCountCountable(starsPrice)
                        
                        if !presentation.alwaysPaidMessage {
                            
                            let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                            
                            verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                                
                                if starsState.balance.value > starsPrice {
                                    chatInteraction.update({ current in
                                        return current
                                            .withUpdatedAlwaysPaidMessage(result == .thrid)
                                    })
                                    invoke()
                                    if result == .thrid {
                                        FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                                    }
                                } else {
                                    showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                                }
                            })
                            
                        } else {
                            if starsState.balance.value > starsPrice {
                                invoke()
                            } else {
                                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                            }
                        }
                    } else {
                        invoke()
                    }

                }
                
                /*
                 

                 */
                
                if chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                    switch FastSettings.recordingState {
                    case .voice:
                        let permission: Signal<Bool, NoError> = requestMediaPermission(.audio) |> deliverOnMainQueue
                       _ = permission.start(next: { access in
                            if access {
                                checkStars()
                            } else {
                                verifyAlert_button(for: context.window, information: strings().requestAccesErrorHaveNotAccessVoiceMessages, ok: strings().modalOK, cancel: "", option: strings().requestAccesErrorConirmSettings, successHandler: { result in
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
                        _ = permission.start(next: { access in
                            if access {
                                checkStars()
                            } else {
                                verifyAlert_button(for: context.window, information: strings().requestAccesErrorHaveNotAccessVideoMessages, ok: strings().modalOK, cancel: "", option: strings().requestAccesErrorConirmSettings, successHandler: { result in
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
            self.context.bindings.entertainment().closePopover()
            self.context.cancelGlobalSearch.set(true)
//            self.reactionManager?.clearAndTempLock()
        }
        
        
        let afterSentTransition = { [weak self] in
            self?.chatInteraction.update({ presentation in
                return presentation.updatedInputQueryResult {_ in
                    return nil
                }.updatedInterfaceState { current in
                
                    var value: ChatInterfaceState = current
                        .withUpdatedReplyMessageId(nil)
                        .withUpdatedInputState(ChatTextInputState())
                        .withUpdatedForwardMessageIds([])
                        .withUpdatedComposeDisableUrlPreview(nil)
                        .withUpdatedMessageEffect(nil)
                        .withUpdatedSuggestPost(nil)
                        .withoutEditMessage()
                        
                
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
                }).withUpdatedAcknowledgedPaidMessage(false)
            
            })
            self?.chatInteraction.saveState(scrollState: self?.immediateScrollState())
            if !context.isLite(.animations) {
                if self?.genericView.doBackgroundAction() != true {
                    self?.navigationController?.doBackgroundAction()
                }
            }
        }
        
        chatInteraction.jumpToDate = { [weak self] date in
            if let strongSelf = self, let window = self?.window, let peerId = self?.chatInteraction.peerId {
                
                
                switch strongSelf.mode {
                case .history, .thread, .preview:
                    let signal = context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: threadId64(), timestamp: Int32(date.timeIntervalSince1970))
                    
                    self?.dateDisposable.set(showModalProgress(signal: signal, for: window).start(next: { messageId in
                        if let messageId = messageId {
                            self?.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .top(id: 0, innerId: nil, animated: true, focus: .init(focus: false), inset: 30))
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
                case .pinned:
                    break
                case .customChatContents:
                    break
                case .customLink:
                    break
                }
                
                
            }
        }
       
        let editMessage:(ChatEditState, Date?)->Void = { [weak self] state, atDate in
            guard let `self` = self else {return}
            let presentation = self.chatInteraction.presentation

            let inputState = state.inputState.subInputState(from: NSMakeRange(0, state.inputState.inputText.length))

            let text = inputState.inputText.trimmed
            if text.length > chatInteraction.maxInputCharacters {
                if context.isPremium || context.premiumIsBlocked {
                    alert(for: context.window, info: strings().chatInputErrorMessageTooLongCountable(text.length - Int(chatInteraction.maxInputCharacters)))
                } else if !context.premiumIsBlocked {
                    verifyAlert_button(for: context.window, information: strings().chatInputErrorMessageTooLongCountable(text.length - Int(chatInteraction.maxInputCharacters)), ok: strings().alertOK, cancel: "", option: strings().premiumGetPremiumDouble, successHandler: { result in
                        switch result {
                        case .thrid:
                            showPremiumLimit(context: context, type: .caption(text.length))
                        default:
                            break
                        }

                    })
                }
                return
            }

            self.urlPreviewQueryState?.1.dispose()
            
            
            let webpagePreviewAttribute: WebpagePreviewMessageAttribute?
            
            let media: RequestEditMessageMedia
            if let webpreview = presentation.urlPreview?.1 {
                webpagePreviewAttribute = .init(leadingPreview: !presentation.interfaceState.linkBelowMessage, forceLargeMedia: presentation.interfaceState.largeMedia, isManuallyAdded: false, isSafe: true)
                if presentation.urlPreview?.0 == presentation.interfaceState.composeDisableUrlPreview {
                    media = .keep
                } else {
                    media = .update(.webPage(webPage: WebpageReference(webpreview), media: webpreview))
                }
            } else {
                webpagePreviewAttribute = nil
                media = state.editMedia
            }
            
            let invertMediaAttribute = state.invertMedia ? InvertMediaMessageAttribute() : nil
            
            
            if atDate == nil {
                self.context.account.pendingUpdateMessageManager.add(messageId: state.message.id, text: inputState.inputText, media: media, entities: TextEntitiesMessageAttribute(entities: inputState.messageTextEntities()), inlineStickers: inputState.inlineMedia, webpagePreviewAttribute: webpagePreviewAttribute, invertMediaAttribute: invertMediaAttribute, disableUrlPreview: presentation.interfaceState.composeDisableUrlPreview != nil)
                
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
                                
                
                self.chatInteraction.editDisposable.set((context.engine.messages.requestEditMessage(messageId: state.message.id, text: inputState.inputText, media: media, entities: TextEntitiesMessageAttribute(entities: inputState.messageTextEntities()), inlineStickers: inputState.inlineMedia, webpagePreviewAttribute: webpagePreviewAttribute, invertMediaAttribute: invertMediaAttribute, disableUrlPreview: presentation.interfaceState.composeDisableUrlPreview != nil, scheduleTime: scheduleTime) |> deliverOnMainQueue).start(next: { [weak self] progress in
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
        
        chatInteraction.sendMessage = { [weak self] silent, atDate, messageEffect in
            if let strongSelf = self, !strongSelf.nextTransaction.isExutable {
                let presentation = strongSelf.chatInteraction.presentation
                let peerId = strongSelf.chatInteraction.peerId
                let currentSendAsPeerId = presentation.currentSendAsPeerId
                if presentation.abilityToSend {
                    func apply(_ controller: ChatController, atDate: Date?) {
                        var invokeSignal:Signal<Never, NoError> = .complete()
                        
                        let suggest = presentation.interfaceState.suggestPost
                        
                        var isSuggestEditing: Bool = false
                        if let suggest {
                            switch suggest.mode {
                            case .edit, .suggest:
                                isSuggestEditing = true
                            default:
                                break
                            }
                        }
                        
                        var setNextToTransaction = false
                        if let state = presentation.interfaceState.editState, !isSuggestEditing {
                            editMessage(state, atDate)
                            return
                        } else {
                            var messagesCount: Int = presentation.interfaceState.forwardMessageIds.count
                            if !presentation.effectiveInput.inputText.trimmed.isEmpty {
                                setNextToTransaction = true
                                invokeSignal = Sender.enqueue(input: presentation.effectiveInput, context: context, peerId: controller.chatInteraction.peerId, replyId: takeReplyId(), threadId: makeThreadId64(true), disablePreview: presentation.interfaceState.composeDisableUrlPreview != nil, linkBelowMessage: presentation.interfaceState.linkBelowMessage, largeMedia: presentation.interfaceState.largeMedia, silent: silent, atDate: atDate, sendAsPeerId: currentSendAsPeerId, mediaPreview: presentation.urlPreview?.1, emptyHandler: { [weak strongSelf] in
                                    _ = strongSelf?.nextTransaction.execute()
                                }, customChatContents: customChatContents, messageEffect: messageEffect, sendPaidMessageStars: takePaidMessageStars(), suggestPost: presentation.interfaceState.suggestPost) |> deliverOnMainQueue |> ignoreValues
                                messagesCount += 1
                            }
                            
                            let invoke:()->Void = {
                                
                                let fwdIds: [MessageId] = presentation.interfaceState.forwardMessageIds
                                let hideNames = presentation.interfaceState.hideSendersName
                                let hideCaptions = presentation.interfaceState.hideCaptions
                                let cachedData = presentation.cachedData
                                if !fwdIds.isEmpty {
                                    setNextToTransaction = true
                                    
                                    
                                    let fwd = combineLatest(queue: .mainQueue(), context.account.postbox.messagesAtIds(fwdIds), context.account.postbox.loadedPeerWithId(peerId)) |> mapToSignal { messages, peer -> Signal<[MessageId?], NoError> in
                                        let errors:[String] = messages.compactMap { message in
                                            
                                            for attr in message.attributes {
                                                if let _ = attr as? InlineBotMessageAttribute, peer.hasBannedRights(.banSendInline) {
                                                    return permissionText(from: peer, for: .banSendInline, cachedData: cachedData)
                                                }
                                            }
                                            
                                            if let media = message.anyMedia {
                                                return checkMediaPermission(media, for: peer)
                                            }
                                            
                                            return nil
                                        }
                                        
                                        if !errors.isEmpty {
                                            alert(for: context.window, info: errors.joined(separator: "\n\n"))
                                            return .complete()
                                        }
                                        
                                        return Sender.forwardMessages(messageIds: messages.map { $0.id }, context: context, peerId: peerId, replyId: takeReplyId(), threadId: makeThreadId64(true), hideNames: hideNames, hideCaptions: hideCaptions, silent: silent, atDate: atDate, sendAsPeerId: currentSendAsPeerId)
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
                            
                            if messagesCount > 0, let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                                let starsPrice = Int(payStars.value * Int64(messagesCount))
                                let amount = strings().starListItemCountCountable(starsPrice)
                                
                                if !presentation.alwaysPaidMessage {
                                    
                                    let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                                    
                                    verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                                        
                                        if starsState.balance.value > starsPrice {
                                            chatInteraction.update({ current in
                                                return current
                                                    .withUpdatedAlwaysPaidMessage(result == .thrid)
                                            })
                                            if result == .thrid {
                                                FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                                            }
                                            invoke()
                                        } else {
                                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                                        }
                                    })
                                } else {
                                    if starsState.balance.value > starsPrice {
                                        invoke()
                                    } else {
                                        showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                                    }
                                }
                            } else {
                                invoke()
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
                    case .history, .thread, .pinned, .customChatContents:
                        delay(0.1, closure: {
                            if atDate != nil {
                                strongSelf.openScheduledChat()
                            }
                        })
                        apply(strongSelf, atDate: atDate)
                    case let .customLink(contents):
                        contents.saveText?(presentation.effectiveInput)
                        strongSelf.navigationController?.invokeBack(checkLock: false)
                    case .preview:
                        break
                    }
                    
                } else {
                    if let suggest = presentation.interfaceState.suggestPost, suggest.amount == nil {
                        strongSelf.chatInteraction.editPostSuggestion(suggest)
                        return
                    }
                    if let editState = presentation.interfaceState.editState, editState.inputState.inputText.isEmpty {
                        if editState.message.media.isEmpty || editState.message.anyMedia is TelegramMediaWebpage {
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
                                strongSelf.chatInteraction.focusMessageId(nil, .init(messageId: last, string: nil), .CenterEmpty)
                            } else {
                                strongSelf.genericView.inputView.textView.shake()
                            }
                        } else {
                            strongSelf.genericView.inputView.textView.shake()
                        }
                       
                    }
                }
            }
        }
        
        chatInteraction.sendMessageMenu = { [weak self] fromEffect in
            guard let self else {
                return .single(nil)
            }
            let presentation = self.chatInteraction.presentation
            let chatInteraction = self.chatInteraction
            
            guard let peer = presentation.peer else {
                return .single(nil)
            }
            
            let context = context
            if let slowMode = presentation.slowMode, slowMode.hasLocked {
                return .single(nil)
            }
            if presentation.state != .normal {
                return .single(nil)
            }
            var items:[ContextMenuItem] = []
            
            if peer.id != context.account.peerId, !fromEffect {
                items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: { [weak chatInteraction] in
                    chatInteraction?.sendMessage(true, nil, chatInteraction?.presentation.messageEffect)
                }, itemImage: MenuAnimation.menu_mute.value))
            }
            switch chatInteraction.mode {
            case .history, .thread:
                if fromEffect {
                    items.append(ContextMenuItem(strings().modalRemove, handler: { [weak self] in
                        self?.chatInteraction.update {
                            $0.updatedInterfaceState {
                                $0.withUpdatedMessageEffect(nil)
                            }
                        }
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value))
                } else {
                    if !peer.isSecretChat {
                        
                        if peer.id != context.peerId, presentation.canScheduleWhenOnline, presentation.sendPaidMessageStars == nil {
                            items.append(ContextMenuItem(strings().chatSendSendWhenOnline, handler: { [weak chatInteraction] in
                                chatInteraction?.sendMessage(false, scheduleWhenOnlineDate, chatInteraction?.presentation.messageEffect)
                            }, itemImage: MenuAnimation.menu_online.value))
                        }
                        
                        if presentation.sendPaidMessageStars == nil {
                            let text = peer.id == context.peerId ? strings().chatSendSetReminder : strings().chatSendScheduledMessage
                            items.append(ContextMenuItem(text, handler: { [weak chatInteraction] in
                                showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak chatInteraction] date in
                                    chatInteraction?.sendMessage(false, date, chatInteraction?.presentation.messageEffect)
                                }), for: context.window)
                            }, itemImage: MenuAnimation.menu_schedule_message.value))
                        }
                    }
                }
                
                
            default:
                break
            }
                                    
            let reactions:Signal<[AvailableMessageEffects.MessageEffect], NoError> = context.diceCache.availableMessageEffects |> map { view in
                return view?.messageEffects ?? []
            } |> deliverOnMainQueue |> take(1)
                        
            return reactions |> map { [weak self] reactions in
                
                let width = ContextAddReactionsListView.width(for: reactions.count, maxCount: 7, allowToAll: true)
                let aboveText: String = strings().chatContextMessageEffectAdd
                
                let w_width = width + 20
                let color = theme.colors.darkGrayText.withAlphaComponent(0.8)
                let link = theme.colors.link.withAlphaComponent(0.8)
                let attributed = parseMarkdownIntoAttributedString(aboveText, attributes: .init(body: .init(font: .normal(.text), textColor: color), bold: .init(font: .medium(.text), textColor: color), link: .init(font: .normal(.text), textColor: link), linkAttribute: { link in
                    return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                        prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                    }))
                })).detectBold(with: .medium(.text))
                let aboveLayout = TextViewLayout(attributed, maximumNumberOfLines: 2, alignment: .center)
                aboveLayout.measure(width: w_width - 24)
                aboveLayout.interactions = globalLinkExecutor
                
                let rect = NSMakeRect(0, 0, w_width, 40 + 20 + aboveLayout.layoutSize.height + 4)
                
                let panel = Window(contentRect: rect, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
                panel._canBecomeMain = false
                panel._canBecomeKey = false
                panel.level = .popUpMenu
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                

                let reveal:((ContextAddReactionsListView & StickerFramesCollector)->Void)?
                
                
                var selectedItems: [EmojiesSectionRowItem.SelectedItem] = []
                
                if let effect = presentation.interfaceState.messageEffect {
                    selectedItems.append(.init(source: .custom(effect.effect.effectSticker.fileId.id), type: .transparent))
                }
                
                let update:(Int64, NSRect?)->Void = { fileId, fromRect in
                    let effect = reactions.first(where: {
                        $0.effectSticker.fileId.id == fileId
                    })
                    let current = self?.chatInteraction.presentation.interfaceState.messageEffect
                    let value: ChatInterfaceMessageEffect?
                    if let effect, current?.effect != effect {
                        value = ChatInterfaceMessageEffect(effect: effect, fromRect: fromRect)
                    } else {
                        value = nil
                    }
                    self?.chatInteraction.update {
                        $0.updatedInterfaceState {
                            $0.withUpdatedMessageEffect(value)
                        }
                    }
                }
                
                reveal = { view in
                    let window = ReactionsWindowController(context, peerId: peerId, selectedItems: selectedItems, react: { sticker, fromRect in
                        update(sticker.file.fileId.id, fromRect)
                    }, moveTop: true, mode: .messageEffects)
                    window.show(view)
                }
                
                let available: [ContextReaction] = Array(reactions.map { value in
                    return .custom(value: .custom(value.effectSticker.fileId.id), fileId: value.effectSticker.fileId.id, value.effectSticker._parse(), isSelected: presentation.interfaceState.messageEffect?.effect.effectSticker.fileId.id == value.effectSticker.fileId.id)
                }.prefix(7))
                
                let view = ContextAddReactionsListView(frame: rect, context: context, list: available, add: { value, checkPrem, fromRect in
                    switch value {
                    case let .custom(fileId):
                        update(fileId, fromRect)
                    default:
                        break
                    }
                }, radiusLayer: nil, revealReactions: reveal, aboveText: aboveLayout)
                
                
                panel.contentView?.addSubview(view)
                panel.contentView?.wantsLayer = true
                view.autoresizingMask = [.width, .height]
                
                let menu = ContextMenu(bottomAnchor: true)
                if peer.isUser, peer.id != context.peerId {
                    menu.topWindow = panel
                }
                
                for item in items {
                    menu.addItem(item)
                }
                return menu
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
                    let options: [ModalOptionSet] = [ModalOptionSet(title: strings().blockContactOptionsReport, selected: true, editable: true), ModalOptionSet(title: strings().blockContactOptionsDeleteChat, selected: true, editable: true)]
                    
                    showModal(with: ModalOptionSetController(context: chatInteraction.context, options: options, actionText: (strings().blockContactOptionsAction(peer.compactDisplayTitle), theme.colors.redUI), desc: strings().blockContactTitle(peer.compactDisplayTitle), title: strings().blockContactOptionsTitle, result: { result in
                        
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
                                context.bindings.rootNavigation().back()
                            }
                        })
                        
                    }), for: context.window)
                } else {
                    chatInteraction.reportSpamAndClose()
                }
               
            }
            
        }
        
        chatInteraction.unarchive = { [weak self] in
            _ = context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .root).start()
            let removeFlagsSignal = context.account.postbox.transaction { transaction in
                transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, cachedData in
                    if let cachedData = cachedData as? CachedUserData {
                        let current = cachedData.peerStatusSettings
                        var flags = current?.flags ?? []
                        flags.remove(.autoArchived)
                        flags.remove(.canBlock)
                        flags.remove(.canReport)
                        return cachedData.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: flags, geoDistance: current?.geoDistance, managingBot: nil))
                    }
                    if let cachedData = cachedData as? CachedChannelData {
                        let current = cachedData.peerStatusSettings
                        var flags = current?.flags ?? []
                        flags.remove(.autoArchived)
                        flags.remove(.canBlock)
                        flags.remove(.canReport)
                        return cachedData.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: flags, geoDistance: current?.geoDistance, managingBot: nil))
                    }
                    if let cachedData = cachedData as? CachedGroupData {
                        let current = cachedData.peerStatusSettings
                        var flags = current?.flags ?? []
                        flags.remove(.autoArchived)
                        flags.remove(.canBlock)
                        flags.remove(.canReport)
                        return cachedData.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: flags, geoDistance: current?.geoDistance, managingBot: nil))
                    }
                    return cachedData
                })
            }
            let unmuteSignal = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: self?.chatLocation.threadId, muteInterval: nil)
            
            _ = combineLatest(unmuteSignal, removeFlagsSignal).start()
        }
        
        chatInteraction.appendAttributedText = { [weak self] attr in
            _ = self?.chatInteraction.appendText(attr)
        }
        
        chatInteraction.sendPlainText = { [weak self] text in
            if let strongSelf = self, let peer = self?.chatInteraction.presentation.peer, peer.canSendMessage(strongSelf.mode.isThreadMode, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData) {
                
                let chatInteraction = strongSelf.chatInteraction
                let presentation = chatInteraction.presentation
                let _ = (Sender.enqueue(input: ChatTextInputState(inputText: text), context: context, peerId: chatInteraction.peerId, replyId: takeReplyId(), threadId: threadId64(), sendAsPeerId: presentation.currentSendAsPeerId, customChatContents: customChatContents, sendPaidMessageStars: takePaidMessageStars()) |> deliverOnMainQueue).start(completed: scrollAfterSend)
            }
        }
        
        chatInteraction.hashtag = { hashtag in
            context.bindings.globalSearch(hashtag, peerId, nil)
        }
        
        chatInteraction.sendLocation = { [weak self] coordinate, venue in
            let media = TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, heading: nil, accuracyRadius: nil, venue: venue, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
            self?.chatInteraction.sendMedias([media], ChatTextInputState(), false, nil, false, nil, false, nil, false)
        }
        
        chatInteraction.scrollToLatest = { [weak self] removeStack in
            if let strongSelf = self {
                if removeStack {
                    strongSelf.historyState = strongSelf.historyState.withClearReplies()
                }
                strongSelf.scrollup(force: removeStack)
            }
        }

        chatInteraction.reportMessages = { [weak self] value, ids in
            showModal(with: ReportDetailsController(context: context, reason: value, updated: { [weak self] value in
                _ = showModalProgress(signal: context.engine.peers.reportPeerMessages(messageIds: ids, reason: value.reason, message: value.comment), for: context.window).start(completed: { [weak self] in
                    showModalText(for: context.window, text: strings().peerInfoChannelReported)
                    self?.changeState()
                })
            }), for: context.window)

        }
        
        chatInteraction.translateTo = { [weak self] toLang in
            self?.liveTranslate?.translate(toLang: toLang)
        }
        chatInteraction.enableTranslatePaywall = { [weak self] in
            self?.liveTranslate?.enablePaywall()
        }
        
        chatInteraction.boostToUnrestrict = { source in
            let signal: Signal<(Peer, ChannelBoostStatus?, MyBoostStatus?)?, NoError> = context.account.postbox.loadedPeerWithId(peerId) |> mapToSignal { value in
                return combineLatest(context.engine.peers.getChannelBoostStatus(peerId: value.id), context.engine.peers.getMyBoostStatus()) |> map {
                    (value, $0, $1)
                }
            }
            _ = showModalProgress(signal: signal, for: context.window).start(next: { value in
                if let value = value, let boosts = value.1 {
                    showModal(with: BoostChannelModalController(context: context, peer: value.0, boosts: boosts, myStatus: value.2, source: source), for: context.window)
                } else {
                    alert(for: context.window, info: strings().unknownError)
                }
            })
        }
        
        chatInteraction.forwardMessages = { [weak self] messages in
            guard let strongSelf = self else {
                return
            }
            if let report = strongSelf.chatInteraction.presentation.reportMode {
                strongSelf.chatInteraction.reportMessages(report, messages.map { $0.id })
                return
            }
            showModal(with: ShareModalController(ForwardMessagesObject(context, messages: messages, getMessages: strongSelf.chatInteraction.getMessages)), for: context.window)
        }
        
        chatInteraction.deleteMessages = { [weak self] messageIds in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {

                
                if let customChatContents {
                    customChatContents.deleteMessages(ids: messageIds)
                    strongSelf.chatInteraction.update({$0.withoutSelectionState()})
                    return
                }
                
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
                        var allPeers:Set<PeerId> = Set()
                        let peerId = peer.id
                        var _mustDeleteForEveryoneMessage: Bool = true
                        for message in messages {
                            if !canDeleteMessage(message, account: context.account, chatLocation: chatLocation(), mode: mode) {
                                canDelete = false
                            }
                            if !mustDeleteForEveryoneMessage(message) {
                                _mustDeleteForEveryoneMessage = false
                            }
                            if !canDeleteForEveryoneMessage(message, context: context) {
                                canDeleteForEveryone = false
                                if let author = message.effectiveAuthor {
                                    if !allPeers.contains(author.id) {
                                        allPeers.insert(author.id)
                                    }
                                }
                            } else {
                                if message.effectiveAuthor?.id != context.peerId && !(context.limitConfiguration.canRemoveIncomingMessagesInPrivateChats && message.peers[message.id.peerId] is TelegramUser)  {
                                    if let peer = message.peers[message.id.peerId] as? TelegramGroup {
                                        inner: switch peer.role {
                                        case .member:
                                            if let author = message.effectiveAuthor {
                                                if !allPeers.contains(author.id) {
                                                    allPeers.insert(author.id)
                                                }
                                            }
                                        default:
                                            break inner
                                        }
                                    } else {
                                        if let author = message.effectiveAuthor {
                                            if !allPeers.contains(author.id) {
                                                allPeers.insert(author.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if peer.id == context.peerId {
                            canDeleteForEveryone = false
                        }
                        if messages.isEmpty {
                            strongSelf.chatInteraction.update({$0.withoutSelectionState()})
                            return
                        }
                        
                        if canDelete {
                            if mustManageDeleteMessages(messages, for: peer, account: context.account) {
                                if let channel = peer as? TelegramChannel {
                                    showModal(with: DeleteGroupMessagesController(context: context, channel: channel, messages: messages, allPeers: allPeers, onComplete: { [weak strongSelf] in
                                        strongSelf?.chatInteraction.update({$0.withoutSelectionState()})
                                    }), for: context.window)
                                }
                            } else {
                                
                                let successHandler: (ConfirmResult)->Void = { [weak strongSelf] result in
                                    
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
                                }
                                
                                if messages.count == 1, let giveaway = messages[0].media.first as? TelegramMediaGiveaway {
                                    let title = strings().chatGiveawayDeleteConfirmationTitle
                                    let info = strings().chatGiveawayDeleteConfirmationText(stringForFullDate(timestamp: giveaway.untilDate))
                                    verifyAlert(for: context.window, header: title, information: info, ok: strings().confirmDelete, cancel: strings().modalCancel, successHandler: successHandler)
                                } else {
                                    
                                    if messages.count == 1, messages[0].timestamp > context.timestamp + .secondsInDay, let attr = messages[0].publishedSuggestedPostMessageAttribute {
                                        let header: String
                                        let info: String

                                        switch attr.currency {
                                        case .ton:
                                            header = strings().chatDeleteMessageSuggestedPostHeaderTon
                                            info = strings().chatDeleteMessageSuggestedPostInfoTon
                                        case .stars:
                                            header = strings().chatDeleteMessageSuggestedPostHeaderStars
                                            info = strings().chatDeleteMessageSuggestedPostInfoStars
                                        }

                                        verifyAlert(for: context.window, header: header, information: info, ok: strings().chatDeleteMessageSuggestedPostActionDeleteAnyway, successHandler: successHandler)
                                    } else {
                                        let thrid:String? = strongSelf.mode == .scheduled ? nil : (canDeleteForEveryone ? peer.isUser ? strings().chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : strings().chatConfirmDeleteMessagesForEveryone : nil)
                                        
                                        verifyAlert(for: context.window, header: thrid == nil ? strings().chatConfirmActionUndonable : strings().chatConfirmDeleteMessages1Countable(messages.count), information: thrid == nil ? _mustDeleteForEveryoneMessage ? strings().chatConfirmDeleteForEveryoneCountable(messages.count) : strings().chatConfirmDeleteMessages1Countable(messages.count) : nil, ok: strings().confirmDelete, option: thrid, successHandler: successHandler)
                                    }
                                    
                                }
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
                                case let .source(id, _):
                                    fromId = id
                                default:
                                    break
                                }
                            }
                            strongSelf.chatInteraction.focusMessageId(fromId, .init(messageId: postId, string: nil), TableScrollState.CenterEmpty)
                        }
                        if let action = action {
                            strongSelf.chatInteraction.update({ $0.updatedInitialAction(action) })
                            strongSelf.chatInteraction.invokeInitialAction()
                        }
                    } else {
                        if mode.isSavedMessagesThread {
                            navigateToChat(navigation: strongSelf.navigationController, context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: postId), initialAction: action)
                        } else {
                            navigateToChat(navigation: strongSelf.navigationController, context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: postId), initialAction: action, additional: true)
                        }
                    }
                } else {
                    
                    let threadInfo: ThreadInfo? = strongSelf.chatInteraction.threadInfo(peerId, holder: strongSelf.chatLocationContextHolder)
                    
                    let stories: PeerExpiringStoryListContext?
                    if peerId == strongSelf.chatInteraction.peerId {
                        stories = strongSelf.stories
                    } else {
                        stories = nil
                    }
                    if let navigation = strongSelf.navigationController {
                        if mode.isSavedMessagesThread {
                            let controller = PeerMediaController(context: context, peerId: peerId, threadInfo: threadInfo, isBot: false)
                            navigation.push(controller)
                        } else {
                            PeerInfoController.push(navigation: navigation, context: context, peerId: peerId, threadInfo: threadInfo, stories: stories)
                        }
                    }
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
                    self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets(), toVisible: true)
                }
                
            }
        }
        
        self.chatInteraction.openPendingRequests = { [weak self] in
            if let importersContext = self?.tempImportersContext {
                self?.navigationController?.push(RequestJoinMemberListController(context: context, peerId: peerId, manager: importersContext, openInviteLinks: { [weak self] in
                    self?.navigationController?.push(InviteLinksController(context: context, peerId: peerId, isChannel: false, manager: nil))
                }))
            }
        }
        self.chatInteraction.dismissPendingRequests = { [weak self] peerIds in
            guard let `self` = self else {
                return
            }
            FastSettings.dismissPendingRequests(peerIds, for: self.chatInteraction.peerId)
            self.chatInteraction.update {
                $0.withUpdatedInviteRequestsPending(nil)
                    .withUpdatedInviteRequestsPendingPeers(nil)
            }
        }
        
        
        self.chatInteraction.setupChatThemes = { [weak self] in
            self?.showChatThemeSelector()
        }
        self.chatInteraction.closeChatThemes = { [weak self] in
            self?.closeChatThemesSelector()
        }
        
        chatInteraction.openStory = { [weak self ] messageId, storyId in
            StoryModalController.ShowSingleStory(context: context, storyId: storyId, initialId: .init(peerId: peerId, id: nil, messageId: messageId, takeControl: { peerId, messageId, storyId in
                return self?.findStoryControl(messageId, storyId, peerId)
            }), emptyCallback: {
                showModalText(for: context.window, text: strings().storyErrorNotExist)
            })
        }
        
        chatInteraction.openChatPeerStories = { [weak self] messageId, peerId, setProgress in
            StoryModalController.ShowStories(context: context, isHidden: false, initialId: .init(peerId: peerId, id: nil, messageId: messageId, takeControl: { peerId, messageId, storyId in
                return self?.findStoryControl(messageId, storyId, peerId, useAvatar: true)
            }, setProgress: setProgress), singlePeer: true)
        }
        
        chatInteraction.sendMessageShortcut = { item in
            if let shortcutId = item.id {
                context.engine.accountData.sendMessageShortcut(peerId: peerId, id: shortcutId)
            }
        }
        
        chatInteraction.openProxySettings = { [weak self] in
            let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, pushController: { [weak self] controller in
                 self?.navigationController?.push(controller)
            })
            self?.navigationController?.push(controller)
        }
        
        chatInteraction.inlineAudioPlayer = { [weak self] controller in
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: self?.genericView.tableView, supportTableView: nil)
            context.sharedContext.showInlinePlayer(object)
        }
        
        chatInteraction.searchPeerMessages = { [weak self] peer in
            guard let `self` = self else { return }
            self.chatInteraction.update({ current in
                return current.updatedSearchMode(.init(inSearch: true, peer: .init(peer), query: nil, tag: nil))
            })
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
        
        
        chatInteraction.afterSentTransition = afterSentTransition
        
        chatInteraction.sendInlineResult = { [weak self] (results,result) in
            if let strongSelf = self {
                let invoke:()->Void = { [weak strongSelf] in
                    guard let strongSelf = strongSelf else {
                        return
                    }
                    func apply(_ controller: ChatController, atDate: Int32?) {
                        let chatInteraction = controller.chatInteraction
                        let value = context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: chatInteraction.peerId, threadId: threadId64(), botId: results.botId, result: result, replyToMessageId: takeReplyId(), sendPaidMessageStars: takePaidMessageStars())
                        if value {
                            controller.nextTransaction.set(handler: afterSentTransition)
                        }

                    }
                    switch strongSelf.mode {
                    case .history, .thread, .customChatContents:
                        apply(strongSelf, atDate: nil)
                    case .scheduled:
                        if let peer = strongSelf.chatInteraction.peer {
                            showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                                if let strongSelf = strongSelf {
                                    apply(strongSelf, atDate: Int32(date.timeIntervalSince1970))
                                }
                            }), for: context.window)
                        }
                    case .pinned:
                        break
                    case .customLink:
                        break
                    case  .preview:
                        break
                    }
                }
                
                let presentation = strongSelf.chatInteraction.presentation
                let messagesCount = 1
                
                if let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                    let starsPrice = Int(payStars.value * Int64(messagesCount))
                    let amount = strings().starListItemCountCountable(starsPrice)
                    
                    if !presentation.alwaysPaidMessage {
                        
                        let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                        
                        verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                            
                            if starsState.balance.value > starsPrice {
                                chatInteraction.update({ current in
                                    return current
                                        .withUpdatedAlwaysPaidMessage(result == .thrid)
                                })
                                if result == .thrid {
                                    FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                                }
                                invoke()
                            } else {
                                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                            }
                        })
                        
                    } else {
                        if starsState.balance.value > starsPrice {
                            invoke()
                        } else {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                        }
                    }
                } else {
                    invoke()
                }
                
            }
            
        }
        
        chatInteraction.beginEditingMessage = { [weak self] message in
            
            let process:()->Void = { [weak self] in
                if let message = message {
                    self?.chatInteraction.update({ state in
                        var state = state
                        state = state.withEditMessage(message)
                        
                        if let suggestAttr = message.suggestPostAttribute {
                            state = state.updatedInterfaceState({
                                return $0.withUpdatedSuggestPost(.init(amount: suggestAttr.amount, date: suggestAttr.timestamp, mode: message.effectivelyIncoming(context.peerId) ? .suggest(message.id) : .edit(message.id)))
                            })
                        }
                        
                        if let attribute = message.webpagePreviewAttribute {
                            state = state.updatedInterfaceState { current in
                                var current = current
                                current = current.withUpdatedLinkBelowMessage(!attribute.leadingPreview)
                                if let forceLargeMedia = attribute.forceLargeMedia {
                                    current = current.withUpdatedLargeMedia(forceLargeMedia)
                                }
                                return current
                            }
                        }
                        if !context.isPremium && context.peerId != peerId {
                            state = state.updatedInterfaceState { interfaceState in
                                var interfaceState = interfaceState
                                interfaceState = interfaceState.updatedEditState { editState in
                                    if let editState = editState {
                                        return editState.withUpdated(state: editState.inputState.withoutAnimatedEmoji)
                                    }
                                    return editState
                                }
                                return interfaceState
                            }
                        }
                        return state
                    })
                } else {
                    self?.chatInteraction.cancelEditing(true)
                }
                self?.chatInteraction.focusInputField()
            }
            
            if let message, message.media.first is TelegramMediaTodo, let self {
                showModal(with: NewTodoController(chatInteraction: self.chatInteraction, source: .edit(message, taskId: nil)), for: context.window)
                return
            }
            
            if let editState = self?.chatInteraction.presentation.interfaceState.editState, let window = self?.window, let _ = message  {
                if editState.inputState.inputText != editState.message.text {
                    verifyAlert_button(for: window, information: strings().chatEditCancelText, ok: strings().alertDiscard, successHandler: { _ in
                        process()
                    })
                } else {
                    process()
                }
            } else {
                process()
            }
        }
        
        chatInteraction.appendTask = { [weak self] message in
            guard let self else {
                return
            }
            if !context.isPremium {
                showModalText(for: context.window, text: strings().chatServiceTodoCompletePremium, callback: { _ in
                    prem(with: PremiumBoardingController(context: context, source: .todo, openFeatures: true), for: context.window)
                })
            } else {
                showModal(with: NewTodoController(chatInteraction: self.chatInteraction, source: .addOption(message)), for: context.window)
            }
        }
        
        chatInteraction.mentionPressed = { [weak self] in
            let signal = context.engine.messages.earliestUnseenPersonalMentionMessage(peerId: peerId, threadId: self?.chatLocation.threadId)
            self?.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] result in
                switch result {
                case .loading:
                    break
                case .result(let messageId):
                    if let messageId = messageId {
                        self?.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .CenterEmpty)
                    }
                }
            }))
        }
        
        chatInteraction.clearMentions = { [weak self] in
            guard let `self` = self else {return}
            _ = clearPeerUnseenPersonalMessagesInteractively(account: context.account, peerId: self.chatInteraction.peerId, threadId: chatLocation().threadId).start()
        }
        
        chatInteraction.clearReactions = { [weak self] in
            guard let `self` = self else {return}
            _ = clearPeerUnseenReactionsInteractively(account: context.account, peerId: self.chatInteraction.peerId, threadId: chatLocation().threadId).start()
        }
        
        chatInteraction.reactionPressed = { [weak self] in
            if let strongSelf = self {
                let signal = context.engine.messages.earliestUnseenPersonalReactionMessage(peerId: strongSelf.chatInteraction.peerId, threadId: strongSelf.chatLocation.threadId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak strongSelf] result in
                    if let strongSelf = strongSelf {
                        switch result {
                        case .loading:
                            break
                        case .result(let messageId):
                            if let messageId = messageId {
                                strongSelf.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .CenterEmpty)
                            }
                        }
                    }
                }))
            }
        }
        
        chatInteraction.editEditingMessagePhoto = { [weak self] media in
            guard let `self` = self else {return}
            if let resource = media.representationForDisplayAtSize(PixelDimensions(1280, 1280))?.resource {
                _ = (context.account.postbox.mediaBox.resourceData(resource) |> deliverOnMainQueue).start(next: { [weak self] resource in
                    guard let `self` = self else {return}
                    let url = URL(fileURLWithPath: link(path:resource.path, ext:kMediaImageExt)!)
                    let controller = EditImageModalController(url, context: context, defaultData: self.chatInteraction.presentation.interfaceState.editState?.editedData)
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
                case .history, .thread, .customChatContents:
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
                                    BrowserStateContext.get(context).open(tab: .game(url: url, peerId: strongSelf.chatInteraction.peerId, messageId: messageId))
                                } else {
                                    execute(inapp: .external(link: url, !(strongSelf.chatInteraction.peer?.isVerified ?? false)))
                                }
                            }
                        }
                    }
                    strongSelf.botCallbackAlertMessage.set(.single((strings().chatInlineRequestLoading, false)))
                    strongSelf.messageActionCallbackDisposable.set((context.engine.messages.requestMessageActionCallback(messageId: messageId, isGame:isGame, password: nil, data: data?.data) |> deliverOnMainQueue).start(next: applyResult, error: { [weak strongSelf] error in
                        
                        strongSelf?.botCallbackAlertMessage.set(.single(("", false)))
                        if let data = data, data.requiresPassword {
                            var errorText: String? = nil
                            var install2Fa = false
                            switch error {
                            case .invalidPassword:
                                showModal(with: InputPasswordController(context: context, title: strings().botTransferOwnershipPasswordTitle, desc: strings().botTransferOwnershipPasswordDesc, checker: { pwd in
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
                                errorText = strings().botTransferOwnerErrorText
                            case .twoStepAuthMissing:
                                errorText = strings().botTransferOwnerErrorText
                                install2Fa = true
                            case .twoStepAuthTooFresh:
                                errorText = strings().botTransferOwnerErrorText
                            default:
                                break
                            }
                            if let errorText = errorText {
                                verifyAlert_button(for: context.window, header: strings().botTransferOwnerErrorTitle, information: errorText, ok: strings().modalOK, cancel: strings().modalCancel, option: install2Fa ? strings().botTransferOwnerErrorEnable2FA : nil, successHandler: { result in
                                    switch result {
                                    case .basic:
                                        break
                                    case .thrid:
                                        context.bindings.rootNavigation().push(twoStepVerificationUnlockController(context: context, mode: .access(nil), presentController: { (controller, isRoot, animated) in
                                            let navigation = context.bindings.rootNavigation()
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
                case .pinned:
                    break
                case .customLink:
                    break
                case .preview:
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
        
        chatInteraction.setLocationTag = { [weak self] tag in
            guard let `self` = self else {
                return
            }
            self.chatInteraction.update { current in
                return current.updatedSearchMode(.init(inSearch: true, peer: current.searchMode.peer, query: current.searchMode.query, tag: tag == current.searchMode.tag ? nil : tag))
            }
            
        }
        
        chatInteraction.revealFactCheck = { [weak self] messageId in
            self?.updateState { current in
                var current = current
                if current.factCheck.contains(messageId) {
                    current.factCheck.remove(messageId)
                } else {
                    current.factCheck.insert(messageId)
                }
                return current
            }
        }
        
        
        chatInteraction.scrollToTheFirst = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let scroll: ChatHistoryLocation = .Scroll(index: .lowerBound, anchorIndex: .lowerBound, sourceIndex: .lowerBound, scrollPosition: .up(true), count: 50, animated: true)
            
            let historyView = preloadedChatHistoryViewForLocation(scroll, context: context, chatLocation: strongSelf.chatLocation, chatLocationContextHolder: strongSelf.chatLocationContextHolder, tag: strongSelf.locationValue?.tag, additionalData: [])
            
            struct FindSearchMessage {
                let message:Message?
                let loaded:Bool
            }
            
            let signal = historyView
            |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
                switch historyView {
                case .Loading:
                    return .single((nil, true))
                case .HistoryView:
                    return .single((nil, false))
                }
            }
            |> take(until: { index in
                return SignalTakeAction(passthrough: true, complete: !index.1)
            })

            
            strongSelf.chatInteraction.loadingMessage.set(.single(true) |> delay(0.2, queue: Queue.mainQueue()))
            strongSelf.messageIndexDisposable.set(showModalProgress(signal: signal, for: context.window).start(next: { [weak strongSelf] _ in
                strongSelf?.setLocation(scroll)
            }, completed: {
                    
            }))
        }
        
        chatInteraction.openFocusedMedia = { [weak self] timemark in
            if let focusTarget = self?.focusTarget {
                self?.genericView.tableView.enumerateItems(with: { item in
                    if let item = item as? ChatMediaItem, item.message?.id == focusTarget.messageId {
                        item.openMedia(timemark)
                        return false
                    }
                    return true
                })
            }
        }
        
        chatInteraction.focusPinnedMessageId = { [weak self] messageId in
            self?.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .CenterActionEmpty { [weak self] _ in
                self?.chatInteraction.update({$0.withUpdatedTempPinnedMaxId(messageId)})
            })
        }
        
        chatInteraction.toggleUnderMouseMessage = { [weak self] in
            if let event = NSApp.currentEvent, let `self` = self {
                let point = self.genericView.tableView.contentView.convert(event.locationInWindow, from: nil)
                let row = self.genericView.tableView.row(at: point)
                if row != -1 {
                    let item = self.genericView.tableView.item(at: row)
                    (item as? ChatRowItem)?.toggleSelect()
                }
            }
        }
        
        chatInteraction.runPremiumScreenEffect = { [weak self] message, mirror, isIncoming in
            guard let strongSelf = self else {
                return
            }
            let messageId = message.id
            if strongSelf.isOnScreen {
                strongSelf.emojiEffects.addPremiumEffect(mirror: mirror, isIncoming: isIncoming, messageId: messageId, viewFrame: context.window.bounds, for: context.window.contentView!)
            }
        }
        chatInteraction.runEmojiScreenEffect = { [weak self] emoji, message, mirror, isIncoming in
            guard let strongSelf = self else {
                return
            }
            let messageId = message.id
            if strongSelf.isOnScreen {
                strongSelf.emojiEffects.addAnimation(emoji.fixed, index: nil, mirror: mirror, isIncoming: isIncoming, messageId: messageId, animationSize: NSMakeSize(350, 350), viewFrame: context.window.bounds, for: context.window.contentView!)
            }
        }
        
        chatInteraction.runReactionEffect = { [weak self] value, messageId in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.isOnScreen {
                strongSelf.emojiEffects.addReactionAnimation(value, index: nil, messageId: messageId, animationSize: NSMakeSize(80, 80), viewFrame: context.window.bounds, for: context.window.contentView!)
            }
        }
        
        chatInteraction.toggleSendAs = { updatedPeerId in
            _ = context.engine.peers.updatePeerSendAsPeer(peerId: peerId, sendAs: updatedPeerId).start()
        }
        
        chatInteraction.focusMessageId = { [weak self] fromId, focusTarget, state in
            
            if let strongSelf = self {
               
                if focusTarget.messageId.peerId != strongSelf.chatInteraction.peerId {
                    let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: focusTarget.messageId.peerId)) |> deliverOnMainQueue
                    _ = peer.startStandalone(next: { [weak strongSelf] value in
                        let accept: Bool
                        if let value = value {
                            switch value {
                            case let .channel(channel):
                                accept = channel.participationStatus == .member || value.addressName != nil
                            case let .legacyGroup(group):
                                accept = group.membership == .Member || value.addressName != nil
                            default:
                                accept = false
                            }
                            
                        } else {
                            accept = false
                        }
                        if accept {
                            strongSelf?.navigationController?.push(ChatAdditionController(context: context, chatLocation: .peer(focusTarget.messageId.peerId), focusTarget: focusTarget))
                        } else {
                            let text: String
                            if let peer = value {
                                if peer._asPeer().isChannel {
                                    text = strings().chatToastQuoteChatUnavailbalePrivateChannel
                                } else if peer._asPeer().isGroup || peer._asPeer().isSupergroup {
                                    text = strings().chatToastQuoteChatUnavailbalePrivateGroup
                                } else {
                                    text = strings().chatToastQuoteChatUnavailbalePrivateChat
                                }
                            } else {
                                text = strings().chatToastQuoteChatUnavailbalePrivateChat
                            }
                            showModalText(for: context.window, text: text)
                        }
                    })
                    return
                }
                
                switch strongSelf.mode {
                case .history, .thread, .customChatContents:
                    if let fromId = fromId {
                        strongSelf.historyState = strongSelf.historyState.withAddingReply(fromId)
                    }
                    
                    var fromIndex: MessageIndex?
                    let innerId: Int32?
                    
                    if let fromId = fromId, let message = strongSelf.messageInCurrentHistoryView(fromId) {
                        fromIndex = MessageIndex(message)
                    } else {
                        if let message = strongSelf.anchorMessageInCurrentHistoryView() {
                            fromIndex = MessageIndex(message)
                        }
                    }
                    if let fromId = fromId, let message = strongSelf.messageInCurrentHistoryView(fromId) {
                        innerId = message.replyAttribute?.todoItemId
                    } else {
                        innerId = nil
                    }
                    if let fromIndex = fromIndex {
                        let historyView = preloadedChatHistoryViewForLocation(.InitialSearch(location: .id(focusTarget.messageId, focusTarget.string), count: strongSelf.requestCount), context: context, chatLocation: strongSelf.chatLocation, chatLocationContextHolder: strongSelf.chatLocationContextHolder, tag: strongSelf.locationValue?.tag, additionalData: [])
                        
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
                                        if entry.message.id == focusTarget.messageId {
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
                                let scroll = state
                                    .swap(to: ChatHistoryEntryId.message(message)).text(string: focusTarget.string, innerId: innerId)
                                    .focus(action: { [weak strongSelf] view in
                                        if let strongSelf {
                                            let content: ChatHistoryLocation = .Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: .none(nil), count: requestCount, animated: state.animated)
                                            strongSelf.setLocation(content)
                                        }
                                        state.action?(view)
                                    })
                                let content: ChatHistoryLocation = .Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: scroll, count: requestCount, animated: state.animated)
                                let id = strongSelf.takeNextHistoryLocationId()
                                strongSelf.setLocation(content)
                            }
                        }))
                        //  }
                    }
                case .scheduled:
                    strongSelf.navigationController?.back()
                    (strongSelf.navigationController?.controller as? ChatController)?.chatInteraction.focusMessageId(fromId, focusTarget, state)
                case .pinned:
                    break
                case .customLink:
                    break
                case .preview:
                    break
                }
            }
            
        }
        
        chatInteraction.vote = { [weak self] messageId, opaqueIdentifiers, submit in
            guard let `self` = self else {return}
            
            self.updateState { state in
                var state = state
                var data = state.pollAnswers
                data[messageId] = ChatPollStateData(identifiers: opaqueIdentifiers, isLoading: submit && !opaqueIdentifiers.isEmpty)
                state.pollAnswers = data
                return state
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
                        self?.updateState { state in
                            var state = state
                            var data = state.pollAnswers
                            data.removeValue(forKey: messageId)
                            state.pollAnswers = data
                            return state
                        }
                        var once: Bool = true
                        self?.afterNextTransaction = { [weak self] in
                            if let tableView = self?.genericView.tableView, once {
                                tableView.enumerateItems(with: { item -> Bool in
                                    if let item = item as? ChatRowItem, let message = item.message, message.id == messageId, let `self` = self {
                                        
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
                        alert(for: context.window, info: strings().unknownError)
                    }
                    self?.updateState { state in
                        var state = state
                        var data = state.pollAnswers
                        data.removeValue(forKey: messageId)
                        state.pollAnswers = data
                        return state
                    }
                    
                }), forKey: messageId)
            }
            
        }
        chatInteraction.closePoll = { [weak self] messageId in
            guard let `self` = self else {return}
            self.selectMessagePollOptionDisposables.set(context.engine.messages.requestClosePoll(messageId: messageId).start(), forKey: messageId)
        }
        
        chatInteraction.revealMedia = { [weak self] message in
            
            if message.isSensitiveContent(platform: "ios") {
                
                if !context.contentConfig.sensitiveContentEnabled, context.contentConfig.canAdjustSensitiveContent {
                    let need_verification = context.appConfiguration.getBoolValue("need_age_video_verification", orElse: false)
                    
                    if need_verification {
                        showModal(with: VerifyAgeAlertController(context: context), for: context.window)
                        return
                    }
                }
                if context.contentConfig.sensitiveContentEnabled {
                    self?.updateState { current in
                        var current = current
                        current.mediaRevealed.insert(message.id)
                        return current
                    }
                } else {
                    verifyAlert(for: context.window, header: strings().chatSensitiveContent, information: strings().chatSensitiveContentConfirm, ok: strings().chatSensitiveContentConfirmOk, option: context.contentConfig.canAdjustSensitiveContent ? strings().chatSensitiveContentConfirmThird : nil, optionIsSelected: false, successHandler: { result in
                        self?.updateState { current in
                            var current = current
                            current.mediaRevealed.insert(message.id)
                            return current
                        }
                        if result == .thrid {
                            let _ = updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: true).start()
                            let messages = self?.historyView?.originalView?.entries.compactMap { $0.message } ?? []
                            self?.updateState { current in
                                var current = current
                                for message in messages {
                                    current.mediaRevealed.insert(message.id)
                                }
                                return current
                            }
                        }
                    })
                }
            } else {
                self?.updateState { current in
                    var current = current
                    current.mediaRevealed.insert(message.id)
                    return current
                }
            }
            
        }
        chatInteraction.openStories = { [weak self] f, setProgress in
            let state = self?.uiState.with ({ $0.storyState })
            if let _ = state {
                StoryModalController.ShowStories(context: context, isHidden: false, initialId: .init(peerId: peerId, id: nil, messageId: nil, takeControl: f, setProgress: setProgress), singlePeer: true)
            }
        }
        
        chatInteraction.toggleTranslate = { [weak self] in
            let enabled = self?.uiState.with { $0.translate?.translate } == true
            if !context.isPremium && !enabled {
                prem(with: PremiumBoardingController(context: context, source: .translations, openFeatures: true), for: context.window)
            } else {
                self?.liveTranslate?.toggleTranslate()
            }
            self?.genericView.tableView.notifyScrollHandlers()
        }
        chatInteraction.hideTranslation = { [weak self] in
            if !context.isPremium {
                self?.liveTranslate?.disablePaywall()
                showModalText(for: context.window, text: strings().chatTranslateMenuHidePaywallTooltip)
            } else {
                self?.liveTranslate?.hideTranslation()
                if let peer = self?.chatInteraction.peer {
                    let text: String
                    if peer.isUser {
                        text = strings().chatTranslateMenuHideUserTooltip(peer.compactDisplayTitle)
                    } else if peer.isChannel {
                        text = strings().chatTranslateMenuHideChannelTooltip
                    } else if peer.isBot {
                        text = strings().chatTranslateMenuHideBotTooltip
                    } else {
                        text = strings().chatTranslateMenuHideGroupTooltip
                    }
                    showModalText(for: context.window, text: text)
                }
            }
        }
        chatInteraction.doNotTranslate = { code in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var current = settings.doNotTranslate
                if !current.contains(code) {
                    current.insert(code)
                }
                return settings.withUpdatedDoNotTranslate(current)
            }).start()
        }
        
        chatInteraction.sendMedia = { [weak self] media in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {
                let currentSendAsPeerId = strongSelf.chatInteraction.presentation.currentSendAsPeerId
                switch strongSelf.mode {
                case .scheduled:
                    showModal(with: DateSelectorModalController(context: strongSelf.context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                        if let strongSelf = strongSelf {
                            let _ = (Sender.enqueue(media: media, context: context, peerId: peerId, replyId: takeReplyId(), threadId: threadId64(), atDate: date, sendAsPeerId: currentSendAsPeerId, customChatContents: customChatContents, sendPaidMessageStars: takePaidMessageStars()) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                            strongSelf.nextTransaction.set(handler: afterSentTransition)
                        }
                    }), for: strongSelf.context.window)
                case .history, .thread, .customChatContents:
                    let _ = (Sender.enqueue(media: media, context: context, peerId: peerId, replyId: takeReplyId(), threadId: threadId64(), sendAsPeerId: currentSendAsPeerId, customChatContents: customChatContents, sendPaidMessageStars: takePaidMessageStars()) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                    strongSelf.nextTransaction.set(handler: afterSentTransition)
                case .pinned:
                    break
                case .customLink:
                    break
                case .preview:
                    break
                }
            }
        }
        
        chatInteraction.attachFile = { [weak self] asMedia in
            if let `self` = self, let window = self.window {
                if let slowMode = self.chatInteraction.presentation.slowMode, let errorText = slowMode.errorText {
                    tooltip(for: self.genericView.inputView.attachView, text: errorText)
                    if let last = slowMode.sendingIds.last {
                        self.chatInteraction.focusMessageId(nil, .init(messageId: last, string: nil), .CenterEmpty)
                    }
                } else if let peer = self.chatInteraction.peer {
                    
                    let canSend = peer.canSendMessage(self.mode.isThreadMode, threadData: self.chatInteraction.presentation.threadInfo, cachedData: self.chatInteraction.presentation.cachedData)

                    
                    if canSend {
                        filePanel(allowMultiple: true, canChooseDirectories: true, for: window, completion:{ result in
                            if let result = result {
                                
                                let previous = result.count
                                var exceedSize: Int64?
                                let result = result.filter { path -> Bool in
                                    if let size = fileSize(path) {
                                        let exceed = fileSizeLimitExceed(context: context, fileSize: size)
                                        if exceed {
                                            exceedSize = size
                                        }
                                        return exceed
                                    }
                                    return false
                                }
                                
                                let afterSizeCheck = result.count
                                
                                if afterSizeCheck == 0 && previous != afterSizeCheck {
                                    showFileLimit(context: context, fileSize: exceedSize)
                                } else {
                                    self.chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, asMedia, nil)
                                }
                                
                            }
                        })
                    }
                }
            }
            
        }
        chatInteraction.attachPhotoOrVideo = { [weak self] type in
            if let `self` = self, let window = self.window {
                if let slowMode = self.chatInteraction.presentation.slowMode, let errorText = slowMode.errorText {
                    tooltip(for: self.genericView.inputView.attachView, text: errorText)
                    if let last = slowMode.sendingIds.last {
                        self.chatInteraction.focusMessageId(nil, .init(messageId: last, string: nil), .CenterEmpty)
                    }
                } else {
                    var exts:[String]? = nil
                    if let type = type {
                        switch type {
                        case .photo:
                            exts = photoExts
                        case .video:
                            exts = videoExts
                        }
                    }
                                        
                    filePanel(with: exts, allowMultiple: true, canChooseDirectories: true, for: window, completion:{ [weak self] result in
                        if let result = result {
                            let previous = result.count
                            
                            var exceedSize: Int64?
                            let result = result.filter { path -> Bool in
                                if let size = fileSize(path) {
                                    let exceed = fileSizeLimitExceed(context: context, fileSize: size)
                                    if exceed {
                                        exceedSize = size
                                    }
                                    return exceed
                                }
                                return false
                            }
                            
                            let afterSizeCheck = result.count
                            
                            if afterSizeCheck == 0 && previous != afterSizeCheck {
                                showFileLimit(context: context, fileSize: exceedSize)
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
                        let signal = putToTemp(image: image) |> deliverOnMainQueue
                        _ = signal.start(next: { path in
                            self?.chatInteraction.showPreviewSender([URL(fileURLWithPath: path)], true, nil)
                        })
                    }
                })
            }
        }
        chatInteraction.attachLocation = { [weak self] in
            guard let `self` = self else {return}
            showModal(with: LocationModalController(self.chatInteraction), for: context.window)
        }
        
        chatInteraction.sendAppFile = { [weak self] file, silent, query, schedule, collectionId in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode, media: file, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData) {
                
                let invoke:()->Void = {
                    let hasFwd = !strongSelf.chatInteraction.presentation.interfaceState.forwardMessageIds.isEmpty
                    func apply(_ controller: ChatController, atDate: Date?) {
                        let _ = (Sender.enqueue(media: file, context: context, peerId: peerId, replyId: takeReplyId(), threadId: threadId64(), silent: silent, atDate: atDate, query: query, collectionId: collectionId, customChatContents: customChatContents, sendPaidMessageStars: takePaidMessageStars()) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                        controller.nextTransaction.set(handler: {
                            if hasFwd {
                                DispatchQueue.main.async {
                                    self?.chatInteraction.sendMessage(false, nil, self?.chatInteraction.presentation.messageEffect)
                                }
                            } else {
                                afterSentTransition()
                            }
                        })
                    }
                    
                    let shouldSchedule: Bool
                    switch strongSelf.mode {
                    case .scheduled:
                        shouldSchedule = true
                    default:
                        shouldSchedule = schedule
                    }
                    
                    if shouldSchedule {
                        showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak strongSelf] date in
                            if let controller = strongSelf {
                                apply(controller, atDate: date)
                            }
                        }), for: context.window)
                    } else {
                        apply(strongSelf, atDate: nil)
                    }
                }
                
                let presentation = strongSelf.chatInteraction.presentation
                let messagesCount = 1
                
                if let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                    let starsPrice = Int(payStars.value * Int64(messagesCount))
                    let amount = strings().starListItemCountCountable(starsPrice)
                    
                    if !presentation.alwaysPaidMessage {
                        
                        let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                        
                        verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                            
                            if starsState.balance.value > starsPrice {
                                chatInteraction.update({ current in
                                    return current
                                        .withUpdatedAlwaysPaidMessage(result == .thrid)
                                })
                                if result == .thrid {
                                    FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                                }
                                invoke()
                            } else {
                                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                            }
                        })
                        
                    } else {
                        if starsState.balance.value > starsPrice {
                            invoke()
                        } else {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                        }
                    }
                } else {
                    invoke()
                }
                
            }
        }
        
        chatInteraction.sendMedias = { [weak self] medias, caption, isCollage, additionText, silent, atDate, isSpoiler, messageEffect, leadingText in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {
                
                let presentation = strongSelf.chatInteraction.presentation
                
                let canSend = medias.map {
                    return peer.canSendMessage(strongSelf.mode.isThreadMode, media: $0, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData)
                }.allSatisfy { $0 }
                
                if canSend {
                    
                    let invoke:()->Void = {
                        func apply(_ controller: ChatController, atDate: Date?) {
                            let _ = (Sender.enqueue(media: medias, caption: caption, context: context, peerId: controller.chatInteraction.peerId, replyId: takeReplyId(), threadId: threadId64(), isCollage: isCollage, additionText: additionText, silent: silent, atDate: atDate, isSpoiler: isSpoiler, customChatContents: customChatContents, messageEffect: messageEffect, leadingText: leadingText, sendPaidMessageStars: takePaidMessageStars(), suggestPost: presentation.interfaceState.suggestPost) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                            controller.nextTransaction.set(handler: afterSentTransition)
                        }
                        switch strongSelf.mode {
                        case .history, .thread, .customChatContents:
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
                        case .pinned:
                            break
                        case .customLink:
                            break
                        case .preview:
                            break
                        }
                    }
                    invoke()
                }
            }
        }
        
        chatInteraction.shareSelfContact = { [weak self] replyId in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer {
                if let myPeer = context.myPeer as? TelegramUser {
                    let media = TelegramMediaContact(firstName: myPeer.firstName ?? "", lastName: myPeer.lastName ?? "", phoneNumber: myPeer.phone ?? "", peerId: myPeer.id, vCardData: nil)
                    let canSend = peer.canSendMessage(strongSelf.mode.isThreadMode, media: media, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData)
                    if canSend {
                        _ = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: media), threadId: threadId64(), replyToMessageId: replyId.flatMap { .init(messageId: $0, quote: nil, todoItemId: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []), context: context, peerId: peerId).start(completed: scrollAfterSend)
                        strongSelf.nextTransaction.set(handler: afterSentTransition)
                    }
                }
            }
        }
        
        chatInteraction.restartTopic = {
            switch chatLocation() {
            case let .thread(data):
                _ = context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: data.threadId, isClosed: false).start()
            default:
                break
            }
        }
        
        chatInteraction.sendCommand = { [weak self] command in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData) {
                func apply(_ controller: ChatController, atDate: Date?) {
                    var commandText = "/" + command.command.text
                    if controller.chatInteraction.peerId.namespace != Namespaces.Peer.CloudUser {
                        commandText += "@" + (command.peer.username ?? "")
                    }
                    _ = Sender.enqueue(input: ChatTextInputState(inputText: commandText), context: context, peerId: controller.chatLocation.peerId, replyId: takeReplyId(), threadId: threadId64(), atDate: atDate, customChatContents: customChatContents, sendPaidMessageStars: takePaidMessageStars()).start(completed: scrollAfterSend)
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
                case .history, .thread, .customChatContents:
                    apply(strongSelf, atDate: nil)
                case .pinned:
                    break
                case .customLink:
                    break
                case .preview:
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
                        self.chatInteraction.focusMessageId(nil, .init(messageId: slowMode.sendingIds.last!, string: nil), .CenterEmpty)
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
                        if let editState = self.chatInteraction.presentation.interfaceState.editState {
                            if editState.message.media.isEmpty, updated.count == 1 {
                                if let media = updated.first {
                                    self.updateMediaDisposable.set((Sender.generateMedia(for: MediaSenderContainer(path: media.path, isFile: false), account: context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) |> deliverOnMainQueue).start(next: { [weak self] media, _ in
                                        self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                                    }))
                                }

                            } else {
                                alert(for: context.window, info: strings().chatEditAttachError)
                            }
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
            if let peer = strongSelf.chatInteraction.peer, peer.canSendMessage(strongSelf.mode.isThreadMode, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData) {
                _ = (context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peer.id, timeout: seconds) |> deliverOnMainQueue).start(completed: scrollAfterSend)
                strongSelf.nextTransaction.set(handler: afterSentTransition)
            }
            scrollAfterSend()
        }
        
        chatInteraction.showEmojiUseTooltip = { [weak self] in
            if let view = self?.genericView.inputView.emojiView {
                tooltip(for: view, text: strings().emojiPackMoreEmoji)
            }
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
                            tooltip(for: control, text: strings().chatInputAutoDelete1Day)
                        case .secondsInWeek:
                            tooltip(for: control, text: strings().chatInputAutoDelete7Days)
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
            guard let self else {
                return
            }
            let peerId = self.chatInteraction.presentation.peer?.associatedPeerId ?? self.chatLocation.peerId
            if isMuted == nil || isMuted == true {
                _ = context.engine.peers.togglePeerMuted(peerId: peerId, threadId: self.chatLocation.threadId).start()
            } else {
                var options:[ModalOptionSet] = []
                
                options.append(ModalOptionSet(title: strings().chatListMute1Hour, selected: false, editable: true))
                options.append(ModalOptionSet(title: strings().chatListMute4Hours, selected: false, editable: true))
                options.append(ModalOptionSet(title: strings().chatListMute8Hours, selected: false, editable: true))
                options.append(ModalOptionSet(title: strings().chatListMute1Day, selected: false, editable: true))
                options.append(ModalOptionSet(title: strings().chatListMute3Days, selected: false, editable: true))
                options.append(ModalOptionSet(title: strings().chatListMuteForever, selected: true, editable: true))
                
                let intervals:[Int32] = [60 * 60, 60 * 60 * 4, 60 * 60 * 8, 60 * 60 * 24, 60 * 60 * 24 * 3, Int32.max]
                
                showModal(with: ModalOptionSetController(context: context, options: options, selectOne: true, actionText: (strings().chatInputMute, theme.colors.accent), title: strings().peerInfoNotifications, result: { [weak self] result in
                    
                    for (i, option) in result.enumerated() {
                        inner: switch option {
                        case .selected:
                            _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: self?.chatLocation.threadId, muteInterval: intervals[i]).start()
                            break
                        default:
                            break inner
                        }
                    }
                    
                }), for: context.window)
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
                        strongSelf?.context.bindings.rootNavigation().close()
                    }
                }))
            }
        }
        
        chatInteraction.joinChannel = {
            joinChannel(context: context, peerId: peerId)
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
                let join:(PeerId, Date?, Bool)->Void = { joinAs, _, _ in
                    _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: activeCall, initialInfo: groupCall?.data?.info, joinHash: joinHash, reference: nil), for: context.window).start(next: { result in
                        switch result {
                        case let .samePeer(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                            if let joinHash = joinHash {
                                callContext.call.joinAsSpeakerIfNeeded(joinHash)
                            }
                        case let .success(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                        default:
                            alert(for: context.window, info: strings().errorAnError)
                        }
                    })
                }
                if groupCall?.data?.info?.isStream == true {
                    join(context.account.peerId, nil, false)
                } else if let callJoinPeerId = groupCall?.callJoinPeerId {
                    join(callJoinPeerId, nil, false)
                } else {
                    selectGroupCallJoiner(context: context, peerId: peerId, completion: join)
                }
            } else if let peer = self?.chatInteraction.peer {
                if peer.groupAccess.canMakeVoiceChat {
                    verifyAlert_button(for: context.window, information: strings().voiceChatChatStartNew, ok: strings().voiceChatChatStartNewOK, successHandler: { _ in
                        createVoiceChat(context: context, peerId: peerId)
                    })
                }
            }
        }
        
        chatInteraction.returnGroup = { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
              //  _ = showModalProgress(signal: returnGroup(account: context.account, peerId: strongSelf.chatInteraction.peerId), for: window).start()
            }
        }
        
        chatInteraction.transcribeAudio = { [weak self] message in
            
            let messageId = message.id
            
            guard let strongSelf = self else {
                return
            }
            
         
                        
            let value: [MessageId : TranscribeAudioState] = strongSelf.uiState.with { $0.transribe }
           
            if let value = value[messageId] {
                strongSelf.updateState { state in
                    var state = state
                    switch value {
                    case let .revealed(success):
                        state.transribe[messageId] = .collapsed(success)
                    case let .collapsed(success):
                        state.transribe[messageId] = .revealed(success)
                    case .loading:
                        break
                    }
                    return state
                }
            } else {
                
                let currentTime = Int32(Date().timeIntervalSince1970)
                if !context.isPremium, message.audioTranscription == nil {
                    if let cooldownUntilTime = context.audioTranscriptionTrial.cooldownUntilTime, cooldownUntilTime > currentTime {
                        let time = stringForMediumDate(timestamp: Int32(cooldownUntilTime))
                        let trialCount = context.appConfiguration.getGeneralValue("transcribe_audio_trial_weekly_number", orElse: 0)
                        let usedString = strings().conversationFreeTranscriptionCooldownTooltipCountable(Int(trialCount))
                        let waitString = strings().conversationFreeTranscriptionWaitOrSubscribe(time)
                        let fullString = "\(usedString) \(waitString)"
                        showModalText(for: context.window, text: fullString, callback: { _ in
                            prem(with: PremiumBoardingController(context: context, source: .translations), for: context.window)
                        })
                        return
                    } else {
                        let remainingCount = context.audioTranscriptionTrial.remainingCount
                        let text = strings().conversationFreeTranscriptionLimitTooltipCountable(Int(remainingCount))
                        showModalText(for: context.window, text: text)
                    }
                }
                
                strongSelf.updateState { state in
                    var state = state
                    state.transribe[messageId] = .loading
                    return state
                }
                
                let signal = context.engine.messages.transcribeAudio(messageId: messageId)
                |> deliverOnMainQueue

                strongSelf.transcribeDisposable.set(signal.start(next: { [weak strongSelf] result in
                    strongSelf?.updateState { state in
                        var state = state
                        switch result {
                        case .success:
                            state.transribe[messageId] = .revealed(true)
                        case .error:
                            state.transribe[messageId] = .revealed(false)
                        }
                        return state
                    }
                }), forKey: messageId)
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
            if let strongSelf = self, let main = strongSelf.chatInteraction.peer {
                if let permissionText = permissionText(from: main, for: .banSendText, cachedData: strongSelf.chatInteraction.presentation.cachedData) {
                    showModalText(for: context.window, text: permissionText)
                    return
                }
                let media = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)
                let canSend = main.canSendMessage(strongSelf.mode.isThreadMode, media: media, threadData: strongSelf.chatInteraction.presentation.threadInfo, cachedData: strongSelf.chatInteraction.presentation.cachedData)
                if canSend {
                    _ = Sender.shareContact(context: context, peerId: strongSelf.chatInteraction.peerId, media: media, replyId: takeReplyId(), threadId: threadId64(), sendPaidMessageStars: takePaidMessageStars()).start(completed: scrollAfterSend)
                    strongSelf.nextTransaction.set(handler: afterSentTransition)
                }
            }
        }
        
        chatInteraction.unblock = { [weak self] in
            if let strongSelf = self {
                let presentation = strongSelf.chatInteraction.presentation
                if let peer = presentation.mainPeer {
                    strongSelf.unblockDisposable.set(context.blockedPeersContext.remove(peerId: peer.id).start())
                }
            }
        }
        
        chatInteraction.replyToAnother = { [weak self] subject, reset in
            
            if reset {
                self?.chatInteraction.update({
                    $0.updatedInterfaceState({
                        $0.withUpdatedReplyMessageId(nil)
                    })
                })
            }
            
            let message = context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: subject.messageId)) |> deliverOnMainQueue
            
            _ = message.start(next: { message in
                if let message = message?._asMessage() {
                    showModal(with: ShareModalController(ReplyForwardMessageObject(context, message: message, subject: subject)), for: context.window)
                }
                
            })
        }
        
        chatInteraction.toggleQuote = { [weak self] index in
            self?.updateState { current in
                var current = current
                if current.quoteRevealed.contains(index) {
                    current.quoteRevealed.remove(index)
                } else {
                    current.quoteRevealed.insert(index)
                }
                return current
            }
        }
        
        chatInteraction.enqueueCodeSyntax = { [weak self] messageId, range, code, language, theme in
            assertOnMainThread()
            
            let codeSyntaxes = self?.uiState.with { $0.codeSyntaxes }
            
            let key = CodeSyntaxKey(messageId: messageId, range: range, language: language, theme: theme)
            if codeSyntaxes?[key] == nil {
                
                self?.updateState({ current in
                    var current = current
                    current.codeSyntaxes[key] = .init(resut: nil)
                    return current
                })
                
                let signal: Signal<CodeSyntaxResult, NoError> = Signal { subscriber in
                    subscriber.putNext(.init(resut: CodeSyntax.syntax(code: code, language: language, theme: theme)))
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                |> runOn(.concurrentBackgroundQueue())
                |> deliverOnMainQueue
                
                self?.codeSyntaxHighlightDisposables.set(signal.startStrict(next: { result in
                    self?.updateState({ current in
                        var current = current
                        current.codeSyntaxes[key] = result
                        return current
                    })
                }), forKey: key)
            }
        }
        
        chatInteraction.openPhoneNumberContextMenu = { [weak self] phoneNumber in
            let point = context.window.mouseLocationOutsideOfEventStream
            let view = context.window.contentView?.hitTest(point)
            
            if let view, let event = NSApp.currentEvent {
                
                let signal = context.engine.peers.resolvePeerByPhone(phone: phoneNumber) |> deliverOnMainQueue
                
                _ = signal.startStandalone(next: { [weak view] peer in
                    
                    if let view = view {
                        let menu = ContextMenu()
                        
                        menu.addItem(ContextMenuItem(strings().contextCopyToClipboard, handler: {
                            copyToClipboard(phoneNumber)
                            showModalText(for: context.window, text: strings().shareLinkCopied)
                        }, itemImage: MenuAnimation.menu_copy.value))
                        
                        menu.addItem(ContextSeparatorItem())

                        let item: ContextMenuItem
                        if let peer {
                            item = ReactionPeerMenu(title: peer._asPeer().displayTitle, handler: { [weak self] in
                                self?.chatInteraction.openInfo(peer.id, true, nil, nil)
                            }, peer: peer._asPeer(), context: context, reaction: nil, message: nil)
                        } else {
                            item = ContextMenuItem(strings().chatContextPhoneNotTelegram)
                            item.isEnabled = false
                        }
                        menu.addItem(item)
                        
                        AppMenu.show(menu: menu, event: event, for: view)
                    }
                })
                
                
            }
        }
        
        chatInteraction.updatePinned = { [weak self] pinnedId, dismiss, silent, forThisPeerOnlyIfPossible in
            if let `self` = self {
                
                let pinnedUpdate: PinnedMessageUpdate = dismiss ? .clear(id: pinnedId) : .pin(id: pinnedId, silent: silent, forThisPeerOnlyIfPossible: forThisPeerOnlyIfPossible)
                let peerId = self.chatInteraction.peerId
                if let peer = self.chatInteraction.peer as? TelegramChannel {
                    if peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
                        
                        let verify = dismiss ? verifyAlertSignal(for: context.window, header: strings().chatConfirmUnpinHeader, information: strings().chatConfirmUnpin, ok: strings().chatConfirmUnpinOK) |> map { $0 == .basic } |> filter { $0 } : .single(true)
                        
                        self.updatePinnedDisposable.set((verify |> mapToSignal { _ in return
                            showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate) |> `catch` { _ in .complete() }, for: context.window)}).start())
                    } else {
                        self.chatInteraction.update({$0.updatedInterfaceState({$0.withAddedDismissedPinnedIds([pinnedId])})})
                    }
                } else if self.chatInteraction.peerId.namespace == Namespaces.Peer.CloudUser {
                    if dismiss {
                        verifyAlert_button(for: context.window, header: strings().chatConfirmUnpinHeader, information: strings().chatConfirmUnpin, ok: strings().chatConfirmUnpinOK, successHandler: { [weak self] _ in
                            self?.updatePinnedDisposable.set(showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate), for: context.window).start())
                        })
                    } else {
                        self.updatePinnedDisposable.set(showModalProgress(signal: context.engine.messages.requestUpdatePinnedMessage(peerId: peerId, update: pinnedUpdate), for: context.window).start())
                    }
                } else if let peer = self.chatInteraction.peer as? TelegramGroup, peer.canPinMessage {
                    if dismiss {
                        verifyAlert_button(for: context.window, header: strings().chatConfirmUnpinHeader, information: strings().chatConfirmUnpin, ok: strings().chatConfirmUnpinOK, successHandler: {  [weak self]_ in
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
            self.navigationController?.push(ChatAdditionController(context: context, chatLocation: chatLocation(), mode: .pinned, focusTarget: .init(messageId: messageId)))
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
                
                verifyAlert_button(for: context.window, information: strings().chatUnpinAllMessagesConfirmationCountable(count), ok: strings().chatConfirmUnpinOK, cancel: strings().modalCancel, successHandler: { [weak self] _ in
                    let _ = (context.engine.messages.requestUnpinAllMessages(peerId: peerId, threadId: self?.chatLocation.threadId)
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
        
        chatInteraction.openMonoforum = { [weak self] peerId in
            guard let self else {
                return
            }
            
            let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
            
            _ = peer.startStandalone(next: { [weak self] peer in
                
                guard let peer, let self else {
                    return
                }
                self.chatInteraction.saveState(scrollState: self.immediateScrollState())
                
                if peer._asPeer().groupAccess.canManageDirect {
                    let location: ChatLocation = .makeSaved(peerId, peerId: context.peerId, isMonoforum: true)
                    
                    self.navigationController?.push(ChatAdditionController(context: context, chatLocation: location, mode: .history))

                } else {
                    self.navigationController?.push(ChatAdditionController(context: context, chatLocation: .peer(peerId), mode: .history))
                }

            })
        }
        
        chatInteraction.sendGift = {
            showModal(with: GiftingController(context: context, peerId: peerId, isBirthday: false), for: context.window)
        }
        
        chatInteraction.editPostSuggestion = { [weak self] data in
            if let chatInteraction = self?.chatInteraction {
                showModal(with: EditPostSuggestionController(chatInteraction: chatInteraction, data: data), for: context.window)
            }
        }
        
        
        
        chatInteraction.toggleMonoforumState = { [weak self] in
            guard let self else {
                return
            }
            self.updateState { current in
                var current = current
                current.monoforumState = current.monoforumState == .vertical ? .horizontal : .vertical
                return current
            }
            FastSettings.setMonoforumState(peerId, state: self.uiState.with { $0.monoforumState ?? .vertical })
        }
        
        chatInteraction.monoforumMenuItems = { [weak self] item in
            var items: [ContextMenuItem] = []
            
            let threadId = item.uniqueId
                        
            guard let peer = self?.chatInteraction.peer as? TelegramChannel else {
                return .single([])
            }
            
            if let item = item.item, let threadData = item.threadData {
                
                if threadData.isOwnedByMe || peer.isAdmin {
                    items.append(ContextMenuItem(strings().navigationEdit, handler: {
                        ForumUI.editTopic(peer.id, data: threadData, threadId: threadId, context: context)
                    }, itemImage: MenuAnimation.menu_edit.value))
                }
                
                if let readCounters = item.readCounters, readCounters.isUnread {
                    items.append(ContextMenuItem(strings().chatListContextMaskAsRead, handler: {
                        _ = context.engine.messages.markForumThreadAsRead(peerId: peerId, threadId: threadId).start()
                    }, itemImage: MenuAnimation.menu_read.value))
                }
                
                let isPinned = item.chatListIndex.pinningIndex != nil
                let isMuted = item.isMuted
                let isClosedTopic = threadData.isClosed
                
                if peer.hasPermission(.pinMessages) {
                    items.append(ContextMenuItem(!isPinned ? strings().chatListContextPin : strings().chatListContextUnpin, handler: {
                        let signal = context.engine.peers.toggleForumChannelTopicPinned(id: peerId, threadId: threadId) |> deliverOnMainQueue
                        
                        _ = signal.startStandalone(error: { error in
                            switch error {
                            case let .limitReached(count):
                                alert(for: context.window, info: strings().chatListContextPinErrorTopicsCountable(count))
                            default:
                                alert(for: context.window, info: strings().unknownError)
                            }
                        })
                    }, itemImage: !isPinned ? MenuAnimation.menu_pin.value : MenuAnimation.menu_unpin.value))
                }
                
                items.append(ContextMenuItem(isMuted ? strings().chatListContextUnmute : strings().chatListContextMute, handler: {
                    _ = context.engine.peers.togglePeerMuted(peerId: peerId, threadId: threadId).startStandalone()
                }, itemImage: isMuted ? MenuAnimation.menu_unmuted.value : MenuAnimation.menu_mute.value))
        
                
                if threadData.isOwnedByMe || peer.isAdmin {
                    items.append(ContextMenuItem(!isClosedTopic ? strings().chatListContextPause : strings().chatListContextStart, handler: {
                        _ = context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: threadId, isClosed: !isClosedTopic).startStandalone()
                    }, itemImage: !isClosedTopic ? MenuAnimation.menu_pause.value : MenuAnimation.menu_play.value))
                    
                    items.append(ContextSeparatorItem())
                    items.append(ContextMenuItem(strings().chatListContextDelete, handler: {
                        _ = removeChatInteractively(context: context, peerId: peerId, threadId: threadId, userId: nil).startStandalone()
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                }
            } else if let item = item.item, let user = item.renderedPeer.chatOrMonoforumMainPeer {
                if let readCounters = item.readCounters, readCounters.isUnread {
                    items.append(ContextMenuItem(strings().chatListContextMaskAsRead, handler: {
                        _ = context.engine.messages.togglePeerUnreadMarkInteractively(peerId: peerId, threadId: threadId, setToValue: true).startStandalone()
                    }, itemImage: MenuAnimation.menu_read.value))
                }
                
                let isPinned = item.chatListIndex.pinningIndex != nil
                let isMuted = item.isMuted
                
                if let _ = peer.sendPaidMessageStars, self?.chatInteraction.presentation.removePaidMessageFeeData == nil {
                    items.append(ContextMenuItem(strings().chatContextReturnMessageFee, handler: {
                        _ = context.engine.peers.reinstateNoPaidMessagesException(scopePeerId: peer.id, peerId: user.id).startStandalone()
                    }, itemImage: MenuAnimation.menu_plus.value))
                }
                
                items.append(ContextMenuItem(!isPinned ? strings().chatListContextPin : strings().chatListContextUnpin, handler: {
                    let signal = context.engine.peers.toggleForumChannelTopicPinned(id: peerId, threadId: threadId) |> deliverOnMainQueue
                    
                    _ = signal.startStandalone(error: { error in
                        switch error {
                        case let .limitReached(count):
                            alert(for: context.window, info: strings().chatListContextPinErrorTopicsCountable(count))
                        default:
                            alert(for: context.window, info: strings().unknownError)
                        }
                    })
                }, itemImage: !isPinned ? MenuAnimation.menu_pin.value : MenuAnimation.menu_unpin.value))
                
               
                
                items.append(ContextMenuItem(isMuted ? strings().chatListContextUnmute : strings().chatListContextMute, handler: {
                    _ = context.engine.peers.togglePeerMuted(peerId: peerId, threadId: threadId).startStandalone()
                }, itemImage: isMuted ? MenuAnimation.menu_unmuted.value : MenuAnimation.menu_mute.value))
        
                items.append(ContextSeparatorItem())
                items.append(ContextMenuItem(strings().chatListContextDelete, handler: {
                    _ = removeChatInteractively(context: context, peerId: peerId, threadId: threadId, userId: nil).startStandalone()
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))

            }
                        
            return .single(items)
        }
        
        chatInteraction.updateChatLocationThread = { [weak self] threadId in
            guard let self else {
                return
            }
            
            if self.chatLocation.threadId == threadId {
                self.scrollup()
                return
            }
            
            let isMonoforum = self.chatInteraction.isMonoforum
            
            didSetReadIndex = false
            self.updateMaxVisibleReadIncomingMessageIndex(MessageIndex.absoluteLowerBound())
            _ = previousMaxIncomingMessageIdByNamespace.swap([:])
            _ = chatLocationContextHolder.swap(nil)
            
            if isMonoforum {
                let location: ChatLocation
                if let threadId {
                    location = .makeSaved(peerId, threadId: threadId, isMonoforum: isMonoforum)
                } else {
                    location = .peer(peerId)
                }
                self.chatInteraction.update({
                    $0.withUpdatedChatLocation(location)
                })
            } else {
                if let threadId {
                    let message: Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError>
                    message = context.engine.messages.fetchChannelReplyThreadMessage(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), atMessageId: nil) |> deliverOnMainQueue
                    
                    _ = message.startStandalone(next: { [weak self] message in
                        self?.chatInteraction.update({
                            $0.withUpdatedChatLocation(.thread(message))
                        })
                    })
                } else {
                    self.chatInteraction.update({
                        $0.withUpdatedChatLocation(.peer(peerId))
                    })
                }
            }
        }
        
        chatInteraction.reportSpamAndClose = { [weak self] in
            let title: String
            if let peer = self?.chatInteraction.peer {
                if peer.isUser {
                    title = strings().chatConfirmReportSpamUser
                } else if peer.isChannel {
                    title = strings().chatConfirmReportSpamChannel
                } else if peer.isGroup || peer.isSupergroup {
                    title = strings().chatConfirmReportSpamGroup
                } else {
                    title = strings().chatConfirmReportSpam
                }
            } else {
                title = strings().chatConfirmReportSpam
            }
            
            self?.reportPeerDisposable.set((verifyAlertSignal(for: context.window, header: strings().chatConfirmReportSpamHeader, information: title, ok: strings().messageContextReport, cancel: strings().modalCancel) |> filter { $0 == .basic } |> mapToSignal { [weak self] _ in
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
        
        chatInteraction.markAdAction = { [weak self] opaqueId, media in
            self?.adMessages?.markAction(opaqueId: opaqueId, media: media)
        }
        
        chatInteraction.freezeAccountAlert = {
            showModal(with: FrozenAccountController(context: context), for: context.window)
        }
        
        chatInteraction.markAdAsSeen = { [weak self] opaqueId in
            self?.adMessages?.markAsSeen(opaqueId: opaqueId)
        }
        
        chatInteraction.toggleSidebar = { [weak self] in
            FastSettings.toggleSidebarShown(!FastSettings.sidebarShown)
            self?.updateSidebar()
            (self?.navigationController as? MajorNavigationController)?.genericView.update()
        }
        
        chatInteraction.focusInputField = { [weak self] in
            _ = self?.context.window.makeFirstResponder(self?.firstResponder())
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
            let signal:Signal<ThreadInfo, FetchChannelReplyThreadMessageError>
                
            if modalProgress {
                signal = showModalProgress(signal: fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId)) |> take(1) |> deliverOnMainQueue, for: context.window)
            } else {
                signal = fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId)) |> take(1) |> deliverOnMainQueue
            }
            
            currentThreadId = mode.originId
            
            delay(0.2, closure: {
                if currentThreadId == mode.originId {
                    self?.updateState { state in
                        var state = state
                        state.threadLoading = mode.originId
                        return state
                    }
                }
            })
            
            
            self?.loadThreadDisposable.set(signal.start(next: { [weak self] result in
                let chatLocation: ChatLocation = .thread(result.message)
                self?.updateState { state in
                    var state = state
                    state.threadLoading = nil
                    return state
                }
                currentThreadId = nil
                let updatedMode: ReplyThreadMode
                if result.isChannelPost {
                    updatedMode = .comments(origin: mode.originId)
                } else {
                    updatedMode = .replies(origin: mode.originId)
                }
                self?.navigationController?.push(ChatAdditionController(context: context, chatLocation: chatLocation, mode: .thread(mode: updatedMode), focusTarget: isChannelPost ? nil : .init(messageId: mode.originId), initialAction: nil, chatLocationContextHolder: result.contextHolder))
            }, error: { error in
                self?.updateState { state in
                    var state = state
                    state.threadLoading = nil
                    return state
                }
                currentThreadId = nil
                
                switch error {
                case .generic:
                    alert(for: context.window, info: strings().chatDiscussionMessageDeleted)
                }
            }))
        }
        
        
        
        
        chatInteraction.closeAfterPeek = { [weak self] peek in
            
            let showConfirm:()->Void = {
                verifyAlert_button(for: context.window, header: strings().privateChannelPeekHeader, information: strings().privateChannelPeekText, ok: strings().privateChannelPeekOK, cancel: strings().privateChannelPeekCancel, successHandler: { _ in
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
        
        
        let chatLocationValue = self.chatLocationValue
        let topVisibleMessageRange = self.topVisibleMessageRange.get()
        let dismissedPinnedIds = self.dismissedPinnedIds.get()
        let ready = self.ready.get()
        
        let getPinned:()-> Signal<ChatPinnedMessage?, NoError> = {
           
            let replyHistoryFirst: Signal<(ChatHistoryViewUpdate, ChatLocation), NoError> = chatLocationValue |> mapToSignal { chatLocation in
                return preloadedChatHistoryViewForLocation(.Initial(count: 6, scrollPosition: nil), context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, tag: .tag(.pinned), additionalData: []) |> map { ($0, chatLocation) }
            }

            let ready = ready |> filter { $0 } |> take(1)
            
            let replyHistory: Signal<(ChatHistoryViewUpdate, ChatLocation), NoError> = chatLocationValue |> mapToSignal { chatLocation in
                return preloadedChatHistoryViewForLocation(.Initial(count: 100, scrollPosition: nil), context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, tag: .tag(.pinned), additionalData: []) |> map { ($0, chatLocation) }
            }
            
            return combineLatest(queue: prepareQueue, replyHistoryFirst |> then(ready |> mapToSignal { _ in
                return  replyHistory
            }), topVisibleMessageRange, dismissedPinnedIds)
                |> map { update, topVisibleMessageRange, dismissed -> ChatPinnedMessage? in
                    let chatLocation = update.1
                    var message: ChatPinnedMessage?
                    switch update.0 {
                    case .Loading:
                        break
                    case let .HistoryView(view, _, _, _):
                        for i in 0 ..< view.entries.count {
                            let entry = view.entries[i]
                            var matches = false
                            if let topVisibleMessageRange = topVisibleMessageRange {
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
                            if i == view.entries.count - 1, message == nil {
                                matches = true
                            }
                            if matches, chatLocation.threadId == entry.message.threadId || chatLocation.threadId == nil && entry.message.threadId == 1 || entry.message.threadId == context.peerId.toInt64() {
                                message = ChatPinnedMessage(messageId: entry.message.id, message: entry.message, others: view.entries.map { $0.message.id }, isLatest: i == view.entries.count - 1, index: view.entries.count - 1 - i, totalCount: view.entries.count)
                            }
                        }
                        break
                    }
                    return message
                }
                |> distinctUntilChanged
        }
        
        let topPinnedMessage: Signal<ChatPinnedMessage?, NoError>
        switch mode {
        case .history:
            topPinnedMessage = getPinned()
        case .pinned:
            let replyHistory: Signal<ChatHistoryViewUpdate, NoError> = (chatHistoryViewForLocation(.Initial(count: 90, scrollPosition: nil), context: self.context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tag: .tag(.pinned), additionalData: [])
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
        case .thread:
            if mode.isThreadMode, case let .thread(data) = chatLocation() {
                topPinnedMessage = context.account.postbox.messageView(data.effectiveTopId) |> map { view in
                    if let message = view.message {
                        return ChatPinnedMessage(messageId: message.id, message: message, others: [message.id], isLatest: true, index: 0, totalCount: 1)
                    } else {
                        return nil
                    }
                }
            } else {
                topPinnedMessage = getPinned()
            }
            
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
            
            self.chatInteraction.update(animated:false, { present in
                var present = present
                present = present.updatedInterfaceState({ value in
                    return interfaceState ?? value
                }).withUpdatedContentSettings(context.contentSettings)
                
                switch mode {
                case .history, .thread, .preview:
                    let isLiveCall: Bool
                    if let peer = present.peer {
                        isLiveCall = peer.isGigagroup || peer.isChannel
                    } else {
                        isLiveCall = false
                    }
                    if peerId.namespace == Namespaces.Peer.SecretChat {
                        
                    } else if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                            .withUpdatedAllowedReactions(cachedData.reactionSettings.knownValue?.allowedReactions)
                    } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                        present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                            .withUpdatedAllowedReactions(cachedData.reactionSettings.knownValue?.allowedReactions)
                    } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                        present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                    }
                    
                    if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                        present = present.updatedGroupCall({ currentValue in
                            if let call = cachedData.activeCall {
                                return ChatActiveGroupCallInfo(activeCall: call, data: currentValue?.data, callJoinPeerId: cachedData.callJoinPeerId, joinHash: currentValue?.joinHash, isLive: isLiveCall)
                            } else {
                                return nil
                            }
                        }).withUpdatedInviteRequestsPending(cachedData.inviteRequestsPending)
                    }
                    if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                        present = present
                            .withUpdatedBlocked(cachedData.isBlocked)
                            .withUpdatedCanPinMessage(cachedData.canPinMessages || context.peerId == peerId)
                            .updateBotMenu { current in
                                if let botInfo = cachedData.botInfo {
                                    var current = current ?? .init(commands: [], revealed: false, menuButton: botInfo.menuButton)
                                    current.commands = botInfo.commands
                                    current.menuButton = botInfo.menuButton
                                    return current
                                }
                                return nil
                            }
                    } else if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        present = present
                            .withUpdatedIsNotAccessible(cachedData.isNotAccessible)
                            .withUpdatedInviteRequestsPending(cachedData.inviteRequestsPending)
                            .withUpdatedCurrentSendAsPeerId(cachedData.sendAsPeerId)
                            .updatedGroupCall({ currentValue in
                                if let call = cachedData.activeCall {
                                    return ChatActiveGroupCallInfo(activeCall: call, data: currentValue?.data, callJoinPeerId: cachedData.callJoinPeerId, joinHash: currentValue?.joinHash, isLive: isLiveCall)
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
                    
                    present = present.withUpdatedLimitConfiguration(combinedInitialData.limitsConfiguration).withUpdatedCachedData(combinedInitialData.cachedData)
                    
                    let price = present.sendPaidMessageStars.flatMap({ Int($0.value) })
                    
                    let freezeAccount = context.appConfiguration.getGeneralValue("freeze_since_date", orElse: 0)
                    let freezeAccountAppealAddressName = context.appConfiguration.getStringValue("freeze_appeal_url", orElse: "https://t.me/spambot")
                    
                    
                    
                    func extractUsername(from url: String) -> String? {
                        let pattern = "(?:https?://)?t\\.me/([a-zA-Z0-9_]+)"
                        
                        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                            let range = NSRange(location: 0, length: url.utf16.count)
                            if let match = regex.firstMatch(in: url, options: [], range: range) {
                                if let usernameRange = Range(match.range(at: 1), in: url) {
                                    return String(url[usernameRange])
                                }
                            }
                        }
                        return nil
                    }
                    
                    
                    present = present.withUpdatedAlwaysPaidMessage(FastSettings.needConfirmPaid(peerId, price: price ?? 0)).withUpdatedFreezeAccount(freezeAccount).withUpdatedFreezeAccountAddressName(extractUsername(from: freezeAccountAppealAddressName)?.lowercased())
                case .scheduled:
                    if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                        present = present.withUpdatedCurrentSendAsPeerId(cachedData.sendAsPeerId)
                            .withUpdatedCachedData(cachedData)
                    }
                case .pinned:
                    break
                case .customChatContents:
                    break
                case .customLink:
                    break
                }
                return present
            })
            
            
            
            if let modalAction = self.navigationController?.modalAction {
                self.invokeNavigation(action: modalAction)
            }
            
            
            self.state = self.chatInteraction.presentation.state == .selecting ? .Edit : .Normal
            
            
        } |> map {_ in}
        
        
        
        
        let first:Atomic<Bool> = Atomic(value: true)
        
        
        let availableGroupCall: Signal<GroupCallPanelData?, NoError>
        switch self.mode {
        case .history:
            availableGroupCall = getGroupCallPanelData(context: context, peerId: peerId)
        case .thread:
            availableGroupCall = getGroupCallPanelData(context: context, peerId: peerId)
        default:
            availableGroupCall = .single(nil)
        }
        
        let attach = (context.engine.messages.attachMenuBots() |> then(.complete() |> suspendAwareDelay(1, queue: .mainQueue()))) |> restart
        
        let threadInfo: Signal<MessageHistoryThreadData?, NoError> = chatLocationValue |> mapToSignal { [weak self] chatLocation in
            switch chatLocation {
            case .peer:
                return .single(nil) |> beforeNext { [weak self] value in
                    self?.uiState.modify { state in
                        var state = state
                        state.topicCreatorId = nil
                        return state
                    }
                }
            case .thread(let data):
                let key: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: data.threadId)
                return context.account.postbox.combinedView(keys: [key]) |> map { views in
                    let view = views.views[key] as? MessageHistoryThreadInfoView
                    let data = view?.info?.data.get(MessageHistoryThreadData.self)
                    return data
                }
                |> deliverOnMainQueue
                |> beforeNext { [weak self] value in
                    self?.uiState.modify { state in
                        var state = state
                        state.topicCreatorId = value?.author
                        return state
                    }
                }
            }
        }
        
        let isFirst = Atomic(value: true)
        
        let tagsAndFiles: Signal<([SavedMessageTags.Tag], [Int64 : TelegramMediaFile]), NoError>
        if peerId == context.peerId {
            tagsAndFiles = combineLatest(context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: threadId64())
            )
            |> distinctUntilChanged
            |> mapToSignal { tags -> Signal<([MessageReaction.Reaction: Int], [Int64: TelegramMediaFile]), NoError> in
                var customFileIds: [Int64] = []
                for (reaction, _) in tags {
                    switch reaction {
                    case .builtin:
                        break
                    case let .custom(fileId):
                        customFileIds.append(fileId)
                    case .stars:
                        break
                    }
                }
                
                return context.engine.stickers.resolveInlineStickers(fileIds: customFileIds)
                |> map { files in
                    return (tags, files)
                }
            }, context.engine.stickers.savedMessageTagData()) |> map { tagsAndFiles, savedMessageTags in
                var result: [SavedMessageTags.Tag] = []
                let tags = tagsAndFiles.0
                let files = tagsAndFiles.1
                for (reaction, count) in tags {
                    let title = savedMessageTags?.tags.first(where: { $0.reaction == reaction })?.title
                    result.append(.init(reaction: reaction, title: title, count: count))
                }
                result = result.sorted(by: { lhs, rhs in
                    if lhs.count != rhs.count {
                        return lhs.count > rhs.count
                    }
                    return lhs.reaction < rhs.reaction

                })
                return (result, files)
            }
        } else {
            tagsAndFiles = .single(([], [:]))
        }

        
        let shortcuts: Signal<ShortcutMessageList?, NoError>
        if peerId.namespace == Namespaces.Peer.CloudUser {
            shortcuts = context.engine.accountData.shortcutMessageList(onlyRemote: true) |> map(Optional.init)
        } else {
            shortcuts = .single(nil)
        }
        
        
        
        let savedChatsAsTopics = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.DisplaySavedChatsAsTopics())
       
        let managingBot = peerView.get() |> map { (($0 as? PeerView)?.cachedData as? CachedUserData)?.peerStatusSettings?.managingBot }
        
        let connectedBot: Signal<ChatBotManagerData?, NoError>
        switch mode {
        case .history:
            connectedBot = combineLatest(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.BusinessConnectedBot(id: context.peerId)), managingBot) |> mapToSignal { value, managingBot in
               if let value, let managingBot {
                   return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: value.id)) |> map { peer in
                       return peer.flatMap {
                           .init(bot: value, peer: $0, settings: managingBot)
                       }
                   }
               } else {
                   return .single(nil)
               }
           }
        default:
            connectedBot = .single(nil)
        }
        
        titleUpdateDisposable.set((peerView.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] postboxView in
            let title = (self?.centerBarView as? ChatTitleBarView)
            title?.update(postboxView as? PeerView, story: nil, counters: .init(), animated: false)
        }))
        
        let updaterPromise: Promise<Any> = Promise(Void())
        
        switch mode {
        case let .customLink(contents):
            contents.interfaceUpdate = {
                updaterPromise.set(.single(Void()))
            }
        default:
            break
        }
        
        
        
        let monoforumTopics: Promise<[EngineChatList.Item]?> = Promise()

        monoforumTopics.set(self.peerView.get() |> map { peerView -> TelegramChannel? in
            if let peerView = peerView as? PeerView, let channel = peerViewMainPeer(peerView) as? TelegramChannel {
                return channel
            } else {
                return nil
            }
        } |> distinctUntilChanged |> mapToQueue { channel in
            if let channel {
                if channel.flags.contains(.isMonoforum), channel.groupAccess.canManageDirect {
                    return chatListViewForLocation(chatListLocation: .savedMessagesChats(peerId: peerId), location: .Initial(0, nil), filter: nil, account: context.account) |> map {
                        return $0.list.items.reversed()
                    }
                } else if channel.isForum, channel.displayForumAsTabs {
                    return chatListViewForLocation(chatListLocation: .forum(peerId: channel.id), location: .Initial(0, nil), filter: nil, account: context.account) |> map {
                        return $0.list.items.reversed()
                    }
                }
            }
            return .single(nil)
        })
        
                
        monoforumTopicsDisposable.set((monoforumTopics.get()
                                       |> deliverOnMainQueue |> beforeNext( { [weak self] list in
            if let _ = list {
                _ = self?.uiState.modify({ current in
                    var current = current
                    current.monoforumState = FastSettings.monoforumState(peerId)
                    return current
                })
            }
            return list
        })).startStrict())
        
        
        
        
        let titlePeerView: Signal<PeerView, NoError> = self.chatLocationValue |> mapToSignal { location in
            switch location {
            case let .peer(peerId):
                return context.account.viewTracker.peerView(peerId, updateData: false)
            case let .thread(data):
                if data.isMonoforumPost {
                    return context.account.viewTracker.peerView(PeerId(data.threadId), updateData: false)
                } else {
                    return context.account.viewTracker.peerView(peerId, updateData: false)
                }
            }
        }

        peerDisposable.set(combineLatest(queue: .mainQueue(), topPinnedMessage, peerView.get(), titlePeerView, availableGroupCall, attach, threadInfo, stateValue.get(), tagsAndFiles, getPeerView(peerId: context.peerId, postbox: context.account.postbox), savedChatsAsTopics, shortcuts, connectedBot, updaterPromise.get(), ApplicationSpecificNotice.playedMessageEffects(accountManager: context.sharedContext.accountManager), adMessages, context.starsContext.state, monoforumTopics.get()).start(next: { [weak self] pinnedMsg, postboxView, titlePeerView, groupCallData, attachItems, threadInfo, uiState, savedMessageTags, accountPeer, displaySavedChatsAsTopics, shortcuts, connectedBot, _, playedMessageEffects, adMessages, starsState, monoforumTopics in
            
            
            let animated = !isFirst.swap(false)
                        
            guard let `self` = self else {return}
            let title = (self.centerBarView as? ChatTitleBarView)
            title?.update(titlePeerView, story: uiState.storyState, counters: uiState.answersAndOnline, animated: animated)
            let peerView = postboxView as? PeerView
            self.currentPeerView = peerView
            switch self.chatInteraction.mode {
            case .history, .thread, .customChatContents, .customLink, .preview:
                
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
                    if let peerView = peerView, let peer = peerView.peers[peerView.peerId], let mainPeer = peerViewMainPeer(peerView) {
                        var present = presentation.updatedPeer { _ in
                            return peer
                        }.updatedMainPeer(mainPeer)
                            .withUpdatedAccountPeer(accountPeer)
                            .withUpdatedStarsState(starsState)
                        
                        var discussionGroupId:CachedChannelData.LinkedDiscussionPeerId = .unknown
                        if let cachedData = peerView.cachedData as? CachedChannelData {
                            if let peer = mainPeer as? TelegramChannel {
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
                                .withUpdatedAllowedReactions(cachedData.reactionSettings.knownValue?.allowedReactions)
                        } else if let cachedData = peerView.cachedData as? CachedGroupData {
                            present = present.withUpdatedMessageSecretTimeout(cachedData.autoremoveTimeout)
                                .withUpdatedAllowedReactions(cachedData.reactionSettings.knownValue?.allowedReactions)
                        }
                        
                        var removePaidMessageFeeData: ChatPresentationInterfaceState.RemovePaidMessageFeeData?
                        
                        
                        
                        if let peer = peerViewMainPeer(titlePeerView) {
                            if let threadInfo, !threadInfo.isMessageFeeRemoved, let channel = peerView.peers[peerView.peerId] as? TelegramChannel, let sendPaidMessageStars = channel.sendPaidMessageStars, channel.isMonoForum {
                                if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = peerView.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
                                    removePaidMessageFeeData = ChatPresentationInterfaceState.RemovePaidMessageFeeData(
                                        peer: .init(peer),
                                        amount: sendPaidMessageStars
                                    )
                                }
                            }
                        }
                        
                        

                        
                        present = present.withUpdatedDiscussionGroupId(discussionGroupId)
                        present = present.withUpdatedPinnedMessageId(pinnedMsg)
                        present = present.withUpdatedAttachItems(attachItems)
                        present = present.withUpdatedShortcuts(shortcuts)
                        present = present.withUpdatedConnectedBot(connectedBot)
                        present = present.withUpdatedPlayedMessageEffects(playedMessageEffects ?? [])
                        present = present.withUpdatedMonoforumState(uiState.monoforumState)
                        present = present.withUpdatedRemovePaidMessageFeeData(removePaidMessageFeeData)

                        if let monoforumTopics {
                            let topics = monoforumTopics.map(MonoforumItem.init)
                            present = present.withUpdatedMonoforumTopics(topics)
                        }
                        
                        
                        if peer.isBot {
                            present = present.withUpdatedAdMessage(adMessages.fixed)
                        }

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
                        
                        var activeCall: CachedChannelData.ActiveCall? = nil
                        var callJoinPeerId: PeerId? = nil
                        var inviteRequestsPending: Int32? = nil
                        var sendAsPeerId: PeerId? = nil
                        var isNotAccessible: Bool = false
                        switch mode {
                        case .history, .thread, .customChatContents:
                            if let cachedData = peerView.cachedData as? CachedChannelData {
                                if !mode.isThreadMode {
                                    activeCall = cachedData.activeCall
                                }
                                callJoinPeerId = cachedData.callJoinPeerId
                                inviteRequestsPending = cachedData.inviteRequestsPending
                                sendAsPeerId = cachedData.sendAsPeerId
                                isNotAccessible = cachedData.isNotAccessible
                            } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                activeCall = cachedData.activeCall
                                callJoinPeerId = cachedData.callJoinPeerId
                                inviteRequestsPending = cachedData.inviteRequestsPending
                            }
                        default:
                            break
                        }
                        
                        if let cachedData = peerView.cachedData as? CachedUserData {
                            present = present
                                .withUpdatedBlocked(cachedData.isBlocked)
                                .withUpdatedCanPinMessage(cachedData.canPinMessages || context.peerId == peerId)
                                .updateBotMenu { current in
                                    if let botInfo = cachedData.botInfo {
                                        var current = current ?? .init(commands: [], revealed: false, menuButton: botInfo.menuButton)
                                        current.commands = botInfo.commands
                                        current.menuButton = botInfo.menuButton
                                        return current
                                    }
                                    return nil
                                }
                        } else if let cachedData = peerView.cachedData as? CachedChannelData {
                            if let peer = mainPeer as? TelegramChannel {
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
                        
                        if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                            present = present.updatedNotificationSettings(notificationSettings)
                        }
                        present = present.withUpdatedPeerStatusSettings(contactStatus)
                        present = present.withUpdatedInviteRequestsPending(inviteRequestsPending)
                        present = present.withUpdatedCurrentSendAsPeerId(sendAsPeerId)
                        present = present.withUpdatedIsNotAccessible(isNotAccessible)
                        present = present.withUpdatedSavedMessageTags(.init(tags: savedMessageTags.0, files: savedMessageTags.1))
                        present = present.withUpdatedDisplaySavedChatsAsTopics(displaySavedChatsAsTopics)
                        
                        present = present.updatedGroupCall { current in
                            if let call = activeCall {
                                return ChatActiveGroupCallInfo(activeCall: call, data: groupCallData, callJoinPeerId: callJoinPeerId, joinHash: current?.joinHash, isLive: peer.isGigagroup || peer.isChannel)
                            } else {
                                return nil
                            }
                        }
                        return present.withUpdatedCachedData(peerView.cachedData)
                            .withUpdatedThreadInfo(threadInfo)
                            .withUpdatedPresence(peerView.peerPresences[peerView.peerId] as? TelegramUserPresence)
                    }
                    return presentation
                })
            case .scheduled:
                self.chatInteraction.update(animated: !first.swap(false), {  presentation in
                    var presentation = presentation.withUpdatedCanPinMessage(context.peerId == peerId).updatedPeer { _ in
                        if let peerView = peerView {
                            return peerView.peers[peerView.peerId]
                        }
                        return nil
                    }.updatedMainPeer(peerView != nil ? peerViewMainPeer(peerView!) : nil)
                    if let cachedData = peerView?.cachedData as? CachedChannelData {
                        presentation = presentation.withUpdatedCurrentSendAsPeerId(cachedData.sendAsPeerId)
                    }
                    return presentation.withUpdatedCachedData(peerView?.cachedData).withUpdatedThreadInfo(threadInfo)
                })
            case .pinned:
                self.chatInteraction.update(animated: !first.swap(false), { presentation in
                    let pinnedMessage: ChatPinnedMessage? = pinnedMsg
                    return presentation.withUpdatedPinnedMessageId(pinnedMessage).withUpdatedCanPinMessage((peerView?.cachedData as? CachedUserData)?.canPinMessages ?? true || context.peerId == peerId).updatedPeer { _ in
                        if let peerView = peerView {
                            return peerView.peers[peerView.peerId]
                        }
                        return nil
                    }.updatedMainPeer(peerView != nil ? peerViewMainPeer(peerView!) : nil).withUpdatedCachedData(peerView?.cachedData).withUpdatedThreadInfo(threadInfo)
                })
            }
            if !animated {
                self.notify(with: self.chatInteraction.presentation, oldValue: ChatPresentationInterfaceState(chatLocation: self.chatLocation, chatMode: self.mode), animated: animated)
            }
            
            self._monoforumReady.set(.single(true))

        }))
        
        
    
        
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
        
        let combine = combineLatest(queue: .mainQueue(), _historyReady.get() |> take(1), appearanceReady.get(), peerView.get() |> take(1) |> map { _ in } |> then(initialData), genericView.inputView.ready.get() |> take(1), _monoforumReady.get() |> take(1))
        
        
        //self.ready.set(.single(true))
        
        self.ready.set(combine |> map { (hReady, appearanceReady, _, iReady, monoforumReady) in
            return hReady && iReady && appearanceReady && monoforumReady
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
        case .history, .thread:
            
            let unreadCount = chatLocationValue |> mapToSignal { location in
                return context.chatLocationUnreadCount(for: location, contextHolder: chatLocationContextHolder)
            } |> deliverOnMainQueue
            
            let unseenPersonalMessages = chatLocationValue |> mapToSignal { location in
                return context.account.viewTracker.unseenPersonalMessagesAndReactionCount(peerId: peerId, threadId: location.threadId)
            } |> deliverOnMainQueue
    
            self.chatUnreadMentionCountDisposable.set(combineLatest(queue: .mainQueue(), unseenPersonalMessages, unreadCount).start(next: { [weak self] count, unreadCount in
                self?.genericView.updateMentionsCount(mentionsCount: count.mentionCount, reactionsCount: count.reactionCount, scrollerCount: Int32(unreadCount), animated: true)
            }))
        default:
            self.chatUnreadMentionCountDisposable.set(nil)
        }
       
        
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        
        
        let peerInputActivities = chatLocationValue |> mapToSignal { location in
            return context.account.peerInputActivities(peerId: .init(peerId: peerId, category: mode.activityCategory(location.threadId)))
        }
        
        self.peerInputActivitiesDisposable.set((peerInputActivities
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
                                        strongSelf.emojiEffects.addAnimation(emoticon.fixed, index: animation.index, mirror: mirror, isIncoming: true, messageId: messageId, animationSize: NSMakeSize(350, 350), viewFrame: context.window.bounds, for: context.window.contentView!)
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
                            if let item = self.genericView.tableView.item(at: i) as? ChatRowItem, !item.ignoreAtInitialization {
                                messageIndex = item.entry.index
                                break
                            }
                        }
                    } else if view.laterId == nil, !view.holeLater, let locationValue = self.locationValue, !locationValue.content.isAtUpperBound, view.anchorIndex != .upperBound {
                        messageIndex = .upperBound(peerId: self.chatInteraction.peerId)
                    }
                case .bottom:
                    if let contents = self.mode.customChatContents {
                        contents.loadMore()
                    } else {
                        if view.earlierId != nil {
                            for i in stride(from: visible.max - 1, to: -1, by: -1) {
                                if let item = self.genericView.tableView.item(at: i) as? ChatRowItem, !item.ignoreAtInitialization {
                                    messageIndex = item.entry.index
                                    break
                                }
                            }
                        }
                    }
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    let location: ChatHistoryLocation = .Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 90, side: scroll.direction == .bottom ? .upper : .lower)
                    guard location != self.locationValue?.content else {
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
            if self.mode.isThreadMode || self.mode.isTopicMode {
                if let pinnedMessageId = chatInteraction.presentation.pinnedMessageId, position.visibleRows.location != NSNotFound {
                    var hidden: Bool = false
                    for row in position.visibleRows.min ..< position.visibleRows.max {
                        if let item = tableView.item(at: row) as? ChatRowItem {
                            if item.message?.id == pinnedMessageId.others.first {
                                hidden = true
                                break
                            }
                        }
                    }
                    chatInteraction.update({$0.withUpdatedHidePinnedMessage(hidden)})
                }
            }
        }))
        
        genericView.tableView.addScroll(listener: TableScrollListener { [weak self] position in
            let tableView = self?.genericView.tableView
            
            if let strongSelf = self, let tableView = tableView {
            
                if let row = tableView.topVisibleRow, let item = tableView.item(at: row) as? ChatRowItem, let id = item.message?.id {
                    strongSelf.historyState = strongSelf.historyState.withRemovingReplies(max: id)
                }
                if !strongSelf.context.window.isKeyWindow {
                    return
                }
                
                var message:Message? = nil
                
                var messageIdsWithViewCount: [MessageId] = []
                var messageIdsWithUnseenPersonalMention: [MessageId] = []
                var messageIdsWithUnseenReactionsMention: [MessageId] = []

                var messageIdsWithReactions:[MessageId] = []
                var unsupportedMessagesIds: [MessageId] = []
                var topVisibleMessageRange: ChatTopVisibleMessageRange?
 
                var messageIdsWithUnsupportedMedia: [MessageId] = []
                var messageIdsWithRefreshMedia: [MessageId] = []
                var messageIdsWithRefreshStories: [MessageId] = []
                var messageIdsWithLiveLocation: [MessageId] = []
                var messageIdsWithInactiveExtendedMedia = Set<MessageId>()
                var messageIdsToFactCheck: [MessageId] = []


                var messagesToTranslate: [Message] = []

                
                var allVisibleAnchorMessageIds: [(MessageId, Int)] = []


                var readAds:[Data] = []
                
                tableView.enumerateVisibleItems(with: { item in
                    if let item = item as? ChatRowItem {
                        let height = item.view?.visibleRect.height ?? 0
                        if message == nil, height >= (item.height - 10) {
                            message = item.lastMessage
                        }
                        
                        for message in item.messages {
                            var hasUncocumedMention: Bool = false
                            var hasUncosumedContent: Bool = false
                            
                            var contentRequiredValidation = false
                            var mediaRequiredValidation = false
                            var storiesRequiredValidation = false
                            var factCheckRequired = false
                            
                            for attribute in message.attributes {
                                if let _ = attribute as? ContentRequiresValidationMessageAttribute {
                                    contentRequiredValidation = true
                                }  else if let _ = attribute as? ReplyStoryAttribute {
                                    storiesRequiredValidation = true
                                } else if let attribute = attribute as? FactCheckMessageAttribute, case .Pending = attribute.content {
                                    factCheckRequired = true
                                }
                            }
                            
                            for media in message.media {
                                if let _ = media as? TelegramMediaUnsupported {
                                    contentRequiredValidation = true
                                } else if message.flags.contains(.Incoming), let media = media as? TelegramMediaMap, let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                    if Int(message.timestamp) + Int(liveBroadcastingTimeout) > Int(timestamp) {
                                        messageIdsWithLiveLocation.append(message.id)
                                    }
                                } else if let telegramFile = media as? TelegramMediaFile {
                                    if telegramFile.isAnimatedSticker, (message.id.peerId.namespace == Namespaces.Peer.SecretChat || !telegramFile.previewRepresentations.isEmpty), let size = telegramFile.size, size > 0 && size <= 128 * 1024 {
                                        if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                                            if telegramFile.fileId.namespace == Namespaces.Media.CloudFile {
                                                var isValidated = false
                                                attributes: for attribute in telegramFile.attributes {
                                                    if case .hintIsValidated = attribute {
                                                        isValidated = true
                                                        break attributes
                                                    }
                                                }
                                                
                                                if !isValidated {
                                                    mediaRequiredValidation = true
                                                }
                                            }
                                        }
                                    }
                                } else if let invoice = media as? TelegramMediaInvoice, let extendedMedia = invoice.extendedMedia, case .preview = extendedMedia {
                                    messageIdsWithInactiveExtendedMedia.insert(message.id)
                                    if invoice.version != TelegramMediaInvoice.lastVersion {
                                        contentRequiredValidation = true
                                    }
                                } else if let paidContent = media as? TelegramMediaPaidContent, let extendedMedia = paidContent.extendedMedia.first, case .preview = extendedMedia {
                                    messageIdsWithInactiveExtendedMedia.insert(message.id)
                                } else if let _ = media as? TelegramMediaStory {
                                    storiesRequiredValidation = true
                                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, let _ = content.story {
                                    storiesRequiredValidation = true
                                }
                            }

                            if contentRequiredValidation {
                                messageIdsWithUnsupportedMedia.append(message.id)
                            }
                            if mediaRequiredValidation {
                                messageIdsWithRefreshMedia.append(message.id)
                            }
                            if storiesRequiredValidation {
                                messageIdsWithRefreshStories.append(message.id)
                            }
                            if factCheckRequired {
                                messageIdsToFactCheck.append(message.id)
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
                            if let _ = message.reactionsAttribute {
                                messageIdsWithUnseenReactionsMention.append(message.id)
                            }
                            
                            if let topVisibleMessageRangeValue = topVisibleMessageRange {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.id, isLast: item.index == tableView.count - 1)
                            } else {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.id, upperBound: message.id, isLast: item.index == tableView.count - 1)
                            }
                            
                            if message.id.namespace == Namespaces.Message.Cloud, self?.adMessages?.remainingDynamicAdMessageInterval != nil {
                                allVisibleAnchorMessageIds.append((message.id, item.index))
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
                
                
                tableView.enumerateVisibleItems(inset: tableView.frame.height, with: { item in
                    if let item = item as? ChatRowItem {
                        if message == nil {
                            message = item.lastMessage
                        }
                        for message in item.messages {
                            inner: for attribute in message.attributes {
                                if attribute is ViewCountMessageAttribute {
                                    messageIdsWithViewCount.append(message.id)
                                    break inner
                                }
                            }
                            if message.anyMedia is TelegramMediaUnsupported {
                                unsupportedMessagesIds.append(message.id)
                            }
                            if message.id.peerId.namespace == Namespaces.Peer.CloudChannel || message.id.peerId.namespace == Namespaces.Peer.CloudGroup {
                                messageIdsWithReactions.append(message.id)
                            }
                            if message.id.namespace == Namespaces.Message.Cloud {
                                if !message.text.isEmpty {
                                    messagesToTranslate.append(message)
                                } else if let _ = message.media.first as? TelegramMediaPoll {
                                    messagesToTranslate.append(message)
                                }
                                if let reply = message.replyAttribute, let replyMessage = message.associatedMessages[reply.messageId] {
                                    if !replyMessage.text.isEmpty {
                                        messagesToTranslate.append(replyMessage)
                                    }
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
                                
                if !messageIdsWithViewCount.isEmpty {
                    strongSelf.messageProcessingManager.add(messageIdsWithViewCount)
                }
                if !messageIdsWithLiveLocation.isEmpty {
                    strongSelf.seenLiveLocationProcessingManager.add(messageIdsWithLiveLocation)
                }
                if !messageIdsWithUnsupportedMedia.isEmpty {
                    strongSelf.unsupportedMessageProcessingManager.add(messageIdsWithUnsupportedMedia)
                }
                if !messageIdsWithRefreshMedia.isEmpty {
                    strongSelf.refreshMediaProcessingManager.add(messageIdsWithRefreshMedia)
                }
                if !messageIdsWithRefreshStories.isEmpty {
                    strongSelf.refreshStoriesProcessingManager.add(messageIdsWithRefreshStories)
                }
                if !messageIdsToFactCheck.isEmpty {
                    strongSelf.factCheckProcessingManager.add(messageIdsToFactCheck)
                }
                if !messageIdsWithInactiveExtendedMedia.isEmpty {
                    strongSelf.extendedMediaProcessingManager.update(messageIdsWithInactiveExtendedMedia)
                }

                if !messageIdsWithUnseenPersonalMention.isEmpty {
                    strongSelf.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention)
                }
                if !messageIdsWithUnseenReactionsMention.isEmpty {
                    strongSelf.messageReactionsMentionProcessingManager.add(messageIdsWithUnseenReactionsMention)
                }
                if !unsupportedMessagesIds.isEmpty {
                    strongSelf.unsupportedMessageProcessingManager.add(unsupportedMessagesIds)
                }
                
                if !messageIdsWithReactions.isEmpty {
                    strongSelf.reactionsMessageProcessingManager.add(messageIdsWithReactions)
                }
                
                if let message = message {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(MessageIndex(message))
                }
                
                if let pinned = strongSelf.chatInteraction.presentation.pinnedMessageId, let message = pinned.message, !message.text.isEmpty {
                    messagesToTranslate.append(message)
                }
                
                if !messagesToTranslate.isEmpty {
                    strongSelf.liveTranslate?.translate(messagesToTranslate.sorted(by: { $0.id < $1.id}))
                }
                
                if !allVisibleAnchorMessageIds.isEmpty {
                    self?.adMessages?.update(items: allVisibleAnchorMessageIds, tableView: tableView, position: position)
                }
               
            }
        })
        
        switch self.mode {
        case .history, .thread:
            let hasScheduledMessages = combineLatest(peerView.get(), chatLocationValue)
            |> take(1)
            |> mapToSignal { view, chatLocation -> Signal<Bool, NoError> in
                if let view = view as? PeerView, let peer = peerViewMainPeer(view) as? TelegramChannel, !peer.hasPermission(.sendSomething) {
                    return .single(false)
                } else {
                    return context.account.viewTracker.scheduledMessagesViewForLocation(.peer(peerId: peerId, threadId: chatLocation.threadId))
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
            if let threadId = threadId64() {
                return context.account.viewTracker.polledChannel(peerId: PeerId(threadId))
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
        
        
        let personalChannelSignal: Signal<Void, NoError>
        if peerId.namespace == Namespaces.Peer.CloudUser {
            personalChannelSignal = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.PersonalChannel(id: peerId)) |> mapToSignal { value in
                switch value {
                case let .known(channel):
                    if let channel = channel {
                        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: channel.peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 10, fixedCombinedReadStates: nil) |> map { _ in }
                    } else {
                        return .single(Void())
                    }
                case .unknown:
                    return .single(Void())
                }
            }
        } else {
            personalChannelSignal = .single(Void())
        }
        
        preloadPersonalChannel.set(personalChannelSignal.start())
        
        self.premiumOrStarsRequiredDisposable.set(((self.context.engine.peers.isPremiumRequiredToContact([peerId]) |> then(.complete() |> suspendAwareDelay(60.0, queue: Queue.concurrentDefaultQueue()))) |> restart).startStandalone())
        
        
        let count = 50
        let location:ChatHistoryLocation
        
        switch chatLocation() {
        case let .thread(data):
            switch data.initialAnchor {
            case .automatic:
                if let messageId = self.focusTarget?.messageId {
                    location = .InitialSearch(location: .id(messageId, self.focusTarget?.string), count: count)
                } else {
                    location = .Initial(count: count, scrollPosition: nil)
                }
            case let .lowerBoundMessage(index):
                location = .Scroll(index: .message(index), anchorIndex: .message(index), sourceIndex: .message(index), scrollPosition: .up(false), count: count, animated: false)
            }
        default:
            if let messageId = self.focusTarget?.messageId {
                location = .InitialSearch(location: .id(messageId, self.focusTarget?.string), count: count)
            } else {
                location = .Initial(count: count, scrollPosition: nil)
            }
        }
        let id = self.takeNextHistoryLocationId()
        self.setLocation(.init(content: location, chatLocation: self.chatLocation, tag: self.mode.tagMask.flatMap { .tag($0) }, id: id))

    }

    override func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        super.updateFrame(frame, transition: transition)
        self.genericView.updateFrame(frame, transition: transition)
    }
    
    private func openScheduledChat() {
        self.chatInteraction.saveState(scrollState: self.immediateScrollState())
        self.navigationController?.push(ChatScheduleController(context: context, chatLocation: self.chatLocation))
    }
    
    override func windowDidBecomeKey() {
        super.windowDidBecomeKey()
        updateInteractiveReading()
        chatInteraction.saveState(scrollState: immediateScrollState())
        self.genericView.tableView.notifyScrollHandlers()
    }
    override func windowDidResignKey() {
        super.windowDidResignKey()
        updateInteractiveReading()
        chatInteraction.saveState(scrollState:immediateScrollState())
       self.genericView.tableView.notifyScrollHandlers()
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
    
    private func canInteractiveRead() -> Bool {
        let scroll = genericView.scroll
        let hasEntries = self.previousView.with { $0?.filteredEntries.count ?? 0 } > 1
        let checkScroll = self.historyState.isDownOfHistory && scroll.rect.minY == genericView.tableView.frame.height && hasEntries
        let screenIsLocked = appDelegate?.isLockedValue() ?? false
        if checkScroll, !screenIsLocked, context.window.isKeyWindow {
            return true
        } else {
            return false
        }
    }
    
    private func updateInteractiveReading() {
        switch mode {
        case .history:
            if self.canInteractiveRead() {
                self.interactiveReadingDisposable.set(context.engine.messages.installInteractiveReadMessagesAction(peerId: chatInteraction.peerId))

                let visibleMessageRange = self.visibleMessageRange
                self.interactiveReadReactionsDisposable.set(context.engine.messages.installInteractiveReadReactionsAction(peerId: chatInteraction.peerId, getVisibleRange: {

                    return visibleMessageRange.with { $0 }
                }, didReadReactionsInMessages: { [weak self] idsAndReactions in
                    Queue.mainQueue().after(0.1, {
                        self?.playUnseenReactions(Set(idsAndReactions.keys))
                    })
                }))


            } else {
                self.interactiveReadingDisposable.set(nil)
                self.interactiveReadReactionsDisposable.set(nil)
            }

        default:
            self.interactiveReadingDisposable.set(nil)
            self.interactiveReadReactionsDisposable.set(nil)
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
        if chatInteraction.mode == .preview {
            return false
        }
        if presentation.chatMode.customChatContents != nil {
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
    private var checkMessageExists: Bool = true
    private var checkPremiumStickers: Bool = true
    override func updateBackgroundColor(_ backgroundMode: TableBackgroundMode) {
        super.updateBackgroundColor(backgroundMode)
        genericView.updateBackground(backgroundMode, navigationView: self.navigationController?.view, isStandalone: self.navigationController?.modal != nil)
    }
    
    private var currentDeleteAnimationCorrelationIds = Set<AnyHashable>()
    func setCurrentDeleteAnimationCorrelationIds(_ value: Set<AnyHashable>) {
        self.currentDeleteAnimationCorrelationIds = value
    }

    private weak var dustLayerView: DustLayerView? = nil
    
    private func checkMessageDeletions(_ previous: ChatHistoryView?, _ currentView: ChatHistoryView) {
        
        if isLite(.animations) {
            return
        }
        if hasModals(context.window) || !context.window.isKeyWindow {
            return
        }
        
        CATransaction.begin()
        

        var expiredMessageStableIds = Set<AnyHashable>()
        if let previousHistoryView = self.historyView {
            var existingStableIds = Set<AnyHashable>()
            for entry in currentView.filteredEntries {
                switch entry.entry {
                case .MessageEntry:
                    existingStableIds.insert(entry.stableId)
                case .groupedPhotos:
                    existingStableIds.insert(entry.stableId)
                default:
                    break
                }
            }
            let currentTimestamp = Int32(context.timestamp)
            var maybeRemovedInteractivelyMessageIds: [(AnyHashable, EngineMessage.Id)] = []
            for entry in previousHistoryView.filteredEntries {
                switch entry.entry {
                case let .MessageEntry(message, _, _, _, _, _, _):
                    if !existingStableIds.contains(entry.stableId) {
                        if let autoremoveAttribute = message.autoremoveAttribute, let countdownBeginTime = autoremoveAttribute.countdownBeginTime {
                            let exipiresAt = countdownBeginTime + autoremoveAttribute.timeout
                            if exipiresAt <= currentTimestamp - 1 {
                                expiredMessageStableIds.insert(entry.stableId)
                            } else {
                                maybeRemovedInteractivelyMessageIds.append((entry.stableId, message.id))
                            }
                        } else {
                            maybeRemovedInteractivelyMessageIds.append((entry.stableId, message.id))
                        }
                    }
                case let .groupedPhotos(entries, _):
                    var isRemoved = !existingStableIds.contains(entry.stableId)
                    if isRemoved, let message = entries.first?.message {
                        if let autoremoveAttribute = message.autoremoveAttribute, let countdownBeginTime = autoremoveAttribute.countdownBeginTime {
                            let exipiresAt = countdownBeginTime + autoremoveAttribute.timeout
                            if exipiresAt <= currentTimestamp - 1 {
                                expiredMessageStableIds.insert(entry.stableId)
                            } else {
                                maybeRemovedInteractivelyMessageIds.append((entry.stableId, message.id))
                            }
                        } else {
                            maybeRemovedInteractivelyMessageIds.append((entry.stableId, message.id))
                        }
                    }
                default:
                    break
                }
            }
            
            var testIds: [MessageId] = []
            if !maybeRemovedInteractivelyMessageIds.isEmpty {
                for (_, id) in maybeRemovedInteractivelyMessageIds {
                    testIds.append(id)
                }
            }
            for id in self.context.engine.messages.synchronouslyIsMessageDeletedInteractively(ids: testIds) {
                inner: for (stableId, listId) in maybeRemovedInteractivelyMessageIds {
                    if listId == id {
                        expiredMessageStableIds.insert(stableId)
                        break inner
                    }
                }
            }
        }
        self.currentDeleteAnimationCorrelationIds.formUnion(expiredMessageStableIds)
        var appliedDeleteAnimationCorrelationIds = Set<AnyHashable>()

        if !self.currentDeleteAnimationCorrelationIds.isEmpty {
            var foundItemViews: [NSView] = []
            self.genericView.tableView.enumerateViews(with: { view in
                if let view = view as? ChatRowView, let item = view.item as? ChatRowItem {
                    if self.currentDeleteAnimationCorrelationIds.contains(item.stableId) {
                        appliedDeleteAnimationCorrelationIds.insert(item.stableId)
                        self.currentDeleteAnimationCorrelationIds.remove(item.stableId)
                        foundItemViews.append(view.rowView)
                    }
                }
                return true
            })
            if dustLayerView == nil {
                self.dustLayerView = ApplyDustAnimations(for: foundItemViews, superview: self.dustLayerView)
            }
        }
        CATransaction.commit()
    }

    private var prevIsLoading: Bool = false
    private var historyView: ChatHistoryView?
    
    func applyTransition(_ transition:TableUpdateTransition, initialData:ChatHistoryCombinedInitialData, isLoading: Bool, processedView: ChatHistoryView) {
        
                
        let wasEmpty = genericView.tableView.isEmpty
        self.updateBackgroundColor(processedView.theme.controllerBackgroundMode)

        initialDataHandler.set(.single(initialData))
        
        historyState = historyState.withUpdatedStateOfHistory(processedView.originalView?.laterId == nil)
        
        let oldState = genericView.state
        
        
        
        
        let animated: Bool
        switch transition.state {
        case let .none(interface):
            animated = interface != nil
        default:
            animated = transition.animated
        }
        
        var appearAnimated: Bool = false
        if prevIsLoading != isLoading, !isLoading {
            appearAnimated = transition.isOnMainQueue
        } else if !nextTransaction.isExutable {
            switch transition.state {
            case .none, .saveVisible:
                appearAnimated = !transition.isPartOfTransition && genericView.tableView.documentOffset == .zero
            default:
                break
            }
        }
        
        if case .none = transition.state {
            checkMessageDeletions(self.historyView, processedView)
        }
        
        prevIsLoading = isLoading
        
      
        self.currentAnimationRows = []
        
        self.updateHasPhotos(processedView.theme)
        
        genericView.tableView.merge(with: transition, appearAnimated: appearAnimated)
        collectFloatingPhotos(animated: animated && transition.state.isNone, currentAnimationRows: currentAnimationRows)

        
        self.genericView.tableView.notifyScrollHandlers()
        
        genericView.chatTheme = processedView.theme
                   
        genericView.change(state: isLoading ? .progress : .visible, animated: processedView.originalView != nil)
        
        let _ = nextTransaction.execute()

        
        if oldState != genericView.state {
            genericView.tableView.updateEmpties(animated: previousView.with { $0?.originalView != nil })
        }
        
       
        
       // genericView.tableView.notifyScrollHandlers()
        
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
            let messagesCount = processedView.originalView?.entries.count ?? 0
            var current = current.updatedHistoryCount(messagesCount).updatedKeyboardButtonsMessage(initialData.buttonKeyboardMessage)
            
            if let message = initialData.buttonKeyboardMessage {
                if message.requestsSetupReply {
                    if message.id != current.interfaceState.dismissedForceReplyId {
                        current = current.updatedInterfaceState({
                            $0.withUpdatedReplyMessageId(.init(messageId: message.id, quote: nil, todoItemId: nil))
                        })
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
        
        
        
        switch self.mode {
        case .pinned:
            if genericView.tableView.isEmpty {
                navigationController?.back()
            }
        default:
            break
        }
        if !isLoading && checkMessageExists {
            switch self.locationValue?.content {
            case let .InitialSearch(location, _):
                switch location {
                case let .id(messageId, _):
                    checkMessageExists = false

                    delay(1.5, closure: { [weak self] in
                        guard let `self` = self else {
                            return
                        }
                        var found: Bool = false
                        self.genericView.tableView.enumerateItems(with: { item in
                            if let item = item as? ChatRowItem {
                                found = item.messages.contains(where: { $0.id == messageId })
                            }
                            return !found
                        })
                        if !found, !self.genericView.tableView.isEmpty {
                            showModalText(for: context.window, text: strings().chatOpenMessageNotExist, title: nil)
                        }
                    })
                default:
                    break
                }
            default:
                break
            }
        }
        
        if !isLoading {
            var items:[ChatRowItem] = []
            var animatedEmojiItems:[ChatRowItem] = []
            var effectItems:[ChatRowItem] = []
            
            let played: Set<MessageId> = Set(chatInteraction.presentation.playedMessageEffects)

            self.genericView.tableView.enumerateVisibleItems(with: { item in
                if let item = item as? ChatRowItem, let view = item.view, let message = item.message, !played.contains(message.id) {
                    if view.visibleRect == view.bounds {
                        if let file = message.anyMedia as? TelegramMediaFile {
                            if !file.noPremium, !context.premiumIsBlocked, file.isPremiumSticker {
                                items.append(item)
                            } else if file.isEmojiAnimatedSticker || file.isCustomEmoji, file.isPremiumEmoji {
                                if message.globallyUniqueId != nil || message.flags.contains(.Incoming) {
                                    animatedEmojiItems.append(item)
                                }
                            }
                        } else if let _ = item.entry.additionalData.messageEffect {
                            if message.globallyUniqueId != nil || message.flags.contains(.Incoming) {
                                effectItems.append(item)
                            }
                        }
                        
                    }
                }
                return true
            })
            
            let playedIds = (items + animatedEmojiItems + effectItems).compactMap { $0.message?.id }
            
            for item in items {
                if let message = item.message {
                    let mirror = item.renderType == .list || message.isIncoming(item.context.account, item.renderType == .bubble)
                    chatInteraction.runPremiumScreenEffect(message, mirror, false)
                }
            }
            for item in effectItems {
                if let message = item.message {
                    let mirror = item.renderType == .list ? false : message.isIncoming(item.context.account, item.renderType == .bubble)
                    chatInteraction.runPremiumScreenEffect(message, mirror, false)
                }
            }
            for item in animatedEmojiItems {
                if let message = item.message {
                    let mirror = item.renderType == .list || message.isIncoming(item.context.account, item.renderType == .bubble)
                    if let emoji = message.file?.stickerText {
                        chatInteraction.runEmojiScreenEffect(emoji, message, mirror, false)
                    }
                }
            }
            if !playedIds.isEmpty {
                _ = ApplicationSpecificNotice.addPlayedMessageEffects(accountManager: context.sharedContext.accountManager, values: playedIds).startStandalone()
            }
        }
        
        if !didSetReady {
            self.genericView.inputView.updateInterface(with: self.chatInteraction)
        }
        self.didSetReady = true
        
        
        

        
        
        self.historyView = processedView
                
    }
    
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return ChatTitleBarView(controller: self, chatInteraction)
    }
    
    private var editButton:ImageButton? = nil
    private var doneButton:TextButton? = nil
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        editButton?.style = navigationButtonStyle
        
        switch mode {
        case .preview:
            editButton?.set(image: theme.icons.modalClose, for: .Normal)
            editButton?.set(image: theme.icons.modalClose, for: .Highlight)
        default:
            editButton?.set(image: theme.icons.chatActions, for: .Normal)
            editButton?.set(image: theme.icons.chatActionsActive, for: .Highlight)
        }
        

        
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
        let doneButton = TextButton()
      //  doneButton.disableActions()
        doneButton.set(font: .medium(.text), for: .Normal)
        doneButton.set(text: strings().navigationDone, for: .Normal)
        
        
        _ = doneButton.sizeToFit()
        back.addSubview(doneButton)
        doneButton.center()
        
        self.doneButton = doneButton

        
        doneButton.set(handler: { [weak self] _ in
            self?.changeState()
        }, for: .Click)
        
        doneButton.isHidden = true
        
//        doneButton.userInteractionEnabled = false
//        editButton.userInteractionEnabled = false
        
        let context = self.context
        let chatLocation = self.chatLocation
        
        
        switch mode {
        case .preview:
            editButton.set(handler: { [weak self] _ in
                self?.navigationController?.modal?.close()
            }, for: .Click)
        default:
            editButton.contextMenu = { [weak self] in
                
                guard let `self` = self, let peerView = self.currentPeerView, peerViewMainPeer(peerView)?.restrictionText(context.contentSettings) == nil else {
                    return nil
                }
                
                guard !context.isFrozen else {
                    return nil
                }
                
                let chatInteraction = self.chatInteraction
                let menu = ContextMenu(betterInside: true)
                let mode = self.mode
                var items:[ContextMenuItem] = []
                let peerId = chatLocation.peerId
                
                
                switch mode {
                case .history, .thread:
                    if peerId == context.peerId {
                        let displaySavedChatsAsTopics = chatInteraction.presentation.displaySavedChatsAsTopics
                        
                        items.append(ContextMenuItem(strings().chatSavedMessagesViewAsMessages, handler: { [weak self] in
                            context.engine.peers.updateSavedMessagesViewAsTopics(value: false)
                            navigateToChat(navigation: self?.navigationController, context: context, chatLocation: .peer(context.peerId))
                        }, itemImage: !displaySavedChatsAsTopics ? MenuAnimation.menu_check_selected.value : nil))
                        
                        items.append(ContextMenuItem(strings().chatSavedMessagesViewAsChats, handler: { [weak self] in
                            context.engine.peers.updateSavedMessagesViewAsTopics(value: true)
                            self?.navigationController?.back()
                            ForumUI.open(context.peerId, addition: true, context: context)
                        }, itemImage: displaySavedChatsAsTopics ? MenuAnimation.menu_check_selected.value : nil))
                        
                        items.append(ContextSeparatorItem())
                    }
                default:
                    break
                }
                
                switch self.mode {
                case .scheduled:
                    items.append(ContextMenuItem(strings().chatContextClearScheduled, handler: {
                        verifyAlert_button(for: context.window, header: strings().chatContextClearScheduledConfirmHeader, information: strings().chatContextClearScheduledConfirmInfo, ok: strings().chatContextClearScheduledConfirmOK, successHandler: { _ in
                            _ = context.engine.messages.clearHistoryInteractively(peerId: peerId, threadId: nil, type: .scheduledMessages).start()
                        })
                    }, itemImage: MenuAnimation.menu_schedule_message.value))
                case .history:
                    
                    if let peer = peerViewMainPeer(peerView), peer.isForum && peer.displayForumAsTabs {
                        items.append(ContextMenuItem(strings().forumTopicContextNew, handler: {
                            ForumUI.createTopic(peer.id, context: context)
                        }, itemImage: MenuAnimation.menu_plus.value))
                        
                        items.append(ContextSeparatorItem())
                    }
                    
                    switch chatLocation {
                    case let .peer(peerId):
                        
                        
                        items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
                            self?.changeState()
                        }, itemImage: MenuAnimation.menu_edit.value))
                        
                        if peerId != repliesPeerId {
                            items.append(ContextMenuItem(strings().chatContextInfo, handler: { [weak self] in
                                self?.chatInteraction.openInfo(peerId, false, nil, nil)
                            }, itemImage: MenuAnimation.menu_show_info.value))
                        }
                        
                        
                        if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, !self.isAdChat  {
                            if chatInteraction.peerId != context.peerId {
                                items.append(ContextMenuItem(!notificationSettings.isMuted ? strings().chatContextEnableNotifications : strings().chatContextDisableNotifications, handler: { [weak self] in
                                    self?.chatInteraction.toggleNotifications(notificationSettings.isMuted)
                                }, itemImage: notificationSettings.isMuted ? MenuAnimation.menu_unmuted.value : MenuAnimation.menu_mute.value))
                            }
                        }
                        
                        if let peer = peerView.peers[peerView.peerId], let mainPeer = peerViewMainPeer(peerView), !mainPeer.isMonoForum {
                            
                            var activeCall = (peerView.cachedData as? CachedGroupData)?.activeCall
                            activeCall = activeCall ?? (peerView.cachedData as? CachedChannelData)?.activeCall
                            
                            let canDeleteForAll: Bool? = (peerView.cachedData as? CachedChannelData)?.flags.contains(.canDeleteHistory)
                            
                            if peer.groupAccess.canMakeVoiceChat {
                                var isLiveStream: Bool = false
                                if let peer = peer as? TelegramChannel {
                                    isLiveStream = peer.isChannel || peer.flags.contains(.isGigagroup)
                                }
                                items.append(ContextMenuItem(isLiveStream ? strings().peerInfoActionLiveStream : strings().peerInfoActionVoiceChat, handler: { [weak self] in
                                    self?.makeVoiceChat(activeCall, callJoinPeerId: nil)
                                }, itemImage: MenuAnimation.menu_video_chat.value))
                            }
                            if peer.isUser, peer.id != context.peerId {
                                if !peer.isBot, !isServicePeer(peer) {
                                    items.append(ContextMenuItem(strings().peerInfoActionVideoCall, handler: { [weak self] in
                                        self?.chatInteraction.call(isVideo: true)
                                    }, itemImage: MenuAnimation.menu_video_call.value))
                                }
                                
                                if !isServicePeer(peer) {
                                    items.append(ContextMenuItem(strings().chatContextCreateGroup, handler: { [weak self] in
                                        self?.createGroup()
                                    }, itemImage: MenuAnimation.menu_create_group.value))
                                }
                                if !isServicePeer(peer), chatInteraction.presentation.sendPaidMessageStars == nil {
                                    items.append(ContextMenuItem(strings().peerInfoChatBackground, handler: { [weak self] in
                                        self?.showChatThemeSelector()
                                    }, itemImage: MenuAnimation.menu_change_colors.value))
                                }
                            }
                            let deleteChat = { [weak self] in
                                guard let `self` = self else {return}
                                let signal = removeChatInteractively(context: context, peerId: self.chatInteraction.peerId, userId: self.chatInteraction.peer?.id) |> filter {$0} |> mapToSignal { _ -> Signal<ChatLocation?, NoError> in
                                    return context.globalPeerHandler.get() |> take(1)
                                    } |> deliverOnMainQueue
                                
                                self.deleteChatDisposable.set(signal.start(next: { [weak self] location in
                                    if location == self?.chatInteraction.chatLocation {
                                        self?.context.bindings.rootNavigation().close()
                                    }
                                }))
                            }
                            
                            let animation: LocalAnimatedSticker
                            let text: String
                            if peer.isGroup {
                                text = strings().chatListContextDeleteAndExit
                                animation = .menu_delete
                            } else if peer.isChannel {
                                text = strings().chatListContextLeaveChannel
                                animation = .menu_leave
                            } else if peer.isSupergroup {
                                text = strings().chatListContextLeaveGroup
                                animation = .menu_leave
                            } else {
                                text = strings().chatListContextDeleteChat
                                animation = .menu_delete
                            }
                            
                            if !items.isEmpty {
                                items.append(ContextSeparatorItem())
                            }

                            if peer.canManageDestructTimer && context.peerId != peer.id, !isServicePeer(peer) && !peer.isSecretChat, chatInteraction.presentation.sendPaidMessageStars == nil {
                                
                                let best:(Int32) -> MenuAnimation = { value in
    //                                    if value == Int32.secondsInHour {
    //                                        return MenuAnimation.menu_autodelete_1h
    //                                    }
                                    if value == Int32.secondsInDay {
                                        return MenuAnimation.menu_autodelete_1d
                                    }
                                    if value == Int32.secondsInWeek {
                                        return MenuAnimation.menu_autodelete_1w
                                    }
                                    if value == Int32.secondsInMonth {
                                        return MenuAnimation.menu_autodelete_1m
                                    }
                                    if value == 0 {
                                        return MenuAnimation.menu_autodelete_never
                                    }
                                    return MenuAnimation.menu_autodelete_customize
                                }
                                
                                var selected: Int32 = 0
                                var values:[Int32] = [0, .secondsInDay, .secondsInWeek, .secondsInMonth]

                                if let timeout = chatInteraction.presentation.messageSecretTimeout?.timeout {
                                    if !values.contains(timeout.effectiveValue) {
                                        values.append(timeout.effectiveValue)
                                    }
                                    selected = timeout.effectiveValue
                                }
                                let item = ContextMenuItem(strings().chatContextAutoDelete, handler: {
                                    clearHistory(context: context, peer: peer, mainPeer: mainPeer, canDeleteForAll: canDeleteForAll)
                                }, itemImage: selected == 0 ?  MenuAnimation.menu_secret_chat.value : best(selected).value)
                                
                                
                                
                                let submenu = ContextMenu()
                                
                                
             
                                
                                let updateTimer:(Int32)->Void = { value in
                                    _ = showModalProgress(signal: context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peerId, timeout: value == 0 ? nil : value), for: context.window).start()
                                }
                                
                                for value in values {
                                    
                                    
                                    
                                    if value == 0 {
                                        submenu.addItem(ContextMenuItem(strings().autoremoveMessagesNever, handler: {
                                            updateTimer(value)
                                        }, state: selected == value ? .on : nil, itemImage: best(value).value))
                                    } else {
                                        submenu.addItem(ContextMenuItem(autoremoveLocalized(Int(value)), handler: {
                                            updateTimer(value)
                                        }, state: selected == value ? .on : nil, itemImage: best(value).value))
                                    }
                                }
                                
                                item.submenu = submenu
                                items.append(item)
                            }
                            if peer.canClearHistory || (peer.canManageDestructTimer && context.peerId != peer.id) {
                                items.append(ContextMenuItem(strings().chatContextClearHistory, handler: {
                                    clearHistory(context: context, peer: peer, mainPeer: mainPeer, canDeleteForAll: canDeleteForAll)
                                }, itemImage: MenuAnimation.menu_clear_history.value))
                            }
                           
                            
                            items.append(ContextMenuItem(text, handler: deleteChat, itemMode: .destruct, itemImage: animation.value))
                            
                        }
                    case .thread:
                        break
                    }
                case .pinned:
                     items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
                        self?.changeState()
                     }, itemImage: MenuAnimation.menu_edit.value))
                case .thread:
                    items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
                       self?.changeState()
                    }, itemImage: MenuAnimation.menu_edit.value))
                    let threadId = self.chatLocation.threadId
                    if let threadId = threadId, let threadData = chatInteraction.presentation.threadInfo, let peer = chatInteraction.peer {
                        if threadData.isOwnedByMe || peer.isAdmin {
                            if !mode.isSavedMessagesThread {
                                items.append(ContextMenuItem(!threadData.isClosed ? strings().chatListContextPause : strings().chatListContextStart, handler: {
                                    _ = context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: threadId, isClosed: !threadData.isClosed).start()
                                }, itemImage: !threadData.isClosed ? MenuAnimation.menu_pause.value : MenuAnimation.menu_play.value))
                                
                                items.append(ContextSeparatorItem())
                            }
                            if threadId != 1 {
                                items.append(ContextMenuItem(strings().chatListContextDelete, handler: {
                                    _ = removeChatInteractively(context: context, peerId: peerId, threadId: threadId, userId: nil).start()
                                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                            }
                        }
                    }
                case .customChatContents:
                    items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
                       self?.changeState()
                    }, itemImage: MenuAnimation.menu_edit.value))
                case let .customLink(contents):
                    items.append(ContextMenuItem(strings().chatContextBusinessLinkEditName, handler: {
                        contents.editName?()
                    }, itemImage: MenuAnimation.menu_edit.value))
                case .preview:
                    items.append(ContextMenuItem(strings().navigationClose, handler: { [weak self] in
                        self?.navigationController?.modal?.close()
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                }
                
                for item in items {
                    menu.addItem(item)
                }
                return menu
            }

        }
        
        
        requestUpdateRightBar()
        return back
    }

    private func createGroup() {
        createGroupDirectly(with: context, selectedPeers: [self.chatLocation.peerId])
    }
    
    private func startSecretChat() {
        let context = self.context
        let peerId = self.chatLocation.peerId
        let signal = context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
            
        } |> deliverOnMainQueue  |> mapToSignal { peer -> Signal<PeerId, NoError> in
            if let peer = peer {
                let confirm = verifyAlertSignal(for: context.window, header: strings().peerInfoConfirmSecretChatHeader, information: strings().peerInfoConfirmStartSecretChat(peer.displayTitle), ok: strings().peerInfoConfirmSecretChatOK)
                return confirm |> filter { $0 == .basic } |> mapToSignal { (_) -> Signal<PeerId, NoError> in
                    return showModalProgress(signal: context.engine.peers.createSecretChat(peerId: peer.id) |> `catch` { _ in return .complete()}, for: context.window)
                }
            } else {
                return .complete()
            }
        } |> deliverOnMainQueue
        
        
        
        startSecretChatDisposable.set(signal.start(next: { [weak self] peerId in
            if let strongSelf = self {
                navigateToChat(navigation: strongSelf.navigationController, context: strongSelf.context, chatLocation: .peer(peerId))
            }
        }))
    }

    
    private func makeVoiceChat(_ current: CachedChannelData.ActiveCall?, callJoinPeerId: PeerId?) {
        let context = self.context
        let peerId = self.chatLocation.peerId
        if let activeCall = current {
            let join:(PeerId, Date?, Bool)->Void = { joinAs, _, _ in
                _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: activeCall, initialInfo: nil, joinHash: nil, reference: nil), for: context.window).start(next: { result in
                    switch result {
                    case let .samePeer(callContext), let .success(callContext):
                        applyGroupCallResult(context.sharedContext, callContext)
                    default:
                        alert(for: context.window, info: strings().errorAnError)
                    }
                })
            }
            
            if let callJoinPeerId = callJoinPeerId {
                join(callJoinPeerId, nil, false)
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
        } else if case let .contextRequest(_, request) = chatInteraction.presentation.inputContext {
            if request.isEmpty {
                chatInteraction.clearInput()
            } else {
                chatInteraction.clearContextQuery()
            }
            result = .invoked
        } else if chatInteraction.presentation.searchMode.inSearch {
            chatInteraction.update({$0.updatedSearchMode(.init(inSearch: false))})
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
    
    override func invokeNavigationBack() -> Bool {
        let presentation = self.chatInteraction.presentation
        let context = self.context
        switch mode {
        case .customLink(let contents):
            let current = presentation.effectiveInput
            if contents.text.attributes != current.attributes || contents.text.inputText != current.inputText {
                verifyAlert(for: context.window, information: strings().chatAlertUnsaved, ok: strings().chatAlertUnsavedReset, successHandler: { [weak self] _ in
                    self?.navigationController?.invokeBack(checkLock: false)
                })
                return false
            }
        case let .customChatContents(contents):
            if presentation.historyCount == 0 {
                let title: String
                let info: String
                switch contents.kind {
                case .greetingMessageInput:
                    title = strings().quickReplyChatRemoveGreetingMessageTitle
                    info = strings().quickReplyChatRemoveGreetingMessageTitle
                case .awayMessageInput:
                    title = strings().quickReplyChatRemoveAwayMessageTitle
                    info = strings().quickReplyChatRemoveAwayMessageText
                case .quickReplyMessageInput:
                    title = strings().quickReplyChatRemoveGenericTitle
                    info = strings().quickReplyChatRemoveGenericText
                case .searchHashtag:
                    return true
                }
                verifyAlert(for: context.window, header: title, information: info, ok: strings().quickReplyChatRemoveGenericDeleteAction, successHandler: { [weak self] _ in
                    self?.navigationController?.invokeBack(checkLock: false)
                })
                return false
            }
        default:
            break
        }
        return true
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        
        if let window = window, hasModals(window) {
            return .invokeNext
        }
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            if !selectManager.isEmpty {
                let result = selectManager.selectPrevChar()
                if result {
                    return .invoked
                }
            }
        }
        
        return !self.chatInteraction.presentation.searchMode.inSearch && self.chatInteraction.presentation.effectiveInput.inputText.isEmpty ? .rejected : .invokeNext
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
                let result = selectManager.selectNextChar()
                if result {
                    return .invoked
                }
            }
        }
        
        if !self.chatInteraction.presentation.searchMode.inSearch && chatInteraction.presentation.effectiveInput.inputText.isEmpty {
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
        proccessingMessageEventsDisposable.dispose()
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
        interactiveReadReactionsDisposable.dispose()
        deleteChatDisposable.dispose()
        loadSelectionMessagesDisposable.dispose()
        updateMediaDisposable.dispose()
        editCurrentMessagePhotoDisposable.dispose()
        selectMessagePollOptionDisposables.dispose()
        monoforumTopicsDisposable.dispose()
        chatInteraction.clean()
        discussionDataLoadDisposable.dispose()
        slowModeDisposable.dispose()
        slowModeInProgressDisposable.dispose()
        forwardMessagesDisposable.dispose()
        shiftSelectedDisposable.dispose()
        hasScheduledMessagesDisposable.dispose()
        updateUrlDisposable.dispose()
        pollChannelDiscussionDisposable.dispose()
        loadThreadDisposable.dispose()
        recordActivityDisposable.dispose()
        suggestionsDisposable.dispose()
        tempImportersContextDisposable.dispose()
        sendAsPeersDisposable.dispose()
        peekDisposable.dispose()
        transcribeDisposable.dispose()
        startSecretChatDisposable.dispose()
        inputSwapDisposable.dispose()
        keepMessageCountersSyncrhonizedDisposable?.dispose()
        liveTranslateDisposable.dispose()
        presentationDisposable.dispose()
        storiesDisposable.dispose()
        keepSavedMessagesSyncrhonizedDisposable?.dispose()
        keepShortcutDisposable.dispose()
        networkSpeedEventsDisposable?.dispose()
        titleUpdateDisposable.dispose()
        preloadPersonalChannel.dispose()
        codeSyntaxHighlightDisposables.dispose()
        premiumOrStarsRequiredDisposable.dispose()
        _ = previousView.swap(nil)
        
        context.closeFolderFirst = false
        
    }
    
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.emojiEffects.removeAll()

        suggestionsDisposable.set(nil)

        sentMessageEventsDisposable.set(nil)
        proccessingMessageEventsDisposable.set(nil)
        peekDisposable.set(nil)
        
        genericView.inputContextHelper.viewWillRemove()
        chatInteraction.saveState(scrollState: immediateScrollState())
        
        context.window.removeAllHandlers(for: self)
        
        if let window = window {
            selectTextController.removeHandlers(for: window)
        }
        self.visibility.set(false)
        
        context.reactions.sentStarReactions = nil
        context.reactions.forceSendStarReactions = nil
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        chatInteraction.remove(observer: self)
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

        self.context.bindings.entertainment().update(with: self.chatInteraction)
        
        chatInteraction.update(animated: false, {$0.withToggledSidebarEnabled(FastSettings.sidebarEnabled).withToggledSidebarShown(FastSettings.sidebarShown)})
        
         self.failedMessageEventsDisposable.set((context.account.pendingMessageManager.failedMessageEvents(peerId: chatInteraction.peerId)
         |> deliverOnMainQueue).start(next: { [weak self] reason in
            if let strongSelf = self {
                let text: String
                switch reason {
                case .flood:
                    text = strings().chatSendMessageErrorFlood
                case .publicBan:
                    text = strings().chatSendMessageErrorGroupRestricted
                case .mediaRestricted:
                    text = strings().chatSendMessageErrorGroupRestricted
                case .slowmodeActive:
                    text = strings().chatSendMessageSlowmodeError
                case .tooMuchScheduled:
                    text = strings().chatSendMessageErrorTooMuchScheduled
                case .voiceMessagesForbidden:
                    let peer = strongSelf.chatInteraction.presentation.mainPeer
                    text = strings().chatSendVoicePrivacyError(peer?.compactDisplayTitle ?? "")
                case .sendingTooFast:
                    text = strings().chatSendMessageErrorTooFast
                case .nonPremiumMessagesForbidden:
                    let peer = strongSelf.chatInteraction.presentation.mainPeer
                    text = strings().chatSendMessageErrorNonPremiumForbidden(peer?.compactDisplayTitle ?? "")
                }
                verifyAlert_button(for: context.window, information: text, cancel: "", option: strings().genericErrorMoreInfo, successHandler: { [weak strongSelf] confirm in
                    guard let strongSelf = strongSelf else {return}
                    
                    switch confirm {
                    case .thrid:
                        execute(inapp: inAppLink.followResolvedName(link: "@spambot", username: "spambot", postId: nil, forceProfile: false, context: context, action: nil, callback: { [weak strongSelf] peerId, openChat, postid, initialAction in
                            strongSelf?.chatInteraction.openInfo(peerId, openChat, postid, initialAction)
                        }))
                    default:
                        break
                    }
                })
            }
         }))
 
        
        if let peer = chatInteraction.peer {
            if peer.isRestrictedChannel(context.contentSettings), let reason = peer.restrictionText(context.contentSettings) {
                alert(for: context.window, info: reason, completion: { [weak self] in
                    self?.dismiss()
                })
            } else if chatInteraction.presentation.isNotAccessible {
                alert(for: context.window, info: peer.isChannel ? strings().chatChannelUnaccessible : strings().chatGroupUnaccessible, completion: { [weak self] in
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
                        return .invoked
                    }
                } else {
                    if strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                        strongSelf.genericView.tableView.scrollUp()
                        return .invoked
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
                var currentReplyId = self.chatInteraction.presentation.interfaceState.replyMessage
                self.genericView.tableView.enumerateItems(with: { item in
                    if let item = item as? ChatRowItem, let message = item.message {
                        if canReplyMessage(message, peerId: self.chatInteraction.peerId, chatLocation: self.chatLocation, mode: self.chatInteraction.mode), currentReplyId == nil || (message.id < currentReplyId!.id) {
                            currentReplyId = message
                            self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsetsZero, timingFunction: .linear)
                            return false
                        }
                    }
                    return true
                })
                
                let result:KeyHandlerResult = currentReplyId != nil ? .invoked : .rejected
                let subject: EngineMessageReplySubject?
                if let currentReplyId = currentReplyId {
                    subject = .init(messageId: currentReplyId.id, quote: nil, todoItemId: nil)
                } else {
                    subject = nil
                }
                self.chatInteraction.setupReplyMessage(currentReplyId, subject)
                
                return result
            }
            return .rejected
        }, with: self, for: .UpArrow, priority: .low, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let `self` = self, let window = self.window, !hasModals(window), self.chatInteraction.presentation.interfaceState.editState == nil, self.chatInteraction.presentation.interfaceState.inputState.inputText.isEmpty {
                var currentReplyId = self.chatInteraction.presentation.interfaceState.replyMessage
                self.genericView.tableView.enumerateItems(reversed: true, with: { item in
                    if let item = item as? ChatRowItem, let message = item.message {
                        if canReplyMessage(message, peerId: self.chatInteraction.peerId, chatLocation: self.chatLocation, mode: self.chatInteraction.mode), currentReplyId != nil && (message.id > currentReplyId!.id) {
                            currentReplyId = message
                            self.genericView.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsetsZero, timingFunction: .linear)
                            return false
                        }
                    }
                    return true
                })
                
                let result:KeyHandlerResult = currentReplyId != nil ? .invoked : .rejected
                let subject: EngineMessageReplySubject?
                if let currentReplyId = currentReplyId {
                    subject = .init(messageId: currentReplyId.id, quote: nil, todoItemId: nil)
                } else {
                    subject = nil
                }
                self.chatInteraction.setupReplyMessage(currentReplyId, subject)
                
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
            guard let strongSelf = self else {
                return .rejected
            }
            if hasModals() {
                return .rejected
            }
            let inputView = strongSelf.genericView.inputView.textView.inputView
            if strongSelf.context.window.firstResponder != inputView {
                _ = strongSelf.context.window.makeFirstResponder(inputView)
                return .invoked
            } else if (self?.navigationController as? MajorNavigationController)?.genericView.state == .single {
                return .invoked
            }
            return .rejected
        }, with: self, for: .Tab, priority: .high)
        
      
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self, self.mode != .scheduled, self.searchAvailable else {return .rejected}
            if !self.chatInteraction.presentation.searchMode.inSearch {
                self.chatInteraction.update({$0.updatedSearchMode(.init(inSearch: true))})
            } else {
                self.genericView.applySearchResponder()
            }

            return .invoked
        }, with: self, for: .F, priority: .medium, modifierFlags: [.command])
        
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.chatInteraction.attachFile(true)
            return .invoked
        }, with: self, for: .O, priority: .medium, modifierFlags: [.command])
      
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeBold()
            return .invoked
        }, with: self, for: .B, priority: .medium, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeUnderline()
            return .invoked
        }, with: self, for: .U, priority: .high, modifierFlags: [.shift, .command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeQuote()
            return .invoked
        }, with: self, for: .I, priority: .high, modifierFlags: [.shift, .command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeSpoiler()
            return .invoked
        }, with: self, for: .P, priority: .medium, modifierFlags: [.shift, .command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputView.makeStrikethrough()
            return .invoked
        }, with: self, for: .X, priority: .medium, modifierFlags: [.shift, .command])
        
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
            guard let `self` = self, let window = self.window, self.chatInteraction.presentation.canReplyInRestrictedMode else {return .failed}
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
                    guard let item = self.genericView.tableView.item(at: row) as? ChatRowItem else {
                        return .failed
                    }
                    if !item.isSharable {
                        if let message = item.message, !canReplyMessage(message, peerId: self.chatInteraction.peerId, chatLocation: self.chatInteraction.chatLocation, mode: self.chatInteraction.mode) {
                            return .failed
                        }
                    }
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
//                self.reactionManager?.clearAndTempLock()
//                self.reactionManager?.update()
            case let .success(_, controller), let .failed(_, controller):
                let controller = controller as! RevealTableItemController
                guard let view = (controller.item.view as? RevealTableView) else { return .nothing }
                
                view.completeReveal(direction: direction)
                self.updateFloatingPhotos(self.genericView.scroll, animated: true)

             //   self.reactionManager?.update(transition: .animated(duration: 0.2, curve: .easeOut))

            }
            
            
            //  return .success()
            
            return .nothing
        }, with: self.genericView.tableView, identifier: "chat-reply-swipe")
        
                
        let peerId = self.chatLocation.peerId
        
      
        
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
        
       self.sentMessageEventsDisposable.set((context.account.pendingMessageManager.deliveredMessageEvents(peerId: self.chatLocation.peerId) |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { pending in
           
           for result in pending {
               if FastSettings.inAppSounds, !result.isSilent, !result.isPendingProcessing {
                   if let beginPendingTime = beginPendingTime {
                       if CFAbsoluteTimeGetCurrent() - beginPendingTime < 0.5 {
                           return
                       }
                   }
                   beginPendingTime = CFAbsoluteTimeGetCurrent()
                   playSoundEffect(.sent)
               }
               
           }
          
       }))
        
        let proccessingEvents = context.account.pendingMessageManager.deliveredMessageEvents(peerId: self.chatLocation.peerId)
        |> deliverOnMainQueue
        |> map { $0.filter(\.isPendingProcessing) }
        
        let chatLocation = self.chatLocation
        
        
        proccessingMessageEventsDisposable.set(proccessingEvents.start(next: { [weak self] proccessing in
            if let first = proccessing.first {
                self?.navigationController?.push(ChatScheduleController(context: context, chatLocation: chatLocation, focusTarget: .init(messageId: first.id)))
            }
        }))
         

        
        let suggestions = context.engine.notices.getPeerSpecificServerProvidedSuggestions(peerId: self.chatLocation.peerId) |> deliverOnMainQueue

        suggestionsDisposable.set(suggestions.start(next: { suggestions in
            for suggestion in suggestions {
                switch suggestion {
                case .convertToGigagroup:
                    verifyAlert_button(for: context.window, header: strings().broadcastGroupsLimitAlertTitle, information: strings().broadcastGroupsLimitAlertText(Formatter.withSeparator.string(from: NSNumber(value: context.limitConfiguration.maxSupergroupMemberCount))!), ok: strings().broadcastGroupsLimitAlertLearnMore, successHandler: { _ in
                        showModal(with: GigagroupLandingController(context: context, peerId: peerId), for: context.window)
                    }, cancelHandler: {
                        showModalText(for: context.window, text: strings().broadcastGroupsLimitAlertSettingsTip)
                    })
                    _ = context.engine.notices.dismissPeerSpecificServerProvidedSuggestion(peerId: peerId, suggestion: suggestion).startStandalone()
                }
            }
        }))

        
    }
    
    
    func findAndSetEditableMessage() -> Bool {
        if self.previousView.with({ $0?.originalView?.laterId == nil }) {
            
            var edited: Bool = false
            genericView.tableView.enumerateVisibleItems(with: { item in
                guard let item = item as? ChatRowItem else {
                    return true
                }
                if item.messages.count > 1 {
                    var effectiveMessage: Message?
                    for message in item.messages {
                        if !message.text.isEmpty {
                            effectiveMessage = message
                            break
                        }
                    }
                    effectiveMessage = effectiveMessage ?? item.messages.first
                    
                    if let message = effectiveMessage {
                        if canEditMessage(message, chatInteraction: chatInteraction, context: context)  {
                            chatInteraction.beginEditingMessage(message)
                            edited = true
                            return false
                        }
                    }
                } else if let message = item.message {
                    if canEditMessage(message, chatInteraction: chatInteraction, context: context)  {
                        chatInteraction.beginEditingMessage(message)
                        edited = true
                        return false
                    }
                }
                
                
                return true
            })
            return edited
        }
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        if mode == .preview {
            return self.genericView
        }
        return self.genericView.responder
    }
    
    override var responderPriority: HandlerPriority {
        return .medium
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let context = self.context
        
        switch self.mode {
        case .history, .thread:
            self.context.globalPeerHandler.set(.single(chatLocation))
        default:
            break
        }

        self.genericView.tableView.notifyScrollHandlers()
//        self.genericView.updateHeader(chatInteraction.presentation, false, false)
        if let controller = context.sharedContext.getAudioPlayer(), let header = self.navigationController?.header, header.needShown {
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: genericView.tableView, supportTableView: nil)
            header.view.update(with: object)
        }
        self.visibility.set(true)
        
        context.reactions.sentStarReactions = { [weak self] messageId, count in
            self?.genericView.updateStars(context: context, count: Int32(count), messageId: messageId)
        }
        context.reactions.forceSendStarReactions = { [weak self] in
            self?.genericView.forceCancelPendingStars()
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
    private let focusTarget: ChatFocusTarget?
    let mode: ChatMode
    
    private let sizeValue = ValuePromise<NSSize>(ignoreRepeated: true)
    
    public init(context: AccountContext, chatLocation:ChatLocation, mode: ChatMode = .history, focusTarget:ChatFocusTarget? = nil, initialAction: ChatInitialAction? = nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>? = nil) {
        self.focusTarget = focusTarget
        self.chatLocationContextHolder = chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)
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
                
        if chatLocation.peerId.namespace == Namespaces.Peer.CloudChannel || chatLocation.peerId.namespace == Namespaces.Peer.CloudUser, mode == .history {
            self.adMessages = .init(context: context, height: sizeValue.get() |> map { $0 .height}, peerId: chatLocation.peerId)
        } else {
            self.adMessages = nil
        }
        
        
       
        var takeTableItem:((MessageId)->ChatRowItem?)? = nil
        
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
        self.factCheckProcessingManager.process = { messageIds in
            _ = context.engine.messages.getMessagesFactCheck(messageIds: Array(messageIds)).startStandalone()
        }
        
        self.extendedMediaProcessingManager.process = { messageIds in
            context.account.viewTracker.updatedExtendedMediaForMessageIds(messageIds: messageIds)
        }

        self.unsupportedMessageProcessingManager.process = { [weak self] messageIds in
            let msgIds = messageIds.filter { $0.namespace == Namespaces.Message.Cloud }.map { MessageAndThreadId(messageId: $0, threadId: self?.chatLocation.threadId) }
            context.account.viewTracker.updateUnsupportedMediaForMessageIds(messageIds: Set(msgIds) )
        }
        self.messageMentionProcessingManager.process = { messageIds in
            context.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}))
        }
        self.messageReactionsMentionProcessingManager.process = { [weak self] messageIds in
            context.account.viewTracker.updateMarkReactionsSeenForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}))
            self?.playUnseenReactions(messageIds, checkUnseen: true)
        }
        self.refreshStoriesProcessingManager.process = { [weak self] messageIds in
            self?.context.account.viewTracker.refreshStoriesForMessageIds(messageIds: messageIds)
        }
        self.refreshMediaProcessingManager.process = { [weak self] messageIds in
            self?.context.account.viewTracker.refreshSecretMediaMediaForMessageIds(messageIds: messageIds)
        }
        self.seenLiveLocationProcessingManager.process = { [weak self] messageIds in
            self?.context.account.viewTracker.updateSeenLiveLocationForMessageIds(messageIds: messageIds)
        }


        self.reactionsMessageProcessingManager.process = { messageIds in
            context.account.viewTracker.updateReactionsForMessageIds(messageIds: messageIds.filter({$0.namespace == Namespaces.Message.Cloud}))
        }
        
        chatInteraction.contextHolder = { [weak self] in
            return self?.chatLocationContextHolder ?? Atomic(value: nil)
        }
        
        takeTableItem = { [weak self] msgId in
            if self?.isLoaded() == false {
                return nil
            }
            var found: ChatRowItem? = nil
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
        self.notify(with: value, oldValue: oldValue, animated: animated && self.didSetReady, force: false)
//        DispatchQueue.main.async { [weak self] in
//            if let self {
//                self.updateFloatingPhotos(self.genericView.scroll, animated: animated)
//            }
//        }
    }
    
    private var isPausedGlobalPlayer: Bool = false
    private var tempImportersContext: PeerInvitationImportersContext? = nil
    private let tempImportersContextDisposable = MetaDisposable()
    
    func notify(with value: Any, oldValue: Any, animated:Bool, force:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            let context = self.context
            let mode = self.chatInteraction.mode
            
            if value.selectionState != oldValue.selectionState {
                if let selectionState = value.selectionState {
                    let ids = Array(selectionState.selectedIds)
                    let messages: Signal<[Message], NoError>
                    
                    switch mode {
                    case let .customChatContents(contents):
                        messages = contents.messagesAtIds(ids, album: false) |> deliverOnMainQueue
                    default:
                        messages = context.account.postbox.messagesAtIds(ids) |> deliverOnMainQueue
                    }
                    loadSelectionMessagesDisposable.set(messages.start( next:{ [weak self] messages in
                        var canDelete:Bool = !messages.isEmpty && !context.isFrozen
                        var canForward:Bool = !messages.isEmpty && !context.isFrozen
                        if let chatInteraction = self?.chatInteraction {
                            for message in messages {
                                if !canDeleteMessage(message, account: context.account, chatLocation: value.chatLocation, mode: mode) {
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
                
                updateFloatingPhotos(self.genericView.scroll, animated: animated)
            }

            
            if oldValue.recordingState == nil && value.recordingState != nil {
                if let pause = context.sharedContext.getAudioPlayer()?.pause() {
                    isPausedGlobalPlayer = pause
                }
            } else if value.recordingState == nil && oldValue.recordingState != nil {
                if isPausedGlobalPlayer {
                    _ = context.sharedContext.getAudioPlayer()?.play()
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
                genericView.inputContextHelper.context(with: value.inputQueryResult, for: genericView, relativeView: genericView.inputView, animated: true)
            }
            if value.interfaceState.inputState != oldValue.interfaceState.inputState {
                if didSetReady {
                    chatInteraction.saveState(false, scrollState: immediateScrollState())
                }
            }
            if value.searchMode.tag != oldValue.searchMode.tag || value.searchMode.showAll != oldValue.searchMode.showAll {
                let content: ChatHistoryLocation = .Scroll(index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, sourceIndex: MessageHistoryAnchorIndex.upperBound, scrollPosition: .down(true), count: self.requestCount, animated: true)
                if let tag = value.searchMode.tag, !value.searchMode.showAll {
                    self.setLocation(.init(content: content, chatLocation: self.chatLocation, tag: tag, id: self.takeNextHistoryLocationId()))
                } else {
                    self.setLocation(.init(content: content, chatLocation: self.chatLocation, tag: nil, id: self.takeNextHistoryLocationId()))
                }
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
            let input = value.effectiveInput
            if input != oldValue.effectiveInput || value.botMenu != oldValue.botMenu || force {
                
                let textInputContextState = textInputStateContextQueryRangeAndType(input, includeContext: false)
                
                var cleanup = true
                
                if let textInputContextState = textInputContextState {
                    if textInputContextState.1.contains(.swapEmoji) {
                        let stringRange = textInputContextState.0
                        let range = NSRange(string: input.inputText, range: stringRange)
                        if !input.isAnimatedEmoji(at: range) {
                            let query = String(input.inputText[stringRange])
                            let signal = InputSwapSuggestionsPanelItems(query, peerId: chatInteraction.peerId, context: chatInteraction.context)
                            |> deliverOnMainQueue
                            self.inputSwapDisposable.set(signal.start(next: { [weak self] files in
                                self?.genericView.updateTextInputSuggestions(files, range: range, animated: animated)
                            }))
                            cleanup = false
                        }
                    }
                }
                if cleanup {
                    self.genericView.updateTextInputSuggestions([], range: NSMakeRange(0, 0), animated: animated)
                    self.inputSwapDisposable.set(nil)
                }
                
                if let (updatedContextQueryState, updatedContextQuerySignal) = contextQueryResultStateForChatInterfacePresentationState(value, context: self.context, currentQuery: self.contextQueryState?.0) {
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
            
            
            if value.monoforumState != oldValue.monoforumState || value.monoforumTopics != oldValue.monoforumTopics || value.chatLocation != oldValue.chatLocation {
                genericView.updateMonoforumState(state: value.monoforumState, items: value.monoforumTopics, threadId: value.chatLocation.threadId, animated: animated)
            }
            
            if value.searchMode != oldValue.searchMode || value.pinnedMessageId != oldValue.pinnedMessageId || value.peerStatus != oldValue.peerStatus || value.interfaceState.dismissedPinnedMessageId != oldValue.interfaceState.dismissedPinnedMessageId || value.initialAction != oldValue.initialAction || value.restrictionInfo != oldValue.restrictionInfo || value.hidePinnedMessage != oldValue.hidePinnedMessage || value.groupCall != oldValue.groupCall || value.reportMode != oldValue.reportMode || value.inviteRequestsPendingPeers != oldValue.inviteRequestsPendingPeers || value.threadInfo?.isClosed != oldValue.threadInfo?.isClosed || value.translateState != oldValue.translateState || value.savedMessageTags != oldValue.savedMessageTags || value.connectedBot != oldValue.connectedBot || value.adMessage != oldValue.adMessage || value.historyCount != oldValue.historyCount || value.monoforumState != oldValue.monoforumState || value.removePaidMessageFeeData != oldValue.removePaidMessageFeeData {
                genericView.updateHeader(value, animated, value.hidePinnedMessage != oldValue.hidePinnedMessage)
                (centerBarView as? ChatTitleBarView)?.updateStatus(true, presentation: value)
            }
            
            if value.chatLocation != oldValue.chatLocation {
                self.setLocation(.Initial(count: self.requestCount, scrollPosition: .down(true)), chatLocation: value.chatLocation)
            }
            
            if value.reportMode != oldValue.reportMode {
                (self.centerBarView as? ChatTitleBarView)?.updateSearchButton(hidden: !isSearchAvailable(value), animated: animated)
            }

            if value.peer != nil && oldValue.peer == nil {
                genericView.tableView.emptyItem = ChatEmptyPeerItem(genericView.tableView.frame.size, chatInteraction: chatInteraction, theme: previousView.with { $0?.theme ?? theme })
            }
            
            var upgradedToPeerId: PeerId?
            if let previous = oldValue.peer, let group = previous as? TelegramGroup, group.migrationReference == nil, let updatedGroup = value.peer as? TelegramGroup, let migrationReference = updatedGroup.migrationReference {
                upgradedToPeerId = migrationReference.peerId
            }


            self.state = value.selectionState != nil ? .Edit : .Normal
            
            if let upgradedToPeerId = upgradedToPeerId, navigationController?.controller == self {
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
                        if self.chatInteraction.peerIsAccountPeer {
                            self.context.account.updateLocalInputActivity(peerId: .init(peerId: self.chatLocation.peerId, category: mode.activityCategory(value.chatLocation.threadId)), activity: activity, isPresent: true)
                        }
                    }))
                    
                } else if let state = oldValue.recordingState {
                    let activity: PeerInputActivity = state is ChatRecordingAudioState ? .recordingVoice : .recordingInstantVideo
                    if self.chatInteraction.peerIsAccountPeer {
                        self.context.account.updateLocalInputActivity(peerId: .init(peerId: self.chatLocation.peerId, category: mode.activityCategory(value.chatLocation.threadId)), activity: activity, isPresent: false)
                    }
                    recordActivityDisposable.set(nil)
                }
            }
            
            dismissedPinnedIds.set(ChatDismissedPins(ids: value.interfaceState.dismissedPinnedMessageId, tempMaxId: value.tempPinnedMaxId))
           
            
            if value.inviteRequestsPending != oldValue.inviteRequestsPending, let count = value.inviteRequestsPending, count > 0, !self.chatInteraction.presentation.isTopicMode, let peer = value.peer as? TelegramChannel, peer.groupAccess.canCreateInviteLink {
        
                let peerId = self.chatLocation.peerId
                let current:PeerInvitationImportersContext
                if let value = self.tempImportersContext {
                    current = value
                } else {
                    let importersContext = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
                    importersContext.loadMore()
                    current = importersContext
                }
                self.tempImportersContext = current
                let state = current.state
                |> filter { !$0.isLoadingMore }
                |> deliverOnMainQueue
                tempImportersContextDisposable.set(state.start(next: { [weak self] state in
                    let check = FastSettings.canBeShownPendingRequests(state.importers.compactMap { $0.peer.peer?.id }, for: peerId)
                    if check || state.importers.isEmpty  {
                        self?.chatInteraction.update {
                            $0.withUpdatedInviteRequestsPendingPeers(state.importers)
                        }
                    }
                }))
            } else {
                if value.inviteRequestsPending == nil || value.inviteRequestsPending == 0 {
                    tempImportersContext = nil
                    tempImportersContextDisposable.set(nil)
                }
            }
            
            if let peer = value.mainPeer, let oldPeer = oldValue.mainPeer {
                if peer.isForum && !oldPeer.isForum || (oldValue.threadInfo != nil && value.threadInfo == nil && !peer.displayForumAsTabs), !peer.isMonoForum {
                    self.navigationController?.removeImmediately(self)
                }
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
    
    private func playUnseenReactions(_ messageIds: Set<MessageId>, checkUnseen: Bool = false) {
        
        self.genericView.tableView.enumerateVisibleItems(with: { item in
            guard let item = item as? ChatRowItem else {
                return true
            }
            for id in messageIds {
                if item.firstMessage?.id == id, let view = item.view as? ChatRowView {
                    if view.visibleRect.height == view.frame.height {
                        view.playSeenReactionEffect(checkUnseen)
                    }
                }
            }
            return true
        })
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
            
            if case .block = chatInteraction.presentation.state {
                return []
            }
            
            if let list = list, list.count > 0 {
                
                var items:[DragItem] = []
                
                let list = list.filter { path -> Bool in
                    if let size = fileSize(path) {
                        let exceed = fileSizeLimitExceed(context: context, fileSize: size)
                        return exceed
                    }
                    return false
                }
                
                if list.count == 1, let editState = chatInteraction.presentation.interfaceState.editState, editState.canEditMedia {
                    return [DragItem(title: strings().chatDropEditTitle, desc: strings().chatDropEditDesc, handler: { [weak self] in
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
                    
                    
                    let asMediaItem = DragItem(title: strings().chatDropTitle, desc: strings().chatDropQuickDesc, handler:{ [weak self] in
                        NSApp.activate(ignoringOtherApps: true)
                        self?.chatInteraction.showPreviewSender(list.map { URL(fileURLWithPath: $0) }, true, nil)
                    })
                    let fileTitle: String
                    let fileDesc: String
                    
                    if list.count == 1, list[0].isDirectory {
                        fileTitle = strings().chatDropFolderTitle
                        fileDesc = strings().chatDropFolderDesc
                    } else {
                        fileTitle = strings().chatDropTitle
                        fileDesc = strings().chatDropAsFilesDesc
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
                    return [DragItem(title: strings().chatDropEditTitle, desc: strings().chatDropEditDesc, handler: { [weak self] in
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

                let asMediaItem = DragItem(title: strings().chatDropTitle, desc: strings().chatDropQuickDesc, handler:{ [weak self] in
                    NSApp.activate(ignoringOtherApps: true)
                    _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak self] path in
                        self?.chatInteraction.showPreviewSender([URL(fileURLWithPath: path)], true, nil)
                    })

                })
                
                let asFileItem = DragItem(title: strings().chatDropTitle, desc: strings().chatDropAsFilesDesc, handler:{ [weak self] in
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
        if context.layout == .single {
            return super.backSettings()
        }
        return (strings().navigationClose,nil)
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
    func closeChatThemesSelector() {
        self.themeSelector?.close(true)
    }
    
    func findStoryControl(_ messageId: MessageId?, _ storyId: Int32?, _ peerId: PeerId, useAvatar: Bool = false) -> NSView? {
        var control: NSView? = nil
        
        if useAvatar, !self.grouppedFloatingPhotos.isEmpty {
            for value in grouppedFloatingPhotos {
                if value.0.contains(where: { $0.messages.contains(where: { $0.id == messageId })}) {
                    return value.1.storyControl
                }
            }
        }
        
        genericView.tableView.enumerateVisibleItems(with: { item in
            guard let id = storyId else {
                return false
            }
            let storyId: StoryId = .init(peerId: peerId, id: id)
            if let item = item as? ChatRowItem, messageId == item.message?.id || messageId == nil {
                if useAvatar, let view = item.view as? ChatRowView {
                    control = view.storyAvatarControl
                    return false
                }
                if let attr = item.message?.storyAttribute {
                    if attr.storyId == storyId {
                        if let view = item.view as? ChatRowView {
                            control = view.storyControl(storyId)
                        }
                    }
                } else if let media = item.message?.media.first as? TelegramMediaStory, media.storyId == storyId {
                    control = (item.view as? ChatRowView)?.storyMediaControl ?? (item.view as? ChatServiceRowView)?.storyMediaControl
                } else if let media = item.message?.media.first as? TelegramMediaWebpage {
                    switch media.content {
                    case let .Loaded(content):
                        if content.story?.storyId == storyId {
                            control = (item.view as? ChatRowView)?.storyMediaControl
                        }
                    default:
                        break
                    }
                }
            }
            return control == nil
        })
        return control
    }
    
    func showChatThemeSelector() {
        
        guard themeSelector == nil else {
            return
        }
        
        let context = self.context
        
        if let peer = chatInteraction.peer as? TelegramChannel {
            if peer.hasPermission(.changeInfo) {
                navigationController?.push(SelectColorController(context: context, peer: peer))
            }
            return
        }
        
        self.themeSelector = ChatThemeSelectorController(context, installedTheme: self.uiState.with { $0.presentation_emoticon }, chatTheme: chatThemeValue.get(), chatInteraction: self.chatInteraction)
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
            if let value = theme.1 {
                self?.chatThemeTempValue.set(.single((theme.0, value)))
            } else {
                self?.chatThemeTempValue.set(.single(nil))
            }
        }
        
        self.themeSelector?._frameRect = NSMakeRect(0, self.frame.maxY, frame.width, 230)
        self.themeSelector?.loadViewIfNeeded()
        
        self.chatInteraction.update({ $0.updatedInterfaceState({ $0.withUpdatedThemeEditing(true) })})
    }
    
    func focusExistingMessage(_ message: Message) -> Void {
        let scroll: TableScrollState = .center(id: ChatHistoryEntryId.message(message), innerId: nil, animated: true, focus: .init(focus: true, string: nil), inset: 0)
        genericView.tableView.scroll(to: scroll)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        (centerBarView as? ChatTitleBarView)?.updateStatus(presentation: chatInteraction.presentation)
        (centerBarView as? ChatTitleBarView)?.updateLocalizationAndTheme(theme: theme)
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
                case let .mediaId(_, message):
                    return ChatHistoryEntryId.message(message)
                default:
                    break
                }
            }
            return nil
        }
    }

    
}


/*
 switch strongSelf.mode {
 case let .thread(data, mode):
     if mode.originId == toId {
         let controller = strongSelf.navigationController?.previousController as? ChatController
         if let controller = controller, case .peer(mode.originId.peerId) = controller.chatLocation {
             strongSelf.navigationController?.back()
             controller.chatInteraction.focusMessageId(fromId, mode.originId, state)
         } else {
             strongSelf.navigationController?.push(ChatAdditionController(context: strongSelf.context, chatLocation: .thread(data), mode: .history, messageId: toId, initialAction: nil))
         }
         return
     } else if toId.peerId != peerId {
         strongSelf.navigationController?.push(ChatAdditionController(context: strongSelf.context, chatLocation: .peer(toId.peerId), mode: .history, messageId: toId, initialAction: nil))
     }
 default:
     break
 }
 */
