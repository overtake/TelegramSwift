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
import SyncCore
import Postbox
import SwiftSignalKit

#if !APP_STORE
import Sparkle
enum UpdateButtonState {
    case common
    case important
    case critical
}

final class UpdateTabView : Control {
    let textView: TextView = TextView()
    let imageView: ImageView = ImageView()
    let progressView: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 24, 24))
    
    var isInstalling: Bool = false {
        didSet {
            textView.isHidden = isInstalling || layoutState == .minimisize
            progressView.isHidden = !isInstalling
            imageView.isHidden = isInstalling || layoutState != .minimisize
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
        progressView.progressColor = .white
        isInstalling = false
        
        let layout = TextViewLayout(.initialize(string: L10n.updateUpdateTelegram, color: .white, font: .medium(.title)))
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
    }
    
    
    
    override func layout() {
        super.layout()
        
        
       

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
    private let stateDisposable = MetaDisposable()
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
        }
    }
    
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
        genericView.hideAnimated = true
        
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
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let item = self.appcastItem
        self.appcastItem = item
    }
    
    func updateLayout(_ layout: SplitViewState, parentSize: NSSize, isChatList: Bool) {
        genericView.layoutState = layout
        
        if isChatList && layout != .minimisize {
            genericView.setFrameSize(NSMakeSize(genericView.textView.frame.width + 40, 40))
            genericView.layer?.cornerRadius = genericView.frame.height / 2
            genericView.centerX(y: layout == .minimisize ? 10 : 60)
            
            var shakeDelay: Double = 60 * 60
           
            
            let signal = Signal<Void, NoError>.single(Void()) |> delay(shakeDelay, queue: .mainQueue()) |> then(.single(Void()) |> delay(shakeDelay, queue: .mainQueue()) |> restart)
            self.shakeDisposable.set(signal.start(next: { [weak self] in
                self?.genericView.shake(beep: false)
            }))
        } else {
            genericView.setFrameSize(NSMakeSize(parentSize.width, 50))
            genericView.setFrameOrigin(NSMakePoint(0, layout == .minimisize ? 0 : 50))
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

#endif

class MainViewController: TelegramViewController {

    let tabController:TabBarController = TabBarController()
    let contacts:ContactsController
    let chatListNavigation:NavigationViewController
    let settings:AccountViewController
    private let phoneCalls:RecentCallsViewController
    private let layoutDisposable:MetaDisposable = MetaDisposable()
    private let badgeCountDisposable: MetaDisposable = MetaDisposable()
    private let tooltipDisposable = MetaDisposable()
    #if !APP_STORE
    private let updateController: UpdateTabController
    #endif
    var isUpChatList: Bool = false {
        didSet {
            if isUpChatList != oldValue {
                tabController.replace(tab: tabController.tab(at: chatIndex).withUpdatedImages(theme.icons.tab_chats, isUpChatList ? theme.icons.tab_chats_active_filters : theme.icons.tab_chats_active), at: chatIndex)
            }
        }
    }

    
    override var navigationController: NavigationViewController? {
        didSet {
            tabController.navigationController = navigationController
        }
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        tabController.view.frame = bounds
        #if !APP_STORE
        updateController.updateLayout(context.sharedContext.layout, parentSize: size, isChatList: true)
        #endif
    }
    
    override func loadView() {
        super.loadView()
        
        let context = self.context
        
        tabController._frameRect = self._frameRect
        self.bar = NavigationBarStyle(height: 0)
        backgroundColor = theme.colors.background
        addSubview(tabController.view)
        #if !APP_STORE
        addSubview(updateController.view)
        #endif
        
        
        tabController.add(tab: TabItem(image: theme.icons.tab_contacts, selectedImage: theme.icons.tab_contacts_active, controller: contacts))
        
        tabController.add(tab: TabItem(image: theme.icons.tab_calls, selectedImage: theme.icons.tab_calls_active, controller: phoneCalls))
        
        tabController.add(tab: TabBadgeItem(context, controller: chatListNavigation, image: theme.icons.tab_chats, selectedImage: isUpChatList ? theme.icons.tab_chats_active_filters : theme.icons.tab_chats_active, longHoverHandler: { [weak self] control in
            self?.showFastChatSettings(control)
        }))
        
        tabController.add(tab: TabAllBadgeItem(context, image: theme.icons.tab_settings, selectedImage: theme.icons.tab_settings_active, controller: settings, longHoverHandler: { [weak self] control in
            self?.showFastSettings(control)
        }))
        
        tabController.updateLocalizationAndTheme(theme: theme)

        let s:Signal<Bool, NoError> = Signal<Bool, NoError>.single(arc4random() % 2 == 5) |> then(deferred {
            return Signal<Bool, NoError>.single(arc4random() % 2 == 5)
        } |> delay(10 * 10, queue: .mainQueue()) |> restart)
        |> filter { $0 }
        |> mapToSignal { _ in
            return chatListFilterPreferences(postbox: context.account.postbox) |> take(1) |> map { $0.needShowTooltip && $0.isEnabled }
        } |> filter { $0 }
        |> deliverOnMainQueue
        
        tooltipDisposable.set(s.start(next: { [weak self] show in
            
            self?.showFilterTooltip()
            
        }))
        
//        account.postbox.transaction ({ transaction -> Void in
//          
//
//        }).start()
        
        self.ready.set(combineLatest(queue: prepareQueue, self.chatList.ready.get(), self.settings.ready.get()) |> map { $0 && $1 })
        
        layoutDisposable.set(context.sharedContext.layoutHandler.get().start(next: { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.tabController.hideTabView(state == .minimisize)
            #if !APP_STORE
            self.updateController.updateLayout(state, parentSize: self.frame.size, isChatList: true)
            #endif
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
        tabController.showTooltip(text: L10n.chatListFilterTooltip, for: showCallTabs ? 2 : 1)
    }
    
    private var showCallTabs: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        chatListNavigation.hasBarRightBorder = true
        
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
    
    private func _showFastChatSettings(_ control: Control, items: [SPopoverItem]) {
        
        switch self.chatList.mode {
        case .plain, .filter:
            if self.tabController.current == chatListNavigation, !items.isEmpty {
                showPopover(for: control, with: SPopoverViewController(items: items, visibility: 10), edge: .maxX, inset: NSMakePoint(control.frame.width + 40, 0))
            }            
        default:
            break
        }
    }
    
    func showFastChatSettings() {
        self.showFastChatSettings(tabController.control(for: self.chatIndex))
    }
    
    private func showFastChatSettings(_ control: Control) {
        
        filterMenuDisposable.set(self.chatList.filterMenuItems.start(next: { [weak self] items in
            self?._showFastChatSettings(control, items: items)
        }))
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
        var items:[SPopoverItem] = []
        let context = self.context
        var headerItems: [TableRowItem] = []
        for account in accounts {
            if account.account.id != context.account.id {
                
                let item = ShortPeerRowItem(NSZeroSize, peer: account.peer, account: account.account, height: 40, photoSize: NSMakeSize(25, 25), titleStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text, highlightColor: .white), drawCustomSeparator: false, inset: NSEdgeInsets(left: 10), action: {
                    context.sharedContext.switchToAccount(id: account.account.id, action: nil)
                }, highlightOnHover: true, badgeNode: GlobalBadgeNode(account.account, sharedContext: context.sharedContext, getColor: { selected in
                    if selected {
                        return theme.colors.underSelectedColor
                    } else {
                        return theme.colors.accent
                    }
                }), compactText: true)
                
                headerItems.append(item)
//                items.append(SPopoverItem(account.peer.displayTitle, {
//                    context.sharedContext.switchToAccount(id: account.account.id)
//                }))
            }
           
        }
        
        switch passcodeData {
        case .none:
            items.append(SPopoverItem(tr(L10n.fastSettingsSetPasscode), { [weak self] in
                guard let `self` = self else {return}
                self.tabController.select(index: self.tabController.count - 1)
                self.context.sharedContext.bindings.rootNavigation().push(PasscodeSettingsViewController(self.context))
            }, theme.icons.fastSettingsLock))
        default:
            items.append(SPopoverItem(tr(L10n.fastSettingsLockTelegram), {
                context.window.sendKeyEvent(KeyboardKey.L, modifierFlags: [.command])
            }, theme.icons.fastSettingsLock))
        }
        items.append(SPopoverItem(theme.colors.isDark ? L10n.fastSettingsDisableDarkMode : L10n.fastSettingsEnableDarkMode, {
            let nightSettings = autoNightSettings(accountManager: context.sharedContext.accountManager) |> take(1) |> deliverOnMainQueue
            
            _ = nightSettings.start(next: { settings in
                if settings.systemBased || settings.schedule != nil {
                    confirm(for: context.window, header: L10n.darkModeConfirmNightModeHeader, information: L10n.darkModeConfirmNightModeText, okTitle: L10n.darkModeConfirmNightModeOK, successHandler: { _ in
                        
                        _ = context.sharedContext.accountManager.transaction { transaction -> Void in
                            transaction.updateSharedData(ApplicationSharedPreferencesKeys.autoNight, { entry in
                                let settings: AutoNightThemePreferences = entry as? AutoNightThemePreferences ?? AutoNightThemePreferences.defaultSettings
                                return settings.withUpdatedSystemBased(false).withUpdatedSchedule(nil)
                            })
                            transaction.updateSharedData(ApplicationSharedPreferencesKeys.themeSettings, { entry in
                                let settings = entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme
                                return settings.withUpdatedToDefault(dark: !theme.colors.isDark).withUpdatedDefaultIsDark(!theme.colors.isDark)
                            })
                            }.start()
                    })
                } else {
                    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings -> ThemePaletteSettings in
                        return settings.withUpdatedToDefault(dark: !theme.colors.isDark).withUpdatedDefaultIsDark(!theme.colors.isDark)
                    }).start()
                }
            })
        }, theme.colors.isDark ? theme.icons.fastSettingsSunny : theme.icons.fastSettingsDark))
       
        
        let time = Int32(Date().timeIntervalSince1970)
        let unmuted = notifications.muteUntil < time
        items.append(SPopoverItem(unmuted ? tr(L10n.fastSettingsMute2Hours) : tr(L10n.fastSettingsUnmute), { [weak self] in
            if let context = self?.context {
                let time = Int32(Date().timeIntervalSince1970 + 2 * 60 * 60)
                _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedMuteUntil(unmuted ? time : 0)}).start()
            }
            
        }, notifications.muteUntil < time ? theme.icons.fastSettingsMute : theme.icons.fastSettingsUnmute))
        let controller = SPopoverViewController(items: items, visibility: 10, headerItems: headerItems)
        showPopover(for: control, with: controller, edge: .maxX, inset: NSMakePoint(control.frame.width - 12, 0))
        self.quickController = controller
    }
    private var previousTheme:TelegramPresentationTheme?
    private var previousIconColor:NSColor?
    private var previousIsUpChatList: Bool?
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        tabController.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        #if !APP_STORE
        updateController.updateLocalizationAndTheme(theme: theme)
        #endif
        
        updateTabsIfNeeded()
        self.tabController.view.needsLayout = true
    }
    
    private func updateTabsIfNeeded() {
        if !tabController.isEmpty && (previousTheme?.colors != theme.colors ||  previousIconColor != theme.colors.accentIcon || self.isUpChatList != self.previousIsUpChatList) {
            var index: Int = 0
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_contacts, theme.icons.tab_contacts_active), at: index)
            index += 1
            if showCallTabs {
                tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_calls, theme.icons.tab_calls_active), at: index)
                index += 1
            }
            
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_chats, isUpChatList ? theme.icons.tab_chats_active_filters : theme.icons.tab_chats_active), at: index)
            index += 1
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.tab_settings, theme.icons.tab_settings_active), at: index)
        }
        self.previousTheme = theme
        self.previousIconColor = theme.colors.accentIcon
        self.previousIsUpChatList = self.isUpChatList
    }
    
    private var previousIndex: Int? = nil
    
    func checkSettings(_ index:Int) {
        let isSettings = tabController.tab(at: index).controller is AccountViewController
        
        let navigation = context.sharedContext.bindings.rootNavigation()
        
        if let controller = navigation.controller as? InputDataController, controller.identifier == "wallet-create" {
            self.previousIndex = index
            quickController?.popover?.hide()
        } else {
            if previousIndex == tabController.count - 1 || isSettings {
                if isSettings && context.sharedContext.layout != .single {
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
        context.sharedContext.bindings.rootNavigation().to(index: index)
    }
    
    override func focusSearch(animated: Bool) {
        if context.sharedContext.layout == .minimisize {
            return
        }
        let animated = animated && (context.sharedContext.layout != .single || context.sharedContext.bindings.rootNavigation().stackCount == 1)
        if context.sharedContext.layout == .single {
            context.sharedContext.bindings.rootNavigation().close()
        }
        if let current = tabController.current {
            if current is AccountViewController {
                tabController.select(index: chatIndex)
            }
            tabController.current?.focusSearch(animated: animated)
        }
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return TitledBarView(controller: self)
    }
    private var firstTime: Bool = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if firstTime {
        //    self.tabController.select(index: chatIndex)
            firstTime = false
        }
        self.tabController.current?.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabController.current?.viewWillAppear(animated)
       // loadViewIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabController.current?.viewWillDisappear(animated)
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
    
    override func navigationUndoHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        if let controller = self.tabController.current {
            return controller.navigationUndoHeaderDidNoticeAnimation(current, previous, animated)
        }
        return {}
    }
    
    func openChat(_ index: Int, force: Bool = false) {
        if self.tabController.current == chatListNavigation {
            chatList.openChat(index, force: force)
        }
    }
    
    var chatList: ChatListController {
        return chatListNavigation.controller as! ChatListController
    }
    
    func showPreferences() {
        context.sharedContext.bindings.switchSplitLayout(.dual)
        if self.context.sharedContext.layout != .minimisize {
            self.tabController.select(index:settingsIndex)
        }
    }
    
    override var responderPriority: HandlerPriority {
        return context.sharedContext.layout == .single ? .medium : .low
    }
    
    func isCanMinimisize() -> Bool{
        return self.tabController.current == chatListNavigation
    }
    
    override init(_ context: AccountContext) {
        
        chatListNavigation = NavigationViewController(ChatListController(context), context.window)
        contacts = ContactsController(context)
        settings = AccountViewController(context)
        phoneCalls = RecentCallsViewController(context)
        #if !APP_STORE
            updateController = UpdateTabController(context.sharedContext)
        #endif
        super.init(context)
        bar = NavigationBarStyle(height: 0)
       // chatListNavigation.alwaysAnimate = true
    }

    deinit {
        layoutDisposable.dispose()
        prefDisposable.dispose()
        settingsDisposable.dispose()
        filterMenuDisposable.dispose()
    }
}
