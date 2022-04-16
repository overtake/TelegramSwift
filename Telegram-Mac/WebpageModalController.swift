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

import SwiftSignalKit
import Postbox
import WebKit

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
    
    required init(frame frameRect: NSRect, configuration: WKWebViewConfiguration!) {
        _holder = WKWebView(frame: frameRect.size.bounds, configuration: configuration)
        super.init(frame: frameRect)
        addSubview(webview)
        addSubview(loading)
        self.webview.background = theme.colors.background
        
        webview.wantsLayer = true
        
        updateLocalizationAndTheme(theme: theme)

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        loading.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
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
    
    
    override func layout() {
        super.layout()
        self.updateLayout(frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        if let mainButton = mainButton {
            transition.updateFrame(view: mainButton, frame: NSMakeRect(0, size.height - 50, size.width, 50))
            self.webview.frame = NSMakeRect(0, 0, size.width, size.height - mainButton.frame.height)
        } else {
            self.webview.frame = bounds
        }
        transition.updateFrame(view: self.loading, frame: NSMakeRect(0, 0, size.width, 2))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        webview.removeFromSuperview()
        _holder.stopLoading()
        _holder.loadHTMLString("", baseURL: nil)
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}


class WebpageModalController: ModalViewController, WKNavigationDelegate, WKUIDelegate {
    
    struct Data {
        let queryId: Int64
        let bot: Peer
        let peerId: PeerId
        let buttonText: String
        let keepAliveSignal: Signal<Never, KeepWebViewError>
    }
    
    enum RequestData {
        case simple(url: String, bot: Peer)
        case normal(url: String?, peerId: PeerId, bot: Peer, replyTo: MessageId?, buttonText: String, payload: String?, fromMenu: Bool, complete:(()->Void)?)
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
    private var data: Data?
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
    
    fileprivate let loadingProgressPromise = Promise<CGFloat?>(nil)


    
    init(context: AccountContext, url: String, title: String, effectiveSize: NSSize? = nil, requestData: RequestData? = nil, chatInteraction: ChatInteraction? = nil, thumbFile: TelegramMediaFile? = nil) {
        self.url = url
        self.requestData = requestData
        self.data = nil
        self.chatInteraction = chatInteraction
        self.context = context
        self.title = title
        self.effectiveSize = effectiveSize
        self.thumbFile = thumbFile
        super.init(frame:NSMakeRect(0,0,380,450))
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
            case .simple(let url, let bot):
                let signal = context.engine.messages.requestSimpleWebView(botId: bot.id, url: url, themeParams: generateWebAppThemeParams(theme)) |> deliverOnMainQueue
                
                requestWebDisposable.set(signal.start(next: { [weak self] url in
                    self?.genericView.load(url: url, preload: self?.preloadData, animated: true)
                    self?.url = url
                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: strings().unknownError)
                        self?.close()
                    }
                }))
            case .normal(let url, let peerId, let bot, let replyTo, let buttonText, let payload, let fromMenu, let complete):
                
//
//                let placeholder: Signal<(FileMediaReference, Bool)?, NoError>
//                if durgerKingBotIds.contains(bot.id.id._internalGetInt64Value()) {
//                    placeholder = .single(nil)
//                    |> delay(0.05, queue: Queue.mainQueue())
//                } else {
//                    placeholder = self.context.engine.messages.getAttachMenuBot(botId: bot.id, cached: true)
//                    |> map(Optional.init)
//                    |> `catch` { error -> Signal<AttachMenuBot?, NoError> in
//                        return .complete()
//                    }
//                    |> mapToSignal { bot -> Signal<(FileMediaReference, Bool)?, NoError> in
//                        if let bot = bot, let peerReference = PeerReference(bot.peer) {
//                            var imageFile: TelegramMediaFile?
//                            var isPlaceholder = false
//                            if let file = bot.icons[.placeholder] {
//                                imageFile = file
//                                isPlaceholder = true
//                            } else if let file = bot.icons[.iOSStatic] {
//                                imageFile = file
//                            } else if let file = bot.icons[.default] {
//                                imageFile = file
//                            }
//                            if let imageFile = imageFile {
//                                return .single((.attachBot(peer: peerReference, media: imageFile), isPlaceholder))
//                            } else {
//                                return .complete()
//                            }
//                        } else {
//                            return .complete()
//                        }
//                    } |> deliverOnMainQueue
//                }
//
//
//
//
//                placeholderDisposable.set(placeholder.start(next: { [weak self] fileReferenceAndIsPlaceholder in
//                    guard let strongSelf = self else {
//                        return
//                    }
//                    let fileReference: FileMediaReference?
//                    let isPlaceholder: Bool
//                    if let (maybeFileReference, maybeIsPlaceholder) = fileReferenceAndIsPlaceholder {
//                        fileReference = maybeFileReference
//                        isPlaceholder = maybeIsPlaceholder
//                    } else {
//                        fileReference = nil
//                        isPlaceholder = true
//                    }
//
//                    if let fileReference = fileReference {
//                        let _ = freeMediaFileInteractiveFetched(context: context, fileReference: fileReference).start()
//                    }
//                    strongSelf.iconDisposable = (svgIconImageFile(account: context.account, fileReference: fileReference, stickToTop: isPlaceholder)
//                    |> deliverOnMainQueue).start(next: { [weak self] transform in
//                        if let strongSelf = self {
//                            let imageSize: CGSize
//                            if isPlaceholder {
//                                let minSize = min(strongSelf.frame.size.width, strongSelf.frame.size.height)
//                                imageSize = CGSize(width: minSize, height: minSize * 2.0)
//                            } else {
//                                imageSize = CGSize(width: 75.0, height: 75.0)
//                            }
//                            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
//                            let drawingContext = transform(arguments)
//                            if let image = drawingContext?.generateImage() {
//                                var bp = 0
//                                bp += 1
//                                strongSelf.placeholderIcon = (image, isPlaceholder)
//
//                            }
//                        }
//                    })
//                }))

                
                let signal = context.engine.messages.requestWebView(peerId: peerId, botId: bot.id, url: url, payload: payload, themeParams: generateWebAppThemeParams(theme), fromMenu: fromMenu, replyToMessageId: replyTo) |> deliverOnMainQueue
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
        installedBotsDisposable.set(bots.start(next: { [weak self] items in
            self?.installedBots = items.map { $0.peer.id }
        }))

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
        confirm(for: context.window, information: message, successHandler: { _ in
            completionHandler(true)
        }, cancelHandler: {
            completionHandler(false)
        })
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
                    confirm(for: context.window, information: info, okTitle: strings().webAppAccessAllow, successHandler: { _ in
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
            switch requestData {
            case .simple(_, let bot):
                request(bot)
            case .normal(_, _, let bot, _, _, _, _, _):
                request(bot)
            }
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
            let size = embedSize.aspectFitted(NSMakeSize(min(size.width - 100, 800), min(size.height - 100, 800)))
            
            self.modal?.resize(with:size, animated: false)
            self.genericView.updateLayout(size, transition: .immediate)
        } else {
            let size = NSMakeSize(380, 450)
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
        self.genericView._holder.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))

    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            self.genericView.set(estimatedProgress: CGFloat(genericView._holder.estimatedProgress), animated: true)
        }
    }

    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String else {
            return
        }
        
        switch eventName {
        case "web_app_data_send":
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
        case "web_app_ready":
            delay(0.1, closure: { [weak self] in
                self?.webAppReady()
            })
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
        default:
            break
        }

    }
    
    private func webAppReady() {
        genericView.update(inProgress: false, preload: self.preloadData, animated: true)
    }
    
    private func updateSize() {
        
    }
    
    func sendEvent(name: String, data: String?) {
        let script = "window.TelegramGameProxy.receiveEvent(\"\(name)\", \(data ?? "null"))"
        self.genericView._holder.evaluateJavaScript(script, completionHandler: { _, _ in

        })
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
                themeParamsString.append("\"\(key)\": \"#\(color.hexString)\"")
            }
        }
        themeParamsString.append("}}")
        self.sendEvent(name: "theme_changed", data: themeParamsString)

    }
    
    fileprivate func pressMainButton() {
        self.sendEvent(name: "main_button_pressed", data: nil)
    }

    

    
    private func handleSendData(data string: String) {
        guard let controllerData = self.data else {
            return
        }
        
        counter += 1
        
        
        if let data = string.data(using: .utf8), let jsonArray = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String: Any], let data = jsonArray["data"] {
            var resultString: String?
            if let string = data as? String {
                resultString = string
            } else if let data1 = try? JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions.prettyPrinted), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
                resultString = convertedString
            }
            if let resultString = resultString {
                let _ = (self.context.engine.messages.sendWebViewData(botId: controllerData.bot.id, buttonText: controllerData.buttonText, data: resultString)).start()
            }
        }
        self.close()
    }

    private func reloadPage() {
        self.genericView._holder.reload()
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: ModalHeaderData(image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: self.defaultBarTitle, subtitle: strings().presenceBot), right: ModalHeaderData(image: theme.icons.chatActions, contextMenu: { [weak self] in
            
            var items:[ContextMenuItem] = []
            
            items.append(.init(strings().webAppReload, handler: { [weak self] in
                self?.reloadPage()
            }, itemImage: MenuAnimation.menu_reload.value))
            
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
            return items
        }))
    }
    
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
    

}

