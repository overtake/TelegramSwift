//
//  InstantViewInBrowser.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppSettings

private struct PageState : Equatable {
    var isBackButton: Bool = false
    var title: String = ""
    var appearance: InstantViewAppearance
    var loading: CGFloat = 0
}


class InstantViewInBrowser : TelegramGenericViewController<View>, BrowserPage {
    
        
    private let statePromise = ValuePromise<PageState>(ignoreRepeated: true)
    private let stateValue = Atomic(value: PageState(appearance: .defaultSettings))
    private func updateState(_ f:(PageState)->PageState) -> Void {
        self.statePromise.set(self.stateValue.modify(f))
    }
    
    
    func contextMenu() -> ContextMenu {
        
        let menu = ContextMenu()
        
        let context = self.context
        
        menu.addItem(ContextMenuItem("San Francisco", handler: {
            _ = updateInstantViewAppearanceSettingsInteractively(postbox: context.account.postbox, {
                $0.withUpdatedFontSerif(false)
            }).start()
        }, itemImage: stateValue.with { $0.appearance.fontSerif ? nil : MenuAnimation.menu_check_selected.value }))
        
        menu.addItem(ContextMenuItem("Georgia", handler: {
            _ = updateInstantViewAppearanceSettingsInteractively(postbox: context.account.postbox, {
                $0.withUpdatedFontSerif(true)
            }).start()
        }, itemImage: stateValue.with { !$0.appearance.fontSerif ? nil : MenuAnimation.menu_check_selected.value }))

        
        return menu
    }
    
    func backButtonPressed() {
        self.navigation.back()
    }
    
    func reloadPage() {
        
    }
    
    var externalState: Signal<WebpageModalState, NoError> {
        return statePromise.get() |> map {
            return .init(isBackButton: $0.isBackButton, isLoading: $0.loading != 0, isSite: true, title: $0.title)
        }
    }
    
    fileprivate let navigation: NavigationViewController
    private var page: InstantPageViewController {
        return navigation.controller as! InstantPageViewController
    }
    
    private let appearanceDisposable = MetaDisposable()
    private let loadProgressDisposable = MetaDisposable()
    
    private let browser: BrowserLinkManager
    
    init(webPage: TelegramMediaWebpage, context: AccountContext, url: String, anchor: String?, browser: BrowserLinkManager) {
        self.browser = browser
        navigation = NavigationViewController(InstantPageViewController(context, url: url, webPage: webPage, message: nil, anchor: anchor), nil)
        super.init(context)
        bar = .init(height: 0)
        navigation.bar = .init(height: 0)
        self.statePromise.set(.init(isBackButton: false, title: self.page.defaultBarTitle, appearance: .defaultSettings))
        
        navigation.controllerDidChange = { [weak self] in
            self?.update()
        }
        
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        navigation.frame = bounds
        self.page.frame = bounds
    }
    
    private func update() {
        let isBackButton = self.navigation.stackCount > 1
        let title = self.navigation.controller.defaultBarTitle
        self.updateState { current in
            var current = current
            current.isBackButton = isBackButton
            current.title = title
            return current
        }
    }
    
    func add(_ tab: BrowserTabData.Data) -> Bool {
        switch tab {
        case let .instantView(url, webPage, anchor):
            var existing: InstantPageViewController?
            navigation.enumerateControllers ({ controller, _ in
                if let controller = controller as? InstantPageViewController {
                    if controller.webPage.webpageId == webPage.webpageId {
                        existing = controller
                        return true
                    }
                }
                return false
            })
            
            if let existing {
                navigation.push(existing)
                if let anchor {
                    existing.scrollToAnchor(anchor, animated: false)
                }
            } else {
                navigation.push(InstantPageViewController(context, url: url, webPage: webPage, message: nil, anchor: anchor))
            }
            return true
        default:
            return false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigation._frameRect = self.bounds
        self.genericView.addSubview(navigation.view)
        
        appearanceDisposable.set((ivAppearance(postbox: context.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] appearance in
            self?.updateState({ current in
                var current = current
                current.appearance = appearance
                return current
            })
        }))
        
        update()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigation.controller.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigation.controller.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] _ in
            self?.page.scrollPage(direction: .up)
            return .invoked
        }, with: self, for: .UpArrow, priority: .medium)
        
        window?.set(handler: { [weak self] _ in
            self?.page.scrollPage(direction: .down)
            return .invoked
        }, with: self, for: .DownArrow, priority: .medium)

        let spaceScrollDownKeyboardHandler:(NSEvent)->KeyHandlerResult = { [weak self] _ in
            if let window = self?.window {
                if !window.styleMask.contains(.fullScreen) {
                    self?.page.scrollPage(direction: .down)
                }
            }
            
            return .invoked
        }
        window?.set(handler: spaceScrollDownKeyboardHandler, with: self, for: .Space, priority: .low)
        
        let spaceScrollUpKeyboardHandler:(NSEvent)->KeyHandlerResult = { [weak self, weak page] _ in
            if let window = self?.window {
                if !window.styleMask.contains(.fullScreen) {
                    page?.scrollPage(direction: .up)
                }
            }
            
            return .invoked
        }
        
        window?.set(handler: spaceScrollUpKeyboardHandler, with: self, for: .Space, priority: .medium, modifierFlags: [.shift])
        
        window?.set(handler: { [weak self] _ in
            let isBackButton = self?.stateValue.with { $0.isBackButton } ?? false
            if isBackButton {
                self?.backButtonPressed()
            } else {
                self?.browser.close(confirm: false)
            }
            return .invoked
        }, with: self, for: .Escape, priority: .medium)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigation.controller.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigation.controller.viewDidDisappear(animated)
    }
    
    
    func updateProgress(_ signal: Signal<CGFloat, NoError>, animated: Bool = true) {
        loadProgressDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let `self` = self else {return}
            
            self.updateState { current in
                var current = current
                current.loading = value
                return current
            }
        }))
    }

    
    private func openInSafari() {
        if let currentPageUrl = currentPageUrl {
            execute(inapp: .external(link: currentPageUrl, false))
            if navigation.stackCount > 1 {
                navigation.back()
            }
        }
    }
    
    private var currentPageUrl:String? {
        let content = (navigation.controller as? InstantPageViewController)?.webPage.content
        if let content = content {
            switch content {
            case .Loaded(let content):
                return content.url
            default:
                break
            }
        }
        return nil
    }
    
    private func share() {
        if let currentPageUrl = currentPageUrl, let window = window {
            showModal(with: ShareModalController(ShareLinkObject(context, link: currentPageUrl)), for: window)
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
    }
    
    
    deinit {
        appearanceDisposable.dispose()
        loadProgressDisposable.dispose()
    }

}

