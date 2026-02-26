//
//  AccountViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Localization
import Postbox
import SwiftSignalKit

let normalAccountsLimit: Int = 3



struct SetupPasswordConfiguration {
    
    let setup2Fa: Bool
    
    static func with(appConfiguration: AppConfiguration) -> SetupPasswordConfiguration {
        if let data = appConfiguration.data {
            return .init(setup2Fa: data["SETUP_PASSWORD"] != nil)
        } else {
            return .init(setup2Fa: false)
        }
    }
}

private final class AccountSearchBarView: View {
    fileprivate let searchView = SearchView(frame: NSMakeRect(0, 0, 100, 30))
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(searchView)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        searchView.updateLocalizationAndTheme(theme: theme)
        borderColor = theme.colors.border
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        searchView.setFrameSize(NSMakeSize(frame.width - 20, 30))
        searchView.centerY(x: 10)
    }
    
}


fileprivate final class AccountInfoArguments {
    let context: AccountContext
    var storyList: PeerStoryListContext
    let presentController:(ViewController, Bool) -> Void
    let openFaq:()->Void
    let ask:()->Void
    let openUpdateApp:() -> Void
    let openPremium:(Bool)->Void
    let giftPremium:()->Void
    let stars:()->Void
    let ton:()->Void
    let addAccount:([AccountWithInfo])->Void
    let setStatus:(Control, TelegramUser)->Void
    let runStatusPopover:()->Void
    let set2Fa:(TwoStepVeriticationAccessConfiguration?)->Void
    let openStory:(StoryInitialIndex?)->Void
    let openWebBot:(AttachMenuBot)->Void
    init(context: AccountContext, storyList: PeerStoryListContext, presentController:@escaping(ViewController, Bool)->Void, openFaq: @escaping()->Void, ask:@escaping()->Void, openUpdateApp: @escaping() -> Void, openPremium:@escaping(Bool)->Void, giftPremium:@escaping()->Void, addAccount:@escaping([AccountWithInfo])->Void, setStatus:@escaping(Control, TelegramUser)->Void, runStatusPopover:@escaping()->Void, set2Fa:@escaping(TwoStepVeriticationAccessConfiguration?)->Void, openStory:@escaping(StoryInitialIndex?)->Void, openWebBot:@escaping(AttachMenuBot)->Void, stars:@escaping()->Void, ton:@escaping()->Void) {
        self.context = context
        self.storyList = storyList
        self.presentController = presentController
        self.openFaq = openFaq
        self.ask = ask
        self.openUpdateApp = openUpdateApp
        self.giftPremium = giftPremium
        self.openPremium = openPremium
        self.addAccount = addAccount
        self.setStatus = setStatus
        self.runStatusPopover = runStatusPopover
        self.set2Fa = set2Fa
        self.openStory = openStory
        self.openWebBot = openWebBot
        self.stars = stars
        self.ton = ton
    }
}


private enum AccountInfoEntryId : Hashable {
    case index(Int)
    case account(AccountWithInfo)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .index(value):
            hasher.combine(value)
        case let .account(info):
            hasher.combine(info.account.id.int64)
        }
    }
}

private final class AnyUpdateStateEquatable  : Equatable {
    let any: Any
    init(any: Any) {
        self.any = any
    }
    static func ==(lhs: AnyUpdateStateEquatable, rhs: AnyUpdateStateEquatable) -> Bool {
        return lhs === rhs
    }
}


private enum AccountInfoEntry : TableItemListNodeEntry {
    case info(index:Int, viewType: GeneralViewType, PeerEquatable, EngineStorySubscriptions.Item?)
    case setStatus(index:Int, viewType: GeneralViewType, PeerEquatable)
    case set2FaAlert(index:Int, viewType: GeneralViewType)
    case set2Fa(index:Int, settings: TwoStepVeriticationAccessConfiguration?, viewType: GeneralViewType)
    case accountRecord(index: Int, viewType: GeneralViewType, info: AccountWithInfo)
    case addAccount(index: Int, [AccountWithInfo], viewType: GeneralViewType)
    case proxy(index: Int, viewType: GeneralViewType, status: String?)
    case stories(index: Int, viewType: GeneralViewType)
    case attach(index: Int, AttachMenuBot, viewType: GeneralViewType)
    case general(index: Int, viewType: GeneralViewType)
    case stickers(index: Int, viewType: GeneralViewType)
    case notifications(index: Int, viewType: GeneralViewType, status: UNUserNotifications.AuthorizationStatus)
    case language(index: Int, viewType: GeneralViewType, current: String)
    case appearance(index: Int, viewType: GeneralViewType)
    case privacy(index: Int, viewType: GeneralViewType, AccountPrivacySettings?, TwoStepVeriticationAccessConfiguration?, WebSessionsContextState)
    case dataAndStorage(index: Int, viewType: GeneralViewType)
    case activeSessions(index: Int, viewType: GeneralViewType, activeSessions: Int)
    case passport(index: Int, viewType: GeneralViewType, peer: PeerEquatable)
    case update(index: Int, viewType: GeneralViewType, state: AnyUpdateStateEquatable)
    case filters(index: Int, viewType: GeneralViewType)
    case premium(index: Int, viewType: GeneralViewType)
    case business(index: Int, viewType: GeneralViewType)
    case giftPremium(index: Int, viewType: GeneralViewType)
    case stars(index: Int, count: StarsAmount, viewType: GeneralViewType)
    case ton(index: Int, count: StarsAmount, viewType: GeneralViewType)
    case about(index: Int, viewType: GeneralViewType)
    case faq(index: Int, viewType: GeneralViewType)
    case ask(index: Int, viewType: GeneralViewType)

    case whiteSpace(index:Int, height:CGFloat)
    
    var stableId: AccountInfoEntryId {
        switch self {
        case .info:
            return .index(0)
        case .setStatus:
            return .index(1)
        case .set2FaAlert:
            return .index(2)
        case .set2Fa:
            return .index(3)
        case let .accountRecord(_, _, info):
            return .account(info)
        case .addAccount:
            return .index(4)
        case .stories:
            return .index(5)
        case .general:
            return .index(6)
        case .proxy:
            return .index(7)
        case .notifications:
            return .index(8)
        case .dataAndStorage:
            return .index(9)
        case .activeSessions:
            return .index(10)
        case .privacy:
            return .index(11)
        case .language:
            return .index(12)
        case .stickers:
            return .index(13)
        case .filters:
            return .index(14)
        case .update:
            return .index(15)
        case .appearance:
            return .index(16)
        case .passport:
            return .index(17)
        case .premium:
            return .index(18)
        case .business:
            return .index(19)
        case .giftPremium:
            return .index(20)
        case .stars:
            return .index(21)
        case .ton:
            return .index(22)
        case .faq:
            return .index(23)
        case .ask:
            return .index(24)
        case .about:
            return .index(25)
        case let .attach(index, _, _):
            return .index(26 + index)
        case let .whiteSpace(index, _):
            return .index(1000 + index)
        }
    }
    
    var index:Int {
        switch self {
        case let .info(index, _, _, _):
            return index
        case let .setStatus(index, _, _):
            return index
        case let .set2FaAlert(index, _):
            return index
        case let .set2Fa(index, _, _):
            return index
        case let .accountRecord(index, _, _):
            return index
        case let .addAccount(index, _, _):
            return index
        case let  .stories(index, _):
            return index
        case let .attach(index, _, _):
            return index
        case let  .general(index, _):
            return index
        case let  .proxy(index, _, _):
            return index
        case let .stickers(index, _):
            return index
        case let .notifications(index, _, _):
            return index
        case let .language(index, _, _):
            return index
        case let .appearance(index, _):
            return index
        case let .privacy(index, _, _, _, _):
            return index
        case let .dataAndStorage(index, _):
            return index
        case let .activeSessions(index, _, _):
            return index
        case let .about(index, _):
            return index
        case let .passport(index, _, _):
            return index
        case let .filters(index, _):
            return index
        case let .premium(index, _):
            return index
        case let .business(index, _):
            return index
        case let .giftPremium(index, _):
            return index
        case let .stars(index, _, _):
            return index
        case let .ton(index, _, _):
            return index
        case let .faq(index, _):
            return index
        case let .ask(index, _):
            return index
        case let .update(index, _, _):
            return index
        case let .whiteSpace(index, _):
            return index
        }
    }
    
    static func <(lhs:AccountInfoEntry, rhs:AccountInfoEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: AccountInfoArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .info(_, viewType, peer, storyStats):
            return AccountInfoItem(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets(left: 12, right: 12), context: arguments.context, peer: peer.peer as! TelegramUser, storyStats: storyStats, action: {
                let first: Atomic<Bool> = Atomic(value: true)
                EditAccountInfoController(context: arguments.context, f: { controller in
                    arguments.presentController(controller, first.swap(false))
                })
            }, setStatus: arguments.setStatus, openStory: arguments.openStory)
        case let .setStatus(_, viewType, peer):
            let icon: CGImage = peer.peer.emojiStatus != nil ? theme.icons.account_change_status : theme.icons.account_set_status
            let text = peer.peer.emojiStatus != nil ? strings().accountSettingsChangeStatus : strings().accountSettingsUpdateStatus
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accentIcon), type: .none, viewType: viewType, action: arguments.runStatusPopover, thumb: GeneralThumbAdditional(thumb: icon, textInset: 35, thumbInset: 0), border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .set2FaAlert(_, viewType):
            return TitleAndInfoAlertItem(initialSize, stableId: stableId, title: strings().accountSettingsProtectAccountTitle, info: strings().accountSettingsProtectAccountInfo, viewType: viewType, inset: NSEdgeInsets(left: 12, right: 12))
        case let .set2Fa(_, privacy, viewType):
            let icon: CGImage = theme.icons.account_settings_set_password
            let text = strings().accountSettingsProtectAccountSet
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accentIcon), type: .none, viewType: viewType, action: {
                arguments.set2Fa(privacy)
            }, thumb: GeneralThumbAdditional(thumb: icon, textInset: 35, thumbInset: 0), border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .accountRecord(_, viewType, info):
            return ShortPeerRowItem(initialSize, peer: info.peer, account: info.account, context: nil, height: 42, photoSize: NSMakeSize(28, 28), titleStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text, highlightColor: theme.colors.underSelectedColor), borderType: [.Right], inset: NSEdgeInsets(left: 12, right: 12), viewType: viewType, action: {
                arguments.context.sharedContext.switchToAccount(id: info.account.id, action: nil)
            }, contextMenuItems: {
                
                var items:[ContextMenuItem] = []
                
                items.append(ContextMenuItem(strings().accountOpenInWindow, handler: {
                    arguments.context.sharedContext.openAccount(id: info.account.id)
                }, itemImage: MenuAnimation.menu_open_profile.value))
                
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().accountSettingsDeleteAccount, handler: {
                    verifyAlert_button(for: arguments.context.window, information: strings().accountConfirmLogoutText, successHandler: { _ in
                        _ = logoutFromAccount(id: info.account.id, accountManager: arguments.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                    })
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                
                return .single(items)
            }, alwaysHighlight: true, badgeNode: GlobalBadgeNode(info.account, sharedContext: arguments.context.sharedContext, getColor: { _ in theme.colors.accent }, sync: true), compactText: true, highlightVerified: true)
        case let .addAccount(_, accounts, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsAddAccount, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accentIcon), type: .none, viewType: viewType, action: {
                arguments.addAccount(accounts)
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.account_add_account, textInset: 35, thumbInset: 0), border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .general(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsGeneral, icon: theme.icons.settingsGeneral, activeIcon: theme.icons.settingsGeneralActive, type: .next, viewType: viewType, action: {
                arguments.presentController(GeneralSettingsViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .stories(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsMyProfile, icon: theme.icons.settingsStories, activeIcon: theme.icons.settingsStoriesActive, type: .next, viewType: viewType, action: {
                PeerInfoController.push(navigation: arguments.context.bindings.rootNavigation(), context: arguments.context, peerId: arguments.context.peerId, animated: false)
//                arguments.presentController(StoryMediaController(context: arguments.context, peerId: arguments.context.peerId, listContext: arguments.storyList, standalone: true), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .attach(_, bot, viewType):
            var icon: CGImage?
            
            if let file = bot.icons[.macOSSettingsStatic] {
                let iconPath = arguments.context.account.postbox.mediaBox.resourcePath(file.resource)
                let linked = link(path: iconPath, ext: "png")!
                
                if let image = NSImage(contentsOf: .init(fileURLWithPath: linked)) {
                    icon = generateSettingsIcon(image.precomposed(flipVertical: true, scale: System.backingScale))
                }
            }
            
            if icon == nil {
                icon = NSImage(named: "Icon_Settings_BotCap")!.precomposed(flipVertical: true, scale: System.backingScale)
            }
            let type: GeneralInteractedType
            if bot.flags.contains(.notActivated) || bot.flags.contains(.showInSettingsDisclaimer) {
                type = .imageContext(generateTextIcon_NewBadge(bgColor: theme.colors.accent, textColor: theme.colors.underSelectedColor), "")
            } else {
                type = .next
            }
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: bot.shortName, icon: icon!, activeIcon: icon!, type: type, viewType: viewType, action: {
                arguments.openWebBot(bot)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .proxy(_, viewType, status):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsProxy, icon: theme.icons.settingsProxy, activeIcon: theme.icons.settingsProxyActive, type: .nextContext(status ?? ""), viewType: viewType, action: {
                let controller = proxyListController(accountManager: arguments.context.sharedContext.accountManager, network: arguments.context.account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed
                    
                    showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: message)), for: arguments.context.window)
                }, pushController: { controller in
                     arguments.presentController(controller, false)
                })
                arguments.presentController(controller, true)

            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .stickers(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsStickersAndEmoji, icon: theme.icons.settingsStickers, activeIcon: theme.icons.settingsStickersActive, type: .next, viewType: viewType, action: {
                arguments.presentController(InstalledStickerPacksController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .notifications(_, viewType, status):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsNotifications, icon: theme.icons.settingsNotifications, activeIcon: theme.icons.settingsNotificationsActive, type: status == .denied ? .image(#imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed()) : .next, viewType: viewType, action: {
                arguments.presentController(NotificationPreferencesController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .language(_, viewType, current):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsLanguage, icon: theme.icons.settingsLanguage, activeIcon: theme.icons.settingsLanguageActive, type: .nextContext(current), viewType: viewType, action: {
                arguments.presentController(LanguageController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .appearance(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsTheme, icon: theme.icons.settingsAppearance, activeIcon: theme.icons.settingsAppearanceActive, type: .next, viewType: viewType, action: {
                arguments.presentController(AppAppearanceViewController(context: arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .privacy(_, viewType, privacySettings, twoStep, _):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsPrivacyAndSecurity, icon: theme.icons.settingsSecurity, activeIcon: theme.icons.settingsSecurityActive, type: .next, viewType: viewType, action: {
                arguments.presentController(PrivacyAndSecurityViewController(arguments.context, initialSettings: privacySettings, twoStepVerificationConfiguration: twoStep), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .dataAndStorage(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsDataAndStorage, icon: theme.icons.settingsStorage, activeIcon: theme.icons.settingsStorageActive, type: .next, viewType: viewType, action: {
                arguments.presentController(DataAndStorageViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .activeSessions(_, viewType, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsActiveSessions, icon: theme.icons.settingsSessions, activeIcon: theme.icons.settingsSessionsActive, type: count > 0 ? .nextContext("\(count)") : .none, viewType: viewType, action: {
                arguments.presentController(RecentSessionsController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case .about:
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .modern(position: .single, insets: .init()), text: APP_VERSION_STRING, font: .normal(.text), color: theme.colors.grayText)
        case let .passport(_, viewType, peer):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsPassport, icon: theme.icons.settingsPassport, activeIcon: theme.icons.settingsPassportActive, type: .next, viewType: viewType, action: {
                arguments.presentController(PassportController(arguments.context, peer.peer, request: nil, nil), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .premium(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsPremium, icon: theme.icons.settingsPremium, activeIcon: theme.icons.settingsPremium, type: .next, viewType: viewType, action: {
                arguments.openPremium(false)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .business(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsTelegramBusiness, icon: theme.icons.settingsBusiness, activeIcon: theme.icons.settingsBusinessActive, type: .next, viewType: viewType, action: {
                arguments.openPremium(true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .giftPremium(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsSendGift, icon: theme.icons.settingsGiftPremium, activeIcon: theme.icons.settingsGiftPremium, type: .next, viewType: viewType, action: arguments.giftPremium, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .stars(_, stars, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsStars, icon: theme.icons.settingsStars, activeIcon: theme.icons.settingsStars, type: .nextContext(stars.value > 0 ? "\(stars.stringValue)" : ""), viewType: viewType, action: arguments.stars, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .ton(_, ton, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsTon, icon: theme.icons.settingsWallet, activeIcon: theme.icons.settingsWalletActive, type: .nextContext(ton.value > 0 ? "\(ton.string(.ton))" : ""), viewType: viewType, action: arguments.ton, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .faq(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsFAQ, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, viewType: viewType, action: arguments.openFaq, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .ask(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsAskQuestion, icon: theme.icons.settingsAskQuestion, activeIcon: theme.icons.settingsAskQuestionActive, type: .next, viewType: viewType, action: {
                verifyAlert_button(for: arguments.context.window, information: strings().accountConfirmAskQuestion, option: strings().accountConfirmGoToFaq, successHandler: {  result in
                    switch result {
                    case .basic:
                        _ = showModalProgress(signal: arguments.context.engine.peers.supportPeerId(), for: arguments.context.window).start(next: {  peerId in
                            if let peerId = peerId {
                                arguments.presentController(ChatController(context: arguments.context, chatLocation: .peer(peerId)), true)
                            }
                        })
                    case .thrid:
                        arguments.openFaq()
                    }
                })
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .filters(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsFilters, icon: theme.icons.settingsFilters, activeIcon: theme.icons.settingsFiltersActive, type: .next, viewType: viewType, action: {
                arguments.presentController(ChatListFiltersListController(context: arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .update(_, viewType, state):
            
            var text: String = ""
            #if !APP_STORE
            if let state = state.any as? AppUpdateState {
                switch state.loadingState {
                case let .loading(_, current, total):
                    text = "\(Int(Float(current) / Float(total) * 100))%"
                case let .readyToInstall(item), let .unarchiving(item):
                    text = "\(item.displayVersionString!).\(item.versionString!)"
                case .uptodate:
                    text = "" //strings().accountViewControllerDescUpdated
                case .failed:
                    text = strings().accountViewControllerDescFailed
                default:
                    text = ""
                }
            }
            #endif
           
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountViewControllerUpdate, icon: theme.icons.settingsUpdate, activeIcon: theme.icons.settingsUpdateActive, type: .nextContext(text), viewType: viewType, action: {
                arguments.openUpdateApp()
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .whiteSpace(_, height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId, border: [BorderType.Right], backgroundColor: .clear)
        }
    }
    
}


private func accountInfoEntries(peerView:PeerView, context: AccountContext, accounts: [AccountWithInfo], language: TelegramLocalization, privacySettings: AccountPrivacySettings?, webSessions: WebSessionsContextState, proxySettings: (ProxySettings, ConnectionStatus), passportVisible: Bool, appUpdateState: Any?, hasFilters: Bool, sessionsCount: Int, unAuthStatus: UNUserNotifications.AuthorizationStatus, has2fa: Bool, twoStepConfiguration: TwoStepVeriticationAccessConfiguration?, storyStats: EngineStorySubscriptions?, attachMenuBots: [AttachMenuBot], stars: StarsContext.State?, ton: StarsContext.State?) -> [AccountInfoEntry] {
    var entries:[AccountInfoEntry] = []
    
    var index:Int = 0
        
    if let peer = peerViewMainPeer(peerView) as? TelegramUser {
//        entries.append(.whiteSpace(index: index, height: 20))
//        index += 1
        entries.append(.info(index: index, viewType: .singleItem, PeerEquatable(peer), storyStats?.accountItem))
        index += 1
        
//        entries.append(.whiteSpace(index: index, height: 20))
//        index += 1

       
    }
    
    if let peer = peerViewMainPeer(peerView), context.isPremium {
        entries.append(.setStatus(index: index, viewType: .singleItem, PeerEquatable(peer)))
        index += 1
    }
    
    
    var has2fa = has2fa
    if let twoStepConfiguration = twoStepConfiguration {
        switch twoStepConfiguration {
        case .set:
            has2fa = true
        default:
            has2fa = false
        }
    } else {
        has2fa = true
    }
    if !SetupPasswordConfiguration.with(appConfiguration: context.appConfiguration).setup2Fa {
        has2fa = true
    }
    
    if !has2fa {
        entries.append(.whiteSpace(index: index, height: 10))
        index += 1
        entries.append(.set2FaAlert(index: index, viewType: .firstItem))
        index += 1
        entries.append(.set2Fa(index: index, settings: twoStepConfiguration, viewType: .lastItem))
        index += 1
        entries.append(.whiteSpace(index: index, height: 10))
        index += 1
    }
    
   
//    entries.append(.whiteSpace(index: index, height: 20))
//    index += 1
//
//
    
    if !context.isSupport {
        for account in accounts {
            if account.account.id != context.account.id {
                entries.append(.accountRecord(index: index, viewType: .singleItem, info: account))
                index += 1
            }
        }
    }
    
    let accountsLimit: Int = normalAccountsLimit
    let effectiveLimit: Int
    if context.premiumIsBlocked {
        effectiveLimit = accountsLimit
    } else {
        effectiveLimit = accountsLimit + 1
    }
//    let hasPremium = accounts.filter({ $0.peer.isPremium })
//    let normalCount = accounts.filter({ !$0.peer.isPremium }).count

    if accounts.count < effectiveLimit, !context.isSupport {
        entries.append(.addAccount(index: index, accounts, viewType: .singleItem))
        index += 1
    }
    entries.append(.whiteSpace(index: index, height: 10))
    index += 1
    
    
    entries.append(.stories(index: index, viewType: .singleItem))
    index += 1

    entries.append(.whiteSpace(index: index, height: 10))
    index += 1
    
    for bot in attachMenuBots {
        if bot.flags.contains(.showInSettings) {
            entries.append(.attach(index: index, bot, viewType: .singleItem))
            index += 1
        }
    }
    
    
    if !proxySettings.0.servers.isEmpty {
        entries.append(.whiteSpace(index: index, height: 10))
        index += 1
        
        let status: String
        switch proxySettings.1 {
        case .online:
            status = proxySettings.0.enabled ? strings().accountSettingsProxyConnected : strings().accountSettingsProxyDisabled
        default:
            status = proxySettings.0.enabled ? strings().accountSettingsProxyConnecting : strings().accountSettingsProxyDisabled
        }
        entries.append(.proxy(index: index, viewType: .singleItem, status: status))
        index += 1
        
    }
    
    entries.append(.whiteSpace(index: index, height: 10))
    index += 1
    
    entries.append(.general(index: index, viewType: .singleItem))
    index += 1
    entries.append(.notifications(index: index, viewType: .singleItem, status: unAuthStatus))
    index += 1
    entries.append(.privacy(index: index, viewType: .singleItem, privacySettings, twoStepConfiguration, webSessions))
    index += 1
    entries.append(.dataAndStorage(index: index, viewType: .singleItem))
    index += 1
    entries.append(.activeSessions(index: index, viewType: .singleItem, activeSessions: sessionsCount))
    index += 1
    entries.append(.appearance(index: index, viewType: .singleItem))
    index += 1
    entries.append(.language(index: index, viewType: .singleItem, current: language.localizedName))
    index += 1
    entries.append(.stickers(index: index, viewType: .singleItem))
    index += 1
    
    if hasFilters {
        entries.append(.filters(index: index, viewType: .singleItem))
        index += 1
    }
    
    if let state = appUpdateState, !context.isSupport {
        entries.append(.update(index: index, viewType: .singleItem, state: AnyUpdateStateEquatable(any: state)))
        index += 1
    }
   

    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    if let peer = peerViewMainPeer(peerView) as? TelegramUser, passportVisible {
        entries.append(.passport(index: index, viewType: .singleItem, peer: PeerEquatable(peer)))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
    }
    
    if !context.premiumIsBlocked {
        entries.append(.premium(index: index, viewType: .singleItem))
        index += 1
        
        
        let stars_purchase_blocked = context.appConfiguration.getBoolValue("stars_purchase_blocked", orElse: true)
        
        if !stars_purchase_blocked, let stars  {
            entries.append(.stars(index: index, count: stars.balance, viewType: .singleItem))
            index += 1
        }
        
        if let ton, ton.balance.value > 0 || !ton.transactions.isEmpty  {
            entries.append(.ton(index: index, count: ton.balance, viewType: .singleItem))
            index += 1
        }

        entries.append(.business(index: index, viewType: .singleItem))
        index += 1
        
        entries.append(.giftPremium(index: index, viewType: .singleItem))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
    }
   

    entries.append(.faq(index: index, viewType: .singleItem))
    index += 1
    entries.append(.ask(index: index, viewType: .singleItem))
    index += 1
    
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    entries.append(.about(index: index, viewType: .singleItem))
    index += 1
    
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    return entries
}

private func prepareEntries(left: [AppearanceWrapperEntry<AccountInfoEntry>], right: [AppearanceWrapperEntry<AccountInfoEntry>], arguments: AccountInfoArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated)  = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


final class AccountControllerView : Control {
    fileprivate let searchView: AccountSearchBarView
    fileprivate let tableView: TableView
    fileprivate let edit = TextButton()
    private let statusContainer: View
    private let textView = TextView()
    
    required init(frame frameRect: NSRect) {
        statusContainer = .init(frame: NSMakeRect(0, 0, frameRect.width, 40))
        searchView = AccountSearchBarView(frame: NSMakeRect(0, 40, frameRect.width, 50))
        tableView = TableView(frame: NSMakeRect(0, 50, frameRect.width, frameRect.height - 50))
        super.init(frame: frameRect)
        addSubview(statusContainer)
        addSubview(searchView)
        addSubview(tableView)
        border = [.Right]
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false

        statusContainer.addSubview(edit)
        statusContainer.addSubview(textView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        borderColor = theme.colors.border
        edit.set(font: .medium(.title), for: .Normal)
        edit.set(text: strings().navigationEdit, for: .Normal)
        edit.set(color: theme.colors.accent, for: .Normal)
        edit.scaleOnClick = true
        self.backgroundColor = theme.colors.background
        
        let layout = TextViewLayout(.initialize(string: strings().accountViewControllerTitle, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
    }
    
    override func layout() {
        super.layout()
        statusContainer.frame = NSMakeRect(0, 0, frame.width, 40)
        edit.sizeToFit(NSMakeSize(10, 14))
        edit.setFrameOrigin(NSMakePoint(statusContainer.frame.width - edit.frame.width - 10, statusContainer.frame.height - edit.frame.height))
        textView.centerX(y: 14)

        searchView.frame = NSMakeRect(0, statusContainer.frame.maxY, frame.width, 50)
        tableView.frame = NSMakeRect(0, searchView.frame.maxY, frame.width, frame.height - searchView.frame.maxY)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AccountViewController : TelegramGenericViewController<AccountControllerView>, TableViewDelegate {
    
    
    private let disposable = MetaDisposable()
    
    let actionsDisposable = DisposableSet()
    
    private var searchController: InputDataController?
    private let searchState: ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    var navigation:NavigationViewController? {
        return context.bindings.rootNavigation()
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        self.searchController?.view.frame = bounds
    }
    
    
    private func showSearchController(animated: Bool) {
        if searchController == nil {
            let rect = tableView.frame
            let searchController = SearchSettingsController(context: context, searchQuery: self.searchState.get(), archivedStickerPacks: .single(nil), privacySettings: self.settings.get() |> map { $0.0 })
            searchController.bar = .init(height: 0)
            searchController._frameRect = rect
            searchController.tableView.border = [.Right]
            self.searchController = searchController
            searchController.navigationController = self.navigationController
            searchController.viewWillAppear(true)
            if animated {
                searchController.view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            } else {
                searchController.viewDidAppear(animated)
            }
            
            self.addSubview(searchController.view)
            searchController.viewDidAppear(animated)
        }
    }
    
    
    
    private func hideSearchController(animated: Bool) {
        if let searchController = self.searchController {
            searchController.viewWillDisappear(animated)
            searchController.view.layer?.opacity = animated ? 1.0 : 0.0
            searchController.viewDidDisappear(true)
            self.searchController = nil
            let view = searchController.view
            
            searchController.view._change(opacity: 0, animated: animated, duration: 0.25, timingFunction: CAMediaTimingFunctionName.spring, completion: { [weak view] completed in
                view?.removeFromSuperview()
            })
        }
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        guard context.layout != .minimisize else {
            return .invoked
        }
        if searchView.state == .None {
            return searchView.changeResponder() ? .invoked : .rejected
        } else if searchView.state == .Focus && searchView.query.length > 0 {
            searchView.change(state: .None,  true)
            return .invoked
        }
        return .rejected
    }
    
 
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return item is GeneralInteractedRowItem || item is AccountInfoItem || item is ShortPeerRowItem
    }
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        
    }
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    private let settings: Promise<(AccountPrivacySettings?, WebSessionsContextState, (ProxySettings, ConnectionStatus), (Bool, Bool))> = Promise()
    
    func updateMessagesPrivacy(noPaidMessages: SelectivePrivacySettings, globalSettings: GlobalPrivacySettings) {
        let privacy = self.settings.get() |> deliverOnMainQueue |> take(1)
        _ = privacy.startStandalone(next: { [weak self] privacy, web, proxy, value in
            var privacy = privacy
            privacy?.noPaidMessages = noPaidMessages
            privacy?.globalSettings = globalSettings
            DispatchQueue.main.async {
                self?.settings.set(.single((privacy, web, proxy, value)))
            }
        })
    }
    
    func updatePrivacy(_ updated: SelectivePrivacySettings, kind: SelectivePrivacySettingsKind) {
        let privacy = self.settings.get() |> deliverOnMainQueue |> take(1)
        
        _ = privacy.startStandalone(next: { [weak self] privacy, web, proxy, value in
            var privacy = privacy
            switch kind {
            case .presence:
                privacy?.presence = updated
            case .groupInvitations:
                privacy?.groupInvitations = updated
            case .voiceCalls:
                privacy?.voiceCalls = updated
            case .profilePhoto:
                privacy?.profilePhoto = updated
            case .forwards:
                privacy?.forwards = updated
            case .phoneNumber:
                privacy?.phoneNumber = updated
            case .voiceMessages:
                privacy?.voiceMessages = updated
            case .bio:
                privacy?.bio = updated
            case .birthday:
                privacy?.birthday = updated
            case .gifts:
                privacy?.giftsAutoSave = updated
            }
            DispatchQueue.main.async {
                self?.settings.set(.single((privacy, web, proxy, value)))
            }
        })
    }
    
    var privacySettings: Signal<AccountPrivacySettings?, NoError> {
        return settings.get() |> map { $0.0 }
    }
    
    private let syncLocalizations = MetaDisposable()
    fileprivate let passportPromise: Promise<(Bool, Bool)> = Promise((false, false))
    fileprivate let hasFilters: Promise<Bool> = Promise(false)

    private weak var arguments: AccountInfoArguments?
    override func viewDidLoad() {
        super.viewDidLoad()
//        genericView.border = [.Right]
        tableView.delegate = self
       // self.rightBarView.border = [.Right]
        let context = self.context
        //theme.colors.listBackground
        tableView.getBackgroundColor = {
            return .clear
        }
        
        searchView.searchInteractions = SearchInteractions({ [weak self] state, animated in
            guard let `self` = self else {return}
            self.searchState.set(state)
            switch state.state {
            case .Focus:
                self.showSearchController(animated: animated)
            case .None:
                self.hideSearchController(animated: animated)
            }
            
        }, { [weak self] state in
            self?.searchState.set(state)
        })
        
        genericView.edit.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            let first: Atomic<Bool> = Atomic(value: true)
            EditAccountInfoController(context: context, f: { [weak self] controller in
                self?.arguments?.presentController(controller, first.swap(false))
            })
        }, for: .Click)
        
        let privacySettings = context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)
        
        settings.set(combineLatest(Signal<AccountPrivacySettings?, NoError>.single(nil) |> then(privacySettings), context.webSessions.state, proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { settings in
            return context.account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        
        
        
        
        syncLocalizations.set(context.engine.localization.synchronizedLocalizationListState().start())
        
        
        self.hasFilters.set(context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { view -> Bool in
            let configuration = ChatListFilteringConfiguration(appConfiguration: view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue)
            return configuration.isEnabled
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<AccountInfoEntry>]> = Atomic(value: [])
        
        
        let setStatus:(Control, TelegramUser)->Void = { control, peer in
            let callback:(TelegramMediaFile, StarGift.UniqueGift?, Int32?, CGRect?)->Void = { file, starGift, timeout, fromRect in
                context.reactions.setStatus(file, peer: peer, timestamp: context.timestamp, timeout: timeout, fromRect: fromRect, starGift: starGift)
            }
            if control.popover == nil {
                showPopover(for: control, with: PremiumStatusController(context, callback: callback, peer: peer), edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .reveal)
            }
        }
        
        
        let arguments = AccountInfoArguments(context: context, storyList: PeerStoryListContext(account: context.account, peerId: context.peerId, isArchived: false, folderId: nil), presentController: { [weak self] controller, main in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            guard let singleLayout = self?.context.layout else {return}
            if main {
                navigation.removeExceptMajor()
            }
            navigation.push(controller, !main || singleLayout == .single)
        }, openFaq: {
            openFaq(context: context)
        }, ask: {
            
        }, openUpdateApp: { [weak self] in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            #if !APP_STORE
            navigation.push(AppUpdateViewController(), false)
            #endif
        }, openPremium: { [weak self] business in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            if business, context.isPremium {
                if !(navigation.controller is PremiumBoardingController) {
                    navigation.push(PremiumBoardingController(context: context, source: .business_standalone), false)
                }
            } else {
                prem(with: PremiumBoardingController(context: context, source: business ? .business : .settings), for: context.window)
            }
        }, giftPremium: {
            multigift(context: context)
        }, addAccount: { accounts in
            let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            let hasPremium = accounts.contains(where: { $0.peer.isPremium })
            if accounts.count == normalAccountsLimit {
                if hasPremium {
                    context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
                } else {
                    showPremiumLimit(context: context, type: .accounts(accounts.count))
                }
            } else {
                context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
            }
        }, setStatus: { control, user in
            setStatus(control, user)
        }, runStatusPopover: { [weak self] in
            guard let item = self?.tableView.item(at: 0) as? AccountInfoItem else {
                return
            }
            if let control = item.statusControl {
                setStatus(control, item.peer)
            }
        }, set2Fa: { [weak self] configuration in
            self?.navigation?.push(twoStepVerificationUnlockController(context: context, mode: .access(configuration), presentController: { [weak self] controller, isRoot, animated in
                guard let `self` = self, let navigation = self.navigation else {return}
                if isRoot {
                    navigation.removeUntil(PrivacyAndSecurityViewController.self)
                }
                if !animated {
                    navigation.stackInsert(controller, at: navigation.stackCount)
                } else {
                    navigation.push(controller)
                }
            }))
        }, openStory: { initialId in
            StoryModalController.ShowStories(context: context, isHidden: false, initialId: initialId, singlePeer: true)
        }, openWebBot: { bot in
            openWebBot(bot, context: context)
        }, stars: {
            showModal(with: Star_ListScreen(context: context, source: .account), for: context.window)
        }, ton: {
            showModal(with: Star_ListScreen(context: context, currency: .ton, source: .account), for: context.window)
        })
        
        self.arguments = arguments
        
        let atomicSize = self.atomicSize
        

        let appUpdateState: Signal<Any?, NoError>
        #if APP_STORE
            appUpdateState = .single(nil)
        #else
        appUpdateState = appUpdateStateSignal |> map(Optional.init)
        #endif
        
        
        let sessionsCount = context.activeSessionsContext.state |> map {
            $0.sessions.count
        }
        
        passportPromise.set(context.engine.auth.twoStepAuthData() |> map { value in
            return (value.hasSecretValues, value.currentPasswordDerivation != nil)
        } |> `catch` { error -> Signal<(Bool, Bool), NoError> in
                return .single((false, false))
        })

        let twoStep: Signal<TwoStepVeriticationAccessConfiguration?, NoError> = .single(nil) |> then(context.engine.auth.twoStepVerificationConfiguration() |> map { .init(configuration: $0, password: nil) })
        
        let storyStats = context.engine.messages.storySubscriptions(isHidden: false)
        
        let bots = context.engine.messages.attachMenuBots() |> then(.complete() |> suspendAwareDelay(1.0, queue: .mainQueue())) |> restart
        
        let acceptBots:ValuePromise<[AttachMenuBot]> = ValuePromise(ignoreRepeated: true)
        
        var loading:Set<PeerId> = Set()
        actionsDisposable.add(bots.start(next: { value in
            var ready: [AttachMenuBot] = []
            for value in value {
                if !loading.contains(value.peer.id) {
                    if let file = value.icons[.macOSSettingsStatic] {
                        if let peerReference = PeerReference(value.peer._asPeer()) {
                            _ = freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.attachBot(peer: peerReference, media: file)).start()
                            loading.insert(value.peer.id)
                        }
                    }
                }
                if let file = value.icons[.macOSSettingsStatic] {
                    let iconPath = arguments.context.account.postbox.mediaBox.resourcePath(file.resource)
                    let linked = link(path: iconPath, ext: "png")!
                    
                    if let _ = NSImage(contentsOf: .init(fileURLWithPath: linked)) {
                        ready.append(value)
                    }
                } else {
                    ready.append(value)
                }
            }
            acceptBots.set(ready)
        }))
        
        
        let apply = combineLatest(queue: prepareQueue, context.account.viewTracker.peerView(context.account.peerId), context.sharedContext.activeAccountsWithInfo, appearanceSignal, settings.get(), appUpdateState, hasFilters.get(), sessionsCount, UNUserNotifications.recurrentAuthorizationStatus(context), twoStep, storyStats, acceptBots.get(), context.starsContext.state, context.tonContext.state) |> map { peerView, accounts, appearance, settings, appUpdateState, hasFilters, sessionsCount, unAuthStatus, twoStepConfiguration, storyStats, attachMenuBots, stars, ton -> TableUpdateTransition in
            let entries = accountInfoEntries(peerView: peerView, context: context, accounts: accounts.accounts, language: appearance.language, privacySettings: settings.0, webSessions: settings.1, proxySettings: settings.2, passportVisible: settings.3.0, appUpdateState: appUpdateState, hasFilters: hasFilters, sessionsCount: sessionsCount, unAuthStatus: unAuthStatus, has2fa: settings.3.1, twoStepConfiguration: twoStepConfiguration, storyStats: storyStats, attachMenuBots: attachMenuBots, stars: stars, ton: ton).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            var size = atomicSize.modify {$0}
            size.width = max(size.width, 280)
            return prepareEntries(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: size)
        } |> deliverOnMainQueue
        
        disposable.set(apply.start(next: { [weak self] transition in
            self?.tableView.merge(with: transition)
            self?.readyOnce()
        }))
       
    }
    
    
    var tableView: TableView {
        return genericView.tableView
    }
    var searchView: SearchView {
        return genericView.searchView.searchView
    }
    
    
    
    override func navigationWillChangeController() {
        if let navigation = navigation as? ExMajorNavigationController {
            if navigation.controller is DataAndStorageViewController {
                if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(9))) {
                    _ = tableView.select(item: item)
                }
            } else if navigation.controller is PrivacyAndSecurityViewController {
                if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(11))) {
                    _ = tableView.select(item: item)
                }
            } else if navigation.controller is InstalledStickerPacksController {
                if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(13))) {
                    _ = tableView.select(item: item)
                }
                
            } else if navigation.controller is GeneralSettingsViewController {
                if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(6))) {
                    _ = tableView.select(item: item)
                }
            }  else if navigation.controller is RecentSessionsController {
                if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(10))) {
                    _ = tableView.select(item: item)
                }
            } else if let controller = navigation.controller as? PeerInfoController, controller.peerId == context.peerId {
                if let item = tableView.item(stableId: AccountInfoEntryId.index(Int(5))) {
                    _ = tableView.select(item: item)
                }
            } else if navigation.controller is PassportController {
                if let item = tableView.item(stableId: AccountInfoEntryId.index(Int(17))) {
                    _ = tableView.select(item: item)
                }
            } else if let _ = navigation.controller as? PremiumBoardingController {
                if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(19))) {
                    _ = tableView.select(item: item)
                }
            } else if let controller = navigation.controller as? ChatController {
                switch controller.mode {
                case .customChatContents, .customLink:
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(19))) {
                        _ = tableView.select(item: item)
                    }
                default:
                    break
                }
            } else if let controller = navigation.controller as? InputDataController {
                switch true {
                case controller.identifier == "proxy":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(7))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "language":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(12))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "account":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(0))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "passport":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(17))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "app_update":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(15))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "filters":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(14))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "notification-settings":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(8))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier == "app_appearance":
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(16))) {
                        _ = tableView.select(item: item)
                    }
                case controller.identifier.hasPrefix("business"):
                    if let item = tableView.item(stableId: AnyHashable(AccountInfoEntryId.index(19))) {
                        _ = tableView.select(item: item)
                    }
                default:
                    tableView.cancelSelection()
                }
               
            } else {
                tableView.cancelSelection()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (navigation as? MajorNavigationController)?.add(listener: WeakReference(value: self))
        
        passportPromise.set(context.engine.auth.twoStepAuthData() |> map { value in
            return (value.hasSecretValues, value.currentPasswordDerivation != nil)
        } |> `catch` { error -> Signal<(Bool, Bool), NoError> in
                return .single((false, false))
        })
        
        updateLocalizationAndTheme(theme: theme)
        
        
        context.window.set(handler: { [weak self] _ in
            if let strongSelf = self {
                return strongSelf.escapeKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Escape, priority:.low)
        
        context.starsContext.load(force: true)
        context.tonContext.load(force: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let context = self.context
                
        let privacySettings = context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)

        settings.set(combineLatest(Signal<AccountPrivacySettings?, NoError>.single(nil) |> then(privacySettings), context.webSessions.state, proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { settings in
            return context.account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        

        syncLocalizations.set(context.engine.localization.synchronizedLocalizationListState().start())
        
    }
    
    override func getLeftBarViewOnce() -> BarView {
        return BarView(10, controller: self)
    }
    
    override init(_ context: AccountContext) {
        super.init(context)
        bar = .init(height: 0)
    }
    

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        navigationController?.updateLocalizationAndTheme(theme: theme)
    }
    
    override func firstResponder() -> NSResponder? {
        return nil
    }

    
    override func scrollup(force: Bool = false) {
        
        if searchController != nil {
            self.searchView.cancel(true)
            return
        }
        
        if let currentEvent = NSApp.currentEvent, currentEvent.clickCount == 5, !context.isSupport {
            context.bindings.rootNavigation().push(DeveloperViewController(context: context))
        }
        
        tableView.scroll(to: .up(true))
    }
    
    deinit {
        syncLocalizations.dispose()
        disposable.dispose()
        actionsDisposable.dispose()
    }

}


