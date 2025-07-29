//
//  ChatSearchHeader.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30.01.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import SwiftSignalKit
import Postbox

private final class CSearchContextState : Equatable {
    let inputQueryResult: ChatPresentationInputQueryResult?
    let tokenState: TokenSearchState
    let peerId:PeerId?
    let messages: ([Message], SearchMessagesState?)
    let selectedIndex: Int
    let searchState: SearchState
    
    init(inputQueryResult: ChatPresentationInputQueryResult? = nil, messages: ([Message], SearchMessagesState?) = ([], nil), selectedIndex: Int = -1, searchState: SearchState = SearchState(state: .None, request: ""), tokenState: TokenSearchState = .none, peerId: PeerId? = nil) {
        self.inputQueryResult = inputQueryResult
        self.tokenState = tokenState
        self.peerId = peerId
        self.messages = messages
        self.selectedIndex = selectedIndex
        self.searchState = searchState
    }
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: f(self.inputQueryResult), messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedTokenState(_ token: TokenSearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: token, peerId: self.peerId)
    }
    func updatedPeerId(_ peerId: PeerId?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: peerId)
    }
    func updatedMessages(_ messages: ([Message], SearchMessagesState?)) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedSelectedIndex(_ selectedIndex: Int) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedSearchState(_ searchState: SearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
}

private func ==(lhs: CSearchContextState, rhs: CSearchContextState) -> Bool {
    if lhs.messages.0.count != rhs.messages.0.count {
        return false
    } else {
        for i in 0 ..< lhs.messages.0.count {
            if !isEqualMessages(lhs.messages.0[i], rhs.messages.0[i]) {
                return false
            }
        }
    }
    return lhs.inputQueryResult == rhs.inputQueryResult && lhs.tokenState == rhs.tokenState && lhs.selectedIndex == rhs.selectedIndex && lhs.searchState == rhs.searchState && lhs.messages.1 == rhs.messages.1
}

private final class CSearchInteraction : InterfaceObserver {
    private(set) var state: CSearchContextState = CSearchContextState()
    
    func update(animated:Bool = true, _ f:(CSearchContextState)->CSearchContextState) -> Void {
        let oldValue = self.state
        self.state = f(state)
        if oldValue != state {
            notifyObservers(value: state, oldValue:oldValue, animated: animated)
        }
    }
    
    var currentMessage: Message? {
        if state.messages.0.isEmpty {
            return nil
        } else if state.messages.0.count <= state.selectedIndex || state.selectedIndex < 0 {
            return nil
        }
        return state.messages.0[state.selectedIndex]
    }
}

struct SearchStateQuery : Equatable {
    let query: String?
    let state: SearchMessagesState?
    init(_ query: String?, _ state: SearchMessagesState?) {
        self.query = query
        self.state = state
    }
}

struct SearchMessagesResultState : Equatable {
    static func == (lhs: SearchMessagesResultState, rhs: SearchMessagesResultState) -> Bool {
        if lhs.query != rhs.query {
            return false
        }
        if lhs.messages.count != rhs.messages.count {
            return false
        } else {
            for i in 0 ..< lhs.messages.count {
                if !isEqualMessages(lhs.messages[i], rhs.messages[i]) {
                    return false
                }
            }
        }
        return true
    }
    
    let query: String
    let messages: [Message]
    init(_ query: String, _ messages: [Message]) {
        self.query = query
        self.messages = messages
    }
    
    func containsMessage(_ message: Message) -> Bool {
        return self.messages.contains(where: { $0.id == message.id })
    }
}


private final class ChatSearchTagsView: View {
    
    class Arguments {
        let context: AccountContext
        let callback: (EmojiTag?)->Void
        init(context: AccountContext, callback: @escaping(EmojiTag?)->Void) {
            self.context = context
            self.callback = callback
        }
    }
    
    class Item : TableRowItem {
        
        class View : HorizontalRowView {
            
            final class TagView: Control {
                fileprivate private(set) var item: Item?
                fileprivate let imageView: AnimationLayerContainer = AnimationLayerContainer(frame: NSMakeRect(0, 0, 16, 16))
                private let backgroundView: NinePathImage = NinePathImage()
                private var textView: TextView?
                private var countView: TextView? = nil
                required init(frame frameRect: NSRect) {
                    super.init(frame: frameRect)
                    
                    self.backgroundColor = .clear
                    self.backgroundView.capInsets = NSEdgeInsets(top: 3, left: 5, bottom: 3, right: 15)

                    
                    addSubview(backgroundView)
                    addSubview(imageView)

                    scaleOnClick = true
                    
                    self.set(handler: { [weak self] _ in
                        if let item = self?.item {
                            item.arguments.callback(item.tag)
                        }
                    }, for: .Click)
                    
                    self.contextMenu = { [weak self] in
                        
                        if let item = self?.item {
                            let menu = ContextMenu()
                            let context = item.arguments.context

                            menu.addItem(ContextMenuItem(item.tag.tag.title != nil ? strings().chatReactionContextEditTag : strings().chatReactionContextAddLabel, handler: {
                                showModal(with: EditTagLabelController(context: context, reaction: item.tag.tag.reaction, label: item.tag.tag.title), for: context.window)
                            }, itemImage: MenuAnimation.menu_tag_rename.value))
                            
                            return menu
                        }
                        
                        return nil
                    }
                    

                }
                
                func update(with item: Item, selected: Bool, animated: Bool) {
                    self.item = item
                    
                    self.isEnabled = item.enabled
                    
                    self.change(opacity: item.enabled ? 1.0 : 0.8, animated: animated)
                                        
                    let image = NSImage(named: "Icon_SavedMessages_Premium_Tag")!
                    let background = NSImage(cgImage: generateTintedImage(image: image._cgImage, color: selected ? theme.colors.accent : theme.colors.grayBackground)!, size: image.size)
                    
                    self.backgroundView.image = background
                    
                    let layer: InlineStickerItemLayer = .init(account: item.arguments.context.account, file: item.tag.file, size: NSMakeSize(16, 16), playPolicy: .framesCount(1))
                    imageView.updateLayer(layer, isLite: isLite(.emoji), animated: animated)
                    
                    if let layout = item.countViewLayout {
                        let current: TextView
                        if let view = self.countView {
                            current = view
                        } else {
                            current = TextView()
                            current.userInteractionEnabled = false
                            current.isSelectable = false
                            addSubview(current)
                            self.countView = current
                        }
                        current.update(layout)
                    } else if let view = self.countView {
                        performSubviewRemoval(view, animated: animated)
                        self.countView = nil
                    }
                    
                    if let title = item.textViewLayout {
                        let current: TextView
                        if let view = self.textView {
                            current = view
                        } else {
                            current = TextView()
                            self.textView = current
                            current.userInteractionEnabled = false
                            current.isSelectable = false
                            addSubview(current)
                        }
                        current.update(title)
                    } else if let view = self.textView {
                        performSubviewRemoval(view, animated: animated)
                        self.textView = nil
                    }
                }
                
                deinit {
                }
                
    
                
                func getView() -> NSView {
                    return self.imageView
                }
                
                
                required init?(coder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }
                
                func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
                    transition.updateFrame(view: backgroundView, frame: size.bounds)
                    transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 5))
                    
                    
                    var offset: CGFloat = 5
                    if let textView = textView {
                        transition.updateFrame(view: textView, frame: textView.centerFrameY(x: imageView.frame.maxX + offset))
                        offset += textView.frame.width + 5
                    }
                    
                    if let countView = countView {
                        transition.updateFrame(view: countView, frame: countView.centerFrameY(x: imageView.frame.maxX + offset))
                    }
                    
                   // transition.updateFrame(view: self.imageView, frame: CGRect(origin: NSMakePoint(presentation.insetOuter, (size.height - reactionSize.height) / 2), size: reactionSize))
                }
                override func layout() {
                    super.layout()
                    updateLayout(size: frame.size, transition: .immediate)
                }
            }

            private let tagView: TagView = TagView(frame: NSMakeRect(0, 0, 40, 26))
            
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(tagView)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func set(item: TableRowItem, animated: Bool) {
                super.set(item: item, animated: animated)
                guard let item = item as? Item else {
                    return
                }
                tagView.setFrameSize(NSMakeSize(item.height - 10, 26))
                tagView.update(with: item, selected: item.selected, animated: animated)
            }
            
            override var backdorColor: NSColor {
                return .clear
            }
            
            override func layout() {
                super.layout()
                tagView.center()
            }
        }
        
        override func viewClass() -> AnyClass {
            return View.self
        }
        
        override var width: CGFloat {
            return 40
        }
        override var height: CGFloat {
            var width: CGFloat = 40
            
            if let textViewLayout = textViewLayout {
                width += textViewLayout.layoutSize.width + 5
            }
            
            if let countViewLayout = countViewLayout {
                width += countViewLayout.layoutSize.width + 10
            }
            
            return width
        }
        
        fileprivate let tag: EmojiTag
        fileprivate let arguments: Arguments
        fileprivate let selected: Bool
        fileprivate let countViewLayout: TextViewLayout?
        fileprivate let textViewLayout: TextViewLayout?
        fileprivate let enabled: Bool
        init(_ initialSize: NSSize, stableId: AnyHashable, tag: EmojiTag, selected: Bool, arguments: Arguments) {
            self.tag = tag
            self.selected = selected
            self.arguments = arguments
            self.enabled = arguments.context.isPremium
            let tagLabel = tag.tag.title
            
            if let title = tagLabel {
                let layout = TextViewLayout(.initialize(string: title, color: selected ? theme.colors.underSelectedColor : theme.colors.grayText, font: .normal(.text)))
                layout.measure(width: .greatestFiniteMagnitude)
                self.textViewLayout = layout
            } else {
                self.textViewLayout = nil
            }
            
            if tag.tag.count > 0 {
                let layout = TextViewLayout(.initialize(string: "\(tag.tag.count)", color: selected ? theme.colors.underSelectedColor : theme.colors.grayText, font: .normal(.text)))
                layout.measure(width: .greatestFiniteMagnitude)
                self.countViewLayout = layout
            } else {
                self.countViewLayout = nil
            }
            super.init(initialSize, stableId: stableId)
        }
    }
    
    class UnlockItem : TableRowItem {
        
        class UnlockView : HorizontalRowView {
            
            

            private let view = Control()
            
            private let tagView: NinePathImage = NinePathImage(frame: NSMakeRect(0, 0, 26, 26))
            private let imageView = ImageView()
            private let textView = TextView()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(view)
                view.addSubview(tagView)
                tagView.addSubview(imageView)
                tagView.addSubview(textView)
                
                textView.userInteractionEnabled = false
                textView.isSelectable = false
                
                view.scaleOnClick = true
                
                view.set(handler: { [weak self] _ in
                    (self?.item as? UnlockItem)?.arguments.callback(nil)
                }, for: .Click)
                
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func set(item: TableRowItem, animated: Bool) {
                super.set(item: item, animated: animated)
                guard let item = item as? UnlockItem else {
                    return
                }
                tagView.setFrameSize(NSMakeSize(item.height - 10, 26))
                textView.update(item.textViewLayout)
                self.tagView.capInsets = NSEdgeInsets(top: 3, left: 5, bottom: 3, right: 10)
                
                let image = NSImage(named: "Icon_SavedMessages_Premium_Tag")!

                self.tagView.image = NSImage(cgImage: generateTintedImage(image: image._cgImage, color: theme.colors.accent.withAlphaComponent(0.2))!, size: image.size)

                
                self.imageView.image = NSImage(named: "Icon_Premium_Lock")?.precomposed(theme.colors.accent)
                self.imageView.sizeToFit()
//                tagView.update(with: item, selected: item.selected, animated: animated)
            }
            
            override var backdorColor: NSColor {
                return .clear
            }
            
            override func layout() {
                super.layout()
                view.frame = container.bounds
                self.tagView.center()
                self.imageView.centerY(x: 4)
                self.textView.centerY(x: self.imageView.frame.maxX + 4)
            }
        }
        
        override func viewClass() -> AnyClass {
            return UnlockView.self
        }
        
        override var width: CGFloat {
            return 40
        }
        override var height: CGFloat {
            var width: CGFloat = 50
            
            width += textViewLayout.layoutSize.width + 5
            
            return width
        }
        
        fileprivate let arguments: Arguments
        fileprivate let textViewLayout: TextViewLayout
        init(_ initialSize: NSSize, stableId: AnyHashable, arguments: Arguments) {
            self.arguments = arguments
            
            let layout = TextViewLayout(.initialize(string: strings().savedMessagesTagsUnlock, color: theme.colors.accent, font: .normal(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            self.textViewLayout = layout

            super.init(initialSize, stableId: stableId)
        }
    }

    
    
    struct EmojiTagEntry : TableItemListNodeEntry {
        static func < (lhs: ChatSearchTagsView.EmojiTagEntry, rhs: ChatSearchTagsView.EmojiTagEntry) -> Bool {
            return lhs.index < rhs.index
        }
        
        let tag: EmojiTag?
        let index: Int
        let theme: TelegramPresentationTheme
        let selected: Bool
        func item(_ arguments: ChatSearchTagsView.Arguments, initialSize: NSSize) -> TableRowItem {
            if let tag = tag {
                return Item(initialSize, stableId: self.stableId, tag: tag, selected: selected, arguments: arguments)
            } else {
                return UnlockItem(initialSize, stableId: self.stableId, arguments: arguments)
            }
        }
        
        var stableId: AnyHashable {
            if let tag = tag {
                return tag.file.fileId
            } else {
                return 0
            }
        }
    }
    
    class PremiumView : Control {
        private let tagImageView = NinePathImage()
        private let tagTextView = TextView()
        private let secondTextView = TextView()
        private let chevron = ImageView()
        private var context: AccountContext?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(tagImageView)
            addSubview(tagTextView)
            addSubview(secondTextView)
            addSubview(chevron)
            
            self.tagImageView.capInsets = NSEdgeInsets(top: 3, left: 5, bottom: 3, right: 10)

            secondTextView.userInteractionEnabled = false
            secondTextView.isSelectable = false
            
            tagTextView.userInteractionEnabled = false
            tagTextView.isSelectable = false
            
            self.scaleOnClick = true
            
            self.set(handler: { [weak self] _ in
                if let context = self?.context {
                    prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                }
            }, for: .Click)
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(context: AccountContext) {
            self.context = context
            let tagLayout: TextViewLayout = TextViewLayout(.initialize(string: strings().chatHeaderSearchAddTags, color: theme.colors.accent, font: .normal(.text)))
            let secondLayout: TextViewLayout = TextViewLayout(.initialize(string: strings().chatHeaderSearchAddTagsSecond, color: theme.colors.grayText, font: .normal(.text)))

            tagLayout.measure(width: .greatestFiniteMagnitude)
            secondLayout.measure(width: .greatestFiniteMagnitude)
            
            self.tagTextView.update(tagLayout)
            self.secondTextView.update(secondLayout)
            
            let image = NSImage(named: "Icon_SavedMessages_Premium_Tag")!

            tagImageView.image = NSImage(cgImage: generateTintedImage(image: image._cgImage, color: theme.colors.accent.withAlphaComponent(0.2))!, size: image.size)
            tagImageView.setFrameSize(NSMakeSize(tagLayout.layoutSize.width + 6, 22))
            
            chevron.image = theme.icons.generalNext
            chevron.sizeToFit()
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            
            self.tagTextView.centerY(x: 30)
            self.tagImageView.centerY(x: self.tagTextView.frame.minX - 6)

            self.secondTextView.centerY(x: self.tagTextView.frame.maxX + 16)
            chevron.centerY(x: self.secondTextView.frame.maxX + 5, addition: 1)
        }
    }
    
    private let tableView = HorizontalTableView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    var selected: [EmojiTag] = [] {
        didSet {
            self.updateLocalizationAndTheme(theme: theme)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
        premiumView?.frame = bounds
    }
    
    private var entries: [EmojiTagEntry] = []
    private var context: AccountContext?
    private var callback:((EmojiTag?)->Void)?
    private var tags: [EmojiTag] = []
    
    private var premiumView: PremiumView?
    
    func set(tags: [EmojiTag], context: AccountContext, animated: Bool, callback: @escaping(EmojiTag?)->Void) {
        
        self.tags = tags
        self.context = context
        self.callback = callback
        let arguments = Arguments(context: context, callback: callback)
        
        var entries: [EmojiTagEntry] = []
        var index: Int = 0
        
        if !context.isPremium {
            entries.append(.init(tag: nil, index: index, theme: theme, selected: false))
            index += 1
        }
        
        for tag in tags {
            entries.append(.init(tag: tag, index: index, theme: theme, selected: self.selected.contains(tag)))
            index += 1
        }
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.entries, rightList: entries)
        
        for rdx in deleteIndices.reversed() {
            tableView.remove(at: rdx, animation: animated ? .effectFade : .none)
            self.entries.remove(at: rdx)
        }
        
        for (idx, item, _) in indicesAndItems {
            _ = tableView.insert(item: item.item(arguments, initialSize: frame.size), at: idx, animation: animated ? .effectFade : .none)
            self.entries.insert(item, at: idx)
        }
        for (idx, item, _) in updateIndices {
            let item = item
            tableView.replace(item: item.item(arguments, initialSize: frame.size), at: idx, animated: animated)
            self.entries[idx] = item
        }
        
        if tableView.isEmpty {
            let current: PremiumView
            if let view = self.premiumView {
                current = view
            } else {
                current = PremiumView(frame: frame.size.bounds)
                self.premiumView = current
                addSubview(current)
            }
            current.set(context: context)
        } else if let premiumView = self.premiumView {
            performSubviewRemoval(premiumView, animated: animated)
            self.premiumView = nil
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        if let context = self.context, let callback = self.callback {
            self.set(tags: self.tags, context: context, animated: false, callback: callback)
        }
    }
}

class ChatSearchHeader : View, Notifable, ChatHeaderProtocol {
    
    private let searchView:ChatSearchView = ChatSearchView(frame: NSMakeRect(0, 0, 200, 30))
    private let cancel:ImageButton = ImageButton()
    private let from:ImageButton = ImageButton()
    private let calendar:ImageButton = ImageButton()
    
    private let prev:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()
    
    private let searchContainer = View()
    
    private var tagsView: ChatSearchTagsView?

    
    private let separator:View = View()
    private let interactions:ChatSearchInteractions
    private let chatInteraction: ChatInteraction
    
    private let query:ValuePromise<SearchStateQuery> = ValuePromise()

    private let disposable:MetaDisposable = MetaDisposable()
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction: CSearchInteraction = CSearchInteraction()
    private let parentInteractions: ChatInteraction
    private let loadingDisposable = MetaDisposable()
   
    private let calendarController: CalendarController
    required init(_ chatInteraction: ChatInteraction, state: ChatHeaderState, frame: NSRect) {

        switch state.main {
        case let .search(interactions, _, initialString, _, _, _):
            self.interactions = interactions
            self.parentInteractions = chatInteraction
            self.calendarController = CalendarController(NSMakeRect(0, 0, 300, 300), chatInteraction.context.window, selectHandler: interactions.calendarAction)
            self.chatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, context: chatInteraction.context, mode: chatInteraction.mode)
            self.chatInteraction.update({$0.updatedPeer({_ in chatInteraction.presentation.peer})})
            self.inputContextHelper = InputContextHelper(chatInteraction: self.chatInteraction, highlightInsteadOfSelect: true)

            if let initialString = initialString {
                searchView.setString(initialString)
                self.query.set(SearchStateQuery(initialString, nil))
            }
        default:
            fatalError()
        }

        super.init()
        
        self.chatInteraction.movePeerToInput = { [weak self] peer in
            self?.searchView.completeToken(peer.compactDisplayTitle)
            self?.inputInteraction.update({$0.updatedPeerId(peer.id)})
        }
        
        
        self.chatInteraction.focusMessageId = { [weak self] fromId, messageId, state in
            self?.parentInteractions.focusMessageId(fromId, messageId, state)
            self?.inputInteraction.update({$0.updatedSelectedIndex($0.messages.0.firstIndex(where: { $0.id == messageId.messageId }) ?? -1)})
            _ = self?.window?.makeFirstResponder(nil)
        }
        
     

        initialize(state)
        

        
        parentInteractions.loadingMessage.set(.single(false))
        
        inputInteraction.add(observer: self)
        self.loadingDisposable.set((parentInteractions.loadingMessage.get() |> deliverOnMainQueue).start(next: { [weak self] loading in
            self?.searchView.isLoading = loading
        }))
        switch state.main {
        case let .search(_, initialPeer, _, _, _, _):
            if let initialPeer = initialPeer {
                self.chatInteraction.movePeerToInput(initialPeer)
            }
        default:
            break
        }
        Queue.mainQueue().justDispatch { [weak self] in
            self?.applySearchResponder(false)
        }
        
        chatInteraction.add(observer: self)
    }
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        self.inputInteraction.update {$0.updatedTokenState(.none).updatedSelectedIndex(-1).updatedMessages(([], nil)).updatedSearchState(SearchState(state: .None, request: ""))}
        self.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
    }
    
    
    func applySearchResponder(_ animated: Bool = false) {
       // _ = window?.makeFirstResponder(searchView.input)
        searchView.layout()
        if searchView.state == .Focus && window?.firstResponder != searchView.input {
            _ = window?.makeFirstResponder(searchView.input)
        }
        searchView.change(state: .Focus, animated)
    }
    
    private var calendarAbility: Bool {
        return chatInteraction.mode != .scheduled && chatInteraction.mode != .pinned
    }
    
    private func fromAbility(_ chatLocation: ChatLocation) -> Bool {
        if let peer = chatInteraction.presentation.peer {
            if peer.isMonoForum {
                return false
            }
            return (peer.isSupergroup || peer.isGroup) && (chatInteraction.mode == .history || chatInteraction.mode.isThreadMode || chatInteraction.mode.isTopicMode)
        } else {
            return false
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        let context = chatInteraction.context
        if let value = value as? CSearchContextState, let oldValue = oldValue as? CSearchContextState, let superview = superview, let view = superview.superview {
            
            let stateValue = self.query
            
            prev.isEnabled = !value.messages.0.isEmpty && value.selectedIndex < value.messages.0.count - 1
            next.isEnabled = !value.messages.0.isEmpty && value.selectedIndex > 0
            next.set(image: next.isEnabled ? theme.icons.chatSearchDown : theme.icons.chatSearchDownDisabled, for: .Normal)
            prev.set(image: prev.isEnabled ? theme.icons.chatSearchUp : theme.icons.chatSearchUpDisabled, for: .Normal)

            
            
            if let peer = chatInteraction.presentation.peer {
                if value.inputQueryResult != oldValue.inputQueryResult {
                    inputContextHelper.context(with: value.inputQueryResult, for: view, relativeView: superview, position: .below, selectIndex: value.selectedIndex != -1 ? value.selectedIndex : nil, animated: animated, inset: superview.frame.minX)
                }
                switch value.tokenState {
                case .none:
                    from.isHidden = !fromAbility(self.chatInteraction.chatLocation)
                    calendar.isHidden = !calendarAbility
                    needsLayout = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    
                    if (peer.isSupergroup || peer.isGroup) && chatInteraction.mode == .history {
                        if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(chatLocations: [chatInteraction.chatLocation], .mention(query: value.searchState.request, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context) {
                            self.contextQueryState?.1.dispose()
                            self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                                if let strongSelf = self {
                                    strongSelf.inputInteraction.update(animated: animated, { state in
                                        return state.updatedInputQueryResult { previousResult in
                                            let messages = state.searchState.responder ? state.messages : ([], nil)
                                            var suggestedPeers:[Peer] = []
                                            let inputQueryResult = result(previousResult)
                                            if let inputQueryResult = inputQueryResult, state.searchState.responder, !state.searchState.request.isEmpty, messages.1 != nil {
                                                switch inputQueryResult {
                                                case let .mentions(mentions):
                                                    suggestedPeers = mentions
                                                default:
                                                    break
                                                }
                                            }
                                            return .searchMessages((messages.0, messages.1, { searchMessagesState in
                                                stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                            }), suggestedPeers, state.searchState.request)
                                        }
                                    })
                                }
                            }))
                        }
                    } else {
                        inputInteraction.update(animated: animated, { state in
                            return state.updatedInputQueryResult { previousResult in
                                let result = state.searchState.responder ? state.messages : ([], nil)
                                return .searchMessages((result.0, result.1, { searchMessagesState in
                                    stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                }), [], state.searchState.request)
                            }
                        })
                    }
                    
                    
                case let .from(query, complete):
                    from.isHidden = true
                    calendar.isHidden = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    needsLayout = true
                    if complete {
                        inputInteraction.update(animated: animated, { state in
                            return state.updatedInputQueryResult { previousResult in
                                let result = state.searchState.responder ? state.messages : ([], nil)
                                return .searchMessages((result.0, result.1, { searchMessagesState in
                                    stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                }), [], state.searchState.request)
                            }
                        })
                    } else {
                        if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(chatLocations: [chatInteraction.chatLocation], .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context) {
                            self.contextQueryState?.1.dispose()
                            var inScope = true
                            var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                            self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                                if let strongSelf = self {
                                    if Thread.isMainThread && inScope {
                                        inScope = false
                                        inScopeResult = result
                                    } else {
                                        strongSelf.inputInteraction.update(animated: animated, {
                                            $0.updatedInputQueryResult { previousResult in
                                                return result(previousResult)
                                            }.updatedMessages(([], nil)).updatedSelectedIndex(-1)
                                        })
                                        
                                    }
                                }
                            }))
                            inScope = false
                            if let inScopeResult = inScopeResult {
                                inputInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return inScopeResult(previousResult)
                                    }.updatedMessages(([], nil)).updatedSelectedIndex(-1)
                                })
                            }
                        }
                    }
                case .emojiTag:
                    from.isHidden = true
                    calendar.isHidden = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    needsLayout = true
                //    self.tagsView?.selected = tag
                    inputInteraction.update(animated: animated, { state in
                        return state.updatedInputQueryResult { previousResult in
                            let result = state.searchState.responder ? state.messages : ([], nil)
                            return .searchMessages((result.0, result.1, { searchMessagesState in
                                stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                            }), [], state.searchState.request)
                        }
                    })
                }
            }
        } else if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.chatLocation != oldValue.chatLocation {
                
                let request = self.searchView.query
                
                self.parentInteractions.updateSearchRequest(SearchMessagesResultState(request, []))
                self.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1)})
                self.parentInteractions.loadingMessage.set(.single(true))
                self.query.set(SearchStateQuery(request, nil))
                self.parentInteractions.setLocationTag(nil)
                
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let to = other as? ChatSearchView {
            return to === other
        } else {
            return false
        }
    }
    
    
    
    
    
    private func initialize(_ state: ChatHeaderState) {
        
        _ = self.searchView.tokenPromise.get().start(next: { [weak self] state in
            self?.inputInteraction.update({$0.updatedTokenState(state)})
        })
        
     
        self.searchView.searchInteractions = SearchInteractions({ [weak self] state, _ in
            if state.state == .None {
                self?.parentInteractions.loadingMessage.set(.single(false))
                self?.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                self?.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1).updatedSearchState(state)})
            }
        }, { [weak self] state in
            guard let `self` = self else {return}
            
            self.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1).updatedSearchState(state)})
            
            self.updateSearchState()
            switch self.searchView.tokenState {
            case .none:
                if state.request == strings().chatSearchFrom, let peer = self.chatInteraction.presentation.peer, peer.isGroup || peer.isSupergroup  {
                    self.query.set(SearchStateQuery("", nil))
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
                    self.searchView.initToken()
                } else {
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                    self.parentInteractions.loadingMessage.set(.single(true))
                    self.query.set(SearchStateQuery(state.request, nil))
                    self.parentInteractions.setLocationTag(nil)
                }
                
            case .from(_, let complete):
                if complete {
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                    self.parentInteractions.loadingMessage.set(.single(true))
                    self.query.set(SearchStateQuery(state.request, nil))
                }
            case .emojiTag:
                self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                self.parentInteractions.loadingMessage.set(.single(true))
                self.query.set(SearchStateQuery(state.request, nil))
            }
            
        }, responderModified: { [weak self] state in
            self?.inputInteraction.update({$0.updatedSearchState(state)})
        })
 
        
        let apply = query.get() |> mapToSignal { [weak self] state -> Signal<([Message], SearchMessagesState?, String), NoError> in
            
            guard let `self` = self else { return .single(([], nil, "")) }
            if let query = state.query {
                
                let stateSignal: Signal<SearchMessagesState?, NoError>
                if state.state == nil {
                    stateSignal = .single(state.state) |> delay(0.3, queue: Queue.mainQueue())
                } else {
                    stateSignal = .single(state.state)
                }
                
                return stateSignal |> mapToSignal { [weak self] state in
                    
                    guard let `self` = self else { return .single(([], nil, "")) }
                    
                    var request = query
                    
                    var tags: [EmojiTag] = []
                    
                    let emptyRequest: Bool
                    if case let .emojiTag(tag) = self.inputInteraction.state.tokenState {
                        tags.append(tag)
                        emptyRequest = true
                    } else if case .from = self.inputInteraction.state.tokenState {
                        emptyRequest = true
                    } else {
                        emptyRequest = !query.isEmpty
                    }
                    if emptyRequest {
                        return self.interactions.searchRequest(request, self.inputInteraction.state.peerId, state, tags) |> map { ($0.0, $0.1, request) }
                    }
                    return .single(([], nil, ""))
                }
            } else {
                return .single(([], nil, ""))
            }
        } |> deliverOnMainQueue
        
        self.disposable.set(apply.start(next: { [weak self] messages in
            guard let `self` = self else {return}
            self.parentInteractions.updateSearchRequest(SearchMessagesResultState(messages.2, messages.0))
            self.inputInteraction.update({$0.updatedMessages((messages.0, messages.1)).updatedSelectedIndex(-1)})
            self.parentInteractions.loadingMessage.set(.single(false))
        }))
        
        
        next.autohighlight = false
        prev.autohighlight = false



        _ = calendar.sizeToFit()
        
        searchContainer.addSubview(next)
        searchContainer.addSubview(prev)

        
        searchContainer.addSubview(from)
        
        
        searchContainer.addSubview(calendar)
        

        _ = cancel.sizeToFit()
        
        let interactions = self.interactions
        let searchView = self.searchView
        cancel.set(handler: { [weak self] _ in
            self?.inputInteraction.update {$0.updatedTokenState(.none).updatedSelectedIndex(-1).updatedMessages(([], nil)).updatedSearchState(SearchState(state: .None, request: ""))}
            self?.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
            interactions.cancel()
        }, for: .Click)
        
        next.set(handler: { [weak self] _ in
            self?.nextAction()
            }, for: .Click)
        prev.set(handler: { [weak self] _ in
            self?.prevAction()
        }, for: .Click)

        

        from.set(handler: { [weak self] _ in
            self?.searchView.initToken()
        }, for: .Click)
        
        
        
        calendar.set(handler: { [weak self] calendar in
            guard let `self` = self else {return}
            showPopover(for: calendar, with: self.calendarController, edge: .maxY, inset: NSMakePoint(-160, -40))
        }, for: .Click)

        searchContainer.addSubview(searchView)
        searchContainer.addSubview(cancel)
        
        addSubview(searchContainer)
        addSubview(separator)
        
        updateLocalizationAndTheme(theme: theme)
        
        self.update(with: state, animated: false)
    }
    
    
    func update(with state: ChatHeaderState, animated: Bool) {
        
        
        switch state.main {
        case let .search(_, _, _, tags, tag, chatLocation):
            
            self.calendar.isHidden = !calendarAbility
            self.from.isHidden = !fromAbility(chatLocation)

            
            if let tags = tags {
                let current: ChatSearchTagsView
                if let view = self.tagsView {
                    current = view
                } else {
                    current = ChatSearchTagsView(frame: NSMakeRect(0, 39, frame.width, 40))
                    self.tagsView = current
                    addSubview(current, positioned: .below, relativeTo: separator)
                }
                current.selected = tag.flatMap { [$0] } ?? []
                
                if let tag = tag {
                    self.searchView.completeEmojiToken(tag, context: parentInteractions.context)
                } else {
                    self.searchView.cancelEmojiToken(animated: animated)
                }
                
                if current.selected.isEmpty {
                    self.parentInteractions.setLocationTag(nil)
                }
                
                let context = self.parentInteractions.context
                
                current.set(tags: tags, context: chatInteraction.context, animated: false, callback: { [weak self] selected in
                    if let `self` = self {
                        if let selected {
                            if selected.tag.reaction == self.tagsView?.selected.first?.tag.reaction {
                                self.parentInteractions.setLocationTag(nil)
                            } else {
                                self.parentInteractions.setLocationTag(.customTag(ReactionsMessageAttribute.messageTag(reaction: selected.tag.reaction), nil))
                            }
                        } else {
                            prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                        }
                        
                    }
                })
            } else if let tagsView = tagsView {
                performSubviewRemoval(tagsView, animated: animated)
                self.tagsView = nil
                self.searchView.cancelEmojiToken(animated: animated)
            }
        default:
            fatalError()
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        backgroundColor = theme.colors.background
        
        next.set(image: theme.icons.chatSearchDown, for: .Normal)
        _ = next.sizeToFit()
        
        prev.set(image: theme.icons.chatSearchUp, for: .Normal)
        _ = prev.sizeToFit()


        calendar.set(image: theme.icons.chatSearchCalendar, for: .Normal)
        _ = calendar.sizeToFit()
        
        cancel.set(image: theme.icons.chatSearchCancel, for: .Normal)
        _ = cancel.sizeToFit()

        from.set(image: theme.icons.chatSearchFrom, for: .Normal)
        _ = from.sizeToFit()
        
        separator.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.background
        needsLayout = true
        updateSearchState()
    }
    
    func updateSearchState() {
       
    }
    
    func prevAction() {
        inputInteraction.update({$0.updatedSelectedIndex(min($0.selectedIndex + 1, $0.messages.0.count - 1))})
        perform()
    }
    
    func perform() {
        _ = window?.makeFirstResponder(nil)
        if let currentMessage = inputInteraction.currentMessage {
            interactions.jump(currentMessage)
        }
    }
    
    func nextAction() {
        inputInteraction.update({$0.updatedSelectedIndex(max($0.selectedIndex - 1, 0))})
        perform()
    }
    
    private var searchWidth: CGFloat {
        return frame.width - cancel.frame.width - 20 - 20 - 80 - (calendar.isHidden ? 0 : calendar.frame.width + 20) - (from.isHidden ? 0 : from.frame.width + 20)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: searchContainer, frame: NSMakeRect(0, 0, size.width, 44))

        transition.updateFrame(view: prev, frame: prev.centerFrameY(x: 10))
        transition.updateFrame(view: next, frame: next.centerFrameY(x: prev.frame.maxX))

        transition.updateFrame(view: cancel, frame: cancel.centerFrameY(x: size.width - cancel.frame.width - 20))
        
        transition.updateFrame(view: searchView, frame: NSMakeRect(80, 10, searchWidth, 30))
        searchView.updateLayout(size: searchView.frame.size, transition: transition)

        let inputContextView = inputContextHelper.controller.view
        
        let rect = CGRect(origin: inputContextHelper.controller.frame.origin, size: NSSize(width: size.width, height: inputContextHelper.controller.frame.height))
        transition.updateFrame(view: inputContextView, frame: rect)

        
                
        transition.updateFrame(view: separator, frame: NSMakeRect(0, size.height - .borderSize, size.width, .borderSize))

        transition.updateFrame(view: from, frame: from.centerFrameY(x: searchView.frame.maxX + 20))

        let calendarAnchor = from.isHidden ? searchView : from
        transition.updateFrame(view: calendar, frame: calendar.centerFrameY(x: calendarAnchor.frame.maxX + 20))

        if let tagsView = tagsView {
            transition.updateFrame(view: tagsView, frame: NSMakeRect(0, searchContainer.frame.maxY - 5, size.width, 40))
        }
    }

    
    override func viewDidMoveToWindow() {
        if let _ = window {
            layout()
            //self.searchView.change(state: .Focus, false)
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
         //   self.searchView.change(state: .None, false)
        }
    }
    
    
    deinit {
        self.inputInteraction.update(animated: false, { state in
            return state.updatedInputQueryResult( { _ in return nil } )
        })
        self.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
        self.disposable.dispose()
        self.inputInteraction.remove(observer: self)
        self.loadingDisposable.dispose()
        self.chatInteraction.remove(observer: self)
        
        if let window = window as? Window {
            window.removeAllHandlers(for: self)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    init(frame frameRect: NSRect, interactions:ChatSearchInteractions, chatInteraction: ChatInteraction) {
//        self.interactions = interactions
//        self.chatInteraction = chatInteraction
//        self.parentInteractions = chatInteraction
//        self.inputContextHelper = InputContextHelper(chatInteraction: chatInteraction, highlightInsteadOfSelect: true)
//        self.calendarController = CalendarController(NSMakeRect(0,0,300, 300), chatInteraction.context.window, selectHandler: interactions.calendarAction)
//        super.init(frame: frameRect)
//        initialize()
//    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

