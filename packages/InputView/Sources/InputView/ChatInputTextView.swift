import Foundation
import AppKit
import TGUIKit
import ColorPalette

private enum InputViewSubviewDestination {
    case below
    case above
}


@objc public class InputViewUndoItem : NSObject {
    var was: NSAttributedString
    var be: NSAttributedString
    var wasRange: NSRange
    var beRange: NSRange

    public init(was: NSAttributedString, be: NSAttributedString, wasRange: NSRange, beRange: NSRange) {
        self.was = was
        self.be = be
        self.wasRange = wasRange
        self.beRange = beRange
    }
}

private func isEnterEvent(_ theEvent: NSEvent) -> Bool {
    return (theEvent.keyCode == 0x24 || theEvent.keyCode ==  0x4C)
}

public struct ChatTextInputPresentation {
    public let text: NSColor
    public let accent: NSColor
    public let fontSize: CGFloat
    public init(text: NSColor, accent: NSColor, fontSize: CGFloat) {
        self.text = text
        self.accent = accent
        self.fontSize = fontSize
    }
}

public enum InputViewTransformReason {
    case attribute(NSAttributedString.Key)
    case url
    case clear
}

public protocol ChatInputTextViewDelegate: AnyObject {
    
    
    
    func chatInputTextViewDidUpdateText()
    func chatInputTextViewDidChangeSelection(dueToEditing: Bool)
    func chatInputTextViewDidBeginEditing()
    func chatInputTextViewDidFinishEditing()
        
    func chatInputTextView(shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func chatInputTextViewShouldCopy() -> Bool
    func chatInputTextViewShouldPaste() -> Bool
    
    func inputTextCanTransform() -> Bool
    func inputApplyTransform(_ reason: InputViewTransformReason, textRange: NSRange)
    func inputMaximumHeight() -> CGFloat
    
    func inputViewIsEnabled() -> Bool
    func inputViewProcessEnter(_ theEvent: NSEvent) -> Bool
    func inputViewMaybeClosed() -> Bool
}



private final class EmojiProviderView: View {
    
    struct Key: Hashable {
        var id: Int64
        var index: Int
    }
    
    fileprivate var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute, NSSize, InputViewTheme) -> NSView)?
    
    
    private var emojiLayers: [Key: NSView] = [:]
    
    override init() {
        super.init(frame: CGRect())
        isEventLess = true
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func update(emojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)], theme: InputViewTheme) {
        var nextIndexById: [Int64: Int] = [:]
        
        var validKeys = Set<Key>()
        for (rect, emoji) in emojiRects {
            let index: Int
            if let nextIndex = nextIndexById[emoji.fileId] {
                index = nextIndex
            } else {
                index = 0
            }
            nextIndexById[emoji.fileId] = index + 1
            
            let key = Key(id: emoji.fileId, index: index)
            
            let view: NSView
            if let current = self.emojiLayers[key] {
                view = current
            } else if let newView = self.emojiViewProvider?(emoji, rect.size, theme) {
                view = newView
                self.addSubview(newView)
                self.emojiLayers[key] = view
            } else {
                continue
            }
            
            let size = rect.size
            
            view.frame = CGRect(origin: CGPoint(x: floor(rect.midX - size.width / 2.0), y: floor(rect.midY - size.height / 2.0)), size: size)
            
            validKeys.insert(key)
        }
        
        var removeKeys: [Key] = []
        for (key, view) in self.emojiLayers {
            if !validKeys.contains(key) {
                removeKeys.append(key)
                view.removeFromSuperview()
            }
        }
        for key in removeKeys {
            self.emojiLayers.removeValue(forKey: key)
        }
    }
}


open class ChatInputTextView: ScrollView, NSTextViewDelegate {
    public weak var delegate: ChatInputTextViewDelegate? {
        didSet {
            self.textView.customDelegate = self.delegate
        }
    }
    
    private var selectionChangedForEditedText: Bool = false
    private var isPreservingSelection: Bool = false
    
    public let textView: InputTextView
    
    private var placeholder: TextView? = nil
    public var placeholderString: NSAttributedString? = nil {
        didSet {
            updatePlaceholder(animated: false)
        }
    }
    
    
    private var emojiContent: EmojiProviderView
    public var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute, NSSize, InputViewTheme) -> NSView)? {
        get {
            return emojiContent.emojiViewProvider
        } set {
            emojiContent.emojiViewProvider = newValue
        }
    }

    
    private let containerView = View()
    
    public var selectedRange: NSRange {
        get {
            return self.textView.selectedRange
        } set(value) {
            if self.textView.selectedRange != value {
                self.textView.selectedRange = value
            }
        }
    }
    
    public var attributedText: NSAttributedString {
        get {
            return self.textView.attributedString()
        } set(value) {
            if self.textView.attributedString() != value {
                
                let selectedRange = self.textView.selectedRange;
                let preserveSelectedRange = selectedRange.location != self.textView.textStorage?.length
                
                self.textView.setAttributedString(value)
                
                if preserveSelectedRange {
                    self.isPreservingSelection = true
                    self.textView.selectedRange = selectedRange
                    self.isPreservingSelection = false
                }
                self.textView.updateTextContainerInset()
            }
        }
    }
    
    public func addUndoItem(_ item: InputViewUndoItem) {
        self.textView.addUndoItem(item)
        self.updatePlaceholder(animated: true)
    }
    
    public var textContainerInset: NSEdgeInsets {
        get {
            return self.textView.defaultTextContainerInset
        } set(value) {
            let targetValue = NSEdgeInsets(top: value.top, left: 0.0, bottom: value.bottom, right: 0.0)
            if self.textView.defaultTextContainerInset != value {
                self.textView.defaultTextContainerInset = targetValue
            }
        }
    }

    
    public var theme: InputViewTheme {
        get {
            return textView.theme
        } set {
            textView.theme = newValue
        }
    }

    public required override init(frame: CGRect) {
        self.emojiContent = .init()
        self.textView = InputTextView()
        super.init(frame: frame)
        containerView.frame = self.bounds
        textView.frame = self.bounds
        emojiContent.frame = self.bounds
        self.textView.delegate = self

        containerView.addSubview(textView)
        containerView.addSubview(emojiContent)
        self.documentView = containerView
        
        
        NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: textView, queue: nil, using: { [weak self] notification in
            self?.textDidChangeSelection(notification)
        })
        
        self.textView.updateEmojies = { [weak self] rects, theme in
            self?.emojiContent.update(emojiRects: rects, theme: theme)
        }

    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    public func textHeightForWidth(_ width: CGFloat) -> CGFloat {
        return self.textView.textHeightForWidth(width)
    }
    
    @objc public func textDidBeginEditing(_ notification: Notification) {
        self.delegate?.chatInputTextViewDidBeginEditing()
    }

    @objc public func textDidEndEditing(_ notification: Notification) {
        self.delegate?.chatInputTextViewDidFinishEditing()
    }
    

    @objc public func textDidChange(_ notification: Notification) {
        self.updatePlaceholder(animated: true)

        CATransaction.begin()
        self.selectionChangedForEditedText = true
        
        self.delegate?.chatInputTextViewDidUpdateText()
        
        self.textView.updateTextContainerInset()
        CATransaction.commit()
        
    }
    
    @objc public func textDidChangeSelection(_ notification: Notification) {
        if self.isPreservingSelection {
            return
        }
        self.selectionChangedForEditedText = false
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            self.delegate?.chatInputTextViewDidChangeSelection(dueToEditing: self.selectionChangedForEditedText)
        }
    }

    @objc public func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let delegate = self.delegate else {
            return true
        }
        return delegate.chatInputTextView(shouldChangeTextIn: range, replacementText: text)
    }
    
    public func updateLayout(size: CGSize, textHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let immediate = ContainedViewLayoutTransition.immediate
        let contentRect = CGRect(origin: .zero, size: NSMakeSize(size.width, textHeight))
        immediate.updateFrame(view: self.containerView, frame: contentRect)
        immediate.updateFrame(view: self.textView, frame: contentRect)
        
        immediate.updateFrame(view: emojiContent, frame: contentRect)

        if let placeholder = self.placeholder {
            placeholder.resize(size.width)
            transition.updateFrame(view: placeholder, frame: placeholder.centerFrameY(x: 0))
        }
        
        self.textView.updateLayout(size: size)
    }
    
    private func updatePlaceholder(animated: Bool) {
        if let placeholderString = placeholderString, self.attributedText.string.isEmpty {
            let current: TextView
            let isNew: Bool
            if let view = self.placeholder {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.placeholder = current
                containerView.addSubview(current, positioned: .below, relativeTo: containerView.subviews.first)
                isNew = true
            }
            let layout = TextViewLayout(placeholderString)
            layout.measure(width: frame.width)
            current.update(layout)
            current.centerY(x: 0)
            
            if animated, isNew {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.layer?.animatePosition(from: current.frame.origin.offsetBy(dx: 20, dy: 0), to: current.frame.origin)
            }
        } else if let view = self.placeholder {
            performSubviewPosRemoval(view, pos: NSMakePoint(20, view.frame.minY), animated: animated)
            if animated {
                view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
            }
            self.placeholder = nil
        }
    }
}


private final class ChatInputTextContainer: NSTextContainer {
    override var isSimpleRectangularTextContainer: Bool {
        return false
    }
    
    override init(size: CGSize) {
        super.init(size: size)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func lineFragmentRect(forProposedRect proposedRect: CGRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection, remaining remainingRect: UnsafeMutablePointer<CGRect>?) -> CGRect {
        var result = super.lineFragmentRect(forProposedRect: proposedRect, at: characterIndex, writingDirection: baseWritingDirection, remaining: remainingRect)
        
        result.origin.x -= 5.0
        result.size.width -= 5.0
        
        if let textStorage = self.layoutManager?.textStorage {
            let string: NSString = textStorage.string as NSString
            let index = Int(characterIndex)
            if index >= 0 && index < string.length {
                let attributes = textStorage.attributes(at: index, effectiveRange: nil)
                let blockQuote = attributes[ChatTextInputAttributes.quote] as? NSObject
                if let blockQuote {
                    result.origin.x += 9.0
                    result.size.width -= 9.0
                    result.size.width -= 7.0
                    
                    var isFirstLine = false
                    if index == 0 {
                        isFirstLine = true
                    } else {
                        let previousAttributes = textStorage.attributes(at: index - 1, effectiveRange: nil)
                        let previousBlockQuote = previousAttributes[ChatTextInputAttributes.quote] as? NSObject
                        if let previousBlockQuote {
                            if !blockQuote.isEqual(previousBlockQuote) {
                                isFirstLine = true
                            }
                        } else {
                            isFirstLine = true
                        }
                    }
                    
                    if (isFirstLine) {
                        result.size.width -= 18.0
                    }
                }
            }
        }
        
        return result
    }
}

public final class InputTextView: NSTextView, NSLayoutManagerDelegate, NSTextStorageDelegate {
    
    
    
    public weak var customDelegate: ChatInputTextViewDelegate?
    
    fileprivate var ignoreNextDrawing: Bool = false
    
    public var theme: InputViewTheme = presentation.inputTheme {
        didSet {
            if self.theme != oldValue {
                self.updateTextElements()
            }
        }
    }
    
    
    var onRedraw:(()->Void)? = nil
    
    private let customTextContainer: ChatInputTextContainer
    private let customTextStorage: NSTextStorage
    private let customLayoutManager: NSLayoutManager
    
    private let measurementTextContainer: ChatInputTextContainer
    private let measurementTextStorage: NSTextStorage
    private let measurementLayoutManager: NSLayoutManager
    
    private var blockQuotes: [Int: QuoteBackgroundView] = [:]
    private var spoilers: [Int: SpoilerView] = [:]
    
    fileprivate var updateEmojies:(([(CGRect, ChatTextInputTextCustomEmojiAttribute)], InputViewTheme)->Void)?

    public var defaultTextContainerInset: NSEdgeInsets = NSEdgeInsets() {
        didSet {
            if self.defaultTextContainerInset != oldValue {
                self.updateTextContainerInset()
            }
        }
    }
    
    public init() {
        self.customTextContainer = ChatInputTextContainer(size: CGSize(width: 340, height: 100000.0))
        self.customLayoutManager = NSLayoutManager()
        self.customTextStorage = NSTextStorage()
        self.customTextStorage.addLayoutManager(self.customLayoutManager)
        self.customLayoutManager.addTextContainer(self.customTextContainer)
        
        self.measurementTextContainer = ChatInputTextContainer(size: CGSize(width: 340, height: 100000.0))
        self.measurementLayoutManager = NSLayoutManager()
        self.measurementTextStorage = NSTextStorage()
        self.measurementTextStorage.addLayoutManager(self.measurementLayoutManager)
        self.measurementLayoutManager.addTextContainer(self.measurementTextContainer)
        
        super.init(frame: CGRect(), textContainer: self.customTextContainer)
        
        self.textContainerInset = NSMakeSize(0, 0)
        
        self.drawsBackground = true
        self.backgroundColor = NSColor.red.withAlphaComponent(0.01)
        self.isRichText = false
        self.font = .normal(.text)
        
        self.allowsDocumentBackgroundColorChange = true
               
        
        self.allowsUndo = true
        
        self.isVerticallyResizable = false
        self.isHorizontallyResizable = false

        
        self.customTextContainer.widthTracksTextView = false
        self.customTextContainer.heightTracksTextView = false
        
        self.measurementTextContainer.widthTracksTextView = false
        self.measurementTextContainer.heightTracksTextView = false
        
        self.customLayoutManager.delegate = self
        self.measurementLayoutManager.delegate = self
        
        self.customTextStorage.delegate = self
        self.measurementTextStorage.delegate = self
        
        self.updateTextElements()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func copy(_ sender: Any?) {
        super.copy(sender)
    }
    
    override public func paste(_ sender: Any?) {
        super.paste(sender)
    }
    
    public func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingBeforeGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: NSRect) -> CGFloat {
        guard let textStorage = layoutManager.textStorage else {
            return 0.0
        }
        let characterIndex = Int(layoutManager.characterIndexForGlyph(at: glyphIndex))
        if characterIndex < 0 || characterIndex >= textStorage.length {
            return 0.0
        }
        
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        guard let blockQuote = attributes[ChatTextInputAttributes.quote] as? NSObject else {
            return 0.0
        }
        
        if characterIndex != 0 {
            let previousAttributes = textStorage.attributes(at: characterIndex - 1, effectiveRange: nil)
            let previousBlockQuote = previousAttributes[ChatTextInputAttributes.quote] as? NSObject
            if let previousBlockQuote, blockQuote.isEqual(previousBlockQuote) {
                return 0.0
            }
        }
        
        return 8.0
    }
    
    
    
    public func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: NSRect) -> CGFloat {
        guard let textStorage = layoutManager.textStorage else {
            return 0.0
        }
        var characterIndex = Int(layoutManager.characterIndexForGlyph(at: glyphIndex))
        characterIndex -= 1
        if characterIndex < 0 {
            characterIndex = 0
        }
        if characterIndex < 0 || characterIndex >= textStorage.length {
            return 0.0
        }
        
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        guard let blockQuote = attributes[ChatTextInputAttributes.quote] as? NSObject else {
            return 0.0
        }
        
        if characterIndex + 1 < textStorage.length {
            let nextAttributes = textStorage.attributes(at: characterIndex + 1, effectiveRange: nil)
            let nextBlockQuote = nextAttributes[ChatTextInputAttributes.quote] as? NSObject
            if let nextBlockQuote, blockQuote.isEqual(nextBlockQuote) {
                return 0.0
            }
        }
        
        return 8
    }
    
    
    public func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        if textContainer !== self.customTextContainer {
            return
        }
        self.updateTextElements()
    }
    
    public func updateTextContainerInset() {
        
        var result = self.defaultTextContainerInset
        if self.customTextStorage.length != 0 {
            let topAttributes = self.customTextStorage.attributes(at: 0, effectiveRange: nil)
            let bottomAttributes = self.customTextStorage.attributes(at: self.customTextStorage.length - 1, effectiveRange: nil)
            
            if topAttributes[ChatTextInputAttributes.quote] != nil {
                result.bottom += 8.0
            }
            if bottomAttributes[ChatTextInputAttributes.quote] != nil {
                result.bottom += 8.0
            }
        }
        
        self.customLayoutManager.ensureLayout(for: self.customTextContainer)
        self.updateTextElements()
    }
    
    var insets: NSEdgeInsets {
        var result = self.defaultTextContainerInset
        if self.customTextStorage.length != 0 {
            let topAttributes = self.customTextStorage.attributes(at: 0, effectiveRange: nil)
            let bottomAttributes = self.customTextStorage.attributes(at: self.customTextStorage.length - 1, effectiveRange: nil)
            
            if topAttributes[ChatTextInputAttributes.quote] != nil {
                result.bottom += 7.0
            }
            if bottomAttributes[ChatTextInputAttributes.quote] != nil {
                result.bottom += 8.0
            }
        }
        return result
    }
    
    public override var textContainerOrigin: NSPoint {
        return NSMakePoint(defaultTextContainerInset.left, 3)
    }
    
    public func textHeightForWidth(_ width: CGFloat) -> CGFloat {
        let measureSize = CGSize(width: width, height: 1000000.0)
        
        if self.measurementTextStorage != self.attributedString() || self.measurementTextContainer.size != measureSize {
            self.measurementTextStorage.setAttributedString(self.attributedString())
            self.measurementTextContainer.size = measureSize
            self.measurementLayoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.measurementTextStorage.length), actualCharacterRange: nil)
            self.measurementLayoutManager.ensureLayout(for: self.measurementTextContainer)
        }
        
        var textSize = self.measurementLayoutManager.usedRect(for: self.measurementTextContainer).size
        
        if string.isEmpty {
            textSize.height += 2
        }
        return textSize.height + insets.top + insets.bottom + self.textContainerOrigin.y * 2
    }
    
    public func updateLayout(size: CGSize) {
        let measureSize = CGSize(width: size.width, height: 1000000.0)
        
        if self.textContainer?.size != measureSize {
            self.textContainer?.size = measureSize
            self.customLayoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.customTextStorage.length), actualCharacterRange: nil)
            self.customLayoutManager.ensureLayout(for: self.customTextContainer)
        }
    }
    
    public func setAttributedString(_ attributedString: NSAttributedString) {
        self.customTextStorage.setAttributedString(attributedString)
    }
    
    
    public func updateTextElements() {
        
        self.insertionPointColor = theme.indicatorColor
        self.backgroundColor = theme.backgroundColor.withAlphaComponent(0.01)
        self.selectedTextAttributes = [.backgroundColor : theme.selectingColor]

                
        self.validateBlockQuotes()
        self.validateSpoilers()
        self.validateEmojies()
    }
    
    
    
    private func validateEmojies() {
        
        let textStorage = self.customTextStorage
        var rects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)] = []

        textStorage.enumerateAttributes(in: NSMakeRange(0, textStorage.length), options: [], using: { attributes, range, _ in
            if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                
                if attributes[ChatTextInputAttributes.spoiler] == nil {
                    let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                    } else {
                        return
                    }

                    var boundingRect = self.customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: self.customTextContainer)
                    boundingRect.origin.y += self.textContainerOrigin.y
                    rects.append((boundingRect, value))
                }
            }
        })
        
        self.updateEmojies?(rects, theme)
    }
    
    private func validateSpoilers() {
        var index = 0
        var valid: [Int] = []
        
        let textStorage = self.customTextStorage

        
        textStorage.enumerateAttribute(ChatTextInputAttributes.spoiler, in: NSRange(location: 0, length: textStorage.length), using: { value, range, _ in
            if let value {
                let _ = value
                
                let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                } else {
                    return
                }
                
                let id = index
                
                let spoiler: SpoilerView
                if let current = self.spoilers[id] {
                    spoiler = current
                } else {
                    spoiler = SpoilerView(frame: .zero)
                    self.spoilers[id] = spoiler
                    self.addSubview(spoiler)
                }
                
                var boundingRect = self.customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: self.customTextContainer)
                boundingRect.origin.y += self.textContainerOrigin.y
                spoiler.frame = boundingRect
                spoiler.update(size: boundingRect.size, theme: theme)

                valid.append(index)
                index += 1
            }
        })
        
        var removedSpoilers: [Int] = []
        for (id, spoiler) in self.spoilers {
            if !valid.contains(id) {
                removedSpoilers.append(id)
                spoiler.removeFromSuperview()
            }
        }
        for id in removedSpoilers {
            self.spoilers.removeValue(forKey: id)
        }
    }
    
    private func validateBlockQuotes() {
        var blockQuoteIndex = 0
        var validBlockQuotes: [Int] = []
        
        let textStorage = self.customTextStorage

        
        textStorage.enumerateAttribute(ChatTextInputAttributes.quote, in: NSRange(location: 0, length: textStorage.length), using: { value, range, _ in
            if let value {
                let _ = value
                
                let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                } else {
                    return
                }
                
                let id = blockQuoteIndex
                
                let blockQuote: QuoteBackgroundView
                if let current = self.blockQuotes[id] {
                    blockQuote = current
                } else {
                    blockQuote = QuoteBackgroundView(frame: .zero)
                    self.blockQuotes[id] = blockQuote
                    self.superview?.subviews.insert(blockQuote, at: 0)
                }
                
                var boundingRect = CGRect()
                var startIndex = glyphRange.lowerBound
                while startIndex < glyphRange.upperBound {
                    var effectiveRange = NSRange(location: NSNotFound, length: 0)
                    let rect = self.customLayoutManager.lineFragmentUsedRect(forGlyphAt: startIndex, effectiveRange: &effectiveRange)
                    if boundingRect.isEmpty {
                        boundingRect = rect
                    } else {
                        boundingRect = boundingRect.union(rect)
                    }
                    if effectiveRange.location != NSNotFound {
                        startIndex = max(startIndex + 1, effectiveRange.upperBound)
                    } else {
                        break
                    }
                }
                //     boundingRect.origin.y += 5.0
                
                boundingRect.origin.x -= 3.0
                boundingRect.size.width += 9.0
                boundingRect.size.width += 18.0
                boundingRect.size.width = min(boundingRect.size.width, self.bounds.width - 18.0)
                
                boundingRect.origin.y -= (4.0 - self.textContainerOrigin.y)
                boundingRect.size.height += 8.0
                
                blockQuote.frame = boundingRect
                blockQuote.update(size: boundingRect.size, theme: theme.quote)


                
                validBlockQuotes.append(blockQuoteIndex)
                blockQuoteIndex += 1
            }
        })
        
        var removedBlockQuotes: [Int] = []
        for (id, blockQuote) in self.blockQuotes {
            if !validBlockQuotes.contains(id) {
                removedBlockQuotes.append(id)
                blockQuote.removeFromSuperview()
            }
        }
        for id in removedBlockQuotes {
            self.blockQuotes.removeValue(forKey: id)
        }
    }
    
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        var removeItems = [NSMenuItem]()
        var addedTransformations = false

        menu?.appearance = self.appearance

        menu?.items.enumerated().forEach { (idx, item) in
            if item.action == NSSelectorFromString("submenuAction:") {
                item.submenu?.items.enumerated().forEach { (subIdx, subItem) in
                    if subItem.action == NSSelectorFromString("_shareServiceSelected:")
                        || subItem.action == NSSelectorFromString("orderFrontFontPanel:")
                        || subItem.action == NSSelectorFromString("orderFrontSubstitutionsPanel:")
                        || subItem.action == NSSelectorFromString("changeLayoutOrientation:") {
                        removeItems.append(item)
                    } else if subItem.action == #selector(capitalizeWord(_:)) {
                        addedTransformations = true
                        if self.selectedRange.length > 0 {
                            if self.customDelegate?.inputTextCanTransform() == true {
                                self.transformItems.enumerated().forEach { (transformIdx, obj) in
                                    item.submenu?.insertItem(obj, at: transformIdx)
                                }
                                item.submenu?.insertItem(NSMenuItem.separator(), at: self.transformItems.count)
                            }
                        }
                    }
                }
            }
        }

        if !addedTransformations {
            if self.selectedRange.length > 0 {
                if self.customDelegate?.inputTextCanTransform() == true {
                    let sep = NSMenuItem.separator()
                    menu?.addItem(sep)

                    let item = NSMenuItem(title: NSLocalizedString("Text.View.Transformations", comment: ""), action: nil, keyEquivalent: "")
                    item.submenu = NSMenu()
                    self.transformItems.enumerated().forEach { (transformIdx, obj) in
                        item.submenu?.insertItem(obj, at: transformIdx)
                    }
                    menu?.addItem(item)
                }
            }
        }

        removeItems.forEach { item in
            if menu?.items.contains(item) == true {
                menu?.removeItem(item)
            }
        }
        return menu
    }
    

    var transformItems: [NSMenuItem] {
        let bold = NSMenuItem(title: NSLocalizedString("TextView.Transform.Bold", comment: ""), action: #selector(makeBold(_:)), keyEquivalent: "b")
        bold.keyEquivalentModifierMask = .command

        let italic = NSMenuItem(title: NSLocalizedString("TextView.Transform.Italic", comment: ""), action: #selector(makeItalic(_:)), keyEquivalent: "i")
        italic.keyEquivalentModifierMask = .command

        let code = NSMenuItem(title: NSLocalizedString("TextView.Transform.Code", comment: ""), action: #selector(makeCode(_:)), keyEquivalent: "k")
        code.keyEquivalentModifierMask = [.shift, .command]

        let url = NSMenuItem(title: NSLocalizedString("TextView.Transform.URL1", comment: ""), action: #selector(makeUrl(_:)), keyEquivalent: "u")
        url.keyEquivalentModifierMask = .command

        let strikethrough = NSMenuItem(title: NSLocalizedString("TextView.Transform.Strikethrough", comment: ""), action: #selector(makeStrikethrough(_:)), keyEquivalent: "x")
        strikethrough.keyEquivalentModifierMask = [.shift, .command]

        let underline = NSMenuItem(title: NSLocalizedString("TextView.Transform.Underline", comment: ""), action: #selector(makeUnderline(_:)), keyEquivalent: "u")
        underline.keyEquivalentModifierMask = [.shift, .command]

        let spoiler = NSMenuItem(title: NSLocalizedString("TextView.Transform.Spoiler", comment: ""), action: #selector(makeSpoiler(_:)), keyEquivalent: "p")
        spoiler.keyEquivalentModifierMask = [.shift, .command]

        let quote = NSMenuItem(title: NSLocalizedString("TextView.Transform.Quote", comment: ""), action: #selector(makeQuote(_:)), keyEquivalent: "i")
        quote.keyEquivalentModifierMask = [.shift, .command]

        let removeAll = NSMenuItem(title: NSLocalizedString("TextView.Transform.RemoveAll", comment: ""), action: #selector(removeAll(_:)), keyEquivalent: "")
        
        return [removeAll, NSMenuItem.separator(), strikethrough, underline, spoiler, code, italic, bold, url, quote]
    }
    
    @objc private func makeBold(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.bold), textRange: self.selectedRange())
    }
    @objc private func makeItalic(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.italic), textRange: self.selectedRange())
    }
    @objc private func makeCode(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.monospace), textRange: self.selectedRange())
    }
    @objc private func makeUrl(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.url, textRange: self.selectedRange())
    }
    @objc private func makeStrikethrough(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.strikethrough), textRange: self.selectedRange())
    }
    @objc private func makeUnderline(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.underline), textRange: self.selectedRange())
    }
    @objc private func makeSpoiler(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.spoiler), textRange: self.selectedRange())
    }
    @objc private func makeQuote(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(ChatTextInputAttributes.quote), textRange: self.selectedRange())
    }
    @objc private func removeAll(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.clear, textRange: self.selectedRange())
    }
    
    @objc func addUndoItem(_ item: InputViewUndoItem) {
        self.undoManager?.registerUndo(withTarget: self, selector: #selector(removeUndoItem(_:)), object: item)
        if !(self.undoManager?.isUndoing ?? false) {
            self.undoManager?.setActionName(NSLocalizedString("actions.add-item", comment: "Add Item"))
        }
        self.textStorage?.setAttributedString(item.be)
        self.setSelectedRange(item.beRange)
    }

    @objc func removeUndoItem(_ item: InputViewUndoItem) {
        self.undoManager?.registerUndo(withTarget: self, selector: #selector(addUndoItem(_:)), object: item)
        if !(self.undoManager?.isUndoing ?? false) {
            self.undoManager?.setActionName(NSLocalizedString("actions.remove-item", comment: "Remove Item"))
        }
        self.textStorage?.setAttributedString(item.was)
        self.setSelectedRange(item.wasRange)
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        
        super.draw(dirtyRect)
        onRedraw?()
    }
    
    public override func keyDown(with theEvent: NSEvent) {
        if let delegate = self.customDelegate {
            if delegate.inputViewIsEnabled() {
                
                if isEnterEvent(theEvent) && !self.hasMarkedText() {
                    
                    let result = delegate.inputViewProcessEnter(theEvent)
                    
                    if (!result && (theEvent.modifierFlags.contains(.command) || theEvent.modifierFlags.contains(.shift))) {
                        super.insertNewline(self)
                        return
                    }
                    
                    if result {
                        return
                    }
                } else if theEvent.keyCode == 53, delegate.inputViewMaybeClosed() {
                    return
                }
                
                if !theEvent.modifierFlags.contains(.command) || !isEnterEvent(theEvent) {
                    super.keyDown(with: theEvent)
                }
            } else {
                super.keyDown(with: theEvent)
            }
        } else {
            super.keyDown(with: theEvent)
        }
    }
    
    fileprivate func highlightRect(forRange aRange: NSRange, whole: Bool) -> NSRect {
        if aRange.location > self.string.count || self.string.isEmpty {
            return NSZeroRect
        }
        
        var r = aRange
        let startLineRange = (self.string as NSString).lineRange(for: NSRange(location: r.location, length: 0))
        var er = NSMaxRange(r) - 1
        let text = self.string
        
        if er >= text.count {
            return NSZeroRect
        }
        
        if er < r.location {
            er = r.location
        }
        
        let gr = self.customLayoutManager.glyphRange(forCharacterRange: aRange, actualCharacterRange: nil)
        var br = self.customLayoutManager.boundingRect(forGlyphRange: gr, in: self.customTextContainer)
        let b = self.bounds
        var h = br.size.height
        var w: CGFloat = 0
        
        if whole {
            w = b.size.width
        } else {
            w = br.size.width
        }
        
        let y = br.origin.y
        let containerOrigin = self.textContainerOrigin
        var aRect = NSZeroRect
        
        if whole {
            aRect = NSMakeRect(0, y, w, h)
        } else {
            aRect = br
        }
        aRect = NSOffsetRect(aRect, containerOrigin.x, containerOrigin.y)
        
        return aRect
    }

}

private final class QuoteBackgroundView: View {
    private let lineLayer: SimpleLayer
    private let iconView: ImageView
    
    private var theme: InputViewTheme.Quote?
    
    var destination: InputViewSubviewDestination  {
        return .below
    }
    
    required init(frame: CGRect) {
        self.lineLayer = SimpleLayer()
        self.iconView = ImageView()
        
        super.init(frame: frame)
        
        self.layer?.addSublayer(self.lineLayer)
        self.addSubview(self.iconView)
        
        self.layer?.cornerRadius = 3.0
        self.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, theme: InputViewTheme.Quote) {
        if self.theme != theme {
            self.theme = theme
            
            self.backgroundColor = theme.background
            self.lineLayer.backgroundColor = theme.foreground.cgColor
            self.iconView.image = theme.icon.precomposed(theme.foreground)
            self.iconView.sizeToFit()
        }
            
        self.lineLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 00), size: CGSize(width: 3.0, height: size.height))
        self.iconView.frame = CGRect(origin: CGPoint(x: size.width - 4.0 - self.iconView.frame.width, y: 4.0), size: self.iconView.frame.size)
    }
    
}


private final class SpoilerView: View {
    private var theme: InputViewTheme?
    
    private let dustView: InvisibleInkDustView = InvisibleInkDustView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dustView)
        self.layer?.masksToBounds = false
        self.dustView.layer?.masksToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func update(size: CGSize, theme: InputViewTheme) {
        dustView.frame = size.bounds
        dustView.update(size: size, color: theme.textColor, textColor: .white, rects: [size.bounds], wordRects: [size.bounds.insetBy(dx: 2, dy: 2)])
    }
}

