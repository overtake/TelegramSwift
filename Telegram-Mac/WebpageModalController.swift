//
//  WebpageModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 14/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import LocalAuthentication
import SwiftSignalKit
import Postbox
import WebKit
import HackUtils
import ColorPalette




//
//private class SelectChatRequired : SelectPeersBehavior {
//    private let peerType: ReplyMarkupButtonRequestPeerType
//    private let context: AccountContext
//
//    init(peerType: [String], context: AccountContext) {
//        self.peerType = peerType
//        self.context = context
//        super.init(settings: [.remote, .], limit: 1)
//    }
//
//    override func filterPeer(_ peer: Peer) -> Bool {
//
//    }
//}


private class NoScrollWebView: WKWebView {
    override func scrollWheel(with theEvent: NSEvent) {
        super.scrollWheel(with: theEvent)
        
    }
}

private let durgerKingBotIds: [Int64] = [5104055776, 2200339955]



private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}


private final class HeaderView : View {
    
    enum Left {
        case back
        case dismiss
    }
    
    private let titleView: TextView = TextView()
    private let subtitleView: TextView = TextView()
    private var leftButton: Control?
    private let rightButton: ImageButton = ImageButton()
    private var leftCallback:(()->Void)?
    private var rightCallback:(()->ContextMenu?)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(titleView)
        addSubview(subtitleView)
        addSubview(rightButton)
        
        subtitleView.userInteractionEnabled = false
        subtitleView.isSelectable = false
        
        
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        
        self.rightButton.contextMenu = { [weak self] in
            return self?.rightCallback?()
        }
        self.leftButton?.set(handler: { [weak self] _ in
            self?.leftCallback?()
        }, for: .Click)
        
        rightButton.autohighlight = false
        rightButton.scaleOnClick = true
    }
    
    private var prevLeft: Left?
    private var title: String = ""
    private var subtitle: String = ""
    
    func update(title: String, subtitle: String, left: Left, animated: Bool, leftCallback: @escaping()->Void, contextMenu:@escaping()->ContextMenu?) {
        
        self.subtitle = subtitle
        self.title = title
        
        let prevLeft = self.prevLeft
        self.prevLeft = left

        self.leftCallback = leftCallback
        self.rightCallback = contextMenu
        
        let color: NSColor = self.backgroundColor.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
                
        titleView.update(TextViewLayout(.initialize(string: title, color: color, font: .medium(.title)), maximumNumberOfLines: 1))
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        let secondColor = self.backgroundColor.lightness > 0.8 ? darkPalette.grayText : dayClassicPalette.grayText
                
        subtitleView.update(TextViewLayout(.initialize(string: subtitle, color: secondColor, font: .normal(.text)), maximumNumberOfLines: 1))
        
        rightButton.set(image: NSImage(named: "Icon_ChatActionsActive")!.precomposed(color), for: .Normal)
        rightButton.sizeToFit()
        
        if prevLeft != left || prevLeft == nil || !animated {
            let previousBtn = self.leftButton
            let button: Control
        
            switch left {
            case .dismiss:
                let btn = ImageButton()
                btn.autohighlight = false
                btn.animates = false
                btn.set(image: NSImage(named: "Icon_ChatSearchCancel")!.precomposed(color), for: .Normal)
                btn.sizeToFit()
                button = btn
            case .back:
                let btn = TextButton()
                btn.autohighlight = false
                btn.animates = false
                btn.set(image: NSImage(named: "Icon_ChatNavigationBack")!.precomposed(color), for: .Normal)
                btn.set(text: strings().navigationBack, for: .Normal)
                btn.set(font: .normal(.title), for: .Normal)
                btn.set(color: color, for: .Normal)
                btn.sizeToFit()
                button = btn
            }
            button.scaleOnClick = true
            button.set(handler: { [weak self] _ in
                self?.leftCallback?()
            }, for: .Click)
            self.leftButton = button
            addSubview(button)
            if let previousBtn = previousBtn {
                performSubviewRemoval(previousBtn, animated: false, scale: false)
            }
            if animated && prevLeft != nil {
                button.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
        
        needsLayout = true
    }
    
    override var backgroundColor: NSColor {
        didSet {
            if let prevLeft = prevLeft, let leftCallback = leftCallback, let rightCallback = rightCallback {
                self.update(title: self.title, subtitle: self.subtitle, left: prevLeft, animated: false, leftCallback: leftCallback, contextMenu: rightCallback)
            }
        }
    }
    
    override func layout() {
        super.layout()
        var additionalSize: CGFloat = 0
        additionalSize += rightButton.frame.width * 2
        rightButton.centerY(x: frame.width - rightButton.frame.width - 20)
        
        if let leftButton = leftButton {
            additionalSize += leftButton.frame.width * 2
            leftButton.centerY(x: 20)
        }
        
        titleView.resize(frame.width - 40 - additionalSize)
        subtitleView.resize(frame.width - 40 - additionalSize)
        
        let center = frame.midY
        titleView.centerX(y: center - titleView.frame.height - 1)
        subtitleView.centerX(y: center + 1)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WebpageView : View {
    private var indicator: NSView?
    
    
    fileprivate var _holder: WKWebView!
    private var fakeHolder = View()
    fileprivate var webview: NSView {
        if _holder == nil {
            return fakeHolder
        }
        return _holder
    }
    
    private var placeholderIcon: (CGImage, Bool)?
    private var placeholderNode: ShimmerEffectView?

    

    
    private let loading: LinearProgressControl = LinearProgressControl(progressHeight: 2)

    
    private class MainButton : Control {
        private let textView: TextView = TextView()
        private var loading: InfiniteProgressView?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            addSubview(textView)
            textView.isEventLess = true
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
        }
        
        func update(_ state: WebpageModalController.MainButtonState, animated: Bool) {
            
            let textLayout = TextViewLayout(.initialize(string: state.text, color: state.textColor, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .middle)
            textLayout.measure(width: frame.width - 60)
            textView.update(textLayout)
            
            set(background: state.backgroundColor, for: .Normal)
            set(background: state.backgroundColor.darker(), for: .Highlight)
            
            if state.isLoading {
                let current: InfiniteProgressView
                if let view = self.loading {
                    current = view
                } else {
                    current = .init(color: state.textColor, lineWidth: 2)
                    current.setFrameSize(NSMakeSize(30, 30))
                    self.loading = current
                    addSubview(current)
                }
                current.progress = nil
            } else if let view = self.loading {
                performSubviewRemoval(view, animated: animated)
                self.loading = nil
            }
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            textView.resize(frame.width - 60)
            textView.center()
            if let loading = loading {
                loading.centerY(x: frame.width - loading.frame.width - 10)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var mainButton:MainButton?
    
    private let headerView = HeaderView(frame: .zero)
    
    private let halfTop = View()
    private let halfBottom = View()
    
    required init(frame frameRect: NSRect, configuration: WKWebViewConfiguration!) {
        _holder = NoScrollWebView(frame: frameRect.size.bounds, configuration: configuration)
        super.init(frame: frameRect)
        addSubview(halfTop)
        addSubview(halfBottom)
        addSubview(webview)
        addSubview(loading)
        addSubview(headerView)
        
        webview.wantsLayer = true
                
        updateLocalizationAndTheme(theme: theme)

    }
    
    var _backgroundColor: NSColor? {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    var _headerColorKey: String? {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    var _headerColor: NSColor? {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        loading.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
        self.backgroundColor = _backgroundColor ?? theme.colors.background
        
//        halfBottom.backgroundColor = .red
//        halfTop.backgroundColor = .blue

        if let key = _headerColorKey {
            if key == "bg_color" {
                self.headerView.backgroundColor = self.backgroundColor
            } else {
                self.headerView.backgroundColor = theme.colors.listBackground
            }
        } else if let color = _headerColor {
            self.headerView.backgroundColor = color
        } else {
            self.headerView.backgroundColor = self.backgroundColor
        }
    }
    
    func load(url: String, preload: (TelegramMediaFile, AccountContext)?, animated: Bool) {
        if let url = URL(string: url) {
            _holder.load(URLRequest(url: url))
        }
        self.update(inProgress: true, preload: preload, animated: animated)
    }
    
    func update(inProgress: Bool, preload: (TelegramMediaFile, AccountContext)?, animated: Bool) {
        self.webview._change(opacity: inProgress ? 0 : 1, animated: animated)
        if inProgress {
            
            if let placeholderIcon = placeholderIcon {
                
            } else if let preload = preload {
                let current: MediaAnimatedStickerView
                if let view = self.indicator as? MediaAnimatedStickerView {
                    current = view
                } else {
                    current = .init(frame: NSMakeRect(0, 0, 50, 50))
                    current.frame = focus(current.frame.size)
                    self.indicator = current
                    self.addSubview(current)
                }
                current.update(with: preload.0, size: current.frame.size, context: preload.1, table: nil, parameters: ChatAnimatedStickerMediaLayoutParameters(playPolicy: .loop, alwaysAccept: true, media: preload.0, colors: [.init(keyPath: "", color: theme.colors.grayText)], noThumb: true), animated: false)

                if let animation = current.layer?.makeAnimation(from: NSNumber(value: 1.0), to: NSNumber(value: 0.2), keyPath: "opacity", timingFunction: .easeOut, duration: 2.0) {
                    animation.repeatCount = 1000
                    animation.autoreverses = true
                    
                    current.layer?.add(animation, forKey: "opacity")
                }
            } else {
                let current: ProgressIndicator
                if let view = self.indicator as? ProgressIndicator {
                    current = view
                } else {
                    current = .init(frame: NSMakeRect(0, 0, 30, 30))
                    current.frame = focus(current.frame.size)
                    self.indicator = current
                    self.addSubview(current)
                }
                current.progressColor = theme.colors.text
            }
        } else if let view = self.indicator {
            performSubviewRemoval(view, animated: animated)
            self.indicator = nil
        }
        self.needsLayout = true
    }
    
    func set(estimatedProgress: CGFloat?, animated: Bool) {
        if let estimatedProgress = estimatedProgress {
            if estimatedProgress == 0 || estimatedProgress == 1 {
                self.loading.change(opacity: 0, animated: animated)
            } else {
                self.loading.change(opacity: 1, animated: animated)
            }
            self.loading.set(progress: estimatedProgress, animated: animated)
        } else {
            self.loading.change(opacity: 0, animated: animated)
            self.loading.set(progress: 0, animated: animated)
        }
    }
    
    func updateMainButton(_ state: WebpageModalController.MainButtonState?, animated: Bool, callback:@escaping()->Void) {
        if let state = state, state.isVisible, let text = state.text, !text.isEmpty {
            let current: MainButton
            if let view = self.mainButton {
                current = view
            } else {
                current = .init(frame: NSMakeRect(0, frame.height, frame.width, 50))
                self.mainButton = current
                self.addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                
                current.set(handler: { _ in
                    callback()
                }, for: .Click)
            }
            current.update(state, animated: animated)
        } else if let view = self.mainButton {
            performSubviewRemoval(view, animated: animated)
            view.layer?.animatePosition(from: view.frame.origin, to: view.frame.origin.offset(dx: 0, dy: view.frame.height), removeOnCompletion: false)
            self.mainButton = nil
        }
        self.updateLayout(frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    
    func updateHeader(title: String, subtitle: String, left: HeaderView.Left, animated: Bool, leftCallback: @escaping()->Void, contextMenu:@escaping()->ContextMenu?) {
        self.headerView.update(title: title, subtitle: subtitle, left: left, animated: animated, leftCallback: leftCallback, contextMenu: contextMenu)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.headerView, frame: NSMakeRect(0, 0, size.width, 50))
        if let mainButton = mainButton {
            transition.updateFrame(view: mainButton, frame: NSMakeRect(0, size.height - 50, size.width, 50))
            self.webview.frame = NSMakeRect(0, self.headerView.frame.maxY, size.width, size.height - mainButton.frame.height - self.headerView.frame.height)
        } else {
            self.webview.frame = NSMakeRect(0, self.headerView.frame.maxY, size.width, size.height - self.headerView.frame.height)
        }
        
        if let indicator = indicator {
            transition.updateFrame(view: indicator, frame: indicator.centerFrame())
        }
        transition.updateFrame(view: self.loading, frame: NSMakeRect(0, 0, size.width, 2))
        
        transition.updateFrame(view: halfTop, frame: NSMakeRect(0, 0, size.width, size.height / 2))
        transition.updateFrame(view: halfBottom, frame: NSMakeRect(0, size.height / 2, size.width, size.height / 2))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        _holder.stopLoading()
        _holder.loadHTMLString("", baseURL: nil)
        webview.removeFromSuperview()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}


class WebpageModalController: ModalViewController, WKNavigationDelegate, WKUIDelegate {
    
    struct BotData {
        let queryId: Int64
        let bot: Peer
        let peerId: PeerId
        let buttonText: String
        let keepAliveSignal: Signal<Never, KeepWebViewError>
    }
    
    enum RequestData {
        case simple(url: String, bot: Peer, buttonText: String, source: RequestSimpleWebViewSource, hasSettings: Bool)
        case normal(url: String?, peerId: PeerId, threadId: Int64?, bot: Peer, replyTo: MessageId?, buttonText: String, payload: String?, fromMenu: Bool, hasSettings: Bool, complete:(()->Void)?)
        
        var bot: Peer {
            switch self {
            case let .simple(_, bot, _, _, _):
                return bot
            case let .normal(_, _, _, bot, _, _, _, _, _, _):
                return bot
            }
        }
        var buttonText: String {
            switch self {
            case let .simple(_, _, buttonText, _, _):
                return buttonText
            case let .normal(_, _, _, _, _, buttonText, _, _, _, _):
                return buttonText
            }
        }
        var isInline: Bool {
            switch self {
            case let .simple(_, _, _, source, _):
                return source == .inline
            case .normal:
                return false
            }
        }
        var hasSettings: Bool {
            switch self {
            case let .simple(_, _, _, _, hasSettings):
                return hasSettings
            case let .normal(_, _, _, _, _, _, _, _, hasSettings, _):
                return hasSettings
            }
        }
    }
    
    
    struct MainButtonState {
        let text: String?
        let backgroundColor: NSColor
        let textColor: NSColor
        let isVisible: Bool
        let isLoading: Bool
        
        public init(
            text: String?,
            backgroundColor: NSColor,
            textColor: NSColor,
            isVisible: Bool,
            isLoading: Bool
        ) {
            self.text = text
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.isVisible = isVisible
            self.isLoading = isLoading
        }
        
        static var initial: MainButtonState {
            return MainButtonState(text: nil, backgroundColor: .clear, textColor: .clear, isVisible: false, isLoading: false)
        }
    }



    

    private var url:String
    private let context:AccountContext
    private var effectiveSize: NSSize?
    private var data: BotData?
    private var requestData: RequestData?
    private var locked: Bool = false
    private var counter: Int = 0
    private let title: String
    private let thumbFile: TelegramMediaFile?
    
    private var keepAliveDisposable: Disposable?
    private let installedBotsDisposable = MetaDisposable()
    private let requestWebDisposable = MetaDisposable()
    private let placeholderDisposable = MetaDisposable()
    private var iconDisposable: Disposable?
    
    private var installedBots:[PeerId] = []
    private var chatInteraction: ChatInteraction?
    
    private let laContext = LAContext()

    
    private var needCloseConfirmation = false
    
    fileprivate let loadingProgressPromise = Promise<CGFloat?>(nil)
    
    private var clickCount: Int = 0
    
    private var _backgroundColor: NSColor? {
        didSet {
            genericView._backgroundColor = _backgroundColor
        }
    }
    private var _headerColorKey: String? {
        didSet {
            genericView._headerColorKey = _headerColorKey
        }
    }
    private var _headerColor: NSColor? {
        didSet {
            genericView._headerColor = _headerColor
        }
    }
    
    private var botPeer: Peer? = nil
    
    private var biometryState: TelegramBotBiometricsState? {
        didSet {
            if let biometryState, let bot = requestData?.bot {
                context.engine.peers.updateBotBiometricsState(peerId: bot.id, update: { _ in
                    return biometryState
                })
            }
        }
    }
    private var biometryDisposable: Disposable?
    
    init(context: AccountContext, url: String, title: String, effectiveSize: NSSize? = nil, requestData: RequestData? = nil, chatInteraction: ChatInteraction? = nil, thumbFile: TelegramMediaFile? = nil, botPeer: Peer? = nil) {
        self.url = url
        self.requestData = requestData
        self.data = nil
        self.chatInteraction = chatInteraction
        self.context = context
        self.title = title
        self.effectiveSize = effectiveSize
        self.thumbFile = thumbFile
        self.botPeer = botPeer
        super.init(frame: NSMakeRect(0,0,380,450))
    }
    
    private var preloadData: (TelegramMediaFile, AccountContext)? {
        if let thumbFile = self.thumbFile {
            return (thumbFile, context)
        } else {
            return nil
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        genericView.update(inProgress: false, preload: self.preloadData, animated: true)
//        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override var dynamicSize:Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return WebpageView.self
    }
    
    override func initializer() -> NSView {
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
        "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
        "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
        "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"

        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
//        #if DEBUG
        if #available(macOS 14.0, *) {
            if !FastSettings.isDefaultAccount(context.account.id.int64) {
                if let uuid = FastSettings.getUUID(context.account.id.int64) {
                    let store = WKWebsiteDataStore(forIdentifier: uuid)
                    configuration.websiteDataStore = store
                }
            }
            
        }
//        #endif
        
       
        

        if FastSettings.debugWebApp {
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        

        userController.add(WeakScriptMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")

        configuration.userContentController = userController
        
        return WebpageView(frame: self._frameRect, configuration: configuration)
    }
    
    private var genericView: WebpageView {
        return self.view as! WebpageView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(mouseHandler: { [weak self] _ in
            guard let strongSelf = self else {
                return .rejected
            }
            strongSelf.clickCount += 1
            delay(10, closure: { [weak strongSelf] in
                strongSelf?.clickCount = 0
            })
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .supreme)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeObserver(for: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        genericView._holder.uiDelegate = self
        genericView._holder.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
        genericView._holder.navigationDelegate = self
        //
        genericView.update(inProgress: true, preload: self.preloadData, animated: false)
        
        updateLocalizationAndTheme(theme: theme)
        
        readyOnce()
        let context = self.context
        
        
        if let requestData = requestData {
            
            
            switch requestData {
            case let .simple(url, bot, _, source, _):
                let signal = context.engine.messages.requestSimpleWebView(botId: bot.id, url: url, source: source, themeParams: generateWebAppThemeParams(theme)) |> deliverOnMainQueue
                
                requestWebDisposable.set(signal.start(next: { [weak self] url in
                    self?.url = url
                    self?.genericView.load(url: url, preload: self?.preloadData, animated: true)
                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: strings().unknownError)
                        self?.close()
                    }
                }))
            case .normal(let url, let peerId, let threadId, let bot, let replyTo, let buttonText, let payload, let fromMenu, _, let complete):
                
                
                
                
                let signal = context.engine.messages.requestWebView(peerId: peerId, botId: bot.id, url: url, payload: payload, themeParams: generateWebAppThemeParams(theme), fromMenu: fromMenu, replyToMessageId: replyTo, threadId: threadId) |> deliverOnMainQueue
                requestWebDisposable.set(signal.start(next: { [weak self] result in
                    
                    
                    self?.data = .init(queryId: result.queryId, bot: bot, peerId: peerId, buttonText: buttonText, keepAliveSignal: result.keepAliveSignal)
                    self?.genericView.load(url: result.url, preload: self?.preloadData, animated: true)
                    self?.keepAliveDisposable = (result.keepAliveSignal
                                                 |> deliverOnMainQueue).start(error: { [weak self] _ in
                        self?.close()
                    }, completed: { [weak self] in
                        self?.close()
                        complete?()
                    })
                    self?.url = result.url
                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: strings().unknownError)
                        self?.close()
                    }
                }))
            }
            
            
           
            
        } else {
            self.genericView.load(url: url, preload: self.preloadData, animated: true)
        }
        
        let bots = self.context.engine.messages.attachMenuBots() |> deliverOnMainQueue
        installedBotsDisposable.set(combineLatest(bots, appearanceSignal).start(next: { [weak self] items, appearance in
            self?.installedBots = items.filter { $0.flags.contains(.showInAttachMenu) }.map { $0.peer.id }
            self?.updateLocalizationAndTheme(theme: appearance.presentation)
        }))
        
        guard let botPeer = requestData?.bot else {
            return
        }
        let biometrySignal = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.BotBiometricsState(id: botPeer.id)) |> deliverOnMainQueue
        biometryDisposable = biometrySignal.start(next: { [weak self] result in
            self?.biometryState = result
        })

    }
    
    @available(macOS 10.12, *)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {

        let allowDirectories: Bool
        if #available(macOS 10.13.4, *) {
            allowDirectories = parameters.allowsDirectories
        } else {
            allowDirectories = true
        }
        
        filePanel(with: nil, allowMultiple: parameters.allowsMultipleSelection, canChooseDirectories: allowDirectories, for: context.window, completion: { files in
            completionHandler(files?.map { URL(fileURLWithPath: $0) })
        })
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        verifyAlert_button(for: context.window, header: requestData?.bot.displayTitle ?? appName, information: message, successHandler: { _ in
            completionHandler(true)
        }, cancelHandler: {
            completionHandler(false)
        })
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alert(for: context.window, header: requestData?.bot.displayTitle ?? appName, info: message, onDeinit: completionHandler)
    }


    
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping(WKPermissionDecision)->Void) {
        
        let context = self.context
        
        let request:(Peer)->Void = { peer in
            if FastSettings.botAccessTo(type, peerId: peer.id) {
                decisionHandler(.grant)
            } else {
                let runConfirm:()->Void = {
                    let info: String
                    switch type {
                    case .camera:
                        info = strings().webAppAccessVideo(peer.displayTitle)
                    case .microphone:
                        info = strings().webAppAccessAudio(peer.displayTitle)
                    case .cameraAndMicrophone:
                        info = strings().webAppAccessAudioVideo(peer.displayTitle)
                    @unknown default:
                        info = "unknown"
                    }
                    verifyAlert_button(for: context.window, information: info, ok: strings().webAppAccessAllow, successHandler: { _ in
                        decisionHandler(.grant)
                        FastSettings.allowBotAccessTo(type, peerId: peer.id)
                    }, cancelHandler: {
                        decisionHandler(.deny)
                    })
                }
                switch type {
                case .camera:
                    _ = requestMediaPermission(.video).start(next: { value in
                        if value {
                            runConfirm()
                        } else {
                            decisionHandler(.deny)
                        }
                    })
                case .microphone:
                    _ = requestMediaPermission(.audio).start(next: { value in
                        if value {
                            runConfirm()
                        } else {
                            decisionHandler(.deny)
                        }
                    })
                case .cameraAndMicrophone:
                    _ = combineLatest(requestMediaPermission(.video), requestMediaPermission(.audio)).start(next: { audio, video in
                        if audio && video {
                            runConfirm()
                        } else {
                            decisionHandler(.deny)
                        }
                    })
                @unknown default:
                    alert(for: context.window, info: strings().unknownError)
                }
            }
        }
        
        if let requestData = self.requestData {
            request(requestData.bot)
        } else {
            return decisionHandler(.deny)
        }
        
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            let link = inApp(for: url.absoluteString.nsstring, context: context, peerId: nil, openInfo: chatInteraction?.openInfo, hashtag: nil, command: nil, applyProxy: chatInteraction?.applyProxy, confirm: true)
            switch link {
            case .external:
                break
            default:
                self.close()
            }
            execute(inapp: link)
        }
        return nil
    }
    
    

    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                if let currentUrl = URL(string: self.url) {
                    if currentUrl.host == url.host || url.scheme == "tg" {
                        decisionHandler(.allow)
                        return
                    }
                }
                                
                let link = inApp(for: url.absoluteString.nsstring, context: context, peerId: nil, openInfo: chatInteraction?.openInfo, hashtag: nil, command: nil, applyProxy: chatInteraction?.applyProxy, confirm: true)
                switch link {
                case .external:
                    break
                default:
                    self.close()
                }
                execute(inapp: link)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
    
    override func measure(size: NSSize) {
        if let embedSize = effectiveSize {
            let size = embedSize.aspectFitted(NSMakeSize(min(size.width - 100, 550), min(size.height - 100, 550)))
            
            self.modal?.resize(with:size, animated: false)
            self.genericView.updateLayout(size, transition: .immediate)
        } else {
            let size = NSMakeSize(380, min(380 + 380 * 0.6, size.height - 80))
            self.modal?.resize(with:size, animated: false)
            self.genericView.updateLayout(size, transition: .immediate)
        }
    }
    
    
    deinit {
        placeholderDisposable.dispose()
        keepAliveDisposable?.dispose()
        installedBotsDisposable.dispose()
        requestWebDisposable.dispose()
        iconDisposable?.dispose()
        biometryDisposable?.dispose()
        self.genericView._holder.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))

    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            self.genericView.set(estimatedProgress: CGFloat(genericView._holder.estimatedProgress), animated: true)
        }
    }
    
    private var isBackButton: Bool = false {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    private var hasSettings: Bool = false

    fileprivate func sendClipboardTextEvent(requestId: String, fillData: Bool) {
        var paramsString: String
        if fillData {
            let data = NSPasteboard.general.string(forType: .string) ?? ""
            paramsString = "{req_id: \"\(requestId)\", data: \"\(data)\"}"
        } else {
            paramsString = "{req_id: \"\(requestId)\"}"
        }
        sendEvent(name: "clipboard_text_received", data: paramsString)
    }

    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        
        let context = self.context
        
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String else {
            return
        }
        
        let eventData = (body["eventData"] as? String)?.data(using: .utf8)
        let json = try? JSONSerialization.jsonObject(with: eventData ?? Foundation.Data(), options: []) as? [String: Any]


        
        switch eventName {
        case "web_app_data_send":
            self.needCloseConfirmation = false
            if let eventData = body["eventData"] as? String {
                if let requestData = requestData {
                    switch requestData {
                    case .simple:
                        self.handleSendData(data: eventData)
                    default:
                        break
                    }
                }
            }
        case "web_app_read_text_from_clipboard":
            if let json = json, let requestId = json["req_id"] as? String {
                let currentTimestamp = CACurrentMediaTime()
                self.sendClipboardTextEvent(requestId: requestId, fillData: clickCount > 0)
            }

        case "web_app_ready":
            delay(0.1, closure: { [weak self] in
                self?.webAppReady()
            })
        case "web_app_switch_inline_query":
            if let interaction = chatInteraction, let data = self.requestData {
                if data.isInline == true, let json = json, let query = json["query"] as? String {
                    let address = (data.bot.addressName ?? "")
                    let inputQuery = "@\(address)" + " " + query

                    if let chatTypes = json["chat_types"] as? [String], !chatTypes.isEmpty {
                        let controller = ShareModalController(SharefilterCallbackObject(context, limits: chatTypes, callback: { [weak self] peerId, threadId in
                            let action: ChatInitialAction = .inputText(text: .init(inputText: inputQuery), behavior: .automatic)
                            if let threadId = threadId {
                                _ = ForumUI.openTopic(Int64(threadId.id), peerId: peerId, context: context, animated: true, addition: true, initialAction: action).start()
                            } else {
                                context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId), initialAction: action))
                            }
                            self?.needCloseConfirmation = false
                            self?.close()
                            return .complete()
                        }))
                        showModal(with: controller, for: context.window)
                    } else {
                        self.needCloseConfirmation = false
                        self.close()
                        interaction.updateInput(with: inputQuery)
                    }
                }
            }
        case "web_app_setup_main_button":
            if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
                if let isVisible = json["is_visible"] as? Bool {
                    let text = json["text"] as? String
                    let backgroundColorString = json["color"] as? String
                    let backgroundColor = backgroundColorString.flatMap({ NSColor(hexString: $0) }) ?? theme.colors.accent
                    let textColorString = json["text_color"] as? String
                    let textColor = textColorString.flatMap({ NSColor(hexString: $0) }) ?? theme.colors.underSelectedColor
                    
                    let isLoading = json["is_progress_visible"] as? Bool
                    let state = MainButtonState(text: text, backgroundColor: backgroundColor, textColor: textColor, isVisible: isVisible, isLoading: isLoading ?? false)
                    self.genericView.updateMainButton(state, animated: true, callback: { [weak self] in
                        self?.pressMainButton()
                    })
                }
            }
        case "web_app_request_viewport":
            self.updateSize()
        case "web_app_expand":
            break
        case "web_app_close":
            self.close()
        case "web_app_open_scan_qr_popup":
            alert(for: context.window, info: strings().webAppQrIsNotSupported)
        case "web_app_setup_closing_behavior":
            if let json = json, let need_confirmation = json["need_confirmation"] as? Bool {
                self.needCloseConfirmation = need_confirmation
            } else {
                self.needCloseConfirmation = false
            }
        case "web_app_open_popup":
            if let json = json {
                let alert:NSAlert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = (json["title"] as? String) ?? appName
                alert.informativeText = (json["message"] as? String) ?? ""
                alert.window.appearance = theme.appearance
                let buttons = json["buttons"] as? Array<[NSString : Any]>
                if let buttons = buttons {
                    for button in buttons {
                        if (button["type"] as? String) == "default" {
                            alert.addButton(withTitle: button["text"] as? String ?? "")
                        } else if (button["type"] as? String) == "ok" {
                            alert.addButton(withTitle: strings().alertOK)
                        } else if (button["type"] as? String) == "close" {
                            alert.addButton(withTitle: strings().navigationClose)
                        } else if (button["type"]  as? String) == "cancel" {
                            alert.addButton(withTitle: strings().alertCancel)
                        } else if (button["type"]  as? String) == "destructive" {
                            alert.addButton(withTitle: button["text"] as? String ?? "")
                        }
                    }
                }
                if !alert.buttons.isEmpty {
                    alert.beginSheetModal(for: context.window, completionHandler: { [weak self] response in
                        let index = response.rawValue - 1000
                        if let id = buttons?[index]["id"] as? String {
                            self?.poupDidClose(id)
                        }
                    })
                }
            }
        case "web_app_open_link":
            if clickCount > 0 {
                if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
                    if let url = json["url"] as? String {
                        
                        let tryInstantView = json["try_instant_view"] as? Bool ?? false
                        let link = inApp(for: url.nsstring, context: context, openInfo: nil, hashtag: nil, command: nil, applyProxy: nil, confirm: false)

                        if tryInstantView {
                            let signal = showModalProgress(signal: resolveInstantViewUrl(account: self.context.account, url: url), for: context.window)
                            
                            let _ = signal.start(next: { [weak self] result in
                                guard let strongSelf = self else {
                                    return
                                }
                                switch result {
                                case let .instantView(_, webPage, _):
                                    showInstantPage(InstantPageViewController(strongSelf.context, webPage: webPage, message: nil, saveToRecent: false))
                                default:
                                    execute(inapp: link)
                                }
                            })
                        } else {
                            execute(inapp: link)
                        }
                    }
                }
            }
            clickCount = 0
        case "web_app_open_tg_link":
            if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
                if let path_full = json["path_full"] as? String {
                    
                    var openInfo = chatInteraction?.openInfo
                    
                    if openInfo == nil {
                        openInfo = { peerId, toChat, messageId, initialAction in
                            if toChat || initialAction != nil {
                                context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: messageId), initialAction: initialAction))
                            } else {
                                PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
                            }
                        }
                    }
                    
                    let link = inApp(for: "https://t.me\(path_full)".nsstring, context: context, openInfo: openInfo, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
                   
                    execute(inapp: link)
                    self.close()
                }
            }
        case "web_app_setup_back_button":
            if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
                if let isVisible = json["is_visible"] as? Bool {
                    self.isBackButton = isVisible
                }
            }
        case "web_app_setup_settings_button":
            if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
                if let isVisible = json["is_visible"] as? Bool {
                    self.hasSettings = isVisible
                }
            }
        case "web_app_open_invoice":
            if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
                if let slug = json["slug"] as? String {
                    
                    let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: .slug(slug)), for: context.window)
                    
                    _ = signal.start(next: { invoice in
                        showModal(with: PaymentsCheckoutController(context: context, source: .slug(slug), invoice: invoice, completion: { [weak self] status in
                            
                            let data = "{\"slug\": \"\(slug)\", \"status\": \"\(status.rawValue)\"}"
                            
                            self?.sendEvent(name: "invoice_closed", data: data)
                        }), for: context.window)
                    }, error: { error in
                        showModalText(for: context.window, text: strings().paymentsInvoiceNotExists)
                    })
                }
            }
        case "web_app_set_background_color":
            if let json = json, let colorValue = json["color"] as? String, let color = NSColor(hexString: colorValue) {
                self._backgroundColor = color
            }
        case "web_app_set_header_color":
            if let json = json, let colorKey = json["color_key"] as? String, ["bg_color", "secondary_bg_color"].contains(colorKey) {
                self._headerColorKey = colorKey
                self._headerColor = nil
            } else if let json = json, let color = json["color"] as? String {
                self._headerColor = NSColor(hexString: color)
                self._headerColorKey = nil
            }
        case "web_app_request_write_access":
            self.requestWriteAccess()
        case "web_app_request_phone":
            self.shareAccountContact()
        case "web_app_invoke_custom_method":
            if let json = json, let requestId = json["req_id"] as? String, let method = json["method"] as? String, let params = json["params"] {
                var paramsString: String?
                if let string = params as? String {
                    paramsString = string
                } else if let data1 = try? JSONSerialization.data(withJSONObject: params, options: []), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
                    paramsString = convertedString
                }
                self.invokeCustomMethod(requestId: requestId, method: method, params: paramsString ?? "{}")
            }
        case "web_app_biometry_get_info":
            guard let biometryState else {
                return
            }
            self.sendBiometricInfo(biometryState: biometryState)
        case "web_app_biometry_request_access":
            guard let botPeer = requestData?.bot, var biometryState = self.biometryState else {
                return
            }
            var string: String
            if laContext.biometricTypeString == "finger" {
                string = strings().webAppBiometryConfirmTouchId(botPeer.displayTitle)
            } else {
                string = strings().webAppBiometryConfirmFaceId(botPeer.displayTitle)
            }
            
            if let json = json, let reason = json["reason"] as? String {
                string += "\n\n" + reason
            }
            
            let accountId = context.peerId
            
            if biometryState.accessGranted {
                self.sendBiometricInfo(biometryState: biometryState)
                return
            }
            
            verifyAlert(for: context.window, information: string, ok: strings().webAppAccessAllow, cancel: strings().webAppAccessDeny, successHandler: { [weak self] _ in
                FastSettings.allowBotAccessToBiometric(peerId: botPeer.id, accountId: accountId)
                biometryState.accessGranted = true
                biometryState.accessRequested = true
                self?.sendBiometricInfo(biometryState: biometryState)
            }, cancelHandler: { [weak self] in
                biometryState.accessGranted = false
                biometryState.accessRequested = true
                self?.sendBiometricInfo(biometryState: biometryState)
            })
        case "web_app_biometry_update_token":
            
            guard let botPeer = requestData?.bot, var biometryState = self.biometryState else {
                return
            }
            
            let accountId = context.peerId
            
            if let json = json, let token = json["token"] as? String {
                
                let sacObject =
                        SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                            .userPresence,
                                            nil);

                var secQuery: NSMutableDictionary = [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrAccessControl: sacObject!,
                    kSecAttrService: "TelegramMiniApp",
                    kSecAttrAccount: "bot_id_\(botPeer.id.toInt64())"
                ];
                
                

                if token.isEmpty {
                    let resultCode = SecItemDelete(secQuery)
                    let status = resultCode == errSecSuccess ? "removed" : "failed"
                    sendEvent(name: "biometry_token_updated", data: "{status: \"\(status)\"}")
                    biometryState.opaqueToken = nil
                } else {
                    let tokenData = token.data(using: .utf8)!
                    secQuery[kSecValueData] = tokenData
                    let resultCode = SecItemAdd(secQuery as CFDictionary, nil);
                    let status = resultCode == errSecSuccess || resultCode == errSecDuplicateItem ? "updated" : "failed"
                    biometryState.opaqueToken = .init(publicKey: Data(), data: Data())
                    sendEvent(name: "biometry_token_updated", data: "{status: \"\(status)\"}")
                }
                self.sendBiometricInfo(biometryState: biometryState)
            }
        case "web_app_biometry_request_auth":
            
            guard let botPeer = requestData?.bot, var biometryState = self.biometryState else {
                return
            }
            
            let sacObject =
                    SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                        .userPresence,
                                        nil);

            let secQuery: NSMutableDictionary = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccessControl: sacObject!,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecAttrService: "TelegramMiniApp",
                kSecAttrAccount: "bot_id_\(botPeer.id.toInt64())"
            ];
            
            weak var controller = self
            
            
            DispatchQueue.global().async {
                
                var itemCopy: CFTypeRef?
                let resultCode = SecItemCopyMatching(secQuery, &itemCopy)
                
                let data = (itemCopy as? Data).flatMap { String(data: $0, encoding: .utf8) }
                
                let status = resultCode == errSecSuccess && data != nil ? "authorized" : "failed"
                
    
                DispatchQueue.main.async {
                    if resultCode == errSecItemNotFound {
                        biometryState.opaqueToken = nil
                    }
                    if status == "failed" {
                        controller?.sendEvent(name: "biometry_auth_requested", data: "{status: \"\(status)\"}")
                    } else {
                        controller?.sendEvent(name: "biometry_auth_requested", data: "{status: \"\(status)\", token:\"\(data!)\"}")
                    }
                    controller?.sendBiometricInfo(biometryState: biometryState)
                }
                
                
            }

        default:
            break
        }

    }
    
    fileprivate func requestWriteAccess() {
        guard let data = self.requestData else {
            return
        }
        let context = self.context
        
        let sendEvent: (Bool) -> Void = { [weak self] success in
            var paramsString: String
            if success {
                paramsString = "{status: \"allowed\"}"
            } else {
                paramsString = "{status: \"cancelled\"}"
            }
            self?.sendEvent(name: "write_access_requested", data: paramsString)
        }
        
        let _ = showModalProgress(signal: self.context.engine.messages.canBotSendMessages(botId: data.bot.id), for: context.window).start(next: { result in
            if result {
                sendEvent(true)
            } else {
                verifyAlert_button(for: context.window, header: strings().webappAllowMessagesTitle, information: strings().webappAllowMessagesText(data.bot.displayTitle), ok: strings().webappAllowMessagesOK, successHandler: { _ in
                    let _ = showModalProgress(signal: context.engine.messages.allowBotSendMessages(botId: data.bot.id), for: context.window).start(completed: {
                        sendEvent(true)
                    })
                }, cancelHandler: {
                    sendEvent(false)
                })
            }
        })

    }
    fileprivate func shareAccountContact() {
        guard let data = self.requestData else {
            return
        }
        let context = self.context
        
        let sendEvent: (Bool) -> Void = { [weak self] success in
            var paramsString: String
            if success {
                paramsString = "{status: \"sent\"}"
            } else {
                paramsString = "{status: \"cancelled\"}"
            }
            self?.sendEvent(name: "phone_requested", data: paramsString)
        }
        
        let isBlocked = context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.IsBlocked(id: data.bot.id)
        )
        |> deliverOnMainQueue
        |> map { $0.knownValue ?? false }
        |> take(1)
        
        _ = isBlocked.start(next: { isBlocked in
            let text: String
            if isBlocked {
                text = strings().conversationShareBotContactConfirmationUnblock(data.bot.displayTitle)
            } else {
                text = strings().conversationShareBotContactConfirmation(data.bot.displayTitle)
            }
            verifyAlert_button(for: context.window, header: strings().conversationShareBotContactConfirmationTitle, information: text, ok: strings().conversationShareBotContactConfirmationOK, successHandler: { _ in
                
                
                let _ = (context.account.postbox.loadedPeerWithId(context.peerId) |> deliverOnMainQueue).start(next: { peer in
                    if let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                        
                        let invoke:()->Void = {
                            let _ = enqueueMessages(account: context.account, peerId: data.bot.id, messages: [
                                .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                            ]).start()
                            sendEvent(true)
                        }
                        if isBlocked {
                            _ = (context.blockedPeersContext.remove(peerId: data.bot.id) |> deliverOnMainQueue).start(completed: invoke)
                        } else {
                            invoke()
                        }
                    }
                })
            }, cancelHandler: {
                sendEvent(false)
            })
        })
        
       
    }
    
    fileprivate func sendBiometricInfo(biometryState: TelegramBotBiometricsState) {
        
        guard let botPeer = self.requestData?.bot else {
            return
        }
        let type: String = laContext.biometricTypeString
        var error: NSErrorPointer = .none
        
        
        let available = laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: error)
        
        let access_requested = biometryState.accessRequested
        let access_granted = biometryState.accessGranted
        let token_saved = biometryState.opaqueToken != nil
        
        self.biometryState = biometryState
        
        if let uuid = FastSettings.defaultUUID()?.uuidString {
            let paramsString: String = "{available: \"\(available)\", type:\"\(type)\", access_requested:\(access_requested), access_granted:\(access_granted), token_saved:\(token_saved), device_id:\"\(uuid)\"}"
            self.sendEvent(name: "biometry_info_received", data: paramsString)
        }
        
    }
    
    fileprivate func invokeCustomMethod(requestId: String, method: String, params: String) {
        
        let id = self.requestData?.bot.id ?? self.botPeer?.id
        
        guard let peerId = id else {
            return
        }
        let _ = (self.context.engine.messages.invokeBotCustomMethod(botId: peerId, method: method, params: params)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let `self` = self else {
                return
            }
            let paramsString = "{req_id: \"\(requestId)\", result: \(result)}"
            self.sendEvent(name: "custom_method_invoked", data: paramsString)
        })
    }

    
    private func webAppReady() {
        genericView.update(inProgress: false, preload: self.preloadData, animated: true)
    }
    
    
    private func updateSize() {
        if let contentSize = self.modal?.window.contentView?.frame.size {
           measure(size: contentSize)
        }
    }
    
    private func poupDidClose(_ id: String) {
        self.sendEvent(name: "popup_closed", data: "{button_id:\"\(id)\"}")
    }
    
    func sendEvent(name: String, data: String?) {
        let script = "window.TelegramGameProxy.receiveEvent(\"\(name)\", \(data ?? "null"))"
        self.genericView._holder.evaluateJavaScript(script, completionHandler: { _, _ in

        })
    }
    
    private func backButtonPressed() {
        self.sendEvent(name: "back_button_pressed", data: nil)
    }
    private func settingsPressed() {
        self.sendEvent(name: "settings_button_pressed", data: nil)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        
        let themeParams = generateWebAppThemeParams(theme)
        var themeParamsString = "{theme_params: {"
        for (key, value) in themeParams {
            if let value = value as? Int32 {
                let color = NSColor(rgb: UInt32(bitPattern: value))
                
                if themeParamsString.count > 16 {
                    themeParamsString.append(", ")
                }
                themeParamsString.append("\"\(key)\": \"\(color.hexString)\"")
            }
        }
        themeParamsString.append("}}")
        
        self.sendEvent(name: "theme_changed", data: themeParamsString)
        
        
        genericView.updateHeader(title: self.defaultBarTitle, subtitle: strings().presenceBot, left: isBackButton ? .back : .dismiss, animated: true, leftCallback: { [weak self] in
            if self?.isBackButton == true {
                self?.backButtonPressed()
            } else {
                self?.close()
            }
        }, contextMenu: { [weak self] in
            var items:[ContextMenuItem] = []

            items.append(.init(strings().webAppReload, handler: { [weak self] in
                self?.reloadPage()
            }, itemImage: MenuAnimation.menu_reload.value))

            if self?.hasSettings == true {
                items.append(.init(strings().webAppSettings, handler: { [weak self] in
                    self?.settingsPressed()
                }, itemImage: MenuAnimation.menu_gear.value))
            }
            
            if let installedBots = self?.installedBots {
                if let data = self?.data, let bot = data.bot as? TelegramUser, let botInfo = bot.botInfo {
                    if botInfo.flags.contains(.canBeAddedToAttachMenu) {
                        if installedBots.contains(where: { $0 == bot.id }) {
                            items.append(ContextSeparatorItem())
                            items.append(.init(strings().webAppRemoveBot, handler: { [weak self] in
                                self?.removeBotFromAttachMenu(bot: bot)
                            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                        } else {
                            items.append(.init(strings().webAppInstallBot, handler: { [weak self] in
                                self?.addBotToAttachMenu(bot: bot)
                            }, itemImage: MenuAnimation.menu_plus.value))
                        }
                    }
                }
            }
            let menu = ContextMenu()
            for item in items {
                menu.addItem(item)
            }
            return menu
        })

    }
    
    fileprivate func pressMainButton() {
        self.sendEvent(name: "main_button_pressed", data: nil)
    }

    

    
    private func handleSendData(data string: String) {
        
        
        counter += 1
        
        
        if let data = string.data(using: .utf8), let jsonArray = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String: Any], let data = jsonArray["data"] {
            var resultString: String?
            if let string = data as? String {
                resultString = string
            } else if let data1 = try? JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions.prettyPrinted), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
                resultString = convertedString
            }
            if let resultString = resultString {
                if let requestData = self.requestData {
                    let _ = (self.context.engine.messages.sendWebViewData(botId: requestData.bot.id, buttonText: requestData.buttonText, data: resultString)).start()
                }
            }
        }
        self.close()
    }
    
    private func closeAnyway() {
        super.close()
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        if needCloseConfirmation {
            verifyAlert_button(for: context.window, information: strings().webpageConfirmClose, ok: strings().webpageConfirmOk, successHandler: { [weak self] _ in
                self?.closeAnyway()
            })
        } else {
            super.close(animationType: animationType)
        }
    }

    private func reloadPage() {
        self.genericView._holder.reload()
        self.updateLocalizationAndTheme(theme: theme)
    }
    
//    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
//        return (left: ModalHeaderData(image: theme.icons.modalClose, handler: { [weak self] in
//            self?.close()
//        }), center: ModalHeaderData(title: self.defaultBarTitle, subtitle: strings().presenceBot), right: ModalHeaderData(image: theme.icons.chatActions, contextMenu: { [weak self] in
//
//            var items:[ContextMenuItem] = []
//
//            items.append(.init(strings().webAppReload, handler: { [weak self] in
//                self?.reloadPage()
//            }, itemImage: MenuAnimation.menu_reload.value))
//
//            if let installedBots = self?.installedBots {
//                if let data = self?.data, let bot = data.bot as? TelegramUser, let botInfo = bot.botInfo {
//                    if botInfo.flags.contains(.canBeAddedToAttachMenu) {
//                        if installedBots.contains(where: { $0 == bot.id }) {
//                            items.append(ContextSeparatorItem())
//                            items.append(.init(strings().webAppRemoveBot, handler: { [weak self] in
//                                self?.removeBotFromAttachMenu(bot: bot)
//                            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
//                        } else {
//                            items.append(.init(strings().webAppInstallBot, handler: { [weak self] in
//                                self?.addBotToAttachMenu(bot: bot)
//                            }, itemImage: MenuAnimation.menu_plus.value))
//                        }
//                    }
//                }
//            }
//            return items
//        }))
//    }
    
    private func removeBotFromAttachMenu(bot: Peer) {
        let context = self.context
        _ = showModalProgress(signal: context.engine.messages.removeBotFromAttachMenu(botId: bot.id), for: context.window).start(next: { value in
            if value {
                showModalText(for: context.window, text: strings().webAppAttachRemoveSuccess(bot.displayTitle))
            }
        })
        self.installedBots.removeAll(where: { $0 == bot.id})
    }
    private func addBotToAttachMenu(bot: Peer) {
        let context = self.context
        installAttachMenuBot(context: context, peer: bot, completion: { [weak self] value in
            if value {
                self?.installedBots.append(bot.id)
                showModalText(for: context.window, text: strings().webAppAttachSuccess(bot.displayTitle))
            }
        })
    }
    
    
    override var canBecomeResponder: Bool {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.webview
    }
    
    override var defaultBarTitle: String {
        return self.title
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if isBackButton {
            self.backButtonPressed()
            return .invoked
        }
        return super.escapeKeyAction()
    }
    
    override var hasNextResponder: Bool {
        return false
    }
    
    override var hasBorder: Bool {
        return false
    }

}


