//
//  TonsiteController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import WebKit
import TGUIKit
import Svg


private var faviconCache: [String: UIImage] = [:]
func fetchFavicon(context: AccountContext, url: String, size: CGSize) -> Signal<NSImage?, NoError> {
    if let icon = faviconCache[url] {
        return .single(icon)
    }
    let proxyServerHost = context.appConfiguration.getStringValue("ton_proxy_address", orElse: "magic.org")
    let url = mapTonUrl(url, proxyServerHost: proxyServerHost, context: context)
    
    return context.engine.resources.httpData(url: url)
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Data?, NoError> in
        return .single(nil)
    }
    |> map { data in
        if let data {
            if let image = NSImage(data: data) {
                return image
            } else if url.lowercased().contains(".svg"), let preparedData = prepareSvgImage(data) {
                return renderPreparedImage(preparedData, size, .clear, System.backingScale)
            }
            return nil
        } else {
            return nil
        }
    }
    |> beforeNext { image in
        if let image {
            Queue.mainQueue().async {
                faviconCache[url] = image
            }
        }
    }
}




final class BrowserContentState: Equatable {
    enum ContentType: Equatable {
        case webPage
        case instantPage
        case document
    }
    
    struct HistoryItem: Equatable {
        let url: String
        let title: String
        let uuid: UUID?
        let webItem: WKBackForwardListItem?
        
        init(url: String, title: String, uuid: UUID) {
            self.url = url
            self.title = title
            self.uuid = uuid
            self.webItem = nil
        }
        
        init(webItem: WKBackForwardListItem) {
            self.url = webItem.url.absoluteString
            self.title = webItem.title ?? ""
            self.uuid = nil
            self.webItem = webItem
        }
    }
    
    let title: String
    let url: String
    let estimatedProgress: Double
    let readingProgress: Double
    let contentType: ContentType
    let favicon: NSImage?
    let isSecure: Bool
    
    let canGoBack: Bool
    let canGoForward: Bool
    
    let backList: [HistoryItem]
    let forwardList: [HistoryItem]
    let error: RequestWebViewError?

    
    init(
        title: String,
        url: String,
        estimatedProgress: Double,
        readingProgress: Double,
        contentType: ContentType,
        favicon: NSImage? = nil,
        isSecure: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        backList: [HistoryItem] = [],
        forwardList: [HistoryItem] = [],
        error: RequestWebViewError?
    ) {
        self.title = title
        self.url = url
        self.estimatedProgress = estimatedProgress
        self.readingProgress = readingProgress
        self.contentType = contentType
        self.favicon = favicon
        self.isSecure = isSecure
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.backList = backList
        self.forwardList = forwardList
        self.error = error
    }
    
    static func == (lhs: BrowserContentState, rhs: BrowserContentState) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.url != rhs.url {
            return false
        }
        if lhs.estimatedProgress != rhs.estimatedProgress {
            return false
        }
        if lhs.readingProgress != rhs.readingProgress {
            return false
        }
        if lhs.contentType != rhs.contentType {
            return false
        }
        if (lhs.favicon == nil) != (rhs.favicon == nil) {
            return false
        }
        if lhs.isSecure != rhs.isSecure {
            return false
        }
        if lhs.canGoBack != rhs.canGoBack {
            return false
        }
        if lhs.canGoForward != rhs.canGoForward {
            return false
        }
        if lhs.backList != rhs.backList {
            return false
        }
        if lhs.forwardList != rhs.forwardList {
            return false
        }
        if lhs.error != rhs.error {
            return false
        }
        return true
    }
    
    func withUpdatedTitle(_ title: String) -> BrowserContentState {
        return BrowserContentState(title: title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedUrl(_ url: String) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedIsSecure(_ isSecure: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedEstimatedProgress(_ estimatedProgress: Double) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedReadingProgress(_ readingProgress: Double) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedFavicon(_ favicon: UIImage?) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedCanGoBack(_ canGoBack: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedCanGoForward(_ canGoForward: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: canGoForward, backList: self.backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedBackList(_ backList: [HistoryItem]) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: backList, forwardList: self.forwardList, error: self.error)
    }
    
    func withUpdatedForwardList(_ forwardList: [HistoryItem]) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: forwardList, error: self.error)
    }
    
    func withUpdatedError(_ error: RequestWebViewError?) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList, error: error)
    }
}



private func mapTonUrl(_ url: String, proxyServerHost: String, context: AccountContext) -> String {
    
    let link = inApp(for: url.nsstring, context: context)

    switch link {
    case .tonsite:
        guard let url = URL(string: url) else {
            return url
        }
        
        var mappedHost: String = ""
        if let host = url.host {
            mappedHost = host
            mappedHost = mappedHost.replacingOccurrences(of: "-", with: "-h")
            mappedHost = mappedHost.replacingOccurrences(of: ".", with: "-d")
        }
        
        var mappedPath = ""
        if  !url.path.isEmpty {
            mappedPath = url.path
            if !url.path.hasPrefix("/") {
                mappedPath = "/\(mappedPath)"
            }
        }
        let mappedUrl = "https://\(mappedHost).\(proxyServerHost)\(mappedPath)"
        return mappedUrl
    default:
        return url
    }
    
}



private final class TonSchemeHandler: NSObject, WKURLSchemeHandler {
    private final class PendingTask {
        let sourceTask: any WKURLSchemeTask
        var urlSessionTask: URLSessionTask?
        let isCompleted = Atomic<Bool>(value: false)
        
        init(proxyServerHost: String, sourceTask: any WKURLSchemeTask) {
            self.sourceTask = sourceTask
            
            let requestUrl = sourceTask.request.url
            
            var mappedHost: String = ""
            if let host = sourceTask.request.url?.host {
                mappedHost = host
                mappedHost = mappedHost.replacingOccurrences(of: "-", with: "-h")
                mappedHost = mappedHost.replacingOccurrences(of: ".", with: "-d")
            }
            
            var mappedPath = ""
            if let path = sourceTask.request.url?.path, !path.isEmpty {
                mappedPath = path
                if !path.hasPrefix("/") {
                    mappedPath = "/\(mappedPath)"
                }
            }
            let mappedUrl = "https://\(mappedHost).\(proxyServerHost)\(mappedPath)"
            let isCompleted = self.isCompleted
            self.urlSessionTask = URLSession.shared.dataTask(with: URLRequest(url: URL(string: mappedUrl)!), completionHandler: { data, response, error in
                if isCompleted.swap(true) {
                    return
                }
                
                if let error {
                    sourceTask.didFailWithError(error)
                } else {
                    if let response {
                        if let response = response as? HTTPURLResponse, let requestUrl {
                            if let updatedResponse = HTTPURLResponse(
                                url: requestUrl,
                                statusCode: response.statusCode,
                                httpVersion: "HTTP/1.1",
                                headerFields: response.allHeaderFields as? [String: String] ?? [:]
                            ) {
                                sourceTask.didReceive(updatedResponse)
                            } else {
                                sourceTask.didReceive(response)
                            }
                        } else {
                            sourceTask.didReceive(response)
                        }
                    }
                    if let data {
                        sourceTask.didReceive(data)
                    }
                    sourceTask.didFinish()
                }
            })
            self.urlSessionTask?.resume()
        }
        
        func cancel() {
            if let urlSessionTask = self.urlSessionTask {
                self.urlSessionTask = nil
                if !self.isCompleted.swap(true) {
                    switch urlSessionTask.state {
                    case .running, .suspended:
                        urlSessionTask.cancel()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private let proxyServerHost: String
    
    private var pendingTasks: [PendingTask] = []
    
    init(proxyServerHost: String) {
        self.proxyServerHost = proxyServerHost
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        self.pendingTasks.append(PendingTask(proxyServerHost: self.proxyServerHost, sourceTask: urlSchemeTask))
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        if let index = self.pendingTasks.firstIndex(where: { $0.sourceTask === urlSchemeTask }) {
            let task = self.pendingTasks[index]
            self.pendingTasks.remove(at: index)
            task.cancel()
        }
    }
}


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


private class WebsiteView : View {
    fileprivate let webView: WKWebView
    fileprivate init(frame frameRect: NSRect, configration: WKWebViewConfiguration) {
        webView = .init(frame: frameRect.size.bounds, configuration: configration)
        super.init(frame: frameRect)
        addSubview(webView)
        self.webView.allowsLinkPreview = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        webView.frame = bounds
    }
}

final class WebsiteController : ModalViewController, WKNavigationDelegate, WKUIDelegate, BrowserPage {
   
    private let context: AccountContext
    private let url: String
    

    
    
    private let faviconDisposable = MetaDisposable()
    
    private var _state: BrowserContentState!
    private let statePromise: Promise<BrowserContentState> = Promise()
    
    var currentState: BrowserContentState {
        return self._state
    }
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
    
    var externalState: Signal<WebpageModalState, NoError> {
        return state |> map {
            return .init(backgroundColor: .clear, isBackButton: $0.canGoBack, needConfirmation: false, favicon: $0.favicon, error: $0.error, isSite: true, title: $0.title, url: $0.url)
        }
    }

    
    func contextMenu() -> ContextMenu {
        let menu = ContextMenu()
        
        if let url = URL(string: _state.url), let (result, host) = urlWithoutScheme(from: url) {
            if result != host, let scheme = url.scheme {
                menu.addItem(ContextMenuItem(strings().webBrowserOpenMainPage, handler: { [weak self] in
                    self?.navigateTo(address: scheme + "://" + host)
                }, itemImage: MenuAnimation.menu_folder_home.value))
            }
        }
        
        menu.addItem(ContextMenuItem(strings().modalCopyLink, handler: { [weak self] in
            if let url = self?._state.url, let window = self?.window {
                copyToClipboard(url)
                showModalText(for: window, text: strings().shareLinkCopied)
            }
        }, itemImage: MenuAnimation.menu_copy.value))
        
        menu.addItem(ContextMenuItem(strings().webAppReload, handler: { [weak self] in
            self?.reloadPage()
        }, itemImage: MenuAnimation.menu_reload.value))
        
        return menu
    }
    
    func backButtonPressed() {
        self.navigateBack()
    }
    
    func reloadPage() {
        self.webView.reload()
    }
    
    func add(_ tab: BrowserTabData.Data) -> Bool {
        return false
    }
    
    private var browser: BrowserLinkManager
    
    
    init(context: AccountContext, url: String, browser: BrowserLinkManager) {
        self.context = context
        self.browser = browser
        self.url = url
        super.init()
        self.bar = .init(height: 0)
    }
    
    private func updateState(_ f: (BrowserContentState) -> BrowserContentState) {
        let updated = f(self._state)
        self._state = updated
        self.statePromise.set(.single(self._state))
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var title: String = ""
        if let parsedUrl = URL(string: url) {
            let request = URLRequest(url: parsedUrl)
            self.webView.load(request)

            title = parsedUrl.host ?? ""
        }
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = theme.colors.listBackground
        }
        
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, readingProgress: 0.0, contentType: .webPage, favicon: self.browser.getExternal()?.favicon, error: nil)
        statePromise.set(.single(self._state))
        
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.hasOnlySecureContent), options: [], context: nil)
        
        readyOnce()
    }
    
    override func initializer() -> NSView {
        
        let configuration = WKWebViewConfiguration()

        let proxyServerHost = context.appConfiguration.getStringValue("ton_proxy_address", orElse: "magic.org")


        configuration.setURLSchemeHandler(TonSchemeHandler(proxyServerHost: proxyServerHost), forURLScheme: "tonsite")

        let contentController = WKUserContentController()
        let videoScript = WKUserScript(source: videoSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(videoScript)
        configuration.userContentController = contentController

        var handleScriptMessageImpl: ((WKScriptMessage) -> Void)?
        let eventProxyScript = WKUserScript(source: eventProxySource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(eventProxyScript)
        contentController.add(WeakScriptMessageHandler { message in
            handleScriptMessageImpl?(message)
        }, name: "performAction")
        
        if #available(macOS 14.0, *) {
            if !FastSettings.isDefaultAccount(context.account.id.int64) {
                if let uuid = FastSettings.getUUID(context.account.id.int64) {
                    let store = WKWebsiteDataStore(forIdentifier: uuid)
                    configuration.websiteDataStore = store
                }
            }
        }

        if FastSettings.debugWebApp {
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
        handleScriptMessageImpl = { [weak self] message in
            self?.handleScriptMessage(message)
        }

        let view = WebsiteView(frame: _frameRect, configration: configuration)

        return view
    }
    
    private var genericView: WebsiteView {
        return self.view as! WebsiteView
    }
    
    private var webView: WKWebView {
        return self.genericView.webView
    }
    
    deinit {
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.hasOnlySecureContent))
        
        faviconDisposable.dispose()
    }
    
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        
    }

    func stop() {
        self.webView.stopLoading()
    }
    
    func reload() {
        self.webView.reload()
    }
    
    func navigateBack() {
        self.webView.goBack()
    }
    
    func navigateForward() {
        self.webView.goForward()
    }
    
    func navigateTo(historyItem: BrowserContentState.HistoryItem) {
        if let webItem = historyItem.webItem {
            self.webView.go(to: webItem)
        }
    }
    
    func navigateTo(address: String) {
        let finalUrl = explicitUrl(address)
        guard let url = URL(string: finalUrl) else {
            return
        }
        self.webView.load(URLRequest(url: url))
    
    }
    
    func scrollToTop() {
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "title" {
            self.updateState { $0.withUpdatedTitle(self.webView.title ?? "") }
        } else if keyPath == "URL" {
            if let url = self.webView.url {
                self.updateState { $0.withUpdatedUrl(url.absoluteString) }
            }
        }  else if keyPath == "estimatedProgress" {
            self.updateState { $0.withUpdatedEstimatedProgress(self.webView.estimatedProgress) }
        } else if keyPath == "canGoBack" {
            self.updateState { $0.withUpdatedCanGoBack(self.webView.canGoBack) }
        } else if keyPath == "canGoForward" {
            self.updateState { $0.withUpdatedCanGoForward(self.webView.canGoForward) }
        } else if keyPath == "hasOnlySecureContent" {
            self.updateState { $0.withUpdatedIsSecure(self.webView.hasOnlySecureContent) }
        }
    }
    
    @available(macOS 10.15, *)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        decisionHandler(.allow, preferences)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let _ = navigationAction.request.url?.absoluteString {
            decisionHandler(.allow)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.updateState {
            $0.withUpdatedError(nil)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.updateState {
            $0
                .withUpdatedBackList(webView.backForwardList.backList.map { BrowserContentState.HistoryItem(webItem: $0) })
                .withUpdatedForwardList(webView.backForwardList.forwardList.map { BrowserContentState.HistoryItem(webItem: $0) })
        }
        self.parseFavicon()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if [-1003, -1100, 102].contains((error as NSError).code) {
            self.updateState {
                $0.withUpdatedError(.generic)
            }
        } else {
            self.updateState {
                $0.withUpdatedError(nil)
            }
        }
        
    }
        
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            let context = self.context
            if let url = navigationAction.request.url?.absoluteString {
                let link = inApp(for: url.nsstring, context: context, openInfo: { peerId, toChat, messageId, initialAction in
                    if toChat || initialAction != nil {
                        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: messageId), initialAction: initialAction))
                    } else {
                        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
                    }
                    context.window.makeKeyAndOrderFront(nil)
                }, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
               
                switch link {
                case let .tonsite(link, _):
                    self.browser.open(.tonsite(url: link))
                default:
                    execute(inapp: link, window: self.window)
                }
            }
        }
        return nil
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        close()
    }
    
    private func parseFavicon() {
        
        struct Favicon: Equatable, Hashable {
            let url: String
            let dimensions: PixelDimensions?
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(self.url)
                if let dimensions = self.dimensions {
                    hasher.combine(dimensions.width)
                    hasher.combine(dimensions.height)
                }
            }
        }
        
        let js = """
            var favicons = [];
            var nodeList = document.getElementsByTagName('link');
            for (var i = 0; i < nodeList.length; i++)
            {
                if((nodeList[i].getAttribute('rel') == 'icon')||(nodeList[i].getAttribute('rel') == 'shortcut icon')||(nodeList[i].getAttribute('rel').startsWith('apple-touch-icon')))
                {
                    const node = nodeList[i];
                    favicons.push({
                        url: node.getAttribute('href'),
                        sizes: node.getAttribute('sizes')
                    });
                }
            }
            favicons;
        """
        self.webView.evaluateJavaScript(js, completionHandler: { [weak self] jsResult, _ in
            guard let self, let favicons = jsResult as? [Any] else {
                return
            }
            var result = Set<Favicon>();
            for favicon in favicons {
                if let faviconDict = favicon as? [String: Any], let urlString = faviconDict["url"] as? String {
                    if let url = URL(string: urlString, relativeTo: self.webView.url) {
                        let sizesString = faviconDict["sizes"] as? String;
                        let sizeStrings = sizesString?.components(separatedBy: "x") ?? []
                        if (sizeStrings.count == 2) {
                            let width = Int(sizeStrings[0])
                            let height = Int(sizeStrings[1])
                            let dimensions: PixelDimensions?
                            if let width, let height {
                                dimensions = PixelDimensions(width: Int32(width), height: Int32(height))
                            } else {
                                dimensions = nil
                            }
                            result.insert(Favicon(url: url.absoluteString, dimensions: dimensions))
                        } else {
                            result.insert(Favicon(url: url.absoluteString, dimensions: nil))
                        }
                    }
                }
            }
            
            if result.isEmpty, let webViewUrl = self.webView.url {
                let schemeAndHostUrl = webViewUrl.deletingPathExtension()
                let url = schemeAndHostUrl.appendingPathComponent("favicon.ico")
                result.insert(Favicon(url: url.absoluteString, dimensions: nil))
            }
            
            var largestIcon: Favicon?
            if largestIcon == nil {
                largestIcon = result.first
                for icon in result {
                    let maxSize = largestIcon?.dimensions?.width ?? 0
                    if let width = icon.dimensions?.width, width > maxSize {
                        largestIcon = icon
                    }
                }
            }
                                                
            if let favicon = largestIcon {
                self.faviconDisposable.set((fetchFavicon(context: self.context, url: favicon.url, size: CGSize(width: 20.0, height: 20.0))
                |> deliverOnMainQueue).startStrict(next: { [weak self] favicon in
                    guard let self else {
                        return
                    }
                    let updated = favicon.flatMap { favicon in
                        generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
                            ctx.clear(size.bounds)
                            ctx.round(size, 4)
                            ctx.draw(favicon._cgImage!, in: size.bounds)
                        }).flatMap {
                            NSImage(cgImage: $0, size: NSMakeSize(20, 20))
                        }
                    }
                    self.updateState { $0.withUpdatedFavicon(updated) }
                    
                }))
            }
        })
    }

    override var hasBorder: Bool {
        return false
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        window?.set(escape: { [weak self] _ -> KeyHandlerResult in
            if self?.escapeKeyAction() == .rejected {
                self?.close()
            }
            return .invoked
        }, with: self, priority: responderPriority)

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        if self._state.canGoBack {
            self.navigateBack()
        } else {
            browser.close(confirm: false)
        }
    }
    
    
}


let setupFontFunctions = """
(function() {
  const styleId = 'telegram-font-overrides';

  function setTelegramFontOverrides(font, textSizeAdjust) {
    let style = document.getElementById(styleId);

    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }

    let cssRules = '* {';
    if (font !== null) {
        cssRules += `
        font-family: ${font} !important;
        `;
    }
    if (textSizeAdjust !== null) {
        cssRules += `
        -webkit-text-size-adjust: ${textSizeAdjust} !important;
        `;
    }
    cssRules += '}';

    style.innerHTML = cssRules;

    if (font === null && textSizeAdjust === null) {
      style.parentNode.removeChild(style);
    }
  }
  window.setTelegramFontOverrides = setTelegramFontOverrides;
})();
"""

private let videoSource = """
function disableWebkitEnterFullscreen(videoElement) {
  if (videoElement && videoElement.webkitEnterFullscreen) {
    Object.defineProperty(videoElement, 'webkitEnterFullscreen', {
      value: undefined
    });
  }
}

function disableFullscreenOnExistingVideos() {
  document.querySelectorAll('video').forEach(disableWebkitEnterFullscreen);
}

function handleMutations(mutations) {
  mutations.forEach((mutation) => {
    if (mutation.addedNodes && mutation.addedNodes.length > 0) {
      mutation.addedNodes.forEach((newNode) => {
        if (newNode.tagName === 'VIDEO') {
          disableWebkitEnterFullscreen(newNode);
        }
        if (newNode.querySelectorAll) {
          newNode.querySelectorAll('video').forEach(disableWebkitEnterFullscreen);
        }
      });
    }
  });
}

disableFullscreenOnExistingVideos();

const observer = new MutationObserver(handleMutations);

observer.observe(document.body, {
  childList: true,
  subtree: true
});

function disconnectObserver() {
  observer.disconnect();
}
"""

let setupTouchObservers =
"""
(function() {
    function saveOriginalCssProperties(element) {
        while (element) {
            const computedStyle = window.getComputedStyle(element);
            const propertiesToSave = ['transform', 'top', 'left'];
            
            element._originalProperties = {};

            for (const property of propertiesToSave) {
                element._originalProperties[property] = computedStyle.getPropertyValue(property);
            }
            
            element = element.parentElement;
        }
    }

    function checkForCssChanges(element) {
        while (element) {
            if (!element._originalProperties) return false;
            const computedStyle = window.getComputedStyle(element);
            const modifiedProperties = ['transform', 'top', 'left'];

            for (const property of modifiedProperties) {
                if (computedStyle.getPropertyValue(property) !== element._originalProperties[property]) {
                    return true;
                }
            }
            
            element = element.parentElement;
        }
        
        return false;
    }

    function clearOriginalCssProperties(element) {
        while (element) {
            delete element._originalProperties;
            element = element.parentElement;
        }
    }

    let touchedElement = null;

    document.addEventListener('touchstart', function(event) {
        touchedElement = event.target;
        saveOriginalCssProperties(touchedElement);
    }, { passive: true });

    document.addEventListener('touchmove', function(event) {
        if (checkForCssChanges(touchedElement)) {
            TelegramWebviewProxy.postEvent("cancellingTouch", {})
            console.log('CSS properties changed during touchmove');
        }
    }, { passive: true });

    document.addEventListener('touchend', function() {
        clearOriginalCssProperties(touchedElement);
        touchedElement = null;
    }, { passive: true });
})();
"""

private let eventProxySource = "var TelegramWebviewProxyProto = function() {}; " +
    "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
    "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
    "}; " +
"var TelegramWebviewProxy = new TelegramWebviewProxyProto();"

