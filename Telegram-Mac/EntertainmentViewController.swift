//
//  EntertainmentViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox
import TGModernGrowingTextView


enum ESearchCommand {
    case loading
    case normal
    case close
    case clearText
    case apply(String)
}

open class EntertainmentSearchView: OverlayControl, NSTextViewDelegate {
    
    public private(set) var state:SearchFieldState = .None
    private(set) public var input:NSTextView = SearchTextField()
    
    private var lock:Bool = false
    
    private let clear:ImageButton = ImageButton()
    private let search:ImageView = ImageView()
    private let progressIndicator:ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 18, 18))
    private let placeholder:TextViewLabel = TextViewLabel()
    
    
    public let inset:CGFloat = 6
    public let leftInset:CGFloat = 20.0
    
    public var searchInteractions:SearchInteractions?
    
    private let _searchValue:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
    
    public var searchValue: Signal<SearchState, NoError> {
        return _searchValue.get()
    }
    public var shouldUpdateTouchBarItemIdentifiers: (()->[Any])?
    
    
    private let inputContainer = View()
    
    public var isLoading:Bool = false {
        didSet {
            if oldValue != isLoading {
                self.updateLoading()
                needsLayout = true
            }
        }
    }
    
    override open func updateLocalizationAndTheme(theme presentation: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        inputContainer.backgroundColor = .clear
        input.textColor = presentation.search.textColor
        input.backgroundColor = presentation.colors.background
        placeholder.attributedString = .initialize(string: presentation.search.placeholder(), color: presentation.search.placeholderColor, font: .normal(.title))
        placeholder.backgroundColor = presentation.colors.background
        self.backgroundColor = presentation.colors.background
        placeholder.sizeToFit()
        _ =  clear.sizeToFit()
        input.insertionPointColor = presentation.search.textColor
        progressIndicator.progressColor = presentation.colors.grayIcon
        needsLayout = true

        search.image = theme.icons.entertainment_Search
        search.sizeToFit()
        clear.set(image: theme.icons.entertainment_SearchCancel, for: .Normal)

        
    }
    
    open var startTextInset: CGFloat {
        return leftInset
    }
    
    open var placeholderTextInset: CGFloat {
        return startTextInset
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = .grayBackground
        if #available(OSX 10.12.2, *) {
            input.allowsCharacterPickerTouchBarItem = false
        }
        progressIndicator.isHidden = true
        input.focusRingType = .none
        input.autoresizingMask = [.width, .height]
        input.backgroundColor = NSColor.clear
        input.delegate = self
        input.isRichText = false
        
        input.textContainer?.widthTracksTextView = true
        input.textContainer?.heightTracksTextView = false
        
        input.isHorizontallyResizable = false
        input.isVerticallyResizable = false
        
        input.font = .normal(.title)
        input.textColor = .text
        input.isHidden = true
        input.drawsBackground = false
        
        input.setFrameSize(20, 18)
        
        placeholder.sizeToFit()
        self.border = [.Bottom]
        
        //self.addSubview(search)
        self.addSubview(placeholder)
        inputContainer.addSubview(input)
        addSubview(inputContainer)
        inputContainer.backgroundColor = .clear
        clear.backgroundColor = .clear
        
        
        clear.set(handler: { [weak self] _ in
            self?.cancelSearch()
            }, for: .Click)
        
        addSubview(clear)
        
        clear.isHidden = true
        
        
        self.set(handler: {[weak self] (event) in
            if let strongSelf = self {
                strongSelf.change(state: .Focus , true)
            }
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
        
        
        
        progressIndicator.set(handler: { [weak self] _ in
            self?.cancelSearch()
            }, for: .Click)
        
    }
    
    @available(OSX 10.12.2, *)
    public func textView(_ textView: NSTextView, shouldUpdateTouchBarItemIdentifiers identifiers: [NSTouchBarItem.Identifier]) -> [NSTouchBarItem.Identifier] {
        return self.shouldUpdateTouchBarItemIdentifiers?() as? [NSTouchBarItem.Identifier] ?? identifiers
    }
    
    open func cancelSearch() {
        if self.query.isEmpty {
            change(state: .None, true)
        } else {
            setString("")
        }
    }
    
    open func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if let trimmed = replacementString?.trimmed, trimmed.isEmpty, affectedCharRange.min == 0 && affectedCharRange.max == 0, textView.string.isEmpty {
            return false
        }
        if replacementString == "\n" {
            return false
        }
        return true
    }
    
    
    
    open func textDidChange(_ notification: Notification) {
        
        let trimmed = input.string.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r"))
        if trimmed != input.string {
            self.setString(trimmed)
            return
        }
        
        let value = SearchState(state: state, request: trimmed, responder: self.input == window?.firstResponder)
        searchInteractions?.textModified(value)
        _searchValue.set(value)
        
        
        let pHidden = !input.string.isEmpty
        if placeholder.isHidden != pHidden {
            placeholder.isHidden = pHidden
        }
        
        needsLayout = true
        
        let iHidden = !(state == .Focus && !input.string.isEmpty)
        if input.isHidden != iHidden {
            //  input.isHidden = iHidden
            window?.makeFirstResponder(input)
        }
    }
    
    open override func mouseUp(with event: NSEvent) {
        if isLoading {
            let point = convert(event.locationInWindow, from: nil)
            if NSPointInRect(point, progressIndicator.frame) {
                setString("")
            } else {
                super.mouseUp(with: event)
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    
    
    public func textViewDidChangeSelection(_ notification: Notification) {
        if let storage = input.textStorage {
            let size = storage.size()
            
            let inputInset = placeholderTextInset
            
            let defWidth = frame.width - inputInset - inset - clear.frame.width - 10
            //  input.sizeToFit()
            input.setFrameSize(max(size.width + 10, defWidth), size.height)
            // inputContainer.setFrameSize(inputContainer.frame.width, input.frame.height)
            if let layout = input.layoutManager, !input.string.isEmpty {
                let index = max(0, input.selectedRange().max - 1)
                let point = layout.location(forGlyphAt: layout.glyphIndexForCharacter(at: index))
                
                let additionalInset: CGFloat
                if index + 2 < input.string.length {
                    let nextPoint = layout.location(forGlyphAt: layout.glyphIndexForCharacter(at: index + 2))
                    additionalInset = nextPoint.x - point.x
                } else {
                    additionalInset = 8
                }
                
                if defWidth < size.width && point.x > defWidth {
                    input.setFrameOrigin(floorToScreenPixels(backingScaleFactor, defWidth - point.x - additionalInset), input.frame.minY)
                    if input.frame.maxX < inputContainer.frame.width {
                        input.setFrameOrigin(inputContainer.frame.width - input.frame.width + 4, input.frame.minY)
                    }
                } else {
                    input.setFrameOrigin(0, input.frame.minY)
                }
            } else {
                input.setFrameOrigin(0, input.frame.minY)
            }
            needsLayout = true
        }
    }
    
    open func textDidEndEditing(_ notification: Notification) {
        didResignResponder()
    }
    
    open func textDidBeginEditing(_ notification: Notification) {
        didBecomeResponder()
    }
    
    open var isEmpty: Bool {
        return query.isEmpty
    }
    
    open func didResignResponder() {
        let value = SearchState(state: state, request: self.query, responder: false)
        searchInteractions?.responderModified(value)
        _searchValue.set(value)
        if isEmpty {
            change(state: .None, true)
        }
        
        self._window?.removeAllHandlers(for: self)
        self._window?.removeObserver(for: self)
    }
    
    open func didBecomeResponder() {
        let value = SearchState(state: state, request: self.query, responder: true)
        searchInteractions?.responderModified(SearchState(state: state, request: self.query, responder: true))
        _searchValue.set(value)
        
        change(state: .Focus, true)
        
        self._window?.set(escape: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.changeResponder() ? .invoked : .rejected
            }
            return .rejected
            
        }, with: self, priority: .modal)
        
        self._window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
        }, with: self, for: .RightArrow, priority: .modal)
        
        self._window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
        }, with: self, for: .LeftArrow, priority: .modal)
        
        self._window?.set(responder: {[weak self] () -> NSResponder? in
            return self?.input
        }, with: self, priority: .modal)
    }
    
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    
    
    open func change(state:SearchFieldState, _ animated:Bool) -> Void {
        
        if state != self.state && !lock {
            self.state = state
            
            let text = input.string.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r"))
            let value = SearchState(state: state, request: state == .None ? nil : text, responder: self.input == window?.firstResponder)
            searchInteractions?.stateModified(value, animated)
            
            _searchValue.set(value)
            
            lock = true
            
            if state == .Focus {
                
                window?.makeFirstResponder(input)
                
                let inputInset = placeholderTextInset + 8
                
                inputContainer.setFrameSize(frame.width - inputInset - inset - clear.frame.width - 6, input.frame.height)
                inputContainer.centerY(x: inputInset)
                input.frame = inputContainer.bounds
                
                input.isHidden = false
                
                self.input.isHidden = false
                self.window?.makeFirstResponder(self.input)
                self.lock = false
                
                clear.isHidden = false
                clear.layer?.opacity = 1.0
   
            }
            
            if state == .None {
                
                self._window?.removeAllHandlers(for: self)
                self._window?.removeObserver(for: self)
                
                self.input.isHidden = true
                self.input.string = ""
                self.window?.makeFirstResponder(nil)
                self.placeholder.isHidden = false
                
                if animated {
                    
                    clear.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion:true, additive:false, completion: {[weak self] (complete) in
                        self?.clear.isHidden = true
                        self?.lock = false
                    })
                } else {
                    clear.isHidden = true
                    lock = false
                }
                
                clear.layer?.opacity = 0.0
            }
            updateLoading()
            self.needsLayout = true
        }
        
    }
    
    open override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            if isEmpty {
                change(state: .None, false)
            }
            self._window?.removeAllHandlers(for: self)
            self._window?.removeObserver(for: self)
        }
    }
    
    
    func updateLoading() {
        if isLoading && state == .Focus {
            if progressIndicator.superview == nil {
                addSubview(progressIndicator)
            }
            clear.isHidden = false
            progressIndicator.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            clear.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                if completed {
                    self?.clear.isHidden = true
                }
            })
            progressIndicator.isHidden = false
            progressIndicator.animates = true
        } else {
            progressIndicator.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                if completed {
                    self?.progressIndicator.isHidden = true
                }
            })
            clear.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            progressIndicator.animates = false
            progressIndicator.removeFromSuperview()
            clear.isHidden = self.state == .None
        }
        if window?.firstResponder == input {
            window?.makeFirstResponder(input)
        }
    }

    
    
    
    open override func layout() {
        super.layout()
        search.centerY(x: leftInset)
        placeholder.centerY(x: placeholderTextInset + 2)
        clear.centerY(x: frame.width - leftInset - clear.frame.width)
        progressIndicator.frame = NSMakeRect(clear.frame.minX + 2, clear.frame.minY + 2, self.clear.frame.width - 4, self.clear.frame.height - 4)
        inputContainer.centerY(x: placeholderTextInset, addition: 1)
    }
    
    public func changeResponder(_ animated:Bool = true) -> Bool {
        if state == .Focus {
            cancelSearch()
        } else {
            change(state: .Focus, animated)
        }
        return true
    }
    
    deinit {
        self._window?.removeAllHandlers(for: self)
        self._window?.removeObserver(for: self)
    }
    
    public var query:String {
        return self.input.string
    }
    
    open override func change(size: NSSize, animated: Bool = true, _ save: Bool = true, removeOnCompletion: Bool = false, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion: ((Bool) -> Void)? = nil) {
        super.change(size: size, animated: animated, save, duration: duration, timingFunction: timingFunction)
        clear.change(pos: NSMakePoint(frame.width - inset - clear.frame.width, clear.frame.minY), animated: animated)
    }
    
    
    public func setString(_ string:String) {
        self.input.string = string
        textDidChange(Notification(name: NSText.didChangeNotification))
        needsLayout = true
    }
    
    public func cancel(_ animated:Bool) -> Void {
        change(state: .None, animated)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}



public final class EntertainmentInteractions {
    
    var current:EntertainmentState = .emoji
    
    var sendEmoji:(String, CGRect?) ->Void = { _,_ in }
    var sendAnimatedEmoji:(StickerPackItem, StickerPackCollectionInfo?, Int32?, NSRect?) ->Void = { _, _, _, _ in}
    var sendSticker:(TelegramMediaFile, Bool, Bool, ItemCollectionId?) ->Void = { _, _, _, _ in}
    var sendGIF:(TelegramMediaFile, Bool, Bool) ->Void = { _, _, _ in}
    
    var showEntertainment:(EntertainmentState, Bool)->Void = { _,_  in}
    var close:()->Void = {}

    var toggleSearch:()->Void = { }
    
    var showStickerPremium:(TelegramMediaFile, NSView)->Void = { _, _ in }
    
    let peerId:PeerId
    
    init(_ defaultState: EntertainmentState, peerId:PeerId) {
        current = defaultState
        self.peerId = peerId
    }
}

final class EntertainmentView : View {
    fileprivate var sectionView: NSView
    private let bottomView = View()
    private let borderView = View()
    fileprivate let emoji: TextButton = TextButton()
    fileprivate let stickers: TextButton = TextButton()
    fileprivate let gifs: TextButton = TextButton()
    
    private var premiumView: StickerPremiumHolderView?

    
    private let sectionTabs: View = View()
    init(sectionView: NSView, frame: NSRect) {
        self.sectionView = sectionView
        super.init(frame: frame)
        self.bottomView.border = [.Top]
        self.addSubview(self.sectionView)
        addSubview(self.bottomView)
        self.bottomView.addSubview(sectionTabs)
        
        self.emoji.scaleOnClick = true
        self.emoji.autoSizeToFit = false
        
        self.stickers.scaleOnClick = true
        self.stickers.autoSizeToFit = false

        self.gifs.scaleOnClick = true
        self.gifs.autoSizeToFit = false
        
        self.sectionTabs.addSubview(self.emoji)
        self.sectionTabs.addSubview(self.stickers)
        self.sectionTabs.addSubview(self.gifs)
        
        self.bottomView.addSubview(self.borderView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.borderView.background = theme.colors.border
        
        self.emoji.set(font: .medium(.title), for: .Normal)
        self.emoji.set(color: theme.colors.grayIcon, for: .Normal)
        self.stickers.set(font: .medium(.title), for: .Normal)
        self.stickers.set(color: theme.colors.grayIcon, for: .Normal)
        self.gifs.set(font: .medium(.title), for: .Normal)
        self.gifs.set(color: theme.colors.grayIcon, for: .Normal)

        
        self.emoji.set(color: theme.colors.darkGrayText, for: .Highlight)
        self.stickers.set(color: theme.colors.darkGrayText, for: .Highlight)
        self.gifs.set(color: theme.colors.darkGrayText, for: .Highlight)

        self.emoji.set(background: theme.colors.background, for: .Normal)
        self.stickers.set(background: theme.colors.background, for: .Normal)
        self.gifs.set(background: theme.colors.background, for: .Normal)

        self.emoji.set(background: theme.colors.grayText.withAlphaComponent(0.2), for: .Highlight)
        self.stickers.set(background: theme.colors.grayText.withAlphaComponent(0.2), for: .Highlight)
        self.gifs.set(background: theme.colors.grayText.withAlphaComponent(0.2), for: .Highlight)

        
        self.emoji.set(text: strings().entertainmentEmojiNew, for: .Normal)
        self.stickers.set(text: strings().entertainmentStickersNew, for: .Normal)
        self.gifs.set(text: strings().entertainmentGIFNew, for: .Normal)
        
        _ = self.emoji.sizeToFit(NSMakeSize(10, 8))
        _ = self.stickers.sizeToFit(NSMakeSize(10, 8))
        _ = self.gifs.sizeToFit(NSMakeSize(10, 8))
        
        self.emoji.layer?.cornerRadius = self.emoji.frame.height / 2
        self.stickers.layer?.cornerRadius = self.emoji.frame.height / 2
        self.gifs.layer?.cornerRadius = self.emoji.frame.height / 2

    }
    
    func toggleSearch(_ signal:ValuePromise<SearchState>) {

    }
    
    func updateSelected(_ state: EntertainmentState, mode: EntertainmentViewController.Mode) {
        self.emoji.isSelected = false
        self.stickers.isSelected = false
        self.gifs.isSelected = false
        
        switch state {
        case .emoji:
            self.emoji.isSelected = true
        case .stickers:
            self.stickers.isSelected = true
        case .gifs:
            self.gifs.isSelected = true
        }
        emoji.isHidden = mode == .selectAvatar
        stickers.isHidden = false
        gifs.isHidden = false

        needsLayout = true
    }
    
    func previewPremium(_ file: TelegramMediaFile, context: AccountContext, view: NSView, animated: Bool) {
        let current: StickerPremiumHolderView
        if let view = premiumView {
            current = view
        } else {
            current = StickerPremiumHolderView(frame: bounds)
            self.premiumView = current
            addSubview(current)
            
            if animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
        current.set(file: file, context: context, callback: { [weak self] in
            showModal(with: PremiumBoardingController(context: context, source: .premium_stickers), for: context.window)
            self?.closePremium()
        })
        current.close = { [weak self] in
            self?.closePremium()
        }
    }
    
    var isPremium: Bool {
        return self.premiumView != nil
    }
    
    func closePremium() {
        if let view = premiumView {
            performSubviewRemoval(view, animated: true)
            self.premiumView = nil
        }
    }
    
    
    
    override func layout() {
        super.layout()
        self.sectionView.frame = NSMakeRect(0, 0, self.frame.width, self.frame.height - 50)
        self.bottomView.frame = NSMakeRect(0, self.frame.height - 50, self.frame.width, 50)
        self.borderView.frame = NSMakeRect(0, 0, self.bottomView.frame.width, .borderSize)
        
        let buttons:[NSView] = [self.emoji, self.stickers, self.gifs].filter { !$0.isHidden }
        
        self.sectionTabs.setFrameSize(NSMakeSize(buttons.reduce(0, { $0 + $1.frame.width }) + CGFloat(buttons.count - 1) * 4, 40))
        self.sectionTabs.center()
        
        var x: CGFloat = 0
        for button in buttons {
            button.centerY(x: x)
            x += button.frame.width + 4
        }
        self.premiumView?.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


class EntertainmentViewController: TelegramGenericViewController<EntertainmentView> {
    private let languageDisposable:MetaDisposable = MetaDisposable()

    private(set) weak var chatInteraction:ChatInteraction?
    private(set) var interactions:EntertainmentInteractions?
    private let cap:SidebarCapViewController
    
    private let section: SectionViewController

    private var disposable:MetaDisposable = MetaDisposable()
    private var locked:Bool = false

    enum Mode {
        case common
        case selectAvatar
        case stories
        case intro
    }
    
    private let mode: Mode

    private let emoji:EmojiesController
    private let stickers:NStickersViewController
    private let gifs:GifKeyboardController
    
    private let searchState = ValuePromise<SearchState>(.init(state: .None, request: nil))
    
    private var effectiveSearchView: SearchView? {
        if self.gifs.view.superview != nil  {
            return self.gifs.genericView.searchView
        }
        if self.emoji.view.superview != nil  {
            return self.emoji.genericView.searchView
        }
        if self.stickers.view.superview != nil  {
            return self.stickers.genericView.searchView
        }
        return nil
    }
    
    func update(with chatInteraction:ChatInteraction) -> Void {
        self.chatInteraction = chatInteraction
        
        let context = self.context
        
        let state: EntertainmentState
        if mode == .selectAvatar {
            state = .stickers
        } else {
            state = FastSettings.entertainmentState
        }
        
        let interactions = EntertainmentInteractions(state, peerId: chatInteraction.peerId)

        interactions.close = { [weak self] in
            self?.closePopover()
        }
        interactions.sendSticker = { [weak self] file, silent, scheduled, collectionId in
            let cachedData = self?.chatInteraction?.presentation.cachedData
            if let peer = self?.chatInteraction?.peer, let text = permissionText(from: peer, for: .banSendStickers, cachedData: cachedData) {
                showModalText(for: context.window, text: text)
            } else {
                self?.chatInteraction?.sendAppFile(file, silent, self?.effectiveSearchView?.query, scheduled, collectionId)
            }
            self?.closePopover()
        }
        interactions.sendGIF = { [weak self] file, silent, scheduled in
            let cachedData = self?.chatInteraction?.presentation.cachedData
            if let peer = self?.chatInteraction?.peer, let text = permissionText(from: peer, for: .banSendGifs, cachedData: cachedData) {
                showModalText(for: context.window, text: text)
            } else {
                self?.chatInteraction?.sendAppFile(file, silent, self?.effectiveSearchView?.query, scheduled, nil)
            }
            self?.closePopover()
        }
        interactions.sendEmoji = { [weak self] emoji, fromRect in
            if self?.mode == .selectAvatar {
                _ = self?.chatInteraction?.sendPlainText(emoji)
                self?.closePopover()
            } else {
                let cachedData = self?.chatInteraction?.presentation.cachedData
                if let peer = self?.chatInteraction?.peer, let text = permissionText(from: peer, for: .banSendText, cachedData: cachedData) {
                    showModalText(for: context.window, text: text)
                } else {
                    self?.chatInteraction?.appendAttributedText(.initialize(string: emoji))
                }
            }
        }
        
        interactions.sendAnimatedEmoji = { [weak self] sticker, info, _, fromRect in
            if self?.mode == .selectAvatar {
              
            } else {
                let cachedData = self?.chatInteraction?.presentation.cachedData
                if let peer = self?.chatInteraction?.peer, let text = permissionText(from: peer, for: .banSendText, cachedData: cachedData) {
                    showModalText(for: context.window, text: text)
                } else {
                    let text = (sticker.file.customEmojiText ?? sticker.file.stickerText ?? "😀").normalizedEmoji
                    self?.chatInteraction?.appendAttributedText(.makeAnimated(sticker.file, text: text, info: info?.id))
                }
            }
        }
        
        interactions.showStickerPremium = { [weak self] file, view in
            self?.genericView.previewPremium(file, context: context, view: view, animated: true)
        }
        
        interactions.toggleSearch = { [weak self] in
            guard let `self` = self else {
                return
            }
            self.toggleSearch()
        }
        self.interactions = interactions
        
        emoji.update(with: interactions, chatInteraction: chatInteraction)
        stickers.update(with: interactions, chatInteraction: chatInteraction)
        gifs.update(with: interactions, chatInteraction: chatInteraction)
    }
    

    func closedBySide() {
        self.viewWillDisappear(false)
    }
    
    private var presentation: TelegramPresentationTheme? = nil
    
    init(size:NSSize, context:AccountContext, mode: Mode = .common, presentation: TelegramPresentationTheme? = nil) {
        self.mode = mode
        self.presentation = presentation
        self.cap = SidebarCapViewController(context)
        self.emoji = EmojiesController(context, mode: mode == .stories ? .stories : .emoji, presentation: presentation)
        self.stickers = NStickersViewController(context, presentation: presentation)
        self.gifs = GifKeyboardController(context, presentation: presentation)

        
        self.stickers.mode = mode
        self.gifs.mode = mode
        
        var items:[SectionControllerItem] = []
        if mode == .common || mode == .stories {
            items.append(SectionControllerItem(title:{strings().entertainmentEmoji.uppercased()}, controller: emoji))
        }
        items.append(SectionControllerItem(title: {strings().entertainmentStickers.uppercased()}, controller: stickers))
        items.append(SectionControllerItem(title: {strings().entertainmentGIF.uppercased()}, controller: gifs))

        

        let index: Int
        if mode == .selectAvatar {
            index = 0
        } else {
            index = Int(FastSettings.entertainmentState.rawValue)
        }
        self.section = SectionViewController(sections: items, selected: index, hasHeaderView: false)
        super.init(context)
        _frameRect = size.bounds
        bar = .init(height: 0)
    }


    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.section.updateLocalizationAndTheme(theme: theme)
        self.view.background = theme.colors.background
        if emoji.isLoaded() {
            emoji.view.background = theme.colors.background
        }
        if stickers.isLoaded() {
            stickers.view.background = theme.colors.background
        }
        if gifs.isLoaded() {
            gifs.view.background = theme.colors.background
        }
    }
    
    deinit {
        languageDisposable.dispose()
        disposable.dispose()
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        section.viewWillAppear(animated)
        updateLocalizationAndTheme(theme: presentation ?? theme)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        section.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }

    
    
    private func toggleSearch() {
        if let searchView = self.effectiveSearchView {
            if searchView.state == .Focus {
                searchView.setString("")
                searchView.cancel(true)
            } else {
                searchView.change(state: .Focus, true)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        section.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {
                return .rejected
            }
            if self.context.bindings.rootNavigation().genericView.state != .single {
                return .rejected
            }
            self.toggleSearch()
            return .invoked
        }, with: self, for: .F, priority: .modal, modifierFlags: .command)

    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        section.viewDidDisappear(animated)
        genericView.closePremium()
    }
    
    override func initializer() -> EntertainmentView {
        let rect = NSMakeRect(self._frameRect.minX, self._frameRect.minY, self._frameRect.width, self._frameRect.height - self.bar.height)
        self.section._frameRect = NSMakeRect(rect.minX, rect.minY, rect.width, rect.height - 50)
        return EntertainmentView(sectionView: self.section.view, frame: rect)
    }

    override func firstResponder() -> NSResponder? {
        if popover == nil {
            return nil
        }
        return effectiveSearchView//genericView.searchView?.input
    }
    
    override func becomeFirstResponder() -> Bool? {
        return nil
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.isPremium {
            genericView.closePremium()
            return .invoked
        }
        let result = self.section.selectedSection.controller.escapeKeyAction()
        if result == .rejected {
            return super.escapeKeyAction()
        }
        return result
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cap.loadViewIfNeeded()

        let state:EntertainmentState
        if mode == .selectAvatar {
            state = .stickers
        } else {
            state = FastSettings.entertainmentState
        }
        
        
        
        self.genericView.updateSelected(state, mode: mode)

        
        let callSearchCmd:(ESearchCommand, SearchView)->Void = { command, view in
            switch command {
            case .clearText:
                view.setString("")
            case .loading:
                view.isLoading = true
            case .normal:
                view.isLoading = false
            case .close:
                view.cancel(true)
            case let .apply(value):
                view.setString(value)
            }
        }
        
        self.stickers.makeSearchCommand = { [weak self] command in
            if self?.stickers.view.superview != nil, let view = self?.stickers.genericView.searchView  {
                callSearchCmd(command, view)
            }
        }
                
        self.gifs.makeSearchCommand = { [weak self] command in
            if self?.gifs.view.superview != nil, let view = self?.gifs.genericView.searchView  {
                callSearchCmd(command, view)
            }
        }
        
        self.emoji.makeSearchCommand = { [weak self] command in
            if self?.emoji.view.superview != nil, let view = self?.emoji.genericView.searchView  {
                callSearchCmd(command, view)
            }
        }
        
        
        let e_index: Int = 0
        let s_index: Int = mode == .selectAvatar ? 0 : 1
        let g_index: Int = mode == .selectAvatar ? 1 : 2

        self.genericView.emoji.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            if self.genericView.emoji.isSelected {
                self.emoji.scrollup()
            }
            self.section.select(e_index, true, notifyApper: true)
            
        }, for: .SingleClick)
        
        self.genericView.stickers.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            if self.genericView.stickers.isSelected {
                self.stickers.scrollup()
            }
            self.section.select(s_index, true, notifyApper: true)
        }, for: .SingleClick)
        
        self.genericView.gifs.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            if self.genericView.gifs.isSelected {
                self.gifs.scrollup()
            }
            self.section.select(g_index, true, notifyApper: true)
        }, for: .SingleClick)
        

        
        let mode = self.mode
        
        section.selectionUpdateHandler = { [weak self] index in
            var index = index
            if mode == .selectAvatar {
                index += 1
            }
            
            let state = EntertainmentState(rawValue: Int32(index))!
            if mode == .common || mode == .stories {
                FastSettings.changeEntertainmentState(state)
            }
            self?.chatInteraction?.update({ $0.withUpdatedIsEmojiSection(state == .emoji )})
            self?.genericView.updateSelected(state, mode: mode)
            
        }

        self.ready.set(section.ready.get())
        
        languageDisposable.set((combineLatest(appearanceSignal, ready.get() |> filter {$0} |> take(1))).start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme(theme: self?.presentation ?? theme)
        }))
    }
    
}

