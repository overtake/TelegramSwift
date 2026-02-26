import Foundation
import WebKit
import UserNotifications
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Localization
import InAppSettings
import IOKit
import CodeSyntax
import Dock
import PrivateCallScreen
import DetectSpeech


func navigateToChat(navigation: NavigationViewController?, context: AccountContext, chatLocation:ChatLocation, mode: ChatMode = .history, focusTarget:ChatFocusTarget? = nil, initialAction: ChatInitialAction? = nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>? = nil, additional: Bool = false, animated: Bool = true, navigationStyle: ViewControllerStyle? = nil) {
    
    let open:()->Void = { [weak navigation] in
        if additional {
            navigation?.push(ChatAdditionController(context: context, chatLocation: chatLocation, mode: mode, focusTarget: focusTarget, initialAction: initialAction, chatLocationContextHolder: chatLocationContextHolder), animated, style: navigationStyle)
        } else {
            navigation?.push(ChatController(context: context, chatLocation: chatLocation, mode: mode, focusTarget: focusTarget, initialAction: initialAction, chatLocationContextHolder: chatLocationContextHolder), animated, style: navigationStyle)
        }
    }
    
    let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: chatLocation.peerId)) |> deliverOnMainQueue
    
    _ = signal.start(next: { peer in
        if let peer = peer?._asPeer() {
            if peer.hasSensitiveContent(platform: "ios") {
                if !context.contentConfig.sensitiveContentEnabled, context.contentConfig.canAdjustSensitiveContent {
                    let need_verification = context.appConfiguration.getBoolValue("need_age_video_verification", orElse: false)
                    
                    if need_verification {
                        showModal(with: VerifyAgeAlertController(context: context), for: context.window)
                        return
                    }
                }
                if context.contentConfig.sensitiveContentEnabled {
                    open()
                } else {
                    verifyAlert(for: context.window, header: strings().chatSensitiveContent, information: strings().chatSensitiveContentConfirm, ok: strings().chatSensitiveContentConfirmOk, option: context.contentConfig.canAdjustSensitiveContent ? strings().chatSensitiveContentConfirmThird : nil, optionIsSelected: false, successHandler: { result in
                        
                        if result == .thrid {
                            let _ = updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: true).start()
                        }
                        open()
                    })
                }
            } else {
                open()
            }
        }
    })
}

private final class AuthModalController : ModalController {
    override var background: NSColor {
        return theme.colors.background
    }
    override var dynamicSize: Bool {
        return true
    }
    override var closable: Bool {
        return false
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: NSMakeSize(size.width, size.height), animated: false)
    }
}





final class UnauthorizedApplicationContext {
    let account: UnauthorizedAccount
    let rootController: MajorNavigationController
    let window:Window
    let modal: ModalController
    let sharedContext: SharedAccountContext
    
    private let updatesDisposable: DisposableSet = DisposableSet()
    private let authController: AuthController
    
    var rootView: NSView {
        return rootController.view
    }
    
    
    init(window:Window, sharedContext: SharedAccountContext, account: UnauthorizedAccount, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])) {

        
        window.maxSize = NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        window.minSize = NSMakeSize(380, 550)
        
        updatesDisposable.add(managedAppConfigurationUpdates(accountManager: sharedContext.accountManager, network: account.network).start())
                        
        
        if window.frame.height < window.minSize.height || window.frame.width < window.minSize.width {
            window.setFrame(NSMakeRect(window.frame.minX, window.frame.minY, window.minSize.width, window.minSize.height), display: true)
            window.center()
        }
        self.authController = AuthController(account, sharedContext: sharedContext, otherAccountPhoneNumbers: otherAccountPhoneNumbers)
        self.account = account
        self.window = window
        self.sharedContext = sharedContext
        self.rootController = MajorNavigationController(AuthController.self, self.authController, window)
        rootController._frameRect = NSMakeRect(0, 0, window.frame.width, window.frame.height)

        self.modal = AuthModalController(rootController)
        rootController.alwaysAnimate = true

        account.shouldBeServiceTaskMaster.set(.single(.now))
        
    }
    
    func applyExternalLoginCode(_ code: String) {
        authController.applyExternalLoginCode(code)
    }
    
    deinit {
        account.shouldBeServiceTaskMaster.set(.single(.never))
        updatesDisposable.dispose()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    
}


enum ApplicationContextLaunchAction {
    case navigate(ViewController)
    case preferences
}


let leftSidebarWidth: CGFloat = 72

private final class ApplicationContainerView: View {
    fileprivate let splitView: SplitView
    
    fileprivate private(set) var leftSideView: NSView?
    
    required init(frame frameRect: NSRect) {
        splitView = SplitView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(splitView)
        autoresizingMask = [.width, .height]
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLeftSideView(_ view: NSView?, animated: Bool) {
        if let view = view {
            addSubview(view)
        } else {
            self.leftSideView?.removeFromSuperview()
        }
        
        self.leftSideView = view
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        splitView.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        
        if let leftSideView = leftSideView {
            leftSideView.frame = NSMakeRect(0, 0, leftSidebarWidth, frame.height)
            splitView.frame = NSMakeRect(leftSideView.frame.maxX, 0, frame.width - leftSideView.frame.maxX, frame.height)
        } else {
            splitView.frame = bounds
        }
        
    }
}

final class AuthorizedApplicationContext: NSObject, SplitViewDelegate {
    
        
    var rootView: View {
        return view
    }
    
    let context: AccountContext
    private let window:Window
    private let view:ApplicationContainerView
    private let leftController:MainViewController
    private let rightController:MajorNavigationController
    private let emptyController:EmptyChatViewController
    
    private var entertainment: EntertainmentViewController?
    
    private var leftSidebarController: LeftSidebarController?
    
    private let loggedOutDisposable = MetaDisposable()
    
    private let settingsDisposable = MetaDisposable()
    private let suggestedLocalizationDisposable = MetaDisposable()
    private let alertsDisposable = MetaDisposable()
    private let audioDisposable = MetaDisposable()
    private let termDisposable = MetaDisposable()
    private let someActionsDisposable = DisposableSet()
    private let clearReadNotifiesDisposable = MetaDisposable()
    private let appUpdateDisposable = MetaDisposable()
    private let updateFoldersDisposable = MetaDisposable()
    private let _ready:Promise<Bool> = Promise()
    var ready: Signal<Bool, NoError> {
        return _ready.get() |> filter { $0 } |> take (1)
    }
    
    func applyNewTheme() {
        rightController.backgroundColor = theme.colors.background
        rightController.backgroundMode = theme.controllerBackgroundMode
        view.updateLocalizationAndTheme(theme: theme)
    }
    
    private var launchAction: ApplicationContextLaunchAction?
    
    init(window: Window, context: AccountContext, launchSettings: LaunchSettings, callSession: PCallSession?, groupCallContext: GroupCallContext?, inlinePlayerContext: InlineAudioPlayerView.ContextObject?, folders: ChatListFolders?) {
        
        self.context = context
        emptyController = EmptyChatViewController(context)
        
        self.window = window
        
        if !window.initFromSaver {
            window.setFrame(NSMakeRect(0, 0, 800, 650), display: true)
            window.center()
        }
        
        window.maxSize = NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        window.minSize = NSMakeSize(380, 550)

        
        context.account.importableContacts.set(.single([:]))
        
        self.view = ApplicationContainerView(frame: window.contentView!.bounds)
        
      
        self.view.splitView.setProportion(proportion: SplitProportion(min:380, max:300+350), state: .single);
        self.view.splitView.setProportion(proportion: SplitProportion(min:300+350, max:300+350+600), state: .dual)
        
        
        
        rightController = ExMajorNavigationController(context, ChatController.self, emptyController);
        rightController.set(header: NavigationHeader(44, initializer: { header, contextObject, view -> (NavigationHeaderView, CGFloat) in
            let newView = view ?? InlineAudioPlayerView(header)
            newView.update(with: contextObject)
            return (newView, 44)
        }))
        
        
        rightController.set(callHeader: CallNavigationHeader(35, initializer: { header, contextObject, view -> (NavigationHeaderView, CGFloat) in
            let newView: NavigationHeaderView
            if contextObject is GroupCallContext {
                if let view = view, view.className == GroupCallNavigationHeaderView.className() {
                    newView = view
                } else {
                    newView = GroupCallNavigationHeaderView(header)
                }
            } else if contextObject is PCallSession {
                if let view = view, view.className == CallNavigationHeaderView.className() {
                    newView = view
                } else {
                    newView = CallNavigationHeaderView(header)
                }
            } else {
                fatalError("not supported")
            }
            newView.update(with: contextObject)
            return (newView, 35 + 18)
        }))
        
        window.rootViewController = rightController
        
        leftController = MainViewController(context);

                
        
        super.init()
        

                
        context.bindings = AccountContextBindings(rootNavigation: { [weak self] () -> MajorNavigationController in
            guard let `self` = self else {
                return MajorNavigationController(ViewController.self, ViewController(), window)
            }
            return self.rightController
        }, mainController: { [weak self] () -> MainViewController in
            guard let `self` = self else {
                fatalError("Cannot use bindings. Application context is not exists")
            }
            return self.leftController
        }, showControllerToaster: { [weak self] toaster, animated in
            guard let `self` = self else {
                fatalError("Cannot use bindings. Application context is not exists")
            }
            self.rightController.controller.show(toaster: toaster, animated: animated)
        }, globalSearch: { [weak self] search, peerId, cached in
            guard let `self` = self else {
                fatalError("Cannot use bindings. Application context is not exists")
            }
            self.leftController.tabController.select(index: self.leftController.chatIndex)
            self.leftController.globalSearch(search, peerId: peerId, cached: cached)
        }, entertainment: { [weak self] () -> EntertainmentViewController in
            guard let `self` = self else {
                return EntertainmentViewController.init(size: NSZeroSize, context: context)
            }
            if self.entertainment == nil {
                self.entertainment = EntertainmentViewController(size: NSMakeSize(350, 350), context: self.context)
            }
            return self.entertainment!
        }, switchSplitLayout: { [weak self] state in
            guard let `self` = self else {
                fatalError("Cannot use bindings. Application context is not exists")
            }
            self.view.splitView.state = state
        }, needFullsize: { [weak self] in
            self?.view.splitView.needFullsize()
        }, displayUpgradeProgress: { progress in
                
        })
        
        
        termDisposable.set((context.account.stateManager.termsOfServiceUpdate |> deliverOnMainQueue).start(next: { terms in
            if let terms = terms {
                showModal(with: TermsModalController(context, terms: terms), for: context.window)
            } else {
                closeModal(TermsModalController.self)
            }
        }))
        
        closeAllPopovers(for: context.window)
        closeAllModals(window: context.window)
        AppMenu.closeAll()
      
       // var forceNotice:Bool = false
        if FastSettings.isMinimisize {
            self.view.splitView.mustMinimisize = true
           // forceNotice = true
        } else {
            self.view.splitView.mustMinimisize = false
        }
        
        self.view.splitView.delegate = self;
        self.view.splitView.update(false)
        

        let accountId = context.account.id
        self.loggedOutDisposable.set(context.account.loggedOut.start(next: { value in
            if value {
                let _ = logoutFromAccount(id: accountId, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                FastSettings.clear_uuid(context.account.id.int64)
                BrowserStateContext.cleanup(context.account.id)
            }
        }))
        
        
        alertsDisposable.set((context.account.stateManager.displayAlerts |> deliverOnMainQueue).start(next: { alerts in
            for text in alerts {
                
                let alert:NSAlert = NSAlert()
                alert.window.appearance = theme.appearance
                alert.alertStyle = .informational
                alert.messageText = appName
                alert.informativeText = text.text

                if text.isDropAuth {
                    alert.addButton(withTitle: strings().editAccountLogout)
                    alert.addButton(withTitle: strings().modalCancel)

                }

                alert.beginSheetModal(for: window, completionHandler: { result in
                    if result.rawValue == 1000 && text.isDropAuth {
                        let _ = logoutFromAccount(id: context.account.id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                    }
                })
            }
        }))
        

        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.rightController.push(ChatController(context: context, chatLocation: .peer(context.peerId)))
            return .invoked
        }, with: self, for: .Zero, priority: .low, modifierFlags: [.command])
        
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(0, false)
            return .invoked
        }, with: self, for: .One, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(1, false)
            return .invoked
            }, with: self, for: .Two, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(2, false)
            return .invoked
        }, with: self, for: .Three, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(3, false)
            return .invoked
        }, with: self, for: .Four, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(4, false)
            return .invoked
        }, with: self, for: .Five, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(5, false)
            return .invoked
        }, with: self, for: .Six, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(6, false)
            return .invoked
        }, with: self, for: .Seven, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(7, false)
            return .invoked
        }, with: self, for: .Eight, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(8, false)
            return .invoked
        }, with: self, for: .Nine, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { _ -> KeyHandlerResult in
            
            
            appDelegate?.sharedApplicationContextValue?.notificationManager.updatePasslock(context.sharedContext.accountManager.transaction { transaction -> Bool in
                switch transaction.getAccessChallengeData() {
                case .none:
                    return false
                default:
                    return true
                }
            })
            
            let hasPasscode = context.sharedContext.accountManager.transaction { $0.getAccessChallengeData() != .none } |> deliverOnMainQueue
            
            _ = hasPasscode.startStandalone(next: { value in
                if !value {
                    context.bindings.rootNavigation().push(PasscodeSettingsViewController(context))
                }
            })
                        
            return .invoked
        }, with: self, for: .L, priority: .supreme, modifierFlags: [.command])

        
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(0, true)
            return .invoked
        }, with: self, for: .One, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(1, true)
            return .invoked
        }, with: self, for: .Two, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(2, true)
            return .invoked
        }, with: self, for: .Three, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(3, true)
            return .invoked
        }, with: self, for: .Four, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(4, true)
            return .invoked
        }, with: self, for: .Five, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(5, true)
            return .invoked
        }, with: self, for: .Six, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(6, true)
            return .invoked
        }, with: self, for: .Seven, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(7, true)
            return .invoked
        }, with: self, for: .Eight, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(8, true)
            return .invoked
        }, with: self, for: .Nine, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.openChat(9, true)
            return .invoked
        }, with: self, for: .Minus, priority: .low, modifierFlags: [.command, .option])
        
    
        
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(1, true)
            return .invoked
        }, with: self, for: .One, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(2, true)
            return .invoked
        }, with: self, for: .Two, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(3, true)
            return .invoked
        }, with: self, for: .Three, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(4, true)
            return .invoked
        }, with: self, for: .Four, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(5, true)
            return .invoked
        }, with: self, for: .Five, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(6, true)
            return .invoked
        }, with: self, for: .Six, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(7, true)
            return .invoked
        }, with: self, for: .Seven, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(8, true)
            return .invoked
        }, with: self, for: .Eight, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.switchAccount(9, true)
            return .invoked
        }, with: self, for: .Nine, priority: .low, modifierFlags: [.control])
              
        
        
        #if DEBUG
        
        self.context.window.set(handler: { _ -> KeyHandlerResult in
            
           // showModal(with: AddTonBalanceController(context: context), for: window)
            
           // context.bindings.rootNavigation().push(SuggestPostController(context: context, peerId: context.peerId))

            return .invoked
        }, with: self, for: .T, priority: .supreme, modifierFlags: [.command])
        
        
        self.context.window.set(handler: { _ -> KeyHandlerResult in
                       
            showModal(with: SuggetMessageModalController(context: context), for: window)

           // showModal(with: GroupCallInviteLinkController(context: context, link: .init(link: "t.me/call/+kd93KsOsdd239k"), presentation: darkAppearance), for: window)

            return .invoked
        }, with: self, for: .Y, priority: .supreme, modifierFlags: [.command])
        
        
        #endif
        
        
//        window.set(handler: { [weak self] _ -> KeyHandlerResult in
//            self?.leftController.focusSearch(animated: true)
//            return .invoked
//        }, with: self, for: .F, priority: .supreme, modifierFlags: [.command, .shift])
        
        window.set(handler: { _ -> KeyHandlerResult in
            context.bindings.rootNavigation().push(ShortcutListController(context: context))
            return .invoked
        }, with: self, for: .Slash, priority: .low, modifierFlags: [.command])
        
      
        
        appUpdateDisposable.set((context.account.stateManager.appUpdateInfo |> deliverOnMainQueue).start(next: { info in
            
        }))
        
        
        suggestedLocalizationDisposable.set(( context.account.postbox.preferencesView(keys: [PreferencesKeys.suggestedLocalization]) |> mapToSignal { preferences -> Signal<SuggestedLocalizationInfo, NoError> in
            
            let preferences = preferences.values[PreferencesKeys.suggestedLocalization]?.get(SuggestedLocalizationEntry.self)
            if preferences == nil || !preferences!.isSeen, preferences?.languageCode != appCurrentLanguage.languageCode, preferences?.languageCode != "en" {
                let current = Locale.preferredLanguages[0]
                let split = current.split(separator: "-")
                let lan: String = !split.isEmpty ? String(split[0]) : "en"
                if lan != "en" {
                    return context.engine.localization.suggestedLocalizationInfo(languageCode: lan, extractKeys: ["Suggest.Localization.Header", "Suggest.Localization.Other"]) |> take(1)
                }
            }
            return .complete()
        } |> deliverOnMainQueue).start(next: { suggestionInfo in
            if suggestionInfo.availableLocalizations.count >= 2 {
                showModal(with: SuggestionLocalizationViewController(context, suggestionInfo: suggestionInfo), for: window)
            }
        }))
        

        someActionsDisposable.add(context.engine.peers.managedUpdatedRecentPeers().start())
        
                
        clearReadNotifiesDisposable.set(context.account.stateManager.appliedIncomingReadMessages.start(next: { msgIds in
            UNUserNotifications.current?.clearNotifies(by: msgIds)
        }))
        

        
        someActionsDisposable.add(applyUpdateTextIfNeeded(context.account.postbox).start())
        
        if let folders = folders {
            self.updateLeftSidebar(with: folders, layout: context.layout, animated: false)
        }
        
        
        self.view.splitView.layout()

        
   
        
        if let navigation = launchSettings.navigation {
            switch navigation {
            case .settings:
                self.launchAction = .preferences
                _ready.set(leftController.settings.ready.get())
                leftController.tabController.select(index: leftController.settingsIndex)
            case let .profile(peer, necessary):
                
                _ready.set(leftController.chatList.ready.get())
                self.leftController.tabController.select(index: self.leftController.chatIndex)

                if (necessary || context.layout != .single) {
                    let controller = PeerInfoController(context: context, peer: peer._asPeer())
                    controller.navigationController = self.rightController
                    controller.loadViewIfNeeded(self.rightController.bounds)

                    self.launchAction = .navigate(controller)

                    self._ready.set(combineLatest(self.leftController.chatList.ready.get(), controller.ready.get()) |> map { $0 && $1 })
                    self.leftController.tabController.select(index: self.leftController.chatIndex)
                } else {
                    _ready.set(leftController.chatList.ready.get())
                    self.leftController.tabController.select(index: self.leftController.chatIndex)
                }
            case let .chat(peerId, necessary):
                
                _ready.set(leftController.chatList.ready.get())
                self.leftController.tabController.select(index: self.leftController.chatIndex)
                
                if (necessary || context.layout != .single) {
                    let controller = ChatController(context: context, chatLocation: .peer(peerId))
                    controller.navigationController = self.rightController
                    controller.loadViewIfNeeded(self.rightController.bounds)

                    self.launchAction = .navigate(controller)

                    self._ready.set(combineLatest(self.leftController.chatList.ready.get(), controller.ready.get()) |> map { $0 && $1 })
                    self.leftController.tabController.select(index: self.leftController.chatIndex)
                } else {
                   // self._ready.set(.single(true))
                    _ready.set(leftController.chatList.ready.get())
                    self.leftController.tabController.select(index: self.leftController.chatIndex)
                }
            case let .thread(threadId, fromId, threadData, _):
                self.leftController.tabController.select(index: self.leftController.chatIndex)
                self._ready.set(self.leftController.chatList.ready.get())
                
                if let fromId = fromId {
                    context.navigateToThread(threadId, fromId: fromId)
                } else if let _ = threadData {
                    _ = ForumUI.openTopic(Int64(threadId.id), peerId: threadId.peerId, context: context).start()
                }
            }
        } else {
           // self._ready.set(.single(true))
            _ready.set(leftController.chatList.ready.get())
            leftController.tabController.select(index: leftController.chatIndex)
          //  _ready.set(leftController.ready.get())
        }
        
        if let session = callSession {
            rightController.callHeader?.show(true, contextObject: session)
        }
        
        if let groupCallContext = groupCallContext {
            rightController.callHeader?.show(true, contextObject: groupCallContext)
        }
        if let inlinePlayerContext = inlinePlayerContext {
            rightController.header?.show(true, contextObject: inlinePlayerContext)
        }
        self.updateFoldersDisposable.set(combineLatest(queue: .mainQueue(), chatListFilterPreferences(engine: context.engine), context.layoutValue).start(next: { [weak self] value, layout in
            self?.updateLeftSidebar(with: value, layout: layout, animated: true)
        }))
        
       // _ready.set(.single(true))
    }
    
    private var folders: ChatListFolders?
    private var previousLayout: SplitViewState?
    private let foldersReadyDisposable = MetaDisposable()
    private func updateLeftSidebar(with folders: ChatListFolders, layout: SplitViewState, animated: Bool) -> Void {
        
        if let window = self.window as? AppWindow {
            if (folders.sidebar && !folders.isEmpty) || layout == .minimisize {
                self.context.bindings.rootNavigation().navigationBarLeftPosition = 0
                window.initialButtonPoint = .system
            } else {
                self.context.bindings.rootNavigation().navigationBarLeftPosition = layout == .single ? Window.controlsInset : 0
                window.initialButtonPoint = .app
            }
        }

                
        let currentSidebar = !folders.isEmpty && (folders.sidebar)
        let previousSidebar = self.folders == nil ? nil : !self.folders!.isEmpty && (self.folders!.sidebar)

        let readySignal: Signal<Bool, NoError>
        
        if currentSidebar != previousSidebar {
            if !currentSidebar {
                leftSidebarController?.removeFromSuperview()
                leftSidebarController = nil
                readySignal = .single(true)
            } else {
                let controller = LeftSidebarController(context, filterData: leftController.chatList.filterSignal, updateFilter: leftController.chatList.updateFilter)
                controller._frameRect = NSMakeRect(0, 0, leftSidebarWidth, window.frame.height)
                controller.loadViewIfNeeded()
                self.leftSidebarController = controller
                readySignal = controller.ready.get() |> take(1)
            }
            let enlarge: CGFloat
            
            if currentSidebar && previousSidebar != nil {
                enlarge = leftSidebarWidth
            } else {
                if previousSidebar == true {
                    enlarge = -leftSidebarWidth
                } else {
                    enlarge = 0
                }
            }
            
            foldersReadyDisposable.set(readySignal.start(next: { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                self.view.updateLeftSideView(self.leftSidebarController?.genericView, animated: animated)
                if !self.window.isFullScreen, let screen = self.window.screen {
                    self.window.setFrame(NSMakeRect(max(0, self.window.frame.minX - enlarge), self.window.frame.minY, min(self.window.frame.width + enlarge, screen.frame.width), self.window.frame.height), display: true, animate: false)
                }
                self.updateMinMaxWindowSize(animated: animated)
            }))
                        
            
        }
        self.folders = folders
        self.previousLayout = layout
    }
    
    
    private func updateMinMaxWindowSize(animated: Bool) {
        var width: CGFloat = 380
        if leftSidebarController != nil {
            width += leftSidebarWidth
        }
        if context.layout == .minimisize {
            width += 70
        }
        window.minSize = NSMakeSize(width, 550)
        
        if window.frame.width < window.minSize.width {
            window.setFrame(NSMakeRect(max(0, window.frame.minX - (window.minSize.width - window.frame.width)), window.frame.minY, window.minSize.width, window.frame.height), display: true, animate: false)
        }
    }
    

    
    func runLaunchAction() {
        if let launchAction = launchAction {
            switch launchAction {
            case let .navigate(controller):
                leftController.tabController.select(index: leftController.chatIndex)
                context.bindings.rootNavigation().push(controller, context.layout == .single)
            case .preferences:
                leftController.tabController.select(index: leftController.settingsIndex)
            }
            self.launchAction = nil
        } else {
            leftController.tabController.select(index: leftController.chatIndex)
        }
        Queue.mainQueue().justDispatch { [weak self] in
            self?.leftController.prepareControllers()
        }
    }
    
    private func openChat(_ index: Int, _ force: Bool = false) {
        leftController.openChat(index, force: force)
    }
    
    private func switchAccount(_ index: Int, _ force: Bool = false) {
        
        let accounts = context.sharedContext.activeAccounts |> take(1) |> deliverOnMainQueue
        let context = self.context
        _ = accounts.start(next: { accounts in
            let account = accounts.accounts[min(index - 1, accounts.accounts.count - 1)]
            context.sharedContext.switchToAccount(id: account.0, action: nil)
        })
    }
    
    func splitResizeCursor(at point: NSPoint) -> NSCursor? {
        if FastSettings.isMinimisize {
            return NSCursor.resizeRight
        } else {
            if window.frame.width - point.x <= 380 {
                return NSCursor.resizeLeft
            }
            return NSCursor.resizeLeftRight
        }
    }

    func splitViewShouldResize(at point: NSPoint) {
        if !FastSettings.isMinimisize {
            let max_w = window.frame.width - 380
            let result = round(min(max(point.x, 300), max_w))
            FastSettings.updateLeftColumnWidth(result)
            self.view.splitView.updateStartSize(size: NSMakeSize(result, result), controller: leftController)
        }
        
    }
    

    
    func splitViewDidNeedSwapToLayout(state: SplitViewState) {
        let previousState = self.view.splitView.state
        self.view.splitView.removeAllControllers()
        let w:CGFloat = FastSettings.leftColumnWidth
        FastSettings.isMinimisize = false
        self.view.splitView.mustMinimisize = false
        switch state {
        case .single:
            rightController.empty = leftController
            
            if rightController.modalAction != nil {
                if rightController.controller is ChatController {
                    rightController.push(ForwardChatListController(context), false)
                }
            }
            if rightController.stackCount == 1, previousState != .none {
                leftController.viewWillAppear(false)
            }
            self.view.splitView.addController(controller: rightController, proportion: SplitProportion(min:380, max:CGFloat.greatestFiniteMagnitude))
            if rightController.stackCount == 1, previousState != .none {
                leftController.viewDidAppear(false)
            }
            
        case .dual:
            rightController.empty = emptyController
            if rightController.controller is ForwardChatListController {
                rightController.back(animated:false)
            }
            self.view.splitView.addController(controller: leftController, proportion: SplitProportion(min:w, max:w))
            self.view.splitView.addController(controller: rightController, proportion: SplitProportion(min:380, max:CGFloat.greatestFiniteMagnitude))
        case .minimisize:
            self.view.splitView.mustMinimisize = true
            FastSettings.isMinimisize = true
            self.view.splitView.addController(controller: leftController, proportion: SplitProportion(min:70, max:70))
            self.view.splitView.addController(controller: rightController, proportion: SplitProportion(min:380, max:CGFloat.greatestFiniteMagnitude))
        default:
            break;
        }
        
        updateMinMaxWindowSize(animated: false)
        DispatchQueue.main.async {
            self.view.splitView.needsLayout = true
        }
        context.layout = state
    }
    

    
    func splitViewDidNeedMinimisize(controller: ViewController) {
        
    }
    
    func splitViewDidNeedFullsize(controller: ViewController) {
        
    }
    
    func splitViewIsCanMinimisize() -> Bool {
        return self.leftController.isCanMinimisize();
    }
    
    func splitViewDrawBorder() -> Bool {
        return false
    }
    
    deinit {
        self.loggedOutDisposable.dispose()
        window.removeAllHandlers(for: self)
        settingsDisposable.dispose()
        suggestedLocalizationDisposable.dispose()
        audioDisposable.dispose()
        alertsDisposable.dispose()
        termDisposable.dispose()
        viewer?.close()
        someActionsDisposable.dispose()
        clearReadNotifiesDisposable.dispose()
        appUpdateDisposable.dispose()
        updateFoldersDisposable.dispose()
        foldersReadyDisposable.dispose()
        context.cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
}



