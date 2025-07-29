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


private func optionRects(for items: [TodoItem], width: CGFloat, offset: CGFloat) -> [NSRect] {
    var result: [NSRect] = []
    var y: CGFloat = offset

    for (i, option) in items.enumerated() {
        if i > 0 {
            y += TodoItem.spaceBetweenOptions
        }
        let rect = NSMakeRect(0, y, width, option.contentSize.height)
        result.append(rect)
        y += option.contentSize.height
    }

    return result
}

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
    let author: TextViewLayout?
    let isSelected: Bool
    let isIncoming: Bool
    let isBubbled: Bool
    let isLoading: Bool
    let presentation: TelegramPresentationTheme
    let contentSize: NSSize
    let vote:(Control)-> Void
    let isTranslateLoading: Bool
    let canFinish: Bool
    init(option:TelegramMediaTodo.Item, nameText: TextViewLayout, author: TextViewLayout?, isSelected: Bool, canFinish: Bool, isIncoming: Bool, isBubbled: Bool, isLoading: Bool, presentation: TelegramPresentationTheme, vote: @escaping(Control)->Void = { _ in }, contentSize: NSSize = NSZeroSize, isTranslateLoading: Bool, peer: EnginePeer?) {
        self.option = option
        self.nameText = nameText
        self.author = author
        self.isSelected = isSelected
        self.canFinish = canFinish
        self.presentation = presentation
        self.isIncoming = isIncoming
        self.isBubbled = isBubbled
        self.isLoading = isLoading
        self.vote = vote
        self.contentSize = contentSize
        self.isTranslateLoading = isTranslateLoading
        self.peer = peer
    }
    
    func withUpdatedContentSize(_ contentSize: NSSize) -> TodoItem {
        return TodoItem(option: self.option, nameText: self.nameText, author: self.author, isSelected: self.isSelected, canFinish: self.canFinish, isIncoming: self.isIncoming, isBubbled: self.isBubbled, isLoading: self.isLoading, presentation: self.presentation, vote: self.vote, contentSize: contentSize, isTranslateLoading: self.isTranslateLoading, peer: self.peer)
    }
    func withUpdatedSelected(_ isSelected: Bool) -> TodoItem {
        return TodoItem(option: self.option, nameText: self.nameText, author: self.author, isSelected: isSelected, canFinish: self.canFinish, isIncoming: self.isIncoming, isBubbled: self.isBubbled, isLoading: self.isLoading, presentation: self.presentation, vote: self.vote, contentSize: self.contentSize, isTranslateLoading: self.isTranslateLoading, peer: self.peer)
    }
    
    static func ==(lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.option == rhs.option && lhs.isSelected == rhs.isSelected && lhs.canFinish == rhs.canFinish && lhs.isIncoming == rhs.isIncoming && lhs.isLoading == rhs.isLoading && lhs.contentSize == rhs.contentSize && lhs.isTranslateLoading == rhs.isTranslateLoading && lhs.peer == rhs.peer
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
        author?.measure(width: width - leftOptionInset)
        
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
        let canFinish = todo.flags.contains(.othersCanComplete) || message?.author?.id == context.peerId

        for (i, option) in todo.items.enumerated() {
            
            let isSelected: Bool = todo.completions.contains(where: { $0.id == option.id })
            let isGroup: Bool = todo.flags.contains(.othersCanComplete)
            let nameFont: NSFont = .normal(.text)
            let peerId = isGroup ? todo.completions.first(where: { $0.id == option.id })?.completedBy : nil
            
            let optionText = NSMutableAttributedString()
            optionText.append(string: option.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: nameFont)
            InlineStickerItem.apply(to: optionText, associatedMedia: message?.associatedMedia ?? [:], entities: option.entities, isPremium: context.isPremium)
            
            if !canFinish, isSelected {
                optionText.addAttribute(NSAttributedString.Key.strikethroughStyle, value: true, range: optionText.range)
                optionText.addAttribute(TextInputAttributes.strikethrough, value: true as NSNumber, range: optionText.range)
            }
            
            let nameLayout = TextViewLayout(optionText, alwaysStaticItems: true)
            
            let authorLayout: TextViewLayout?
            if isSelected, let completedBy = todo.completions.first(where: { $0.id == option.id }), isGroup {
                let peer = message?.peers[completedBy.completedBy]
                let color = self.presentation.chat.grayText(isIncoming, renderType == .bubble)
                authorLayout = .init(.initialize(string: peer?.displayTitle, color: color, font: .normal(.small)), maximumNumberOfLines: 1)
            } else {
                authorLayout = nil
            }
                        
            let wrapper = TodoItem(option: option, nameText: nameLayout, author: authorLayout, isSelected: isSelected, canFinish: canFinish, isIncoming: isIncoming, isBubbled: renderType == .bubble, isLoading: false, presentation: self.presentation, vote: { [weak self] control in
                self?.markCompleted(option, canFinish: canFinish, for: control)
            }, isTranslateLoading: isTranslateLoading, peer: peerId.flatMap { message?.peers[$0] }.flatMap(EnginePeer.init))
            
            options.append(wrapper)
        }
        self.options = options
        
        
        let totalText = strings().chatMessageTodoTotal("\(todo.completions.count)", "\(options.count)")

        self.totalVotesText = TextViewLayout(.initialize(string: totalText, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)


        let titleAttr = NSMutableAttributedString()
        titleAttr.append(string: todo.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: .medium(.text))
        
        InlineStickerItem.apply(to: titleAttr, associatedMedia: message?.associatedMedia ?? [:], entities: todo.textEntities, isPremium: context.isPremium)

        
        self.titleText = TextViewLayout(titleAttr, alwaysStaticItems: true)
        
        
        
        let title: String
        if todo.flags.contains(.othersCanComplete) {
            title = strings().chatMessageTodoTitleGroup
        } else {
            title = strings().chatMessageTodoTitleSingle
        }

        self.titleTypeText = TextViewLayout(.initialize(string: title, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)
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
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if let message = message, !context.isFrozen {
            
            var offset: CGFloat = 0
            
            offset += titleText.layoutSize.height + defaultContentInnerInset
            offset += titleTypeText.layoutSize.height + defaultContentInnerInset
            
            let source: ChatMenuItemSource
            let rects = optionRects(for: self.options, width: contentSize.width, offset: offset)
            
            if let index = rects.firstIndex(where: { NSPointInRect(location, $0) }) {
                source = .todo(taskId: options[index].option.id)
            } else {
                source = .general
            }
            
            return chatMenuItems(for: message, entry: entry, textLayout: nil, chatInteraction: chatInteraction, source: source)
        }
        return super.menuItems(in: location)
    }

    
    
    private func markCompleted(_ option: TelegramMediaTodo.Item, canFinish: Bool, for control: Control) {
        guard let message = message else { return }
        
        let context = self.context
        
        if message.forwardInfo != nil {
            showModalText(for: context.window, text: strings().chatMessageTodoEditForwardedError)
            return
        } else if !canFinish, let author = message.author {
            let title = strings().chatMessageTodoEditRestrictedError(author.displayTitle)
            showModalText(for: context.window, text: title)
            return
        } else if !context.isPremium {
            showModalText(for: context.window, text: strings().chatMessageTodoCompletePremium, callback: { _ in
                prem(with: PremiumBoardingController(context: context, source: .todo, openFeatures: true), for: context.window)
            })
            return
        }

        
        
        let completed = self.todo.completions.map { $0.id }
        let isCompleted = completed.contains(option.id)
        
        _ = context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: !isCompleted ? [option.id] : [], incompletedIds: isCompleted ? [option.id] : []).start()

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
    
    private var forceClearContentBackground: Bool = false

    
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
    
    
    private func highlightFrameAndColor(_ item: ChatRowTodoItem, option: TodoItem) -> (color: NSColor, frame: NSRect, flags: LayoutPositionFlags, superview: NSView) {
        
        let optionId = option.option.id
        
        var frame = contentNode.options.first(where: { $0.option?.option.id == optionId})?.frame ?? .zero
        let contentFrame = self.contentFrame(item)
        let bubbleFrame = self.bubbleFrame(item)
        
        frame.origin.y += contentFrame.minY - 2
        
        
        if item.hasBubble {
            
            frame.origin.x = 0
            frame.size.width = bubbleFrame.width
//                        
//           // frame.size.height += 8

            
            frame.origin.y = bubbleFrame.height - frame.maxY
            
            return (item.isIncoming ? item.presentation.colors.bubbleBackground_incoming.darker().withAlphaComponent(0.5) : item.presentation.colors.blendedOutgoingColors.darker().withAlphaComponent(0.5)
                , frame: frame, flags: [], superview: self.bubbleView)
        } else {
            
            frame.origin.x = 0
            frame.size.width = self.frame.width
//            frame.size.height += 8
            
            
//            if index == 0 {
//                frame.size.height += contentFrame.minY
//            } else if index == item.options.count - 1 {
//                frame.origin.y += contentFrame.minY
//                frame.size.height += contentFrame.minY
//            } else {
//                frame.origin.y += contentFrame.minY
//            }
//                        
//            frame.origin.y -= 4
            
            return (color: item.presentation.colors.accentIcon.withAlphaComponent(0.15), frame: frame, flags: [], superview: self.rowView)
        }

    }
    
    
    override func focusAnimation(_ innerId: AnyHashable?, text: String?) {
        
        if let innerId = innerId?.base as? Int32 {
            
            guard let item = item as? ChatRowTodoItem, let option = item.options.first(where: { $0.option.id == innerId }) else {return}
            
            let data = highlightFrameAndColor(item, option: option)
            
            let selectionBackground = CornerView()
            selectionBackground.isDynamicColorUpdateLocked = true
            selectionBackground.didChangeSuperview = { [weak selectionBackground, weak self] in
                self?.forceClearContentBackground = selectionBackground?.superview != nil
                self?.updateColors()
            }
            
            selectionBackground.frame = data.frame
            selectionBackground.backgroundColor = data.color
            
            var positionFlags: LayoutPositionFlags = data.flags
            
          
            selectionBackground.positionFlags = positionFlags
            data.superview.addSubview(selectionBackground)
                                
            let animation: CABasicAnimation = makeSpringAnimation("opacity")
            
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 0.5
            animation.isRemovedOnCompletion = false
            animation.delegate = CALayerAnimationDelegate(completion: { [weak selectionBackground] completed in
                if let selectionBackground = selectionBackground {
                    performSubviewRemoval(selectionBackground, animated: true, duration: 0.35, timingFunction: .spring)
                }
            })
            
            selectionBackground.layer?.add(animation, forKey: "opacity")
        } else {
            super.focusAnimation(innerId, text: text)
        }
    }
    

}


private final class TodoOptionView : Control {
    private let nameView: InteractiveTextView = InteractiveTextView(frame: .zero)
    private var authorView: TextView?
    private var selectingView:ImageView?
    private let progressView: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    private var progressIndicator: ProgressIndicator?
    private let borderView: View = View(frame: NSZeroRect)
    
    private var avatarView: AvatarControl?
    
    private(set) var option: TodoItem?
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
        
        self.scaleOnClick = true 
        
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
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate

        
        let duration: Double = 0.4
        let timingFunction: CAMediaTimingFunctionName = .spring
        
        nameView.set(text: option.nameText, context: context)
        
        nameView.textView.setIsShimmering(option.isTranslateLoading, animated: animated)
        
        borderView.backgroundColor = option.presentation.chat.pollOptionBorder(option.isIncoming, option.isBubbled)
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
        
        if option.canFinish {
            if option.isSelected {
                selectingView?.image = option.presentation.chat.pollSelection(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
            } else {
                selectingView?.image = option.presentation.chat.pollOptionUnselectedImage(option.isIncoming, option.isBubbled)
            }
        } else {
            if option.isSelected {
                selectingView?.image = option.presentation.chat.todoSelected(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
            } else {
                selectingView?.image = option.presentation.chat.todoSelection(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
            }
        }
        
        if let peer = option.peer, option.canFinish {
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
            if animated, isNew {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                current.centerY(x: defaultInset + 10)
            }
        } else if let view = self.avatarView {
            performSubviewRemoval(view, animated: animated, scale: true)
            self.avatarView = nil
        }
        
        if let author = option.author {
            let current: TextView
            let isNew: Bool
            if let view = self.authorView {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.authorView = current
                addSubview(current, positioned: .below, relativeTo: selectingView)
                isNew = true
            }
            
            current.update(author)
            if isNew {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.setFrameOrigin(NSMakePoint(option.leftOptionInset, nameView.frame.maxY))
            }
            
        } else if let view = self.authorView {
            performSubviewRemoval(view, animated: animated)
            self.authorView = nil
        }
        
        selectingView?.sizeToFit()
        
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        // Update nameView position
        
        guard let option else {
            return
        }
        
        transition.updateFrame(view: nameView, frame: nameView.centerFrameY(x: option.leftOptionInset, addition: authorView != nil ? -8 : 0))
        
        // Calculate new progressView position
        let progressViewOrigin = NSPoint(x: nameView.frame.minX, y: nameView.frame.maxY + 5)
        transition.updateFrame(view: progressView, frame: NSRect(origin: progressViewOrigin, size: progressView.frame.size))
        
        let borderFrame = NSRect(
            x: nameView.frame.minX,
            y: size.height - .borderSize,
            width: size.width - nameView.frame.minX,
            height: .borderSize
        )
        transition.updateFrame(view: borderView, frame: borderFrame)
        
        if let selectingView = selectingView {
            transition.updateFrame(view: selectingView, frame: selectingView.centerFrameY(x: defaultInset))
        }
        
        if let avatarView {
            transition.updateFrame(view: avatarView, frame: avatarView.centerFrameY(x: defaultInset + 10))
        }
        if let authorView {
            var rect = authorView.frame
            rect.origin = NSMakePoint(option.leftOptionInset, nameView.frame.maxY)
            transition.updateFrame(view: authorView, frame: rect)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
}

private final class TodoView : Control {
    fileprivate let titleView: InteractiveTextView = InteractiveTextView(frame: .zero)
    private let typeView: TextView = TextView()
    private var actionButton: TextButton?
    private var totalVotesTextView: TextView?
    
    

    private(set) var options:[TodoOptionView] = []
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
