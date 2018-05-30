//
//  InputContextHelper.swift
//  Telegram-Mac
//
//  Created by keepcoder on 31/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TGUIKit
import PostboxMac
import TelegramCoreMac




enum InputContextEntry : Comparable, Identifiable {
    case switchPeer(PeerId, ChatContextResultSwitchPeer)
    case peer(Peer, Int, Int64)
    case contextResult(ChatContextResultCollection,ChatContextResult,Int64)
    case contextMediaResult(ChatContextResultCollection?, InputMediaContextRow, Int64)
    case command(PeerCommand, Int64, Int64)
    case sticker(InputMediaStickersRow, Int64)
    case emoji(EmojiClue, Int32)
    case hashtag(String, Int64)
    case inlineRestricted(String?)
    var stableId: Int64 {
        switch self {
        case .switchPeer:
            return -1
        case let .peer(_,_, stableId):
            return stableId
        case let .contextResult(_,_,index):
            return index
        case let .contextMediaResult(_,_,index):
            return index
        case let .command( _, _, stableId):
            return stableId
        case let .sticker( _, stableId):
            return stableId
        case let .hashtag(hashtag, _):
            return Int64(hashtag.hashValue)
        case let .emoji(clue, _):
            return clue.hashValue
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
        case let .hashtag(_, index):
            return index
        case let .emoji(_, index):
            return Int64(index) //result.maybeId | ((Int64(index) << 40))
        case .inlineRestricted:
            return 0
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
    case let .hashtag(lhsHashtag, lhsIndex):
        if case let .hashtag(rhsHashtag, rhsIndex) = rhs {
            return  lhsHashtag == rhsHashtag && lhsIndex == rhsIndex
        }
        return false
    case let .emoji(lhsClue, lhsIndex):
        if case let .emoji(rhsClue, rhsIndex) = rhs {
            return  lhsClue == rhsClue && lhsIndex == rhsIndex
        }
        return false
    case let .inlineRestricted(lhsText):
        if case let .inlineRestricted(rhsText) = rhs {
            return lhsText == rhsText
        } else {
            return false
        }
    }
}

fileprivate func prepareEntries(left:[AppearanceWrapperEntry<InputContextEntry>]?, right:[AppearanceWrapperEntry<InputContextEntry>], account:Account,initialSize:NSSize, chatInteraction:ChatInteraction) -> TableUpdateTransition {
    
    let (removed,inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
    
        switch entry.entry {
        case let .switchPeer(peerId, switchPeer):
            return ContextSwitchPeerRowItem(initialSize, peerId:peerId, switchPeer:switchPeer, account:account, callback: {
                chatInteraction.switchInlinePeer(peerId, .start(parameter: switchPeer.startParam, behavior: .automatic))
            })
        case let .peer(peer, _, _):
            var status:String?
            if let user = peer as? TelegramUser, let address = user.addressName {
                status = "@\(address)"
            }
            let titleStyle:ControlStyle = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.text, backgroundColor: theme.colors.background, highlightColor:.white)
            let statusStyle:ControlStyle = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText, backgroundColor: theme.colors.background, highlightColor:.white)
            

            return ShortPeerRowItem(initialSize, peer: peer, account: account, height: 40, photoSize: NSMakeSize(30, 30), titleStyle: titleStyle, statusStyle: statusStyle, status: status, borderType: [], drawCustomSeparator: true, inset: NSEdgeInsets(left:20))
        case let .contextResult(results,result,index):
            return ContextListRowItem(initialSize, results, result, index, account, chatInteraction)
        case let .contextMediaResult(results,result,index):
            return ContextMediaRowItem(initialSize, result, index, account, ContextMediaArguments(sendResult: { result in
                if let results = results {
                    chatInteraction.sendInlineResult(results, result)
                }
            }))
        case let .command(command,_, stableId):
            return ContextCommandRowItem(initialSize, account, command, stableId)
        case let .emoji(clue, _):
            return ContextClueRowItem(initialSize, stableId: entry.stableId, clue: clue)
        case let .hashtag(hashtag, _):
            return ContextHashtagRowItem(initialSize, hashtag: "#\(hashtag)")
        case let .sticker(result, stableId):
            return ContextStickerRowItem(initialSize, account, result, stableId, chatInteraction)
        case .inlineRestricted(let until):
            let text = until != nil ? tr(L10n.channelPersmissionDeniedSendInlineUntil(until!)) : tr(L10n.channelPersmissionDeniedSendInlineForever)
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, height: 40, text: text, alignment: .center, centerViewAlignment: true)
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
    
    public required init(frame frameRect: NSRect, isFlipped: Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {
        // tableView = TableView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        separatorView = View(frame: NSMakeRect(0, 0, frameRect.width, .borderSize))
        super.init(frame: frameRect)
        // addSubview(tableView)
        addSubview(separatorView)
        separatorView.autoresizingMask = [.width, .maxYMargin]
        updateLocalizationAndTheme()

    }
    
    
     override func updateLocalizationAndTheme() {
        separatorView.backgroundColor = theme.colors.border
        //backgroundColor = theme.colors.background
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
            separatorView.setFrameOrigin(NSMakePoint(0, frame.height - separatorView.frame.height))
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        //tableView.setFrameSize(newSize)
    }
}

class InputContextViewController : GenericViewController<InputContextView>, TableViewDelegate {
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let account:Account
    private let chatInteraction:ChatInteraction
    fileprivate weak var superview: NSView?
    override func loadView() {
        super.loadView()
        genericView.delegate = self
        view.layer?.opacity = 0
    }
    
    init(account:Account,chatInteraction:ChatInteraction) {
        self.account = account
        self.chatInteraction = chatInteraction
        super.init()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        mainWindow.set(handler: {[weak self] () -> KeyHandlerResult in
            let prev = self?.deselectSelectedSticker()
            self?.genericView.selectNext(true,true)
            self?.selectFirstInRowIfCan(prev)
            return .invoked
        }, with: self, for: .DownArrow, priority: .high)
        
        mainWindow.set(handler: {[weak self] () -> KeyHandlerResult in
            let prev = self?.deselectSelectedSticker()
            self?.genericView.selectPrev(true,true)
            self?.selectFirstInRowIfCan(prev)
            return .invoked
        }, with: self, for: .UpArrow, priority: .high)
        
        mainWindow.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                if case .stickers = strongSelf.chatInteraction.presentation.inputContext {
                    strongSelf.selectPreviousSticker()
                    return strongSelf.genericView.selectedItem() != nil ? .invoked : .invokeNext
                }
            }
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .high)
        
        mainWindow.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                if case .stickers = strongSelf.chatInteraction.presentation.inputContext {
                    strongSelf.selectNextSticker()
                    return strongSelf.genericView.selectedItem() != nil ? .invoked : .invokeNext
                }
            }
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .high)
        
        mainWindow.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.invoke()
            }
            return .invokeNext
        }, with: self, for: .Return, priority: .high)
        
        
        mainWindow.set(handler: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.invokeTab()
            }
            return .invokeNext
        }, with: self, for: .Tab, priority: .high)
        
        mainWindow.set(handler: {[weak self] () -> KeyHandlerResult in
            if self?.genericView.selectedItem() != nil {
                _ = self?.deselectSelectedSticker()
                self?.genericView.cancelSelection()
                return .invoked
            }
            return .rejected
        }, with: self, for: .Escape, priority: .modal)
    }
    
    func invoke() -> KeyHandlerResult {
        if let selectedItem = genericView.selectedItem() {
            if let selectedItem = selectedItem as? ShortPeerRowItem {
                chatInteraction.movePeerToInput(selectedItem.peer)
            } else if let selectedItem = selectedItem as? ContextListRowItem {
                chatInteraction.sendInlineResult(selectedItem.results,selectedItem.result)
            } else if let selectedItem = selectedItem as? ContextCommandRowItem {
                chatInteraction.sendCommand(selectedItem.command)
            } else if let selectedItem = selectedItem as? ContextClueRowItem {
                let clue = selectedItem.clue
                
                let textInputState = chatInteraction.presentation.effectiveInput
                if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                    let inputText = textInputState.inputText
                    
                    let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                    let replacementText = clue.emoji
                    
                    let atLength = 1
                    _ = chatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
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
                chatInteraction.sendAppFile(selectedItem.result.results[index].file)
                chatInteraction.clearInput()
            }
            return .invoked
        }
        return .invokeNext
    }
    
    func invokeTab() -> KeyHandlerResult {
        if let selectedItem = genericView.selectedItem() {
            if let selectedItem = selectedItem as? ShortPeerRowItem {
                chatInteraction.movePeerToInput(selectedItem.peer)
            } else if let selectedItem = selectedItem as? ContextCommandRowItem {
                let commandText = "/" + selectedItem.command.command.text + " "
                chatInteraction.updateInput(with: commandText)

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
    
    func deselectSelectedSticker() -> Int? {
        var prev:Int? = nil
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            prev = selectedItem.selectedIndex
            selectedItem.selectedIndex = nil
            selectedItem.redraw()
        }
        return prev
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
                _ = deselectSelectedSticker()
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
                _ = deselectSelectedSticker()
                genericView.selectNext(true,true)
                selectFirstInRowIfCan()
            } else {
                selectedItem.redraw()
            }
        }
    }
    
    func selectFirstInRowIfCan(_ start:Int? = nil) {
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            var index = start ?? 0
            index = max(index, 0)
            selectedItem.selectedIndex = index
            selectedItem.redraw()
        }
    }
    
    func selectLastInRowIfCan(_ start:Int? = nil) {
        if let selectedItem = genericView.selectedItem() as? ContextStickerRowItem {
            var index = start ?? selectedItem.result.entries.count - 1
            index = min(index, selectedItem.result.entries.count - 1)
            selectedItem.selectedIndex = index
            selectedItem.redraw()
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
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return !(item is ContextMediaRowItem)
    }
    
    func make(with transition:TableUpdateTransition, animated:Bool, result: ChatPresentationInputQueryResult? = nil) {
        assertOnMainThread()
        genericView.cancelSelection()
        genericView.merge(with: transition)
        layout(animated)
        if !genericView.isEmpty, let result = result, case .mentions = result {
            _ = genericView.select(item: genericView.item(at: 0))
        }
    }
    
    func layout(_ animated:Bool) {
        if let superview = superview, let relativeView = genericView.relativeView {
            let future = NSMakeSize(frame.width, min(genericView.listHeight,min(superview.frame.height - 50 - relativeView.frame.height, floor(superview.frame.height / 2))))
            //  genericView.change(size: future, animated: animated)
            //  genericView.change(pos: NSMakePoint(0, 0), animated: animated)
            
            genericView.change(size: future, animated: animated)
            
            switch genericView.position {
            case .above:
                genericView.separatorView.change(pos: NSZeroPoint, animated: true)
            case .below:
                genericView.separatorView.change(pos: NSMakePoint(0, frame.height - genericView.separatorView.frame.height), animated: true)
            }
            
            let y = genericView.position == .above ? relativeView.frame.minY - frame.height : relativeView.frame.maxY
            genericView.change(pos: NSMakePoint(0, y), animated: animated)
        }
        
    }

    
}

enum InputContextPosition {
    case above
    case below
}

class InputContextHelper: NSObject {
    
    var disposable:MetaDisposable = MetaDisposable()

    private var controller:InputContextViewController
    private let account:Account
    private let chatInteraction:ChatInteraction
    private let entries:Atomic<[AppearanceWrapperEntry<InputContextEntry>]?> = Atomic(value:nil)
    
    init(account:Account, chatInteraction:ChatInteraction) {
        self.account = account
        self.chatInteraction = chatInteraction
        controller = InputContextViewController(account:account,chatInteraction:chatInteraction)
    }

    public var accessoryView:NSView? {
        return controller.isLoaded() && controller.view.superview != nil ? controller.view : nil
    }
    
    func viewWillRemove() {
        self.controller.viewWillDisappear(false)
    }
    
    func context(with result:ChatPresentationInputQueryResult?, for view: NSView, relativeView: NSView, position: InputContextPosition = .above, animated:Bool) {
        
        controller._frameRect = NSMakeRect(0, 0, view.frame.width, floor(view.frame.height / 2))
        controller.loadViewIfNeeded()
        controller.superview = view
        controller.genericView.relativeView = relativeView
        controller.genericView.position = position
        let initialSize = controller.atomicSize
        let previosEntries = self.entries
        let account = self.account
        let chatInteraction = self.chatInteraction
        
        let makeSignal = combineLatest(entries(for: result, initialSize:initialSize.modify {$0}, chatInteraction: chatInteraction), appearanceSignal) |> map { entries, appearance -> (TableUpdateTransition,Bool, Bool) in
            let entries = entries.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            let previous = previosEntries.swap(entries)
            let previousIsEmpty:Bool = previous?.isEmpty ?? true
            return (prepareEntries(left: previous, right: entries, account: account, initialSize: initialSize.modify({$0}), chatInteraction:chatInteraction),!entries.isEmpty, previousIsEmpty)
        } |> deliverOnMainQueue
        
        disposable.set(makeSignal.start(next: { [weak self, weak view, weak relativeView] transition, show, previousIsEmpty in
        
            if show, let controller = self?.controller, let relativeView = relativeView {
                if previousIsEmpty {
                    controller.genericView.removeAll()
                }
                controller.make(with: transition, animated:animated, result: result)

                if let view = view {
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
                    controller.genericView.change(pos: NSMakePoint(0, y), animated: animated, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)

                }
                
            } else if let controller = self?.controller, let relativeView = relativeView {
                controller.viewWillDisappear(animated)
                if animated {
                    controller.genericView.change(pos: NSMakePoint(0, relativeView.frame.minY), animated: animated, removeOnCompletion: false, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak controller] completed in
                        
                        if completed {
                            controller?.removeFromSuperview()
                            controller?.genericView.removeAll()
                            controller?.viewDidDisappear(animated)
                            controller?.genericView.cancelSelection()
                        } 
                        
                    })

                    controller.genericView.change(opacity: 0, animated: true)
                } else {
                    controller.removeFromSuperview()
                    controller.viewDidDisappear(animated)
                    controller.genericView.cancelSelection()
                }
            }
    
        }))
    
    }
    
    func entries(for result:ChatPresentationInputQueryResult?, initialSize:NSSize, chatInteraction: ChatInteraction) -> Signal<[InputContextEntry],Void> {
        if let result = result {
            return Signal {(subscriber) in
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
                    
                    if let peer = chatInteraction.presentation.peer as? TelegramChannel {
                        if peer.inlineRestricted, let bannedRights = peer.bannedRights {
                            entries.append(.inlineRestricted(bannedRights.untilDate == .max ? nil : bannedRights.formattedUntilDate))
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
                            
                            let mediaRows = makeMediaEnties(result.results, initialSize:NSMakeSize(initialSize.width, 100))
                            
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
                    
                    if let peer = chatInteraction.presentation.peer as? TelegramChannel {
                        if peer.stickersRestricted {
                            break
                        }
                    }
                    
                    let mediaRows = makeStickerEntries(stickers, initialSize:NSMakeSize(initialSize.width, 100))
                    
                    for i in 0 ..< mediaRows.count {
                        entries.append(.sticker(mediaRows[i], Int64(arc4random()) | ((Int64(entries.count) << 40))))
                    }
                    
                    break
                case let .emoji(clues):
                    var index:Int32 = 0
                    for clue in clues {
                        entries.append(.emoji(clue, index))
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
    }
    
}

