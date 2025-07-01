import Foundation
import AppKit
import TGUIKit
import ColorPalette
import Localization

public extension InputTextView {
    static func rawTextHeight(for attributedString: NSAttributedString, width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        layoutManager.delegate = nil // no delegate needed for raw height
        
        let textContainer = ChatInputTextContainer(size: CGSize(width: width, height: 1000000.0))
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        // Force layout
        layoutManager.ensureLayout(for: textContainer)

        // Get text bounding height without any insets
        var textSize = layoutManager.usedRect(for: textContainer).size

        // Mimic InputTextView's "empty string" compensation
        if attributedString.string.isEmpty {
            textSize.height += 2
        }

        return ceil(textSize.height)
    }
}


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
    case toggleQuote(TextInputTextQuoteAttribute, NSRange)
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
    func inputTextSimpleTransform() -> Bool
    func inputApplyTransform(_ reason: InputViewTransformReason)
    func inputMaximumHeight() -> CGFloat
    func inputMaximumLenght() -> Int
    
    func inputViewIsEnabled(_ event: NSEvent) -> Bool
    func inputViewProcessEnter(_ theEvent: NSEvent) -> Bool
    func inputViewMaybeClosed() -> Bool
    
    func inputViewSupportsContinuityCamera() -> Bool
    func inputViewProcessPastepoard(_ pboard: NSPasteboard) -> Bool
    func inputViewCopyAttributedString(_ attributedString: NSAttributedString) -> Bool
    
    func inputViewRevealSpoilers()
    
    func inputViewResponderDidUpdate()
}



private final class EmojiProviderView: View {
    
    struct Key: Hashable {
        var id: Int64
        var index: Int
    }
    
    fileprivate var emojiViewProvider: ((TextInputTextCustomEmojiAttribute, NSSize, InputViewTheme) -> NSView)?
    
    
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
    
    func update(emojiRects: [(CGRect, TextInputTextCustomEmojiAttribute)], theme: InputViewTheme) {
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
    
    private let _undo: UndoManager = .init()

    
    public func undoManager(for view: NSTextView) -> UndoManager? {
        return _undo
    }
    
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
    public var emojiViewProvider: ((TextInputTextCustomEmojiAttribute, NSSize, InputViewTheme) -> NSView)? {
        get {
            return emojiContent.emojiViewProvider
        } set {
            emojiContent.emojiViewProvider = newValue
        }
    }
    
    public var emojis:[NSView] {
        return emojiContent.subviews
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
    
    public func highlight(for range: NSRange, whole: Bool) -> NSRect {
        return self.textView.highlightRect(forRange: range, whole: whole)
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
    
    public var inputView: NSTextView {
        return self.textView
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
        
        self.backgroundColor = .clear
        self.layer?.backgroundColor = NSColor.clear.cgColor

        
        NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: textView, queue: nil, using: { [weak self] notification in
            self?.textDidChangeSelection(notification)
        })
        
        self.textView.updateEmojies = { [weak self] rects, theme in
            self?.emojiContent.update(emojiRects: rects, theme: theme)
        }

        self.textView.shouldUpdateLayout = { [weak self] in
            guard let `self` = self else {
                return
            }
            self.updateLayout(size: self.frame.size, textHeight: self.textHeightForWidth(self.frame.width), transition: .immediate)
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
        let contentRect = CGRect(origin: .zero, size: NSMakeSize(size.width, max(textHeight, size.height)))
        immediate.updateFrame(view: self.containerView, frame: contentRect)
        
        let textRect: NSRect
        if textHeight < size.height {
            textRect = focus(NSMakeSize(size.width, textHeight))
        } else {
            textRect = contentRect
        }
        immediate.updateFrame(view: self.textView, frame: textRect)

        immediate.updateFrame(view: emojiContent, frame: textRect)

        if let placeholder = self.placeholder {
            placeholder.resize(size.width)
            transition.updateFrame(view: placeholder, frame: placeholder.centerFrameY(x: 0))
        }
        
        self.textView.updateLayout(size: size)
        
        self.verticalScrollElasticity = self.contentView.documentRect.height <= self.frame.height ? .none : .allowed
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
            let layout = TextViewLayout(placeholderString, maximumNumberOfLines: 1)
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
    
    public func scrollToCursor() {
        let lineRect = textView.highlightRect(forRange: NSRange(location: selectedRange.location + selectedRange.length, length: 0), whole: true)
        
        var maxY = self.contentView.documentRect.size.height
        maxY = min(max(lineRect.origin.y, 0), maxY - self.frame.size.height)
        
        let point = NSPoint(x: lineRect.origin.x, y: maxY)
        
        if !self.documentVisibleRect.contains(point) {
            self.contentView.scroll(to: point)
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
                let blockQuote = attributes[TextInputAttributes.quote] as? NSObject
                if let blockQuote = blockQuote {
                    result.origin.x += 9.0
                    result.size.width -= 9.0
                    result.size.width -= 7.0
                    
                    var isFirstLine = false
                    if index == 0 {
                        isFirstLine = true
                    } else {
                        let previousAttributes = textStorage.attributes(at: index - 1, effectiveRange: nil)
                        let previousBlockQuote = previousAttributes[TextInputAttributes.quote] as? NSObject
                        if let previousBlockQuote = previousBlockQuote {
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
    var shouldUpdateLayout:(()->Void)? = nil
    
    private let customTextContainer: ChatInputTextContainer
    private let customTextStorage: NSTextStorage
    private let customLayoutManager: NSLayoutManager
    
    private let measurementTextContainer: ChatInputTextContainer
    private let measurementTextStorage: NSTextStorage
    private let measurementLayoutManager: NSLayoutManager
    
    private var blockQuotes: [Int: QuoteBackgroundView] = [:]
    private var collapseQuotes: [Int : Control] = [:]
    private var spoilers: [Int: SpoilerView] = [:]
    
    fileprivate var updateEmojies:(([(CGRect, TextInputTextCustomEmojiAttribute)], InputViewTheme)->Void)?

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
   
    
    public func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingBeforeGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: NSRect) -> CGFloat {
        guard let textStorage = layoutManager.textStorage else {
            return 0.0
        }
        let characterIndex = Int(layoutManager.characterIndexForGlyph(at: glyphIndex))
        if characterIndex < 0 || characterIndex >= textStorage.length {
            return 0.0
        }
        
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        guard let blockQuote = attributes[TextInputAttributes.quote] as? NSObject else {
            return 0.0
        }
        
        if characterIndex != 0 {
            let previousAttributes = textStorage.attributes(at: characterIndex - 1, effectiveRange: nil)
            let previousBlockQuote = previousAttributes[TextInputAttributes.quote] as? NSObject
            if let previousBlockQuote = previousBlockQuote, blockQuote.isEqual(previousBlockQuote) {
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
        guard let blockQuote = attributes[TextInputAttributes.quote] as? NSObject else {
            return 0.0
        }
        
        if characterIndex + 1 < textStorage.length {
            let nextAttributes = textStorage.attributes(at: characterIndex + 1, effectiveRange: nil)
            let nextBlockQuote = nextAttributes[TextInputAttributes.quote] as? NSObject
            if let nextBlockQuote = nextBlockQuote, blockQuote.isEqual(nextBlockQuote) {
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
        self.customLayoutManager.ensureLayout(for: self.customTextContainer)
        self.display()
        self.updateTextElements()
    }
    
    var insets: NSEdgeInsets {
        var result = self.defaultTextContainerInset
        if self.customTextStorage.length != 0 {
            let topAttributes = self.customTextStorage.attributes(at: 0, effectiveRange: nil)
            let bottomAttributes = self.customTextStorage.attributes(at: self.customTextStorage.length - 1, effectiveRange: nil)
            
            if topAttributes[TextInputAttributes.quote] != nil {
                result.bottom += 7.0
            }
            if bottomAttributes[TextInputAttributes.quote] != nil {
                result.bottom += 8.0
            }
        }
        return result
    }
    
    public override var textContainerOrigin: NSPoint {
        return NSMakePoint(defaultTextContainerInset.left, 5)
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
        updateTextElements()
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
        var rects: [(CGRect, TextInputTextCustomEmojiAttribute)] = []

        textStorage.enumerateAttributes(in: NSMakeRange(0, textStorage.length), options: [], using: { attributes, range, _ in
            if let value = attributes[TextInputAttributes.customEmoji] as? TextInputTextCustomEmojiAttribute {
                
                if let spoiler = attributes[TextInputAttributes.spoiler] as? NSNumber {
                    if spoiler == 1 {
                        return
                    }
                }
                let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                } else {
                    return
                }

                var boundingRect = self.customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: self.customTextContainer)
                boundingRect.origin.y += self.textContainerOrigin.y
                rects.append((boundingRect, value))
            }
        })
        
        self.updateEmojies?(rects, theme)
    }
    
    private func validateSpoilers() {
        var index = 0
        var valid: [Int] = []
        
        let textStorage = self.customTextStorage

        
        textStorage.enumerateAttribute(TextInputAttributes.spoiler, in: NSRange(location: 0, length: textStorage.length), using: { value, range, _ in
            if let value = value as? NSNumber, value.intValue == 1 {
                
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
                if let delegate = self.customDelegate {
                    spoiler.set(delegate)
                }
                
                var wordRects:[[CGRect]] = []
                var line:[NSRect] = []
                var y: CGFloat = 0
                for i in range.min ..< range.max {
                    let current = NSMakeRange(i, 1)
                    let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: current, actualCharacterRange: nil)
                    let rect = self.highlightRect(forRange: glyphRange, whole: false)
                    if y == 0 {
                        y = rect.minY
                    }
                    if y != rect.minY {
                        wordRects.append(line)
                        line.removeAll()
                    }
                    line.append(rect.insetBy(dx: 0, dy: 2))
                    y = rect.minY
                }
                
                if !line.isEmpty {
                    wordRects.append(line)
                }
                
                var rects:[CGRect] = []
                for i in 0 ..< wordRects.count {
                    var current = wordRects[i]
                    let initial = current[0]
                    current.remove(at: 0)
                    rects.append(current.reduce(initial, { current, value in
                        var current = current
                        current.size.width += value.size.width
                        return current
                    }))
                }
                
              //  var boundingRect = self.customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: self.customTextContainer)
                
                
                var current = rects
                let initial = rects[0]
                current.remove(at: 0)
                var boundingRect = current.reduce(initial, { current, value in
                    var current = current
                    current.size.width += value.size.width
                    return current
                })
                
                boundingRect.origin.y += self.textContainerOrigin.y
                spoiler.frame = bounds
                
                
                
                
                spoiler.update(size: self.bounds.size, theme: theme, wordRects: rects)

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

        
        textStorage.enumerateAttribute(TextInputAttributes.quote, in: NSRange(location: 0, length: textStorage.length), using: { value, range, _ in
            if let value = value as? TextInputTextQuoteAttribute {
                
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
                
                let collapseQuote: Control
                if let current = self.collapseQuotes[id] {
                    collapseQuote = current
                } else {
                    collapseQuote = Control(frame: NSMakeRect(0, 0, 25, 20))
                    self.collapseQuotes[id] = collapseQuote
                    self.addSubview(collapseQuote)
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
                
                boundingRect.origin.y += self.textContainerOrigin.y

                boundingRect.origin.x -= 3.0
                boundingRect.size.width += 9.0
                boundingRect.size.width += 18.0
                boundingRect.size.width = min(boundingRect.size.width, self.bounds.width - 18.0)
                
                boundingRect.origin.y -= (4.0)
                boundingRect.size.height += 8.0
                
                blockQuote.frame = boundingRect.offsetBy(dx: 0, dy: frame.minY)


                let lineRect = highlightRect(forRange: NSMakeRange(range.location, 1), whole: true)
                blockQuote.collapsable = lineRect.height * 3 + 8 < boundingRect.height
                blockQuote.collapsed = value.collapsed
                
                blockQuote.update(size: boundingRect.size, theme: theme.quote)
                
                collapseQuote.setFrameOrigin(NSMakePoint(boundingRect.maxX - collapseQuote.frame.width, boundingRect.minY))
                
                collapseQuote.userInteractionEnabled = blockQuote.collapsable
                
                collapseQuote.removeAllHandlers()
                collapseQuote.set(handler: { [weak self] _ in
                    self?.customDelegate?.inputApplyTransform(.toggleQuote(value, range))
                }, for: .Click)
                
                
                validBlockQuotes.append(blockQuoteIndex)
                blockQuoteIndex += 1
                
            }
        })
        
        var removedBlockQuotes: [Int] = []
        var removedCollapseQuotes: [Int] = []
        for (id, blockQuote) in self.blockQuotes {
            if !validBlockQuotes.contains(id) {
                removedBlockQuotes.append(id)
                blockQuote.removeFromSuperview()
            }
        }
        for (id, collapseQuote) in self.collapseQuotes {
            if !validBlockQuotes.contains(id) {
                removedCollapseQuotes.append(id)
                collapseQuote.removeFromSuperview()
            }
        }
        for id in removedBlockQuotes {
            self.blockQuotes.removeValue(forKey: id)
        }
        for id in removedCollapseQuotes {
            self.collapseQuotes.removeValue(forKey: id)
        }

    }
    
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) as? NSMenu
        var removeItems = [NSMenuItem]()
        var addedTransformations = false

//        menu?.appearance = self.appearance

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

                    let item = NSMenuItem(title: _NSLocalizedString("Text.View.Transformations"), action: nil, keyEquivalent: "")
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
        
        let simpleTransform = self.customDelegate?.inputTextSimpleTransform() == true
        
        
        let bold = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Bold"), action: #selector(makeBold(_:)), keyEquivalent: "b")
        bold.keyEquivalentModifierMask = .command

        let italic = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Italic"), action: #selector(makeItalic(_:)), keyEquivalent: "i")
        italic.keyEquivalentModifierMask = .command

        let code = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Code"), action: #selector(makeCode(_:)), keyEquivalent: "k")
        code.keyEquivalentModifierMask = [.shift, .command]

        let url = NSMenuItem(title: _NSLocalizedString("TextView.Transform.URL1"), action: #selector(makeUrl(_:)), keyEquivalent: "u")
        url.keyEquivalentModifierMask = .command

        let strikethrough = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Strikethrough"), action: #selector(makeStrikethrough(_:)), keyEquivalent: "x")
        strikethrough.keyEquivalentModifierMask = [.shift, .command]

        let underline = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Underline"), action: #selector(makeUnderline(_:)), keyEquivalent: "u")
        underline.keyEquivalentModifierMask = [.shift, .command]

        
        let spoiler = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Spoiler"), action: #selector(makeSpoiler(_:)), keyEquivalent: "p")
        spoiler.keyEquivalentModifierMask = [.shift, .command]

        
        let quote = NSMenuItem(title: _NSLocalizedString("TextView.Transform.Quote"), action: #selector(makeQuote(_:)), keyEquivalent: "i")
        quote.keyEquivalentModifierMask = [.shift, .command]

        let removeAll = NSMenuItem(title: _NSLocalizedString("TextView.Transform.RemoveAll"), action: #selector(removeAll(_:)), keyEquivalent: "")
        
        var items: [NSMenuItem] = []
        items.append(removeAll)
        items.append(NSMenuItem.separator())
        if !simpleTransform {
            items.append(strikethrough)
            items.append(underline)
            items.append(spoiler)
            items.append(code)
        }
        items.append(italic)
        items.append(bold)
        items.append(url)
        if !simpleTransform {
            items.append(quote)
        }

        return items
    }
    
    @objc private func makeBold(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.bold))
    }
    @objc private func makeItalic(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.italic))
    }
    @objc private func makeCode(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.monospace))
    }
    @objc private func makeUrl(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.url)
    }
    @objc private func makeStrikethrough(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.strikethrough))
    }
    @objc private func makeUnderline(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.underline))
    }
    @objc private func makeSpoiler(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.spoiler))
    }
    @objc private func makeQuote(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.attribute(TextInputAttributes.quote))
    }
    @objc private func removeAll(_ id: Any) {
        self.customDelegate?.inputApplyTransform(.clear)
    }
    
    @objc func addUndoItem(_ item: InputViewUndoItem) {
        self.undoManager?.registerUndo(withTarget: self, selector: #selector(removeUndoItem(_:)), object: item)
        if !(self.undoManager?.isUndoing ?? false) {
            self.undoManager?.setActionName(NSLocalizedString("actions.add-item", comment: "Add Item"))
        }
        self.textStorage?.setAttributedString(item.be)
        self.setSelectedRange(item.beRange)
        self.shouldUpdateLayout?()
        self.updateTextContainerInset()
    }

    @objc func removeUndoItem(_ item: InputViewUndoItem) {
        self.undoManager?.registerUndo(withTarget: self, selector: #selector(addUndoItem(_:)), object: item)
        if !(self.undoManager?.isUndoing ?? false) {
            self.undoManager?.setActionName(NSLocalizedString("actions.remove-item", comment: "Remove Item"))
        }
        self.textStorage?.setAttributedString(item.was)
        self.setSelectedRange(item.wasRange)
        self.shouldUpdateLayout?()
        self.updateTextContainerInset()
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            return
        }
        
        ctx.setAllowsFontSubpixelPositioning(true)
        ctx.setShouldSubpixelPositionFonts(true)
        
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        
        ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
        ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
        
        super.draw(dirtyRect)
        onRedraw?()
    }
    
    public override func keyDown(with theEvent: NSEvent) {
        if let delegate = self.customDelegate {
            if delegate.inputViewIsEnabled(theEvent) {
                
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
            }
        } else {
            super.keyDown(with: theEvent)
        }
    }
    
    fileprivate func highlightRect(forRange aRange: NSRange, whole: Bool) -> NSRect {
        if aRange.location > self.string.length || self.string.isEmpty {
            return NSZeroRect
        }
        
        let r = aRange
        var er = NSMaxRange(r) - 1
        let text = self.string
        
        if er >= text.length {
            return NSZeroRect
        }
        
        if er < r.location {
            er = r.location
        }
        
        let gr = self.customLayoutManager.glyphRange(forCharacterRange: aRange, actualCharacterRange: nil)
        let br = self.customLayoutManager.boundingRect(forGlyphRange: gr, in: self.customTextContainer)
        let b = self.bounds
        let h = br.size.height
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
    
    public override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        guard let delegate = self.customDelegate else {
            return nil
        }
        if delegate.inputViewSupportsContinuityCamera(), let returnType = returnType, NSImage.imageTypes.contains(returnType.rawValue) {
            return self
        }
        return nil
    }
    
    public override func readSelection(from pboard: NSPasteboard) -> Bool {
        guard let delegate = self.customDelegate else {
            return super.readSelection(from: pboard)
        }
        if pboard.canReadItem(withDataConformingToTypes: NSImage.imageTypes) {
            return delegate.inputViewProcessPastepoard(pboard)
        } else {
            return super.readSelection(from: pboard)
        }
    }
    
    
    @objc override public func copy(_ sender: Any?) {
        guard let delegate = self.customDelegate else {
            return super.copy(sender)
        }
        if !delegate.inputViewCopyAttributedString(self.attributedString().attributedSubstring(from: self.selectedRange())) {
            super.copy(sender)
        }
    }
    
    @objc override public func paste(_ sender: Any?) {
        guard let delegate = self.customDelegate else {
            return super.paste(sender)
        }
        if !delegate.inputViewProcessPastepoard(NSPasteboard.general) {
            super.paste(sender)
        }
    }
    
    public override func becomeFirstResponder() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.customDelegate?.inputViewResponderDidUpdate()
        }
        return super.becomeFirstResponder()
    }
    public override func resignFirstResponder() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.customDelegate?.inputViewResponderDidUpdate()
        }
        return super.resignFirstResponder()
    }
    
    private var settingsKey: String {
        return "TGGrowingTextView"
    }

    public override var isContinuousSpellCheckingEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "ContinuousSpellCheckingEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ContinuousSpellCheckingEnabled\(settingsKey)")
            super.isContinuousSpellCheckingEnabled = newValue
        }
    }

    public override var isGrammarCheckingEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "GrammarCheckingEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "GrammarCheckingEnabled\(settingsKey)")
            super.isGrammarCheckingEnabled = newValue
        }
    }

    public override var isAutomaticSpellingCorrectionEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AutomaticSpellingCorrectionEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AutomaticSpellingCorrectionEnabled\(settingsKey)")
            super.isAutomaticSpellingCorrectionEnabled = newValue
        }
    }

    public override var isAutomaticQuoteSubstitutionEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AutomaticQuoteSubstitutionEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AutomaticQuoteSubstitutionEnabled\(settingsKey)")
            super.isAutomaticSpellingCorrectionEnabled = newValue
        }
    }

    public override var isAutomaticLinkDetectionEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AutomaticLinkDetectionEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AutomaticLinkDetectionEnabled\(settingsKey)")
            super.isAutomaticSpellingCorrectionEnabled = newValue
        }
    }

    public override var isAutomaticDataDetectionEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AutomaticDataDetectionEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AutomaticDataDetectionEnabled\(settingsKey)")
            super.isAutomaticSpellingCorrectionEnabled = newValue
        }
    }

    public override var isAutomaticDashSubstitutionEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AutomaticDashSubstitutionEnabled\(settingsKey)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AutomaticDashSubstitutionEnabled\(settingsKey)")
            super.isAutomaticSpellingCorrectionEnabled = newValue
        }
    }
}

private final class QuoteBackgroundView: View {
    
    private final class Background : View {
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
        }
        
        var colors:PeerNameColors.Colors = .init(main: NSColor.accent) {
            didSet {
                needsDisplay = true
            }
        }
        
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            
            let radius: CGFloat = 3.0
            let lineWidth: CGFloat = 3.0
            
            let blockFrame = self.bounds
            let tintColor = self.colors.main
            let secondaryTintColor = self.colors.secondary
            let tertiaryTintColor = self.colors.tertiary
            
            
            ctx.setFillColor(tintColor.withAlphaComponent(0.1).cgColor)
            ctx.addPath(CGPath(roundedRect: blockFrame, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
            
            ctx.setFillColor(tintColor.cgColor)
            
            
            let lineFrame = CGRect(origin: CGPoint(x: blockFrame.minX, y: blockFrame.minY), size: CGSize(width: lineWidth, height: blockFrame.height))
            ctx.move(to: CGPoint(x: lineFrame.minX, y: lineFrame.minY + radius))
            ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.minY), tangent2End: CGPoint(x: lineFrame.minX + radius, y: lineFrame.minY), radius: radius)
            ctx.addLine(to: CGPoint(x: lineFrame.minX + radius, y: lineFrame.maxY))
            ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY), tangent2End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY - radius), radius: radius)
            ctx.closePath()
            ctx.clip()
            
            if let secondaryTintColor = secondaryTintColor {
                let isMonochrome = secondaryTintColor.alpha == 0.2

                do {
                    ctx.saveGState()
                    
                    let dashHeight: CGFloat = tertiaryTintColor != nil ? 6.0 : 9.0
                    let dashOffset: CGFloat
                    if let _ = tertiaryTintColor {
                        dashOffset = isMonochrome ? -2.0 : 0.0
                    } else {
                        dashOffset = isMonochrome ? -4.0 : 5.0
                    }
                
                    if isMonochrome {
                        ctx.setFillColor(tintColor.withMultipliedAlpha(0.2).cgColor)
                        ctx.fill(lineFrame)
                        ctx.setFillColor(tintColor.cgColor)
                    } else {
                        ctx.setFillColor(tintColor.cgColor)
                        ctx.fill(lineFrame)
                        ctx.setFillColor(secondaryTintColor.cgColor)
                    }
                    
                    func drawDashes() {
                        ctx.translateBy(x: blockFrame.minX, y: blockFrame.minY + dashOffset)
                        
                        var offset = 0.0
                        while offset < blockFrame.height {
                            ctx.move(to: CGPoint(x: 0.0, y: 3.0))
                            ctx.addLine(to: CGPoint(x: lineWidth, y: 0.0))
                            ctx.addLine(to: CGPoint(x: lineWidth, y: dashHeight))
                            ctx.addLine(to: CGPoint(x: 0.0, y: dashHeight + 3.0))
                            ctx.closePath()
                            ctx.fillPath()
                            
                            ctx.translateBy(x: 0.0, y: 18.0)
                            offset += 18.0
                        }
                    }
                    
                    drawDashes()
                    ctx.restoreGState()
                    
                    if let tertiaryTintColor = tertiaryTintColor {
                        ctx.saveGState()
                        ctx.translateBy(x: 0.0, y: dashHeight)
                        if isMonochrome {
                            ctx.setFillColor(tintColor.withAlphaComponent(0.4).cgColor)
                        } else {
                            ctx.setFillColor(tertiaryTintColor.cgColor)
                        }
                        drawDashes()
                        ctx.restoreGState()
                    }
                }
            } else {
                ctx.setFillColor(tintColor.cgColor)
                ctx.fill(lineFrame)
            }
            
            ctx.resetClip()
        }
    }
    
//    private let lineLayer: SimpleLayer
    private let iconView: ImageView
    
    
    private var theme: InputViewTheme.Quote?
    
    var destination: InputViewSubviewDestination  {
        return .below
    }
    private let backgroundView = Background(frame: .zero)
    
    var collapsable: Bool = false
    var collapsed: Bool = false

    required init(frame: CGRect) {
//        self.lineLayer = SimpleLayer()
        self.iconView = ImageView()
        
        super.init(frame: frame)
        
        addSubview(backgroundView)
        
//        self.layer?.addSublayer(self.lineLayer)
        self.addSubview(self.iconView)
        
        self.layer?.cornerRadius = 4.0
       // self.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, theme: InputViewTheme.Quote) {
        if self.theme != theme || collapsable {
            self.theme = theme
            backgroundView.colors = theme.foreground
            if collapsable {
                if !collapsed {
                    self.iconView.image = theme.expand.precomposed(theme.foreground.main)
                } else {
                    self.iconView.image = theme.collapse.precomposed(theme.foreground.main)
                }
            } else {
                self.iconView.image = theme.icon.precomposed(theme.foreground.main)
            }
            self.iconView.sizeToFit()
        }
        

//        self.lineLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0), size: CGSize(width: 3.0, height: size.height))
        self.iconView.frame = CGRect(origin: CGPoint(x: size.width - 4.0 - self.iconView.frame.width, y: 4.0), size: self.iconView.frame.size)
        
        backgroundView.frame = size.bounds
    }
    
}


private final class SpoilerView: Control {
    private var theme: InputViewTheme?
    private weak var delegate: ChatInputTextViewDelegate?
    private let dustView: InvisibleInkDustView = InvisibleInkDustView()
    private var wordrects:[NSRect] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dustView)
        self.layer?.masksToBounds = false
        self.dustView.layer?.masksToBounds = false
        userInteractionEnabled = false
        
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let point = self.convert(event.locationInWindow, from: nil)

        let contains = self.wordrects.contains(where: {
            $0.contains(point)
        })
        if contains {
            self.delegate?.inputViewRevealSpoilers()
        }
    }

    
    func set(_ delegate: ChatInputTextViewDelegate) {
        self.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func update(size: CGSize, theme: InputViewTheme, wordRects: [NSRect]) {
        dustView.frame = size.bounds
        self.wordrects = wordRects
        dustView.update(size: size, color: theme.textColor, textColor: .white, rects: [size.bounds], wordRects: wordRects)
    }
    
    
}

