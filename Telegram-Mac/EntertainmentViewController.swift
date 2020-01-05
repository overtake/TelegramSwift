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
import SyncCore
import Postbox


enum ESearchCommand {
    case loading
    case normal
    case close
    case clearText
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
    
    override open func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        let theme = (theme as! TelegramPresentationTheme)
        inputContainer.backgroundColor = .clear
        input.textColor = presentation.search.textColor
        input.backgroundColor = presentation.colors.background
        placeholder.attributedString = .initialize(string: presentation.search.placeholder(), color: presentation.search.placeholderColor, font: .normal(.title))
        placeholder.backgroundColor = presentation.colors.background
        self.backgroundColor = presentation.colors.background
        placeholder.sizeToFit()
        search.image = theme.icons.entertainment_Search
        search.sizeToFit()
        clear.set(image: theme.icons.entertainment_SearchCancel, for: .Normal)
        _ =  clear.sizeToFit()
        input.insertionPointColor = presentation.search.textColor
        progressIndicator.progressColor = theme.colors.grayIcon
        needsLayout = true
        
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
        
        self.kitWindow?.removeAllHandlers(for: self)
        self.kitWindow?.removeObserver(for: self)
    }
    
    open func didBecomeResponder() {
        let value = SearchState(state: state, request: self.query, responder: true)
        searchInteractions?.responderModified(SearchState(state: state, request: self.query, responder: true))
        _searchValue.set(value)
        
        change(state: .Focus, true)
        
        self.kitWindow?.set(escape: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.changeResponder() ? .invoked : .rejected
            }
            return .rejected
            
        }, with: self, priority: .modal)
        
        self.kitWindow?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
        }, with: self, for: .RightArrow, priority: .modal)
        
        self.kitWindow?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
        }, with: self, for: .LeftArrow, priority: .modal)
        
        self.kitWindow?.set(responder: {[weak self] () -> NSResponder? in
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
                
                self.kitWindow?.removeAllHandlers(for: self)
                self.kitWindow?.removeObserver(for: self)
                
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
            self.kitWindow?.removeAllHandlers(for: self)
            self.kitWindow?.removeObserver(for: self)
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
        self.kitWindow?.removeAllHandlers(for: self)
        self.kitWindow?.removeObserver(for: self)
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
    
    var sendEmoji:(String) ->Void = {_ in}
    var sendSticker:(TelegramMediaFile, Bool) ->Void = { _, _ in}
    var sendGIF:(TelegramMediaFile, Bool) ->Void = { _, _ in}
    
    var showEntertainment:(EntertainmentState, Bool)->Void = { _,_  in}
    var close:()->Void = {}

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
    fileprivate let emoji: ImageButton = ImageButton()
    fileprivate let stickers: ImageButton = ImageButton()
    fileprivate let gifs: ImageButton = ImageButton()
    
    fileprivate let search: ImageButton = ImageButton()

    fileprivate private(set) var searchView: EntertainmentSearchView?
    
    
    
    private let sectionTabs: View = View()
    init(sectionView: NSView, frame: NSRect) {
        self.sectionView = sectionView
        super.init(frame: frame)
        self.bottomView.border = [.Top]
        self.addSubview(self.sectionView)
        addSubview(self.bottomView)
        self.bottomView.addSubview(sectionTabs)
        
        self.sectionTabs.addSubview(self.emoji)
        self.sectionTabs.addSubview(self.stickers)
        self.sectionTabs.addSubview(self.gifs)
        
        self.bottomView.addSubview(self.search)
        self.bottomView.addSubview(self.borderView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.borderView.background = theme.colors.border
        self.emoji.set(image: theme.icons.entertainment_Emoji, for: .Normal)
        self.stickers.set(image: theme.icons.entertainment_Stickers, for: .Normal)
        self.gifs.set(image: theme.icons.entertainment_Gifs, for: .Normal)
        self.search.set(image: theme.icons.entertainment_Search, for: .Normal)
        
        _ = self.search.sizeToFit()
        _ = self.emoji.sizeToFit()
        _ = self.stickers.sizeToFit()
        _ = self.gifs.sizeToFit()
        
    }
    
    func toggleSearch(_ signal:ValuePromise<SearchState>) {
        if let searchView = self.searchView {
            self.searchView = nil
            searchView.searchInteractions = nil
            signal.set(.init(state: .None, request: nil))
            searchView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak searchView] _ in
                searchView?.removeFromSuperview()
            })
            self.search.isSelected = false
        } else {
            self.searchView = EntertainmentSearchView(frame: NSMakeRect(0, 0, frame.width, 50))
            self.addSubview(self.searchView!)
            self.searchView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            self.searchView?.searchInteractions = SearchInteractions({ [weak self] state, _ in
                signal.set(state)
                switch state.state {
                case .Focus:
                    break
                case .None:
                    self?.toggleSearch(signal)
                }
            }, { [weak self] state in
                signal.set(state)
                switch state.state {
                case .Focus:
                    break
                case .None:
                    self?.toggleSearch(signal)
                }
            })
            self.search.isSelected = true
            self.searchView?.change(state: .Focus, false)
        }
    }
    
    func updateSelected(_ state: EntertainmentState) {
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
    }
    
    
    override func layout() {
        super.layout()
        self.sectionView.frame = NSMakeRect(0, 0, self.frame.width, self.frame.height - 50)
        self.bottomView.frame = NSMakeRect(0, self.frame.height - 50, self.frame.width, 50)
        self.borderView.frame = NSMakeRect(0, 0, self.bottomView.frame.width, .borderSize)
        self.sectionTabs.setFrameSize(NSMakeSize(self.sectionTabs.subviewsSize.width + 40, 40))
        self.sectionTabs.center()
        
        self.search.centerY(x: 20)
        
        self.emoji.centerY(x: 0)
        self.stickers.centerY(x: self.emoji.frame.maxX + 20)
        self.gifs.centerY(x: self.stickers.frame.maxX + 20)
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


    private let emoji:EmojiViewController
    private let stickers:NStickersViewController
    private let gifs:GIFViewController
    
    private let searchState = ValuePromise<SearchState>(.init(state: .None, request: nil))
    
    func update(with chatInteraction:ChatInteraction) -> Void {
        self.chatInteraction = chatInteraction
        
        let interactions = EntertainmentInteractions(FastSettings.entertainmentState, peerId: chatInteraction.peerId)

        interactions.close = { [weak self] in
            self?.closePopover()
        }
        interactions.sendSticker = { [weak self] file, silent in
            self?.chatInteraction?.sendAppFile(file, silent)
            self?.closePopover()
        }
        interactions.sendGIF = { [weak self] file, silent in
            self?.chatInteraction?.sendAppFile(file, silent)
            self?.closePopover()
        }
        interactions.sendEmoji = { [weak self] emoji in
            _ = self?.chatInteraction?.appendText(emoji)
        }
        
        self.interactions = interactions
        
        emoji.update(with: interactions)
        stickers.update(with: interactions, chatInteraction: chatInteraction)
        gifs.update(with: interactions, chatInteraction: chatInteraction)
    }
    

    func closedBySide() {
        self.viewWillDisappear(false)
    }
    
    init(size:NSSize, context:AccountContext) {
        
        self.cap = SidebarCapViewController(context)
        self.emoji = EmojiViewController(context, search: self.searchState.get())
        self.stickers = NStickersViewController(context, search: self.searchState.get())
        self.gifs = GIFViewController(context, search: self.searchState.get())
        
        var items:[SectionControllerItem] = []
        items.append(SectionControllerItem(title:{L10n.entertainmentEmoji.uppercased()}, controller: emoji))
        items.append(SectionControllerItem(title: {L10n.entertainmentStickers.uppercased()}, controller: stickers))
        items.append(SectionControllerItem(title: {L10n.entertainmentGIF.uppercased()}, controller: gifs))
        self.section = SectionViewController(sections: items, selected: Int(FastSettings.entertainmentState.rawValue), hasHeaderView: false)
        super.init(context)
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
        updateLocalizationAndTheme(theme: theme)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        section.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        section.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {
                return .rejected
            }
            if self.context.sharedContext.bindings.rootNavigation().genericView.state != .single {
                return .rejected
            }
            self.genericView.toggleSearch(self.searchState)
            return .invoked
        }, with: self, for: .F, priority: .modal, modifierFlags: .command)

    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        section.viewDidDisappear(animated)
    }
    
    override func initializer() -> EntertainmentView {
        let rect = NSMakeRect(self._frameRect.minX, self._frameRect.minY, self._frameRect.width, self._frameRect.height - self.bar.height)
        self.section._frameRect = NSMakeRect(rect.minX, rect.minY, rect.width, rect.height - 50)
        return EntertainmentView(sectionView: self.section.view, frame: rect)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        cap.loadViewIfNeeded()

        self.genericView.updateSelected(FastSettings.entertainmentState)

        
        let callSearchCmd:(ESearchCommand)->Void = { [weak self] command in
            switch command {
            case .clearText:
                self?.genericView.searchView?.setString("")
            case .loading:
                self?.genericView.searchView?.isLoading = true
            case .normal:
                self?.genericView.searchView?.isLoading = false
            case .close:
                self?.genericView.searchView?.cancel(true)
            }
        }
        
        self.stickers.makeSearchCommand = { [weak self] command in
            if self?.stickers.view.superview != nil  {
                callSearchCmd(command)
            }
        }
        self.gifs.makeSearchCommand = { [weak self] command in
            if self?.gifs.view.superview != nil  {
                callSearchCmd(command)
            }
        }
        self.emoji.makeSearchCommand = { [weak self] command in
            if self?.emoji.view.superview != nil  {
                callSearchCmd(command)
            }
        }
        
        
        
        self.genericView.emoji.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            if self.genericView.emoji.isSelected {
                self.emoji.scrollup()
            }
            self.section.select(0, true, notifyApper: true)
            
        }, for: .Click)
        
        self.genericView.stickers.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            if self.genericView.stickers.isSelected {
                self.stickers.scrollup()
            }
            self.section.select(1, true, notifyApper: true)
        }, for: .Click)
        
        self.genericView.gifs.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            if self.genericView.gifs.isSelected {
                self.gifs.scrollup()
            }
            self.section.select(2, true, notifyApper: true)
        }, for: .Click)
        
        self.genericView.search.set(handler: { [weak self] _ in
            if let `self` = self {
                self.genericView.toggleSearch(self.searchState)
            }
        }, for: .Click)
        
        section.selectionUpdateHandler = { [weak self] index in
            let state = EntertainmentState(rawValue: Int32(index))!
            FastSettings.changeEntertainmentState(state)
            self?.chatInteraction?.update({$0.withUpdatedIsEmojiSection(index == 0)})
            self?.genericView.updateSelected(state)
        }

        self.ready.set(section.ready.get())
        
        languageDisposable.set((combineLatest(appearanceSignal, ready.get() |> filter {$0} |> take(1))).start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme(theme: theme)
        }))
    }
    
}

