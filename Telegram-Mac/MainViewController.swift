//
//  MainViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import KeyboardKey

#if !APP_STORE
import Sparkle
#endif

enum UpdateButtonState {
    case common
    case important
    case critical
}

final class UpdateTabView : Control {
    let textView: TextView = TextView()
    let imageView: ImageView = ImageView()
    let shimmer = ShimmerEffectView()
    let progressView: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 24, 24))
    
    var isChatList: Bool = false
    
    var isInstalling: Bool = false {
        didSet {
            shimmer.change(opacity: isInstalling ? 0 : 1)
            textView.isHidden = isInstalling || layoutState == .minimisize
            progressView.isHidden = !isInstalling
            imageView.isHidden = isInstalling || layoutState != .minimisize
            
            if layoutState != .minimisize, isInstalling, let superview = self.superview {
                self.layer?.cornerRadius = frame.height / 2
                change(size: NSMakeSize(60, frame.height), animated: true, timingFunction: .spring)
                change(pos: NSMakePoint(superview.bounds.focus(self.frame.size).minX, self.frame.minY), animated: true, timingFunction: .spring)
                progressView.change(pos: self.bounds.focus(progressView.frame.size).origin, animated: true, timingFunction: .spring)
            } else {
                if let superview = self.superview, isChatList {
                    change(size: NSMakeSize(self.textView.frame.width + 40, frame.height), animated: true, timingFunction: .spring)
                    if layoutState != .minimisize {
                        change(pos: NSMakePoint(superview.bounds.focus(self.frame.size).minX, superview.frame.height - self.frame.height - 60), animated: true, timingFunction: .spring)
                    } else {
                        change(pos: NSMakePoint(superview.bounds.focus(self.frame.size).minX, superview.frame.height - self.frame.height), animated: true, timingFunction: .spring)
                    }
                    imageView.change(pos: self.bounds.focus(imageView.frame.size).origin, animated: true, timingFunction: .spring)
                }
            }
            
        }
    }
    
    var layoutState: SplitViewState = .dual {
        didSet {
            let installing = self.isInstalling
            self.isInstalling = installing
        }
    }
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
        addSubview(progressView)
        addSubview(imageView)
        addSubview(shimmer)
        
        shimmer.isStatic = true
        
        progressView.progressColor = .white
        isInstalling = false
        
        let layout = TextViewLayout(.initialize(string: strings().updateUpdateTelegram, color: theme.colors.underSelectedColor, font: .medium(.title)))
        layout.measure(width: max(280, frame.width))
        textView.update(layout)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.shadow = shadow
        
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
    override var backgroundColor: NSColor {
        didSet {
            textView.backgroundColor = backgroundColor
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        imageView.image = (theme as! TelegramPresentationTheme).icons.appUpdate
        imageView.sizeToFit()
        needsLayout = true
        shimmer.updateAbsoluteRect(bounds, within: bounds.size)
        shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: bounds, cornerRadius: bounds.height / 2)], horizontal: true, size: bounds.size)
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    
    override func layout() {
        super.layout()
        
        
       
        shimmer.frame = bounds
        shimmer.layer?.cornerRadius = bounds.height / 2
        textView.center()
        progressView.center()
        imageView.center()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class UpdateTabController: GenericViewController<UpdateTabView> {
    private let disposable = MetaDisposable()
    private let shakeDisposable = MetaDisposable()
    private let context: SharedAccountContext
    private var state: UpdateButtonState = .common {
        didSet {
            switch state {
            case .common:
                genericView.backgroundColor = theme.colors.accent
            case .important:
                genericView.backgroundColor = theme.colors.greenUI
            case .critical:
                genericView.backgroundColor = theme.colors.redUI
            }
        }
    }
    private var parentSize: NSSize = .zero
    private let stateDisposable = MetaDisposable()
    #if !APP_STORE
    private var appcastItem: SUAppcastItem? {
        didSet {
            
            genericView.isHidden = appcastItem == nil
            
            
            var state = self.state
            
            if appcastItem != oldValue {
                if let appcastItem = appcastItem {
                    state = appcastItem.isCritical ? .critical : .common
                    
                    if state != .critical {
                        
                        let importantDelay: Double = 60 * 60 * 24
                        let criticalDelay: Double = 60 * 60 * 24
                        let updateSignal = Signal<UpdateButtonState, NoError>.single(.important) |> delay(importantDelay, queue: .mainQueue()) |> then(.single(.critical) |> delay(criticalDelay, queue: .mainQueue()))
                        
                        stateDisposable.set(updateSignal.start(next: { [weak self] newState in
                            self?.state = newState
                        }))
                        
                    }
                    
                } else {
                    stateDisposable.set(nil)
                }
            }
            self.state = state
//            self.updateLayout(self.context.layout, parentSize: parentSize, isChatList: true)
        }
    }
    #endif
    init(_ context: SharedAccountContext) {
        self.context = context
        super.init()
        self.bar = NavigationBarStyle(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        
        genericView.set(background: theme.colors.grayForeground, for: .Normal)
        genericView.isHidden = true
        
        #if APP_STORE
        
        let signal = Signal<Void, NoError>.single(Void()) |> then(.single(Void()) |> delay(24 * 60 * 60, queue: .mainQueue()) |> restart)

        disposable.set(signal.start(next: { [weak self] in
            checkForAppstoreUpdate(completion: { needToUpdate in
                self?.genericView.isHidden = !needToUpdate
                self?.state = .common
            })
        }))
        genericView.set(handler: { control in
            execute(inapp: inAppLink.external(link: itunesAppLink, false))
            control.isHidden = true
        }, for: .Click)
        #else
        disposable.set((appUpdateStateSignal |> deliverOnMainQueue).start(next: { [weak self] state in
            switch state.loadingState {
            case let .readyToInstall(item):
                self?.appcastItem = item
                self?.genericView.isInstalling = false
            case .installing:
                self?.genericView.isInstalling = true
            default:
                self?.appcastItem = nil
                self?.genericView.isInstalling = false
            }
        }))
        
        genericView.set(handler: { _ in
            updateApplication(sharedContext: context)
        }, for: .Click)
        #endif
        
        
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        #if !APP_STORE
        let item = self.appcastItem
        self.appcastItem = item
        #endif
    
    }
    
    func updateLayout(_ layout: SplitViewState, parentSize: NSSize, isChatList: Bool) {
        genericView.layoutState = layout
        self.parentSize = parentSize
        let bottom = parentSize.height - genericView.frame.height
        genericView.isChatList = isChatList
        if isChatList && layout != .minimisize {
            genericView.setFrameSize(NSMakeSize(genericView.textView.frame.width + 40, 40))
            genericView.layer?.cornerRadius = genericView.frame.height / 2
            genericView.centerX(y: layout == .minimisize ? bottom - 10 : bottom - 60)
            
            var shakeDelay: Double = 60 * 60
           
            
            let signal = Signal<Void, NoError>.single(Void()) |> delay(shakeDelay, queue: .mainQueue()) |> then(.single(Void()) |> delay(shakeDelay, queue: .mainQueue()) |> restart)
            self.shakeDisposable.set(signal.start(next: { [weak self] in
                self?.genericView.shake(beep: false)
            }))
        } else {
            genericView.setFrameSize(NSMakeSize(parentSize.width, 60))
            genericView.setFrameOrigin(NSMakePoint(0, layout == .minimisize ? bottom : bottom - 60))
            genericView.layer?.cornerRadius = 0
            shakeDisposable.set(nil)
        }
    }
    
    deinit {
        disposable.dispose()
        stateDisposable.dispose()
        shakeDisposable.dispose()
    }
}


class MainViewController: TelegramViewController {

    let chatList: ChatListController
    let navigation: NavigationViewController
    let tabController:TabBarController = TabBarController()
    let contacts:NavigationViewController
    let settings:AccountViewController
    private let phoneCalls:RecentCallsViewController
    private let layoutDisposable:MetaDisposable = MetaDisposable()
    private let badgeCountDisposable: MetaDisposable = MetaDisposable()
    private let tooltipDisposable = MetaDisposable()
    private let updateController: UpdateTabController
    
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        tabController.view.frame = bounds
        self.navigation.frame = bounds
        self.contacts.frame = bounds
        updateController.updateLayout(context.layout, parentSize: size, isChatList: true)
    }
    
    override func loadView() {
        
        navigation.hasBarRightBorder = true
        navigation.hasBarLeftBorder = true
        
        self.contacts.applyAppearOnLoad = false
        self.contacts.hasBarRightBorder = true
        self.contacts.hasBarLeftBorder = true
        self.contacts._frameRect = self._frameRect

        tabController._frameRect = self._frameRect
        self.navigation._frameRect = self._frameRect

        super.loadView()
        
        let context = self.context
        
        


        

        
        self.bar = .init(height: 0)
        self.tabController.bar = .init(height: 0)
        
        backgroundColor = theme.colors.background
        addSubview(self.tabController.view)
        
        if !context.isSupport {
        //#if !APP_STORE
            addSubview(updateController.view)
        //#endif
        }
                
        tabController.add(tab: TabItem(image: theme.icons.tab_contacts, selectedImage: theme.icons.tab_contacts_active, controller: contacts))
        
        tabController.add(tab: TabItem(image: theme.icons.tab_calls, selectedImage: theme.icons.tab_calls_active, controller: phoneCalls))
        
        tabController.add(tab: TabBadgeItem(context, controller: navigation, image: theme.icons.tab_chats, selectedImage: theme.icons.tab_chats_active, longHoverHandler: { [weak self] control in
            self?.showFastChatSettings(control)
        }))
        
        tabController.add(tab: TabAllBadgeItem(context, image: theme.icons.tab_settings, selectedImage: theme.icons.tab_settings_active, controller: settings, longHoverHandler: { [weak self] control in
            self?.showFastSettings(control)
        }))
        
        
        tabController.updateLocalizationAndTheme(theme: theme)
        
        self.ready.set(combineLatest(queue: prepareQueue, self.chatList.ready.get(), self.settings.ready.get()) |> map { $0 && $1 })
        
        
        
        layoutDisposable.set(context.layoutValue.start(next: { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.tabController.hideTabView(state == .minimisize)
            //#if !APP_STORE
            self.updateController.updateLayout(state, parentSize: self.frame.size, isChatList: true)
            //#endif
        }))
        
        tabController.didChangedIndex = { [weak self] index in
            self?.checkSettings(index)
        }
    }
    
    func prepareControllers() {
        chatList.loadViewIfNeeded(bounds)
        settings.loadViewIfNeeded(bounds)
    }
    
    private func showCallsTab() {
        tabController.insert(tab: TabItem(image: theme.icons.tab_calls, selectedImage: theme.icons.tab_calls_active, controller: phoneCalls), at: 1)
    }
    private func hideCallsTab() {
        tabController.remove(at: 1)
    }
    
    private func showFilterTooltip() {
        tabController.showTooltip(text: strings().chatListFilterTooltip, for: showCallTabs ? 2 : 1)
    }
    
    private var showCallTabs: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabController.navigationController = navigation
                
        prefDisposable.set((baseAppSettings(accountManager: context.sharedContext.accountManager) |> deliverOnMainQueue).start(next: { [weak self] settings in
            guard let `self` = self else {return}
            if settings.showCallsTab != self.showCallTabs {
                self.showCallTabs = settings.showCallsTab
                if self.showCallTabs {
                    self.showCallsTab()
                } else {
                    self.hideCallsTab()
                }
            }
        }))
    }
    
    private func _showFastChatSettings(_ control: Control, unreadCount: Int32) {
        var items: [ContextMenuItem] = []
        let context = self.context
        
        if unreadCount > 0 {
            items.append(ContextMenuItem(strings().chatListPopoverReadAll, handler: {
                verifyAlert_button(for: context.window, information: strings().chatListPopoverConfirm, successHandler: { _ in
                    _ = context.engine.messages.markAllChatsAsReadInteractively(items: [(.root, nil), (.archive, nil)]).start()
                })
            }, itemImage: MenuAnimation.menu_folder_read.value))
        }
        
        if self.tabController.current == navigation, !items.isEmpty, let event = NSApp.currentEvent {
            let menu = ContextMenu(betterInside: true)
            for item in items {
                menu.addItem(item)
            }
            AppMenu.show(menu: menu, event: event, for: control)
        }
    }
    
    func showFastChatSettings() {
        self.showFastChatSettings(tabController.control(for: self.chatIndex))
    }
    
    private func showFastChatSettings(_ control: Control) {
        
        let context = self.context
        let unreadCountsKey = PostboxViewKey.unreadCounts(items: [.total(nil)])
        
        _ = (context.account.postbox.combinedView(keys: [unreadCountsKey]) |> take(1) |> deliverOnMainQueue).start(next: { [weak self, weak control] view in
            let totalUnreadState: ChatListTotalUnreadState
            if let value = view.views[unreadCountsKey] as? UnreadMessageCountsView, let (_, total) = value.total() {
                totalUnreadState = total
            } else {
                totalUnreadState = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
            }
            let total = totalUnreadState.absoluteCounters.reduce(0, { current, value in
                return current + value.value.messageCount
            })
            if let control = control {
                self?._showFastChatSettings(control, unreadCount: total)
            }
        })
    }
    private let filterMenuDisposable = MetaDisposable()
    private let settingsDisposable = MetaDisposable()
    private let prefDisposable = MetaDisposable()
    private weak var quickController: ViewController?
    private func showFastSettings(_ control:Control) {
        
        
        let passcodeData = context.sharedContext.accountManager.transaction { transaction -> PostboxAccessChallengeData in
            return transaction.getAccessChallengeData()
        } |> deliverOnMainQueue

        let applicationSettings = appNotificationSettings(accountManager: context.sharedContext.accountManager) |> take(1)  |> deliverOnMainQueue


        settingsDisposable.set(combineLatest(passcodeData, applicationSettings, context.sharedContext.activeAccountsWithInfo |> take(1) |> map {$0.accounts} |> deliverOnMainQueue).start(next: { [weak self] passcode, notifications, accounts in
            self?._showFast(control: control, accounts: accounts, passcodeData: passcode, notifications: notifications)
        }))
        
       
    }
    
    private func _showFast( control: Control, accounts: [AccountWithInfo], passcodeData: PostboxAccessChallengeData, notifications: InAppNotificationSettings) {
        

        var items:[ContextMenuItem] = []
        let context = self.context
        
        func makeItem(_ account: AccountWithInfo) -> ContextMenuItem {
            let item = ContextAccountMenuItem(account: account, context: context, handler: {
                context.sharedContext.switchToAccount(id: account.account.id, action: nil)
            })
            return item
        }
        
        if !context.isSupport {
            for account in accounts {
                if account.account.id != context.account.id {
                    items.append(makeItem(account))
                }
            }
            if !items.isEmpty {
                items.append(ContextSeparatorItem())
            }
        }
        
        switch passcodeData {
        case .none:
            items.append(ContextMenuItem(strings().fastSettingsSetPasscode, handler: { [weak self] in
                guard let `self` = self else {return}
                self.tabController.select(index: self.tabController.count - 1)
                self.context.bindings.rootNavigation().push(PasscodeSettingsViewController(self.context))
            }, itemImage: MenuAnimation.menu_lock.value))
        default:
            items.append(ContextMenuItem(strings().fastSettingsLockTelegram, handler: {
                context.window.sendKeyEvent(KeyboardKey.L, modifierFlags: [.command])
            }, itemImage: MenuAnimation.menu_lock.value))
        }
        items.append(ContextMenuItem(theme.colors.isDark ? strings().fastSettingsDisableDarkMode : strings().fastSettingsEnableDarkMode, handler: {
            toggleDarkMode(context: context)
        }, itemImage: theme.colors.isDark ? MenuAnimation.menu_sun.value : MenuAnimation.menu_moon.value))
       
        
        let time = Int32(Date().timeIntervalSince1970)
        let unmuted = notifications.muteUntil < time
        items.append(ContextMenuItem(unmuted ? strings().fastSettingsMute2Hours : strings().fastSettingsUnmute, handler: { [weak self] in
            if let context = self?.context {
                let time = Int32(Date().timeIntervalSince1970 + 2 * 60 * 60)
                _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedMuteUntil(unmuted ? time : 0)}).start()
            }
            
        }, itemImage: notifications.muteUntil < time ? MenuAnimation.menu_mute.value : MenuAnimation.menu_unmuted.value))
        
        if let event = NSApp.currentEvent {
            let menu = ContextMenu(betterInside: true)
            for item in items {
                menu.addItem(item)
            }
            AppMenu.show(menu: menu, event: event, for: control)
        }
        
//        let controller = SPopoverViewController(items: items, visibility: 10, headerItems: headerItems)
//        showPopover(for: control, with: controller, edge: .maxX, inset: NSMakePoint(control.frame.width - 12, 0))
//        self.quickController = controller
    }
    private var previousTheme:TelegramPresentationTheme?
    private var previousIconColor:NSColor?
    private var previousIsUpChatList: Bool?
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        tabController.updateLocalizationAndTheme(theme: theme)
        
        navigation.hasBarRightBorder = true
        navigation.hasBarLeftBorder = true

        
        let theme = (theme as! TelegramPresentationTheme)
        //#if !APP_STORE
        updateController.updateLocalizationAndTheme(theme: theme)
        //#endif
        
        updateTabsIfNeeded()
        self.tabController.view.needsLayout = true
    }
    
    private func updateTabsIfNeeded() {
        if !tabController.isEmpty && (previousTheme?.colors != theme.colors ||  previousIconColor != theme.colors.accentIcon) {
            var index: Int = 0
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_contacts, theme.icons.tab_contacts_active), at: index)
            index += 1
            if showCallTabs {
                tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_calls, theme.icons.tab_calls_active), at: index)
                index += 1
            }
            
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_chats, theme.icons.tab_chats_active), at: index)
            index += 1
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_settings, theme.icons.tab_settings_active), at: index)
        }
        self.previousTheme = theme
        self.previousIconColor = theme.colors.accentIcon
    }
    
    private var previousIndex: Int? = nil
    
    func checkSettings(_ index:Int) {
        let isSettings = tabController.tab(at: index).controller is AccountViewController
        
        let navigation = context.bindings.rootNavigation()
        
        if let controller = navigation.controller as? InputDataController, controller.identifier == "wallet-create" {
            self.previousIndex = index
            quickController?.popover?.hide()
        } else {
            if previousIndex == tabController.count - 1 || isSettings {
                if isSettings && context.layout != .single {
                    navigation.push(GeneralSettingsViewController(context), false)
                } else {
                    navigation.enumerateControllers( { controller, index in
                        if (controller is ChatController) || (controller is PeerInfoController) || (controller is ChannelAdminsViewController) || (controller is ChannelAdminsViewController) || (controller is EmptyChatViewController) {
                            self.backFromSettings(index)
                            return true
                        }
                        return false
                    })
                }
            }
            self.previousIndex = index
            quickController?.popover?.hide()
        }
    }
    
    private func backFromSettings(_ index:Int) {
        context.bindings.rootNavigation().to(index: index)
    }
    
    override func focusSearch(animated: Bool, text: String? = nil) {
        if context.layout == .minimisize {
            return
        }
        let animated = animated && (context.layout != .single || context.bindings.rootNavigation().stackCount == 1)
        if context.layout == .single {
            context.bindings.rootNavigation().close()
        }
        if let current = tabController.current {
            if current is AccountViewController {
                tabController.select(index: chatIndex)
            }
            tabController.current?.focusSearch(animated: animated, text: text)
        }
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return TitledBarView(controller: self)
    }
    private var firstTime: Bool = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigation.viewDidAppear(animated)
        if firstTime {
            firstTime = false
        }
    }
    
    func globalSearch(_ query: String, peerId: PeerId?) {
        let controller = navigation.empty
        if let controller = controller as? ChatListController {
            if let peerId {
                _ = (controller.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).startStandalone(next: { [weak controller] value in
                    controller?.globalSearch(query, peer: value)
                })
            } else {
                controller.globalSearch(query, peer: nil)
            }
        } else if let tabbar = controller as? TabBarController, let controller = tabbar.current as? ChatListController {
            if let peerId {
                _ = (controller.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).startStandalone(next: { [weak controller] value in
                    controller?.globalSearch(query, peer: value)
                })
            } else {
                controller.globalSearch(query, peer: nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigation.viewWillAppear(animated)
        self.tabController.current?.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigation.viewWillDisappear(animated)
        self.tabController.current?.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigation.viewDidDisappear(animated)
        self.tabController.current?.viewDidDisappear(animated)
    }
    
    var chatIndex: Int {
        if showCallTabs {
            return 2
        } else {
            return 1
        }
    }
    
    var settingsIndex: Int {
        if showCallTabs {
            return 3
        } else {
            return 2
        }
    }
    
    
    func openChat(_ index: Int, force: Bool = false) {
        if self.tabController.current == navigation {
            let controller = navigation.controller
            if let controller = controller as? ChatListController {
                controller.openChat(index, force: force)
            } else if let controller = controller as? TabBarController {
                (controller.current as? ChatListController)?.openChat(index, force: force)
            }
        }
    }

    func showPreferences() {
        context.bindings.switchSplitLayout(.dual)
        if self.context.layout != .minimisize {
            if self.context.layout == .single {
                self.navigationController?.close()
            }
            self.tabController.select(index:settingsIndex)
        }
    }
    
    var effectiveNavigation: NavigationViewController {
        return self.navigation
    }
    
    func showChatList() {
       self.tabController.select(index: self.chatIndex)
    }
    
    override var responderPriority: HandlerPriority {
        return context.layout == .single ? .medium : .low
    }
    
    func isCanMinimisize() -> Bool{
        let current = self.tabController.current
        return current == navigation
    }
    
    override func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        super.updateFrame(frame, transition: transition)
        self.tabController.updateFrame(frame.size.bounds, transition: transition)
    }
    
    override init(_ context: AccountContext) {
        
        self.chatList = ChatListController(context, mode: .plain)
        self.contacts = NavigationViewController(ContactsController(context), context.window)
        self.settings = AccountViewController(context)
        self.phoneCalls = RecentCallsViewController(context)
        self.navigation = NavigationViewController(self.chatList, context.window)
        
        //#if !APP_STORE
            updateController = UpdateTabController(context.sharedContext)
        //#endif
        super.init(context)
    }

    deinit {
        layoutDisposable.dispose()
        prefDisposable.dispose()
        settingsDisposable.dispose()
        filterMenuDisposable.dispose()
    }
}
