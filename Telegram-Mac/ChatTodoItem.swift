//
//  ChatTodoItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30.05.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import ColorPalette


private extension TelegramMediaTodo {
    func translated(_ todo: TranslationMessageAttribute) -> TelegramMediaTodo {
        var options: [TelegramMediaTodo.Item] = self.items
        for (i, option) in options.enumerated() {
            options[i] = .init(text: todo.additional[i].text, entities: todo.additional[i].entities, id: option.id)
        }
        
        return .init(flags: self.flags, text: todo.text, textEntities: todo.entities, items: options, completions: self.completions)
    }
}


private final class TodoItem : Equatable {
    let option: TelegramMediaTodo.Item
    let peer: EnginePeer?
    let nameText: TextViewLayout
    let isSelected: Bool
    let isIncoming: Bool
    let isBubbled: Bool
    let isLoading: Bool
    let presentation: TelegramPresentationTheme
    let contentSize: NSSize
    let vote:(Control)-> Void
    let isTranslateLoading: Bool
    init(option:TelegramMediaTodo.Item, nameText: TextViewLayout, isSelected: Bool, isIncoming: Bool, isBubbled: Bool, isLoading: Bool, presentation: TelegramPresentationTheme, vote: @escaping(Control)->Void = { _ in }, contentSize: NSSize = NSZeroSize, isTranslateLoading: Bool, peer: EnginePeer?) {
        self.option = option
        self.nameText = nameText
        self.isSelected = isSelected
        self.presentation = presentation
        self.isIncoming = isIncoming
        self.isBubbled = isBubbled
        self.isLoading = isLoading
        self.vote = vote
        self.contentSize = contentSize
        self.isTranslateLoading = isTranslateLoading
        self.peer = peer
    }
    
    func withUpdatedLoading(_ isLoading: Bool) -> TodoItem {
        return TodoItem(option: self.option, nameText: self.nameText, isSelected: self.isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, isLoading: isLoading, presentation: self.presentation, vote: self.vote, contentSize: self.contentSize, isTranslateLoading: self.isTranslateLoading, peer: self.peer)
    }
    func withUpdatedContentSize(_ contentSize: NSSize) -> TodoItem {
        return TodoItem(option: self.option, nameText: self.nameText, isSelected: self.isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, isLoading: self.isLoading, presentation: self.presentation, vote: self.vote, contentSize: contentSize, isTranslateLoading: self.isTranslateLoading, peer: self.peer)
    }
    func withUpdatedSelected(_ isSelected: Bool) -> TodoItem {
        return TodoItem(option: self.option, nameText: self.nameText, isSelected: isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, isLoading: self.isLoading, presentation: self.presentation, vote: self.vote, contentSize: self.contentSize, isTranslateLoading: self.isTranslateLoading, peer: self.peer)
    }
    
    static func ==(lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.option == rhs.option && lhs.isSelected == rhs.isSelected && lhs.isIncoming == rhs.isIncoming && lhs.isLoading == rhs.isLoading && lhs.contentSize == rhs.contentSize && lhs.isTranslateLoading == rhs.isTranslateLoading && lhs.peer == rhs.peer
    }
    
    
    var leftOptionInset: CGFloat {
        return 40 + TodoItem.spaceBetweenTexts
    }
    
    static var spaceBetweenTexts: CGFloat {
        return 6
    }
    static var spaceBetweenOptions: CGFloat {
        return 5
    }
    
    var tooltip: String {
        return ""
    }
    
    func measure(width: CGFloat) -> NSSize {
        nameText.measure(width: width - leftOptionInset)
        let contentSize = NSMakeSize(nameText.layoutSize.width + leftOptionInset, 10 + nameText.layoutSize.height + TodoItem.spaceBetweenOptions)
        if isTranslateLoading {
            nameText.maskBlockImage = nameText.generateBlock(backgroundColor: .blackTransparent)
        }
        return contentSize
    }
}

class ChatRowTodoItem: ChatRowItem {
    private(set) fileprivate var titleText:TextViewLayout!
    private(set) fileprivate var titleTypeText:TextViewLayout!

    private(set) fileprivate var options:[TodoItem] = []
    private(set) fileprivate var totalVotesText:TextViewLayout?

    fileprivate let todo: TelegramMediaTodo
    
    var actionButtonText: String? {
        return nil
    }
    
    var actionButtonIsEnabled: Bool {
        guard let message = message else {
            return false
        }
        if message.flags.contains(.Failed) || message.flags.contains(.Sending) || message.flags.contains(.Unsent) {
            return false
        }
        return true
    }
    
    let isTranslateLoading: Bool
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        
        
        var todo = object.message!.media[0] as! TelegramMediaTodo
        let isTranslateLoading: Bool
        if let translate = object.additionalData.translate {
            switch translate {
            case .loading:
                isTranslateLoading = true
            case let .complete(toLang: toLang):
                if let attribute = object.message!.translationAttribute(toLang: toLang) {
                    todo = todo.translated(attribute)
                }
                isTranslateLoading = false
            }
        } else {
            isTranslateLoading = false
        }
        self.todo = todo
        self.isTranslateLoading = isTranslateLoading
        super.init(initialSize, chatInteraction, context, object, theme: theme)
    
        
        
        var options: [TodoItem] = []
        
 

                
        for (i, option) in todo.items.enumerated() {
            
            let isSelected: Bool = todo.completions.contains(where: { $0.id == option.id })
            let nameFont: NSFont = .normal(.text)//voted && isSelected ? .bold(.text) : .normal(.text)
            
            let peerId = todo.completions.first(where: { $0.id == option.id })?.completedBy
            
            let optionText = NSMutableAttributedString()
            optionText.append(string: option.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: nameFont)
            InlineStickerItem.apply(to: optionText, associatedMedia: message?.associatedMedia ?? [:], entities: option.entities, isPremium: context.isPremium)
            
            let nameLayout = TextViewLayout(optionText, alwaysStaticItems: true)
                        
            let wrapper = TodoItem(option: option, nameText: nameLayout, isSelected: isSelected, isIncoming: isIncoming, isBubbled: renderType == .bubble, isLoading: false, presentation: self.presentation, vote: { [weak self] control in
                self?.voteOption(option, for: control)
            }, isTranslateLoading: isTranslateLoading, peer: peerId.flatMap { message?.peers[$0] }.flatMap(EnginePeer.init))
            
            options.append(wrapper)
        }
        self.options = options
        
        
        //TODOLANG
        var totalText = "\(todo.completions.count) of \(options.count) completed"
        
        self.totalVotesText = TextViewLayout(.initialize(string: totalText, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)


        let titleAttr = NSMutableAttributedString()
        titleAttr.append(string: todo.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: .medium(.text))
        
        InlineStickerItem.apply(to: titleAttr, associatedMedia: message?.associatedMedia ?? [:], entities: todo.textEntities, isPremium: context.isPremium)

        
        self.titleText = TextViewLayout(titleAttr, alwaysStaticItems: true)
        
        
        
        //TODOLANG
        self.titleTypeText = TextViewLayout(.initialize(string: "To Do List", color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)
    }
    
    override var isForceRightLine: Bool {
        var size: NSSize = .zero
        if let action = self.actionButtonText {
            size = TextButton.size(with: action, font: .normal(.text))
        } else if let totalVotesText = self.totalVotesText {
            size = totalVotesText.layoutSize
        }
        
        if size.width > 0 {
            let dif = contentSize.width - (contentSize.width / 2 + size.width / 2)
            if dif < (rightSize.width + insetBetweenContentAndDate) {
                return true
            }
            
        }
        
        return super.isForceRightLine
    }
    
        
    private func stop() {
        if let message = message {
            chatInteraction.closePoll(message.id)
        }
    }
    
    private func unvote() {
        
        if canInvokeVote {
            guard let message = message else { return }
            self.chatInteraction.vote(message.id, [], true)
        }
        
    }
    
    private func voteOption(_ option: TelegramMediaTodo.Item, for control: Control) {
        guard let message = message else { return }

        
        var completed = self.todo.completions.map { $0.id }
        var incompleted = self.todo.items.map { $0.id }.filter({ !completed.contains($0) })
        
        let isCompleted = completed.contains(option.id)
        
        
        if !completed.contains(option.id) {
            completed.append(option.id)
            incompleted.removeAll(where: { $0 == option.id })
        } else {
            incompleted.append(option.id)
            completed.removeAll(where: { $0 == option.id })
        }
        
        
        _ = context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: !isCompleted ? [option.id] : [], incompletedIds: isCompleted ? [option.id] : []).start()
//        if canInvokeVote, !self.options.contains(where: { $0.isSelected }) {
//            guard let message = message else { return }
//            var identifiers = self.entry.additionalData.pollStateData.identifiers
//            if let index = identifiers.firstIndex(of: option.opaqueIdentifier) {
//                identifiers.remove(at: index)
//            } else {
//                identifiers.append(option.opaqueIdentifier)
//            }
//           // chatInteraction.vote(message.id, identifiers, !self.poll.isMultiple)
//        } else {
//            if self.options.contains(where: { $0.isSelected }) || self.isClosed, self.poll.publicity == .public {
//                guard let message = message else {
//                    return
//                }
//                if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) || self.options.contains(where: { $0.isLoading }) {
//                    return
//                }
//                self.invokeAction(fromOption: option.opaqueIdentifier)
//            }  else if let option = self.options.first(where: { $0.option.opaqueIdentifier == option.opaqueIdentifier }) {
//                tooltip(for: control, text: option.tooltip)
//            }
//        }
    }

    
    private var canInvokeVote: Bool {
        guard let message = message else {
            return false
        }
        if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
            return false
        }
        if self.options.contains(where: { $0.isLoading }) {
            return false
        }
        
        return true
    }
   
    
    override func viewClass() -> AnyClass {
        return ChatTodoItemView.self
    }
    
    override var instantlyResize: Bool {
        return true
    }

    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        let width = min(width, 320)
        
        
        var rightInset: CGFloat = 0
        


        titleText.measure(width: width - bubbleContentInset - rightInset)
        titleTypeText.measure(width: width - bubbleContentInset - rightInset)
        totalVotesText?.measure(width: width - bubbleContentInset)
        
        if isTranslateLoading {
            titleText.maskBlockImage = titleText.generateBlock(backgroundColor: .blackTransparent)
        }
        
        var maxOptionNameWidth: CGFloat = 0
        for (i, option) in options.enumerated() {
            let size = option.measure(width: width)
            self.options[i] = option.withUpdatedContentSize(size)
            if maxOptionNameWidth < size.width {
                maxOptionNameWidth = size.width
            }
        }
    
        
        let contentWidth:CGFloat = max(max(maxOptionNameWidth, titleText.layoutSize.width), titleTypeText.layoutSize.width)
        
        var contentHeight: CGFloat = 0
        
        contentHeight += titleText.layoutSize.height + defaultContentInnerInset
        contentHeight += titleTypeText.layoutSize.height + defaultContentInnerInset
        contentHeight += options.reduce(0, { $0 + $1.contentSize.height }) + (CGFloat(options.count - 1) * TodoItem.spaceBetweenOptions)
        
        if let totalVotesText = totalVotesText {
            contentHeight += defaultContentInnerInset
            contentHeight += totalVotesText.layoutSize.height
        }
        if let _ = self.actionButtonText {
            contentHeight += defaultContentInnerInset
            contentHeight += 15
        }
        
        return NSMakeSize(max(width, contentWidth), contentHeight)
    }
    
}


final class ChatTodoItemView : ChatRowView {
    private var contentNode:TodoView = TodoView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentNode)
    }
    
    override func contentFrameModifier(_ item: ChatRowItem) -> NSRect {
        if item.isBubbled {
            var frame = bubbleFrame(item)
            let contentFrame = self.contentFrame(item)
            let contentFrameModifier = super.contentFrameModifier(item)
            frame.size.height = contentFrame.height
            frame.size.width -= item.additionBubbleInset
            frame.origin.y = contentFrameModifier.minY
            if item.isIncoming {
                frame.origin.x += item.additionBubbleInset
            }
            return frame
        } else {
            var frame = super.contentFrameModifier(item)
            frame.origin.x -= item.bubbleContentInset
            return frame
        }
    }
    
    
    func doAfterAnswer() {
        
    }
    func doWhenCorrectAnswer() {
        
    }
    func doWhenIncorrectAnswer() {
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatRowTodoItem else { return }
        super.set(item: item, animated: animated)

        contentNode.change(size: NSMakeSize(contentFrameModifier(item).width, item.contentSize.height), animated: animated)
        contentNode.update(with: item, animated: animated)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func canStartTextSelecting(_ event: NSEvent) -> Bool {
        
        let point = contentView.convert(event.locationInWindow, from: nil)
        return NSPointInRect(point, NSMakeRect(0, contentNode.titleView.frame.minY, contentNode.frame.width, contentNode.titleView.frame.height))
    }
    
    override var selectableTextViews: [TextView] {
        return [contentNode.titleView.textView]
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        return true
    }
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode.needsDisplay = true
        }
    }
    
    override var backgroundColor: NSColor {
        didSet {
            
            contentNode.backgroundColor = .clear//contentColor
        }
    }
    
    override func shakeView() {
        contentNode.shake()
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
        
    }

    override func updateColors() {
        super.updateColors()
         contentNode.backgroundColor = .clear//contentColor
    }
    

}


private final class TodoOptionView : Control {
    private let nameView: InteractiveTextView = InteractiveTextView(frame: .zero)
    private var selectingView:ImageView?
    private let progressView: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    private var progressIndicator: ProgressIndicator?
    private let borderView: View = View(frame: NSZeroRect)
    
    private var selectedImageView: ImageView?
    private var avatarView: AvatarControl?
    
    private var option: TodoItem?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameView.userInteractionEnabled = false
        progressView.hasMinumimVisibility = true
        addSubview(nameView)
        addSubview(progressView)
        addSubview(borderView)
        borderView.userInteractionEnabled = false
        progressView.userInteractionEnabled = false
        progressView.roundCorners = true
        
        layer?.masksToBounds = false
        
        progressView.isEventLess = true
        
        set(handler: { [weak self] control in
            self?.option?.vote(control)
        }, for: .Click)
    }
    
    var defaultInset: CGFloat {
        return 13
    }
    
    func update(with option: TodoItem, context: AccountContext, animated: Bool) {
        let animated = animated && self.option != option
        let previousOption = self.option


        self.option = option

        
        let duration: Double = 0.4
        let timingFunction: CAMediaTimingFunctionName = .spring
        
        nameView.set(text: option.nameText, context: context)
        nameView.setFrameOrigin(NSMakePoint(option.leftOptionInset, 0))
        
        nameView.textView.setIsShimmering(option.isTranslateLoading, animated: animated)
        
        progressView.setFrameOrigin(NSMakePoint(nameView.frame.minX, nameView.frame.maxY + 5))
        borderView.backgroundColor = option.presentation.chat.pollOptionBorder(option.isIncoming, option.isBubbled)
        borderView.frame = NSMakeRect(nameView.frame.minX, nameView.frame.maxY + 5 - .borderSize + progressView.progressHeight, frame.width - nameView.frame.minX, .borderSize)
        borderView.change(opacity: 1, animated: animated, duration: duration, timingFunction: timingFunction)
        progressView.change(opacity: 1, animated: animated, duration: duration, timingFunction: timingFunction)
        
        let votedColor: NSColor
        
        votedColor = option.presentation.chat.activityColor(option.isIncoming, option.isBubbled)
        
        progressView.style = ControlStyle(foregroundColor: votedColor, backgroundColor: .clear)
        
        
        
        if selectingView == nil {
            selectingView = ImageView(frame: NSMakeRect(0, 0, 22, 22))
            addSubview(selectingView!)
            if animated {
                selectingView?.layer?.animateAlpha(from: 0, to: 1, duration: duration / 2)
            }
        }
        selectingView?.animates = animated || (previousOption != nil && previousOption?.isSelected != option.isSelected)
        
        if option.isSelected {
            selectingView?.image = option.presentation.chat.pollSelection(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
        } else {
            selectingView?.image = option.presentation.chat.pollOptionUnselectedImage(option.isIncoming, option.isBubbled)
        }
        
        if let peer = option.peer {
            let current: AvatarControl
            var isNew: Bool = false
            if let view = self.avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(8))
                current.setFrameSize(17, 17)
                current.userInteractionEnabled = false
                addSubview(current, positioned: .below, relativeTo: selectingView)
                self.avatarView = current
                isNew = true
            }
            current.setPeer(account: context.account, peer: peer._asPeer())
            current.setFrameOrigin(NSMakePoint(defaultInset + 10, 1))
            if animated, isNew {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
            }
        } else if let view = self.avatarView {
            performSubviewRemoval(view, animated: animated, scale: true)
            self.avatarView = nil
        }
        
        selectingView?.sizeToFit()
        selectingView?.setFrameOrigin(NSMakePoint(defaultInset, 0))

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class TodoView : Control {
    fileprivate let titleView: InteractiveTextView = InteractiveTextView(frame: .zero)
    private let typeView: TextView = TextView()
    private var actionButton: TextButton?
    private var totalVotesTextView: TextView?
    
    

    private var options:[TodoOptionView] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        typeView.isSelectable = false
        typeView.userInteractionEnabled = false
        addSubview(titleView)
        addSubview(typeView)
        
        
        titleView.textView.isSelectable = true
    }
    
    func update(with item: ChatRowTodoItem, animated: Bool) {
        
        titleView.set(text: item.titleText, context: item.context)
        typeView.update(item.titleTypeText)
        
        titleView.textView.setIsShimmering(item.isTranslateLoading, animated: animated)
        
        var y: CGFloat = 0
        
        titleView.setFrameOrigin(NSMakePoint(item.bubbleContentInset, y))
        y += titleView.frame.height + item.defaultContentInnerInset
        typeView.setFrameOrigin(NSMakePoint(item.bubbleContentInset, y))
        y += typeView.frame.height + item.defaultContentInnerInset
        
        while options.count < item.options.count {
            let option = TodoOptionView(frame: NSZeroRect)
            options.append(option)
            addSubview(option)
        }
        while options.count > item.options.count {
            let option = options.removeLast()
            option.removeFromSuperview()
        }
        for (i, option) in item.options.enumerated() {
            
            
            self.options[i].frame = NSMakeRect(0, y - (i > 0 ? TodoItem.spaceBetweenOptions : 0), frame.width, option.contentSize.height)
            self.options[i].update(with: option, context: item.context, animated: animated)
            y += option.contentSize.height
            if i != item.options.count - 1 {
                y += TodoItem.spaceBetweenOptions
            }
        }
        
        if let totalVotesText = item.totalVotesText {
            y += item.defaultContentInnerInset
            if totalVotesTextView == nil {
                totalVotesTextView = TextView()
                totalVotesTextView!.userInteractionEnabled = false
                totalVotesTextView!.isSelectable = false
                addSubview(totalVotesTextView!)
            }
            guard let totalVotesTextView = self.totalVotesTextView else {
                return
            }
            totalVotesTextView.update(totalVotesText, origin: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - totalVotesText.layoutSize.width) / 2), y))
        } else {
            totalVotesTextView?.removeFromSuperview()
            totalVotesTextView = nil
        }
        
        if let actionText = item.actionButtonText {
            y += item.defaultContentInnerInset - 4
            if self.actionButton == nil {
                self.actionButton = TextButton()
                self.addSubview(self.actionButton!)
            }
            guard let actionButton = self.actionButton else {
                return
            }
            
            actionButton.isEnabled = item.actionButtonIsEnabled
            
            actionButton.removeAllHandlers()
            
            
            actionButton.set(font: .normal(.text), for: .Normal)
            actionButton.set(color: item.presentation.chat.activityColor(item.isIncoming, item.isBubbled), for: .Normal)
            actionButton.set(text: actionText, for: .Normal)
            _ = actionButton.sizeToFit(NSMakeSize(10, 4), thatFit: false)
            actionButton.centerX(y: y)
        } else {
            self.actionButton?.removeFromSuperview()
            self.actionButton = nil
        }

    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
