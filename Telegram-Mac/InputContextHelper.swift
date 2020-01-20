//
//  InputContextHelper.swift
//  Telegram-Mac
//
//  Created by keepcoder on 31/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TGUIKit
import Postbox
import TelegramCore
import SyncCore




enum InputContextEntry : Comparable, Identifiable {
    case switchPeer(PeerId, ChatContextResultSwitchPeer)
    case message(Int64, Message, String)
    case peer(Peer, Int, Int64)
    case contextResult(ChatContextResultCollection,ChatContextResult,Int64)
    case contextMediaResult(ChatContextResultCollection?, InputMediaContextRow, Int64)
    case command(PeerCommand, Int64, Int64)
    case sticker(InputMediaStickersRow, Int64)
    case showPeers(Int, Int64)
    case emoji([String], Bool, Int32)
    case hashtag(String, Int64)
    case inlineRestricted(String)
    var stableId: Int64 {
        switch self {
        case .switchPeer:
            return -1
        case let .message(_, message, _):
            return message.id.toInt64()
        case let .peer(_,_, stableId):
            return stableId
        case let .contextResult(_,_,index):
            return index
        case let .contextMediaResult(_,_,index):
            return index
        case let .command( _, _, stableId):
            return stableId
        case let .sticker(_, stableId):
            return stableId
        case let .showPeers(_, stableId):
            return stableId
        case let .hashtag(hashtag, _):
            return Int64(hashtag.hashValue)
        case let .emoji(clue, _, _):
            return Int64(clue.joined().hashValue)
        case .inlineRestricted:
            return -1000
        }
    }
    
    var index:Int64 {
        switch self {
        case .switchPeer:
            return -1
        case let .peer(_, index, _):
            return Int64(index)
        case let .contextResult(_, _, index):
            return index //result.maybeId | ((Int64(index) << 40))
        case let .contextMediaResult(_, _, index):
            return index //result.maybeId | ((Int64(index) << 40))
        case let .command(_, index, _):
            return index //result.maybeId | ((Int64(index) << 40))
        case let .sticker(_, index):
            return index //result.maybeId | ((Int64(index) << 40))
        case let .showPeers(index, _):
            return Int64(index) //result.maybeId | ((Int64(index) << 40))
        case let .hashtag(_, index):
            return index
        case let .emoji(_, _, index):
            return Int64(index) //result.maybeId | ((Int64(index) << 40))
        case .inlineRestricted:
            return 0
        case let .message(index, _, _):
            return index
        }
    }
}

func <(lhs:InputContextEntry, rhs:InputContextEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs:InputContextEntry, rhs:InputContextEntry) -> Bool {
    switch lhs {
    case let .switchPeer(peerId, switchPeer):
        if case .switchPeer(peerId, switchPeer) = rhs {
            return true
        } else {
            return false
        }
    case let .peer(lhsPeer, lhsIndex, _):
        if case let .peer(rhsPeer, rhsIndex, _) = rhs {
            return lhsPeer.id == rhsPeer.id && lhsIndex == rhsIndex
        }
        return false
    case let .contextResult(_, lhsResult,_):
        if case let .contextResult(_, rhsResult, _) = rhs {
            return  lhsResult == rhsResult
        }
        return false
    case let .contextMediaResult(_, lhsResult,_):
        if case let .contextMediaResult(_, rhsResult, _) = rhs {
            return  lhsResult == rhsResult
        }
        return false
    case let .command(lhsCommand, lhsIndex, _):
        if case let .command(rhsCommand, rhsIndex, _) = rhs {
            return  lhsCommand == rhsCommand && lhsIndex == rhsIndex
        }
        return false
    case let .sticker(lhsSticker, lhsIndex):
        if case let .sticker(rhsSticker, rhsIndex) = rhs {
            return  lhsSticker == rhsSticker && lhsIndex == rhsIndex
        }
        return false
    case let .showPeers(index, stableId):
        if case .showPeers(index, stableId) = rhs {
            return true
        }
        return false
    case let .hashtag(lhsHashtag, lhsIndex):
        if case let .hashtag(rhsHashtag, rhsIndex) = rhs {
            return  lhsHashtag == rhsHashtag && lhsIndex == rhsIndex
        }
        return false
    case let .emoji(lhsClue, lhsFirstWord, lhsIndex):
        if case let .emoji(rhsClue, rhsFirstWord, rhsIndex) = rhs {
            return  lhsClue == rhsClue && lhsIndex == rhsIndex && lhsFirstWord == rhsFirstWord
        }
        return false
    case let .inlineRestricted(lhsText):
        if case let .inlineRestricted(rhsText) = rhs {
            return lhsText == rhsText
        } else {
            return false
        }
    case let .message(index, lhsMessage, searchText):
        if case .message(index, let rhsMessage, searchText) = rhs {
            return isEqualMessages(lhsMessage, rhsMessage)
        } else {
            return false
        }
    }
}

fileprivate func prepareEntries(left:[AppearanceWrapperEntry<InputContextEntry>]?, right:[AppearanceWrapperEntry<InputContextEntry>], context: AccountContext, initialSize:NSSize, chatInteraction:ChatInteraction) -> TableUpdateTransition {
    
    let (removed,inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
    
        switch entry.entry {
        case let .switchPeer(peerId, switchPeer):
            return ContextSwitchPeerRowItem(initialSize, peerId:peerId, switchPeer:switchPeer, account: context.account, callback: {
                chatInteraction.switchInlinePeer(peerId, .start(parameter: switchPeer.startParam, behavior: .automatic))
            })
        case let .peer(peer, _, _):
            var status:String?
            if let user = peer as? TelegramUser, let address = user.addressName {
                status = "@\(address)"
            }
            let titleStyle:ControlStyle = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.text, backgroundColor: theme.colors.background, highlightColor:.white)
            let statusStyle:ControlStyle = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText, backgroundColor: theme.colors.background, highlightColor:.white)
            

            return ShortPeerRowItem(initialSize, peer: peer, account: context.account, height: 40, photoSize: NSMakeSize(30, 30), titleStyle: titleStyle, statusStyle: statusStyle, status: status, borderType: [], drawCustomSeparator: true, inset: NSEdgeInsets(left:20))
        case let .contextResult(results,result,index):
            return ContextListRowItem(initialSize, results, result, index, context, chatInteraction)
        case let .contextMediaResult(results,result,index):
            return ContextMediaRowItem(initialSize, result, index, context, ContextMediaArguments(sendResult: { result, view in
                if let results = results {
                    if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                        showSlowModeTimeoutTooltip(slowMode, for: view)
                    } else {
                        chatInteraction.sendInlineResult(results, result)
                    }
                }
            }))
        case let .command(command,_, stableId):
            return ContextCommandRowItem(initialSize, context.account, command, stableId)
        case let .emoji(clues, firstWord, _):
            return ContextClueRowItem(initialSize, stableId: entry.stableId, context: context, clues: clues, canDisablePrediction: firstWord)
        case let .hashtag(hashtag, _):
            return ContextHashtagRowItem(initialSize, hashtag: "#\(hashtag)")
        case let .sticker(result, stableId):
            return ContextStickerRowItem(initialSize, context, result, stableId, chatInteraction)
        case .showPeers:
            return ContextShowPeersHolderItem(initialSize, stableId: entry.stableId, action: {
                
            })
        case let .inlineRestricted(text):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, height: 40, text: text, alignment: .center, centerViewAlignment: true)
        case let .message(_, message, searchText):
            return ContextSearchMessageItem(initialSize, context: context, message: message, searchText: searchText, action: {
                
            })
        }
        
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated:updated, animated: false, animateVisibleOnly: true)
    
}


class InputContextView : TableView {
    //let tableView:TableView
    let separatorView:View
    weak var relativeView: NSView?
    var position: InputContextPosition = .above {
        didSet {
         //   tableView.setIsFlipped(position == .above)
            needsLayout = true
        }
    }
    
    public override init(frame frameRect: NSRect) {
        // tableView = TableView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        separatorView = View(frame: NSMakeRect(0, 0, frameRect.width, .borderSize))
        super.init(frame: frameRect)
        // addSubview(tableView)
        addSubview(separatorView)
        separatorView.autoresizingMask = [.width, .maxYMargin]
        updateLocalizationAndTheme(theme: theme)

    }
    
    
     override func updateLocalizationAndTheme(theme: PresentationTheme) {
        separatorView.backgroundColor = theme.colors.border
       // backgroundColor = theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layout() {
        super.layout()
        switch position {
        case .above:
            separatorView.setFrameOrigin(0, 0)
        case .below:
            separatorView.frame = NSMakeRect(0, frame.height - separatorView.frame.height, frame.width, .borderSize)
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        //tableView.setFrameSize(newSize)
    }
}

private enum OverscrollState {
    case small
    case intermediate
    case full
}

private final class OverscrollData {
    var state:OverscrollState
    init(state: OverscrollState) {
        self.state = state
    }
}

class InputContextViewController : GenericViewController<InputContextView>, TableViewDelegate {
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let overscrollData: OverscrollData = OverscrollData(state: .small)
    
    fileprivate var markAsNeedShown: Bool = false
    
    private let context:AccountContext
    private let chatInteraction:ChatInteraction
    private let highlightInsteadOfSelect: Bool
    
    private var escapeTextMarked: String?
    
    fileprivate var result:ChatPresentationInputQueryResult?
    
    fileprivate weak var superview: NSView?
    override func loadView() {
        super.loadView()
        genericView.delegate = self
        view.layer?.opacity = 0
    }
    
    init(context: AccountContext, chatInteraction: ChatInteraction, highlightInsteadOfSelect: Bool) {
        self.chatInteraction = chatInteraction
        self.context = context
        self.highlightInsteadOfSelect = highlightInsteadOfSelect
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            let prev = self.deselectSelectedHorizontalItem()
            self.highlightInsteadOfSelect ? self.genericView.highlightNext(true,true) : self.genericView.selectNext(true,true)
            self.selectFirstInRowIfCan(prev, false)
            return .invoked
        }, with: self, for: .DownArrow, priority: .modal)
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            let prev = self.deselectSelectedHorizontalItem()
            self.highlightInsteadOfSelect ? self.genericView.highlightPrev(true,true) : self.genericView.selectPrev(true,true)
            self.selectFirstInRowIfCan(prev, true)
            return .invoked
        }, with: self, for: .UpArrow, priority: .modal)
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                if case .stickers = strongSelf.chatInteraction.presentation.inputContext {
                    strongSelf.selectPreviousSticker()
                    return strongSelf.genericView.selectedItem() != nil ? .invoked : .invokeNext
                } else if case .emoji = strongSelf.chatInteraction.presentation.inputContext {
                     return strongSelf.selectPrevEmojiClue()
                }
            }
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal)
        
        context.window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .UpArrow, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .DownArrow, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                if case .stickers = strongSelf.chatInteraction.presentation.inputContext {
                    strongSelf.selectNextSticker()
                    return strongSelf.genericView.selectedItem() != nil ? .invoked : .invokeNext
                } else if case .emoji = strongSelf.chatInteraction.presentation.inputContext {
                    return strongSelf.selectNextEmojiClue()
                }
            }
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal)
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                if strongSelf.context.isInGlobalSearch {
                    return .rejected
                }
                return strongSelf.invoke()
            }
            return .invokeNext
        }, with: self, for: .Return, priority: .modal)
        
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.invokeTab()
            }
            return .invokeNext
        }, with: self, for: .Tab, priority: .modal)
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            if self?.genericView.selectedItem() != nil {
                _ = self?.deselectSelectedHorizontalItem()
                self?.genericView.cancelSelection()
                self?.escapeTextMarked = self?.chatInteraction.presentation.effectiveInput.inputText
                return .invoked
            }
            return .rejected
        }, with: self, for: .Escape, priority: .modal)
        
        
    }
    
    func invoke() -> KeyHandlerResult {
        if let selectedItem = genericView.highlightedItem() ?? genericView.selectedItem()  {
            if let selectedItem = selectedItem as? ShortPeerRowItem {
                chatInteraction.movePeerToInput(selectedItem.peer)
            } else if let selectedItem = selectedItem as? ContextListRowItem {
                
                if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                    if let view = selectedItem.view {
                        showSlowModeTimeoutTooltip(slowMode, for: view)
                        self.genericView.cancelSelection()
                    }
                } else {
                    chatInteraction.sendInlineResult(selectedItem.results,selectedItem.result)
                }
            } else if let selectedItem = selectedItem as? ContextCommandRowItem {
                if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                    if let view = selectedItem.view {
                        showSlowModeTimeoutTooltip(slowMode, for: view)
                        self.genericView.cancelSelection()
                    }
                } else {
                    chatInteraction.sendCommand(selectedItem.command)
                }
            } else if let selectedItem = selectedItem as? ContextClueRowItem {
                if let clue = selectedItem.selectedIndex != nil ? selectedItem.clues[selectedItem.selectedIndex!] : nil {
                    let textInputState = chatInteraction.presentation.effectiveInput
                    if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                        let inputText = textInputState.inputText
                        
                        let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                        let replacementText = clue
                        
                        let atLength = range.lowerBound > inputText.startIndex && inputText[inputText.index(before: range.lowerBound)] == ":" ? 1 : 0
                        _ = chatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                    }
                } else {
                    return .rejected
                }
            } else if let selectedItem = selectedItem as? ContextHashtagRowItem {
                let textInputState = chatInteraction.presentation.effectiveInput
                if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                    let inputText = textInputState.inputText
                    
                    let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                    let replacementText = selectedItem.hashtag + " "
                    
                    let atLength = 1
                    _ = chatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                }
            } else if let selectedItem = selectedItem as? ContextStickerRowItem, let index = selectedItem.selectedIndex {
                chatInteraction.sendAppFile(selectedItem.result.results[index].file, false)
                chatInteraction.clearInput()
            } else if let selectedItem = selectedItem as? ContextSearchMessageItem {
                chatInteraction.focusMessageId(nil, selectedItem.message.id, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
            }
            return .invoked
        }
        return .rejected
    }
    
    func invokeTab() -> KeyHandlerResult {
        if let selectedItem = genericView.selectedItem() {
            if let selectedItem = selectedItem as? ShortPeerRowItem {
                chatInteraction.movePeerToInput(selectedItem.peer)
            } else if let selectedItem = selectedItem as? ContextCommandRowItem {
                let commandText = "/" + selectedItem.command.command.text + " "
                chatInteraction.updateInput(with: commandText)

            } else if let selectedItem = selectedItem as? ContextClueRowItem {
                let clue: String?
                if let index = selectedItem.selectedIndex {
                    clue = selectedItem.clues[index]
                } else {
                    clue = selectedItem.clues.first
                }
                if let clue = clue {
                    let textInputState = chatInteraction.presentation.effectiveInput
                    if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                        let inputText = textInputState.inputText
                        
                        let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                        let replacementText = clue
                        
                        let atLength = range.lowerBound > inputText.startIndex && inputText[inputText.index(before: range.lowerBound)] == ":" ? 1 : 0
                        _ = chatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                    }
                }
                return .invoked
            } else if let selectedItem = selectedItem as? ContextHashtagRowItem {
                let textInputState = chatInteraction.presentation.effectiveInput
                if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                    let inputText = textInputState.inputText
                    
                    let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                    let replacementText = selectedItem.hashtag + " "
                    
                    let atLength = 1
                    _ = chatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                }
            }
            return .invoked
        }
        return .invokeNext
    }
    
    func deselectSelectedHorizontalItem() -> Int? {
        var prev:Int? = nil
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            prev = selectedItem.selectedIndex
            selectedItem.selectedIndex = nil
            selectedItem.redraw(animated: true)
        }
        if let selectedItem = genericView.selectedItem() as? ContextClueRowItem {
            prev = selectedItem.selectedIndex
            selectedItem.selectedIndex = nil
            selectedItem.redraw(animated: true)
        }
        return prev
    }
    
    func selectNextEmojiClue() -> KeyHandlerResult {
        if let selectedItem = genericView.selectedItem() as? ContextClueRowItem {
            if let selectedIndex = selectedItem.selectedIndex {
                var index = selectedIndex
                index += 1
                selectedItem.selectedIndex = max(min(index, selectedItem.clues.count - 1), 0)
                selectedItem.redraw(animated: true)
            }
            
            return selectedItem.selectedIndex != nil ? .invoked : .rejected
        }
        return .rejected

    }
    func selectPrevEmojiClue() -> KeyHandlerResult {
        if let selectedItem = genericView.selectedItem() as? ContextClueRowItem {
            if let selectedIndex = selectedItem.selectedIndex {
                var index = selectedIndex
                index -= 1
                selectedItem.selectedIndex = max(min(index, selectedItem.clues.count - 1), 0)
                selectedItem.redraw(animated: true)
            }
            return selectedItem.selectedIndex != nil ? .invoked : .rejected
        }
        return .rejected
    }
    
    func selectPreviousSticker() {
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            if selectedItem.selectedIndex != nil {
                selectedItem.selectedIndex! -= 1
            } else {
                selectedItem.selectedIndex = selectedItem.result.entries.count - 1
                selectedItem.redraw()
            }
            
            if selectedItem.selectedIndex! < 0 {
                _ = deselectSelectedHorizontalItem()
                genericView.selectPrev(true,true)
                selectLastInRowIfCan()
            } else {
                selectedItem.redraw()
            }
        }
    }
    
    func selectNextSticker() {
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            if selectedItem.selectedIndex != nil {
                selectedItem.selectedIndex! += 1
            } else {
                selectFirstInRowIfCan()
                return
            }
            
            if selectedItem.selectedIndex! > selectedItem.result.entries.count - 1 {
                _ = deselectSelectedHorizontalItem()
                genericView.selectNext(true,true)
                selectFirstInRowIfCan()
            } else {
                selectedItem.redraw()
            }
        }
    }
    
    func selectFirstInRowIfCan(_ start:Int? = nil, _ bottom: Bool = false) {
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            var index = start ?? 0
            index = max(index, 0)
            selectedItem.selectedIndex = index
            selectedItem.redraw()
        }
        if let selectedItem = genericView.selectedItem() as? ContextClueRowItem {
            var index: Int
            if let start = start {
                index = start + (bottom ? -1 : 1)
            } else {
                index = bottom ? selectedItem.clues.count - 1 : 0
            }
            index = min(max(index, 0), selectedItem.clues.count - 1)
            selectedItem.selectedIndex = index
            selectedItem.redraw(animated: true)
        }
    }
    
    func selectLastInRowIfCan(_ start:Int? = nil) {
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            var index = start ?? selectedItem.result.entries.count - 1
            index = min(index, selectedItem.result.entries.count - 1)
            selectedItem.selectedIndex = index
            selectedItem.redraw(animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanup()
    }
    
    func cleanup() {
        mainWindow.removeAllHandlers(for: self)
    }
    
    deinit {
        cleanup()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        if byClick {
            _ = invoke()
        }
    }
    func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return !(item is ContextMediaRowItem)
    }
    
    func make(with transition:TableUpdateTransition, animated:Bool, selectIndex: Int?, result: ChatPresentationInputQueryResult? = nil) {
        assertOnMainThread()
        genericView.cancelSelection()
        genericView.cancelHighlight()
        genericView.merge(with: transition)
        layout(animated)
        if !genericView.isEmpty, let result = result {
            
            if let escapeTextMarked = escapeTextMarked, escapeTextMarked == self.chatInteraction.presentation.effectiveInput.inputText {
                return
            } else {
                escapeTextMarked = nil
            }
            switch result {
            case .mentions, .searchMessages:
                if !highlightInsteadOfSelect {
                    _ = genericView.select(item: genericView.item(at: selectIndex ?? 0))
                } else {
                    _ = genericView.highlight(item: genericView.item(at: selectIndex ?? 0))
                }
            case let .emoji(_, firstWord):
                if !highlightInsteadOfSelect {
                    _ = genericView.select(item: genericView.item(at: selectIndex ?? 0))
                } else {
                    _ = genericView.highlight(item: genericView.item(at: selectIndex ?? 0))
                }
                if !firstWord {
                    _ = selectFirstInRowIfCan()
                }
            default:
                break
            }
            if let selectIndex = selectIndex {
                _ = genericView.select(item: genericView.item(at: selectIndex))
                genericView.scroll(to: .center(id: genericView.item(at: selectIndex).stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: 0))
            }
        }
    }
    
    func layout(_ animated:Bool) {
        if let superview = superview, let relativeView = genericView.relativeView {
            var height = min(superview.frame.height - 50 - relativeView.frame.height, floor(superview.frame.height / 3))
            if genericView.firstItem is ContextClueRowItem {
                height = min(height, 120)
            }
            let future = NSMakeSize(frame.width, min(genericView.listHeight, height))
            //  genericView.change(size: future, animated: animated)
            //  genericView.change(pos: NSMakePoint(0, 0), animated: animated)
            CATransaction.begin()
            genericView.change(size: future, animated: animated, duration: future.height > frame.height || genericView.position == .below ? 0 : 0.5)
            
            switch genericView.position {
            case .above:
                genericView.separatorView.change(pos: NSZeroPoint, animated: animated)
            case .below:
                genericView.separatorView.change(pos: NSMakePoint(0, frame.height - genericView.separatorView.frame.height), animated: animated)
            }
            
//            let y = genericView.position == .above ? relativeView.frame.minY - frame.height : relativeView.frame.maxY
//            genericView.change(pos: NSMakePoint(0, y), animated: animated)
            
            CATransaction.commit()
        }
        
    }

    
}

enum InputContextPosition {
    case above
    case below
}

class InputContextHelper: NSObject {
    
    private let disposable:MetaDisposable = MetaDisposable()

    let controller:InputContextViewController
    private let context:AccountContext
    private let chatInteraction:ChatInteraction
    private let entries:Atomic<[AppearanceWrapperEntry<InputContextEntry>]?> = Atomic(value:nil)
    private let loadMoreDisposable = MetaDisposable()
    init(chatInteraction:ChatInteraction, highlightInsteadOfSelect: Bool = false) {
        self.chatInteraction = chatInteraction
        self.context = chatInteraction.context
        controller = InputContextViewController(context: chatInteraction.context, chatInteraction: chatInteraction, highlightInsteadOfSelect: highlightInsteadOfSelect)
    }

    public var accessoryView:NSView? {
        return controller.isLoaded() && controller.view.superview != nil ? controller.view : nil
    }
    
    func viewWillRemove() {
        self.controller.viewWillDisappear(false)
    }
    
    func context(with result:ChatPresentationInputQueryResult?, for view: NSView, relativeView: NSView, position: InputContextPosition = .above, selectIndex:Int? = nil, animated:Bool) {
        controller._frameRect = NSMakeRect(0, 0, view.frame.width, floor(view.frame.height / 3))
        controller.loadViewIfNeeded()
        controller.superview = view
        controller.genericView.relativeView = relativeView
        controller.genericView.position = position
        controller.updateLocalizationAndTheme(theme: theme)
        var currentResult = result
        
        let initialSize = controller.atomicSize
        let previosEntries = self.entries
        let context = self.chatInteraction.context
        let chatInteraction = self.chatInteraction
        
        let entriesValue: Promise<[InputContextEntry]> = Promise()
        
        self.loadMoreDisposable.set(nil)
        
        controller.genericView.setScrollHandler { [weak self] position in
            guard let `self` = self, let result = currentResult else {return}
            switch position.direction {
            case .bottom:
                switch result {
                case let .searchMessages(messages, _, _):
                    messages.2(messages.1)
                case let .contextRequestResult(peer, oldCollection):
                    if let oldCollection = oldCollection, let nextOffset = oldCollection.nextOffset {
                        self.loadMoreDisposable.set((requestChatContextResults(account: context.account, botId: oldCollection.botId, peerId: self.chatInteraction.peerId, query: oldCollection.query, offset: nextOffset) |> delay(0.5, queue: Queue.mainQueue())).start(next: { [weak self] collection in
                            guard let `self` = self else {return}
                            
                            if let collection = collection {
                                let newResult = ChatPresentationInputQueryResult.contextRequestResult(peer, oldCollection.withAdditionalCollection(collection))
                                currentResult = newResult
                                entriesValue.set(self.entries(for: newResult, initialSize: initialSize.modify {$0}, chatInteraction: chatInteraction))
                            }
                        }))
                    }
                default:
                    break
                }
            default:
                break
            }
        }
        
        entriesValue.set(entries(for: result, initialSize: initialSize.modify {$0}, chatInteraction: chatInteraction))
        
        let makeSignal = combineLatest(entriesValue.get(), appearanceSignal) |> map { entries, appearance -> (TableUpdateTransition,Bool, Bool) in
            let entries = entries.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            let previous = previosEntries.swap(entries)
            let previousIsEmpty:Bool = previous?.isEmpty ?? true
            return (prepareEntries(left: previous, right: entries, context: context, initialSize: initialSize.modify({$0}), chatInteraction:chatInteraction),!entries.isEmpty, previousIsEmpty)
        } |> deliverOnMainQueue
        
        disposable.set((makeSignal |> map { [weak self, weak view, weak relativeView] transition, show, previousIsEmpty in
        
            if show, let controller = self?.controller, let relativeView = relativeView {
                if previousIsEmpty {
                    controller.genericView.removeAll()
                }
                controller.make(with: transition, animated:animated, selectIndex: selectIndex, result: result)

                if let view = view {
                    controller.markAsNeedShown = true
                    controller.viewWillAppear(animated)
                    if controller.view.superview == nil {
                        view.addSubview(controller.view, positioned: .below, relativeTo: relativeView)
                        controller.view.layer?.opacity = 0
                        controller.view.setFrameOrigin(0, relativeView.frame.minY)
                    }
                    controller.viewDidAppear(animated)
                    controller.genericView.isHidden = false
                    controller.genericView.change(opacity: 1, animated: animated)
                    let y = position == .above ? relativeView.frame.minY - controller.frame.height : relativeView.frame.maxY
                    if y != controller.genericView.frame.minY {
                        controller.genericView._change(pos: NSMakePoint(0, y), animated: animated, duration: 0.4, timingFunction: CAMediaTimingFunctionName.spring, forceAnimateIfHasAnimation: true)
                    }
                }
                
            } else if let controller = self?.controller, let relativeView = relativeView {
                var controller:InputContextViewController? = controller
                controller?.viewWillDisappear(animated)
                controller?.markAsNeedShown = false
                if animated {
                    controller?.genericView._change(pos: NSMakePoint(0, relativeView.frame.minY), animated: animated, removeOnCompletion: false, duration: 0.4, timingFunction: CAMediaTimingFunctionName.spring, forceAnimateIfHasAnimation: true, completion: { completed in
                        if controller?.markAsNeedShown == false {
                            controller?.removeFromSuperview()
                            controller?.genericView.removeAll()
                            controller?.viewDidDisappear(animated)
                            controller?.genericView.cancelSelection()
                        }
                        controller = nil
                    })

                    controller?.genericView.change(opacity: 0, animated: true)
                } else {
                    controller?.removeFromSuperview()
                    controller?.viewDidDisappear(animated)
                    controller?.genericView.cancelSelection()
                }
            }
    
        }).start())
    
    }
    
    func entries(for result:ChatPresentationInputQueryResult?, initialSize:NSSize, chatInteraction: ChatInteraction) -> Signal<[InputContextEntry], NoError> {
        if let result = result {
            return Signal { subscriber in
                var entries:[InputContextEntry] = []
                switch result {
                case let .mentions(peers):
                    var mention:[PeerId: PeerId] = [:]
                    for i in 0 ..< peers.count {
                        if mention[peers[i].id] == nil {
                            entries.append(.peer(peers[i],entries.count, Int64(arc4random())))
                            mention[peers[i].id] = peers[i].id
                        }
                    }
                case let .contextRequestResult(_, result):
                    
                    if let peer = chatInteraction.presentation.peer {
                        if let text = permissionText(from: peer, for: .banSendInline) {
                            entries.append(.inlineRestricted(text))
                            break
                        }
                    }
                    
                    if let result = result {
                        
                        if let switchPeer = result.switchPeer {
                            entries.append(.switchPeer(result.botId, switchPeer))
                        }
                        
                        switch result.presentation {
                        case .list:
                            for i in 0 ..< result.results.count {
                                entries.append(.contextResult(result,result.results[i],Int64(arc4random()) | ((Int64(entries.count) << 40))))
                            }
                        case .media:
                            
                            let mediaRows = makeMediaEnties(result.results, isSavedGifs: false, initialSize:NSMakeSize(initialSize.width, 100))
                            
                            for i in 0 ..< mediaRows.count {
                                entries.append(.contextMediaResult(result, mediaRows[i], Int64(arc4random()) | ((Int64(entries.count) << 40))))
                            }
                            
                        }
                    }
                case let .commands(commands):
                    var index:Int64 = 1000
                    for i in 0 ..< commands.count {
                        entries.append(.command(commands[i], index, Int64(arc4random()) | ((Int64(commands.count) << 40))))
                        index += 1
                    }
                case .hashtags(let hashtags):
                    var index:Int64 = 2000
                    for i in 0 ..< hashtags.count {
                        entries.append(.hashtag(hashtags[i], index))
                        index += 1
                    }
                case let .stickers(stickers):
                    
                    if let peer = chatInteraction.presentation.peer {
                        if let text = permissionText(from: peer, for: .banSendStickers) {
                            entries.append(.inlineRestricted(text))
                            break
                        }
                    }
                    
                    let mediaRows = makeStickerEntries(stickers, initialSize:NSMakeSize(initialSize.width, 100))
                    
                    for i in 0 ..< mediaRows.count {
                        entries.append(.sticker(mediaRows[i], Int64(arc4random()) | ((Int64(entries.count) << 40))))
                    }
                    
                case let .emoji(clues, firstWord):
                    var index:Int32 = 0
                    if !clues.isEmpty {
                        entries.append(.emoji(clues, firstWord, index))
                        index += 1
                    }
                   
                case let .searchMessages(messages, suggestPeers, searchText):
                    var index: Int64 = 0
                    
                    
                    let count:Int = min(max(6 - messages.0.count, 1), suggestPeers.count)
                    for i in 0 ..< count {
                        let peer = suggestPeers[i]
                        entries.append(.peer(peer, Int(index), arc4random64()))
                        index += 1
                    }
                    
                   
//                    if suggestPeers.count > 1, messages.0.count > 0 {
//                        entries.append(.showPeers(Int(index), arc4random64()))
//                        index += 1
//                    }
                    
                    for message in messages.0 {
                        entries.append(.message(index, message, searchText))
                        index += 1
                    }
                }
                entries.sort(by: <)
                subscriber.putNext(entries)
                subscriber.putCompletion()
                
                return EmptyDisposable
            } |> runOn(prepareQueue)
        }
        return .single([])
    }
    
    deinit {
        disposable.dispose()
        loadMoreDisposable.dispose()
    }
    
}

