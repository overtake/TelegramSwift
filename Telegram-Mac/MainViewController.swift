//
//  MainViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


class MainViewController: TelegramViewController {

    private var tabController:TabBarController = TabBarController()
    private let accountManager:AccountManager
    private var contacts:ContactsController
    private var chatList:ChatListController
    private var settings:AccountViewController
    private let phoneCalls:RecentCallsViewController
    private let layoutDisposable:MetaDisposable = MetaDisposable()
    private let badgeCountDisposable: MetaDisposable = MetaDisposable()
    
    var isUpChatList: Bool = false {
        didSet {
            if isUpChatList != oldValue {
                updateLocalizationAndTheme()
            }
        }
    }
    private var hasScollThumb: Bool = false {
        didSet {
            if hasScollThumb != oldValue {
               updateLocalizationAndTheme()
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
    }
    
    override func loadView() {
        super.loadView()
        tabController._frameRect = self._frameRect
        self.bar = NavigationBarStyle(height: 0)
        backgroundColor = theme.colors.background
        addSubview(tabController.view)
        
        tabController.add(tab: TabItem(image: theme.tabBar.icon(key: 0, image: #imageLiteral(resourceName: "Icon_TabContacts"), selected: false), selectedImage: theme.tabBar.icon(key: 0, image: #imageLiteral(resourceName: "Icon_TabContacts_Highlighted"), selected: true), controller: contacts))
        
        tabController.add(tab: TabItem(image: theme.tabBar.icon(key: 1, image: #imageLiteral(resourceName: "Icon_TabRecentCalls"), selected: false), selectedImage: theme.tabBar.icon(key: 1, image: #imageLiteral(resourceName: "Icon_TabRecentCallsHighlighted"), selected: true), controller: phoneCalls))
        
        tabController.add(tab: TabBadgeItem(account, controller: chatList, image: theme.icons.chatTabIcon, selectedImage: hasScollThumb ? isUpChatList ? theme.icons.chatTabIconSelectedUp : theme.icons.chatTabIconSelectedDown : theme.icons.chatTabIconSelected))
        
        tabController.add(tab: TabItem(image: theme.tabBar.icon(key: 3, image: #imageLiteral(resourceName: "Icon_TabSettings"), selected: false), selectedImage: theme.tabBar.icon(key: 3, image: #imageLiteral(resourceName: "Icon_TabSettings_Highlighted"), selected: true), controller: settings, longHoverHandler: { [weak self] control in
            self?.showFastSettings(control)
        }))
        
        tabController.updateLocalizationAndTheme()

        
        self.ready.set(.single(true))
        
        layoutDisposable.set(account.context.layoutHandler.get().start(next: { [weak self] state in
            self?.tabController.hideTabView(state == .minimisize)
        }))
        
        tabController.didChangedIndex = { [weak self] index in
            self?.checkSettings(index)
        }
    }
    
    private func showCallsTab() {
        tabController.insert(tab: TabItem(image: theme.tabBar.icon(key: 1, image: #imageLiteral(resourceName: "Icon_TabRecentCalls"), selected: false), selectedImage: theme.tabBar.icon(key: 1, image: #imageLiteral(resourceName: "Icon_TabRecentCallsHighlighted"), selected: true), controller: phoneCalls), at: 1)
    }
    private func hideCallsTab() {
        tabController.remove(at: 1)
    }
    
    private var showCallTabs: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prefDisposable.set((account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.baseAppSettings]) |> deliverOnMainQueue).start(next: { [weak self] view in
            guard let `self` = self else {return}
            let settings = view.values[ApplicationSpecificPreferencesKeys.baseAppSettings] as? BaseApplicationSettings ?? BaseApplicationSettings.defaultSettings
            if settings.showCallsTab != self.showCallTabs {
                self.showCallTabs = settings.showCallsTab
                if self.showCallTabs {
                    self.showCallsTab()
                } else {
                    self.hideCallsTab()
                }
            }
        }))
        
        let items:[UnreadMessageCountsItem] = [.total(.raw, .messages)]
        let postbox = self.account.postbox
        badgeCountDisposable.set((account.context.badgeFilter.get() |> mapToSignal { value -> Signal<(UnreadMessageCountsView, Int32), Void> in
            return postbox.unreadMessageCountsView(items: items) |> map { view in
                var totalCount:Int32 = 0
                if let total = view.count(for: .total(value, .messages)) {
                    totalCount = total
                }
                
                return (view, totalCount)
            }
            
        } |> deliverOnMainQueue).start(next: { [weak self] _, totalValue in
            #if !STABLE && !APP_STORE
            self?.hasScollThumb = totalValue > 0
            #else
            self?.hasScollThumb = false
            #endif
        }))
    }
    
    private let settingsDisposable = MetaDisposable()
    private let prefDisposable = MetaDisposable()
    private var quickController: ViewController?
    private func showFastSettings(_ control:Control) {
        
        let passcodeData = account.postbox.transaction { transaction -> PostboxAccessChallengeData in
            return transaction.getAccessChallengeData()
        } |> deliverOnMainQueue
        
        let applicationSettings = appNotificationSettings(postbox: account.postbox) |> take(1)  |> deliverOnMainQueue
        
       
        settingsDisposable.set(combineLatest(passcodeData, applicationSettings).start(next: { [weak self] passcode, notifications in
            self?._showFast(control: control, passcodeData: passcode, notifications: notifications)
        }))
        
       
    }
    
    private func _showFast( control: Control, passcodeData: PostboxAccessChallengeData, notifications: InAppNotificationSettings) {
        var items:[SPopoverItem] = []
       
        switch passcodeData {
        case .none:
            items.append(SPopoverItem(tr(L10n.fastSettingsSetPasscode), { [weak self] in
                if let account = self?.account {
                    self?.tabController.select(index: 3)
                    account.context.mainNavigation?.push(PasscodeSettingsViewController(account))
                }
            }, theme.icons.fastSettingsLock))
        default:
            items.append(SPopoverItem(tr(L10n.fastSettingsLockTelegram), {
                if let event = NSEvent.keyEvent(with: .keyDown, location: NSZeroPoint, modifierFlags: [.command], timestamp: Date().timeIntervalSince1970, windowNumber: mainWindow.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: KeyboardKey.L.rawValue) {
                    mainWindow.sendEvent(event)
                }
            }, theme.icons.fastSettingsLock))
        }
        
        items.append(SPopoverItem(theme.colors.isDark ? tr(L10n.fastSettingsDisableDarkMode) : tr(L10n.fastSettingsEnableDarkMode), { [weak self] in
            if let strongSelf = self {
               _ = updateThemeInteractivetly(postbox: strongSelf.account.postbox, f: { settings -> ThemePaletteSettings in
                let palette: ColorPalette
                var palettes:[String : ColorPalette] = [:]
                palettes[dayClassic.name] = dayClassic
                palettes[whitePalette.name] = whitePalette
                palettes[darkPalette.name] = darkPalette
                palettes[nightBluePalette.name] = nightBluePalette
                palettes[mojavePalette.name] = mojavePalette

                if !theme.colors.isDark {
                    palette = palettes[settings.defaultNightName] ?? nightBluePalette
                } else {
                    palette = palettes[settings.defaultDayName] ?? dayClassic
                }
                return ThemePaletteSettings(palette: palette, bubbled: settings.bubbled, fontSize: settings.fontSize, wallpaper: settings.bubbled ? palette.name == dayClassic.name ? .builtin : palette.isDark ? .none: settings.wallpaper : .none, defaultNightName: settings.defaultNightName, defaultDayName: settings.defaultDayName)
            }).start()
               // _ = updateThemeSettings(postbox: strongSelf.account.postbox, palette: !theme.colors.isDark ? darkPalette : dayClassic).start()
            }
        }, theme.colors.isDark ? theme.icons.fastSettingsSunny : theme.icons.fastSettingsDark))
        
        let time = Int32(Date().timeIntervalSince1970)
        let unmuted = notifications.muteUntil < time
        items.append(SPopoverItem(unmuted ? tr(L10n.fastSettingsMute2Hours) : tr(L10n.fastSettingsUnmute), { [weak self] in
            if let account = self?.account {
                let time = Int32(Date().timeIntervalSince1970 + 2 * 60 * 60)
                _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, {$0.withUpdatedMuteUntil(unmuted ? time : 0)}).start()
            }
            
        }, notifications.muteUntil < time ? theme.icons.fastSettingsMute : theme.icons.fastSettingsUnmute))
        let controller = SPopoverViewController(items: items)
        if self.tabController.current != settings {
            showPopover(for: control, with: controller, edge: .maxX, inset: NSMakePoint(control.frame.width - 12, 0))
        }
        self.quickController = controller
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        tabController.updateLocalizationAndTheme()
        
        
        if !tabController.isEmpty {
            var index: Int = 0
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.tabBar.icon(key: 0, image: #imageLiteral(resourceName: "Icon_TabContacts"), selected: false), theme.tabBar.icon(key: 0, image: #imageLiteral(resourceName: "Icon_TabContacts_Highlighted"), selected: true)), at: index)
            index += 1
            if showCallTabs {
                tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.tabBar.icon(key: 1, image: #imageLiteral(resourceName: "Icon_TabRecentCalls"), selected: false), theme.tabBar.icon(key: 1, image: #imageLiteral(resourceName: "Icon_TabRecentCallsHighlighted"), selected: true)), at: index)
                index += 1
            }
            
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.icons.chatTabIcon, hasScollThumb ? isUpChatList ? theme.icons.chatTabIconSelectedUp : theme.icons.chatTabIconSelectedDown : theme.icons.chatTabIconSelected), at: index)
            index += 1
            tabController.replace(tab: tabController.tab(at: index).withUpdatedImages(theme.tabBar.icon(key: 3, image: #imageLiteral(resourceName: "Icon_TabSettings"), selected: false), theme.tabBar.icon(key: 3, image: #imageLiteral(resourceName: "Icon_TabSettings_Highlighted"), selected: true)), at: index)
        }
    }
    
    func checkSettings(_ index:Int) {
        let isSettings = tabController.tab(at: index).controller is AccountViewController
        if isSettings && account.context.layout != .single {
            account.context.mainNavigation?.push(GeneralSettingsViewController(account), false)
        } else {
            account.context.mainNavigation?.enumerateControllers( { controller, index in
                if (controller is ChatController) || (controller is PeerInfoController) || (controller is GroupAdminsController) || (controller is GroupAdminsController)  || (controller is ChannelAdminsViewController) || (controller is ChannelAdminsViewController) || (controller is EmptyChatViewController) {
                    self.backFromSettings(index)
                    return true
                }
                return false
            })
        }
        quickController?.popover?.hide()
    }
    
    private func backFromSettings(_ index:Int) {
        account.context.mainNavigation?.to(index: index)
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return TitledBarView(controller: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !animated {
            self.tabController.select(index: chatIndex)
        }
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
    
    private var chatIndex: Int {
        if showCallTabs {
            return 2
        } else {
            return 1
        }
    }
    
    private var settingsIndex: Int {
        if showCallTabs {
            return 3
        } else {
            return 2
        }
    }
    
    func showPreferences() {
        account.context.switchSplitLayout?(.dual)
        if self.account.context.layout != .minimisize {
            
            self.tabController.select(index:settingsIndex)
        }
    }
    
    func isCanMinimisize() -> Bool{
        return self.tabController.current == chatList
    }
    
    init(_ account:Account, accountManager:AccountManager) {
        
        self.accountManager = accountManager
        chatList = ChatListController(account)
        contacts = ContactsController(account)
        settings = AccountViewController(account, accountManager: accountManager)
        phoneCalls = RecentCallsViewController(account)
        super.init(account)
        bar = NavigationBarStyle(height: 0)
    }

    deinit {
        layoutDisposable.dispose()
        prefDisposable.dispose()
        settingsDisposable.dispose()
    }
}
