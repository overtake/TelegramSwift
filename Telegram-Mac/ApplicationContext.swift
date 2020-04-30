import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore

import IOKit

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
    
    var rootView: NSView {
        return rootController.view
    }
    
    init(window:Window, sharedContext: SharedAccountContext, account: UnauthorizedAccount, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])) {

        
        window.maxSize = NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        window.minSize = NSMakeSize(380, 500)
        
        
        updatesDisposable.add(managedAppConfigurationUpdates(accountManager: sharedContext.accountManager, network: account.network).start())
        
        if !window.initFromSaver {
            window.setFrame(NSMakeRect(0, 0, 800, 650), display: true)
            window.center()
        }
        
        if window.frame.height < window.minSize.height {
            window.setFrame(NSMakeRect(window.frame.minX, window.frame.minY, window.minSize.width, window.minSize.height), display: true)
        }
        
        self.account = account
        self.window = window
        self.sharedContext = sharedContext
        self.rootController = MajorNavigationController(AuthController.self, AuthController(account, sharedContext: sharedContext, otherAccountPhoneNumbers: otherAccountPhoneNumbers), window)
        rootController._frameRect = NSMakeRect(0, 0, window.frame.width, window.frame.height)

        self.modal = AuthModalController(rootController)
        rootController.alwaysAnimate = true

        
        account.shouldBeServiceTaskMaster.set(.single(.now))
        
 
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
        
    }
    
    deinit {
        account.shouldBeServiceTaskMaster.set(.single(.never))
        updatesDisposable.dispose()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc func receiveWakeNote(_ notificaiton:Notification) {
        account.shouldBeServiceTaskMaster.set(.single(.never) |> then(.single(.now)))
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
    
    
    private var mediaKeyTap:SPMediaKeyTap?
    
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
    private let ringingStatesDisposable = MetaDisposable()
    
    private let settingsDisposable = MetaDisposable()
    private let suggestedLocalizationDisposable = MetaDisposable()
    private let alertsDisposable = MetaDisposable()
    private let audioDisposable = MetaDisposable()
    private let termDisposable = MetaDisposable()
    private let someActionsDisposable = DisposableSet()
    private let clearReadNotifiesDisposable = MetaDisposable()
    private let chatUndoManagerDisposable = MetaDisposable()
    private let appUpdateDisposable = MetaDisposable()
    private let updatesDisposable = MetaDisposable()
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
    
    init(window: Window, context: AccountContext, launchSettings: LaunchSettings) {
        
        self.context = context
        emptyController = EmptyChatViewController(context)
        
        self.window = window
        
        if !window.initFromSaver {
            window.setFrame(NSMakeRect(0, 0, 800, 650), display: true)
            window.center()
        }
        
        
        context.account.importableContacts.set(.single([:]))
        
        self.view = ApplicationContainerView(frame: window.contentView!.bounds)
        
      
        self.view.splitView.setProportion(proportion: SplitProportion(min:380, max:300+350), state: .single);
        self.view.splitView.setProportion(proportion: SplitProportion(min:300+350, max:300+350+600), state: .dual)
        
        
        
        rightController = ExMajorNavigationController(context, ChatController.self, emptyController);
        rightController.set(header: NavigationHeader(44, initializer: { (header) -> NavigationHeaderView in
            let view = InlineAudioPlayerView(header)
            return view
        }))
        
        rightController.set(callHeader: CallNavigationHeader(35, initializer: { header -> NavigationHeaderView in
            let view = CallNavigationHeaderView(header)
            return view
        }))
        
        window.rootViewController = rightController
        
        leftController = MainViewController(context);

        
        leftController.navigationController = rightController
        
        
        super.init()
        
        
        updatesDisposable.set(managedAppConfigurationUpdates(accountManager: context.sharedContext.accountManager, network: context.account.network).start())
        
        context.sharedContext.bindings = AccountContextBindings(rootNavigation: { [weak self] () -> MajorNavigationController in
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
        }, globalSearch: { [weak self] search in
            guard let `self` = self else {
                fatalError("Cannot use bindings. Application context is not exists")
            }
            self.leftController.tabController.select(index: self.leftController.chatIndex)
            self.leftController.chatList.globalSearch(search)
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
        
        
        chatUndoManagerDisposable.set((context.chatUndoManager.allStatuses() |> deliverOnMainQueue).start(next: { [weak self] statuses in
            guard let `self` = self else {return}
            
            if let header = self.rightController.undoHeader {
                (header.view as? UndoOverlayHeaderView)?.removeAnimationForNextTransition = true

                if statuses.hasProcessingActions {
                    header.show(true)
                } else {
                    header.hide(true)
                }
            }
            
        }))
        
        termDisposable.set((context.account.stateManager.termsOfServiceUpdate |> deliverOnMainQueue).start(next: { terms in
            if let terms = terms {
                showModal(with: TermsModalController(context, terms: terms), for: mainWindow)
            } else {
                closeModal(TermsModalController.self)
            }
        }))
        
      
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
                    alert.addButton(withTitle: L10n.editAccountLogout)
                    alert.addButton(withTitle: L10n.modalCancel)

                }

                alert.beginSheetModal(for: window, completionHandler: { result in
                    if result.rawValue == 1000 && text.isDropAuth {
                        let _ = logoutFromAccount(id: context.account.id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                    }
                })
            }
        }))
        

        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.rightController.push(ChatController(context: context, chatLocation: .peer(context.peerId)))
            return .invoked
        }, with: self, for: .Zero, priority: .low, modifierFlags: [.command])
        
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(0, false)
            return .invoked
        }, with: self, for: .One, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(1, false)
            return .invoked
            }, with: self, for: .Two, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(2, false)
            return .invoked
        }, with: self, for: .Three, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(3, false)
            return .invoked
        }, with: self, for: .Four, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(4, false)
            return .invoked
        }, with: self, for: .Five, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(5, false)
            return .invoked
        }, with: self, for: .Six, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(6, false)
            return .invoked
        }, with: self, for: .Seven, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(7, false)
            return .invoked
        }, with: self, for: .Eight, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(8, false)
            return .invoked
        }, with: self, for: .Nine, priority: .low, modifierFlags: [.command])
        
        
        
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(0, true)
            return .invoked
        }, with: self, for: .One, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(1, true)
            return .invoked
        }, with: self, for: .Two, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(2, true)
            return .invoked
        }, with: self, for: .Three, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(3, true)
            return .invoked
        }, with: self, for: .Four, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(4, true)
            return .invoked
        }, with: self, for: .Five, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(5, true)
            return .invoked
        }, with: self, for: .Six, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(6, true)
            return .invoked
        }, with: self, for: .Seven, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(7, true)
            return .invoked
        }, with: self, for: .Eight, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(8, true)
            return .invoked
        }, with: self, for: .Nine, priority: .low, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(9, true)
            return .invoked
        }, with: self, for: .Minus, priority: .low, modifierFlags: [.command, .option])
        
    
        
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(0, true)
            return .invoked
        }, with: self, for: .One, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(1, true)
            return .invoked
        }, with: self, for: .Two, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(2, true)
            return .invoked
        }, with: self, for: .Three, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(3, true)
            return .invoked
        }, with: self, for: .Four, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(4, true)
            return .invoked
        }, with: self, for: .Five, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(5, true)
            return .invoked
        }, with: self, for: .Six, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(6, true)
            return .invoked
        }, with: self, for: .Seven, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(7, true)
            return .invoked
        }, with: self, for: .Eight, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(8, true)
            return .invoked
        }, with: self, for: .Nine, priority: .low, modifierFlags: [.control])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.openChat(9, true)
            return .invoked
        }, with: self, for: .Minus, priority: .low, modifierFlags: [.control])
        
        
        window.set(handler: { () -> KeyHandlerResult in
            
            let beginPendingTime:CFAbsoluteTime = CACurrentMediaTime()
            
            let afterSentSound:NSSound? = {
                
                let p = Bundle.main.path(forResource: "sent", ofType: "caf")
                var sound:NSSound?
                if let p = p {
                    sound = NSSound(contentsOfFile: p, byReference: true)
                    sound?.volume = 1.0
                }
                
                return sound
            }()
            
            afterSentSound?.play()
            
            alert(for: context.window, info: "Play sound took: \(CACurrentMediaTime() - beginPendingTime)")
            
            return .invoked
        }, with: self, for: .E, priority: .supreme, modifierFlags: [.control, .command])
        
        
//        window.set(handler: { [weak self] () -> KeyHandlerResult in
//            self?.leftController.focusSearch(animated: true)
//            return .invoked
//        }, with: self, for: .F, priority: .supreme, modifierFlags: [.command, .shift])
        
        window.set(handler: { () -> KeyHandlerResult in
            context.sharedContext.bindings.rootNavigation().push(ShortcutListController(context: context))
            return .invoked
        }, with: self, for: .Slash, priority: .low, modifierFlags: [.command])
        
        #if DEBUG
        window.set(handler: { () -> KeyHandlerResult in
            context.sharedContext.bindings.rootNavigation().push(ShortcutListController(context: context))
            return .invoked
        }, with: self, for: .T, priority: .supreme, modifierFlags: .command)
        #endif
        
        
        appUpdateDisposable.set((context.account.stateManager.appUpdateInfo |> deliverOnMainQueue).start(next: { info in
            
        }))
        
        
        suggestedLocalizationDisposable.set(( context.account.postbox.preferencesView(keys: [PreferencesKeys.suggestedLocalization]) |> mapToSignal { preferences -> Signal<SuggestedLocalizationInfo, NoError> in
            
            let preferences = preferences.values[PreferencesKeys.suggestedLocalization] as? SuggestedLocalizationEntry
            if preferences == nil || !preferences!.isSeen, preferences?.languageCode != appCurrentLanguage.languageCode, preferences?.languageCode != "en" {
                let current = Locale.preferredLanguages[0]
                let split = current.split(separator: "-")
                let lan: String = !split.isEmpty ? String(split[0]) : "en"
                if lan != "en" {
                    return suggestedLocalizationInfo(network: context.account.network, languageCode: lan, extractKeys: ["Suggest.Localization.Header", "Suggest.Localization.Other"]) |> take(1)
                }
            }
            return .complete()
        } |> deliverOnMainQueue).start(next: { suggestionInfo in
            if suggestionInfo.availableLocalizations.count >= 2 {
                showModal(with: SuggestionLocalizationViewController(context, suggestionInfo: suggestionInfo), for: window)
            }
        }))
        

        someActionsDisposable.add(managedUpdatedRecentPeers(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network).start())
        
        
       
        
        clearReadNotifiesDisposable.set(context.account.stateManager.appliedIncomingReadMessages.start(next: { msgIds in
            clearNotifies(by: msgIds)
        }))
        

        
        someActionsDisposable.add(applyUpdateTextIfNeeded(context.account.postbox).start())
        
        someActionsDisposable.add(context.globalPeerHandler.get().start(next: { location in
            if let peerId = location?.peerId {
                _ = updateLaunchSettings(context.account.postbox, {
                    $0.withUpdatedNavigation(.chat(peerId, necessary: false))
                }).start()
            } else {
                _ = updateLaunchSettings(context.account.postbox, {
                    $0.withUpdatedNavigation(nil)
                }).start()
            }
        }))
        
        
        let foldersSemaphore = DispatchSemaphore(value: 0)
        var folders: ChatListFolders = ChatListFolders(list: [], sidebar: false)
        
        _ = (chatListFilterPreferences(postbox: context.account.postbox) |> take(1)).start(next: { value in
            folders = value
            foldersSemaphore.signal()
        })
        foldersSemaphore.wait()
        
        self.updateLeftSidebar(with: folders, animated: false)
        
        
        self.view.splitView.layout()

        
   
        
        if let navigation = launchSettings.navigation {
            switch navigation {
            case .settings:
                self.launchAction = .preferences
                _ready.set(leftController.settings.ready.get())
                leftController.tabController.select(index: leftController.settingsIndex)
            case let .chat(peerId, necessary):
                
//                let peerSemaphore = DispatchSemaphore(value: 0)
//                var peer: Peer?
//                _ = context.account.postbox.transaction { transaction in
//                    peer = transaction.getPeer(peerId)
//                    peerSemaphore.signal()
//                }.start()
//                peerSemaphore.wait()
                
                _ready.set(leftController.chatList.ready.get())
                self.leftController.tabController.select(index: self.leftController.chatIndex)
                
//                if (necessary || context.sharedContext.layout != .single) && launchSettings.openAtLaunch {
//                    if let peer = peer {
//                        let controller = ChatController(context: context, chatLocation: .peer(peer.id))
//                        controller.navigationController = self.rightController
//                        controller.loadViewIfNeeded(self.rightController.bounds)
//
//                        self.launchAction = .navigate(controller)
//
//                        self._ready.set(combineLatest(self.leftController.chatList.ready.get(), controller.ready.get()) |> map { $0 && $1 })
//                        self.leftController.tabController.select(index: self.leftController.chatIndex)
//                    } else {
//                       // self._ready.set(self.leftController.chatList.ready.get())
//                        self.leftController.tabController.select(index: self.leftController.chatIndex)
//                        self._ready.set(.single(true))
//                    }
//                } else {
//                   // self._ready.set(.single(true))
//                    _ready.set(leftController.chatList.ready.get())
//                    self.leftController.tabController.select(index: self.leftController.chatIndex)
//                }
            }
        } else {
           // self._ready.set(.single(true))
            _ready.set(leftController.chatList.ready.get())
            leftController.tabController.select(index: leftController.chatIndex)
          //  _ready.set(leftController.ready.get())
        }
        
        
        let callSessionSemaphore = DispatchSemaphore(value: 0)
        var callSession: PCallSession?
        _ = _callSession().start(next: { _session in
            callSession = _session
            callSessionSemaphore.signal()
        })
        callSessionSemaphore.wait()
        
        
        if let session = callSession {
            _ = (session.state.get() |> take(1)).start(next: { [weak session] state in
                if case .active = state, let session = session {
                    context.sharedContext.showCallHeader(with: session)
                }
            })
        }
        
        self.updateFoldersDisposable.set((chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.updateLeftSidebar(with: value, animated: true)
        }))
        
       // _ready.set(.single(true))
    }
    
    private var folders: ChatListFolders?
    private let foldersReadyDisposable = MetaDisposable()
    private func updateLeftSidebar(with folders: ChatListFolders, animated: Bool) -> Void {
        
        let currentSidebar = !folders.list.isEmpty && folders.sidebar
        let previousSidebar = self.folders == nil ? nil : !self.folders!.list.isEmpty && self.folders!.sidebar

        let readySignal: Signal<Bool, NoError>
        
        if currentSidebar != previousSidebar {
            if folders.list.isEmpty || !folders.sidebar {
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
                if !self.window.isFullScreen {
                    self.window.setFrame(NSMakeRect(max(0, self.window.frame.minX - enlarge), self.window.frame.minY, self.window.frame.width + enlarge, self.window.frame.height), display: true, animate: false)
                }
                self.updateMinMaxWindowSize(animated: animated)
            }))
                        
            
        }
        self.folders = folders
    }
    
    
    private func updateMinMaxWindowSize(animated: Bool) {
        window.maxSize = NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var width: CGFloat = 380
        if leftSidebarController != nil {
            width += leftSidebarWidth
        }
        window.minSize = NSMakeSize(width, 500)
        
        if window.frame.width < window.minSize.width {
            window.setFrame(NSMakeRect(max(0, window.frame.minX - (window.minSize.width - window.frame.width)), window.frame.minY, window.minSize.width, window.frame.height), display: true, animate: false)
        }
    }
    

    
    func runLaunchAction() {
        if let launchAction = launchAction {
            switch launchAction {
            case let .navigate(controller):
                leftController.tabController.select(index: leftController.chatIndex)
                context.sharedContext.bindings.rootNavigation().push(controller, context.sharedContext.layout == .single)
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

        
        context.sharedContext.layoutHandler.set(state)
        self.view.splitView.layout()

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
        ringingStatesDisposable.dispose()
        suggestedLocalizationDisposable.dispose()
        audioDisposable.dispose()
        alertsDisposable.dispose()
        termDisposable.dispose()
        viewer?.close()
        globalAudio?.cleanup()
        someActionsDisposable.dispose()
        clearReadNotifiesDisposable.dispose()
        chatUndoManagerDisposable.dispose()
        appUpdateDisposable.dispose()
        updatesDisposable.dispose()
        updateFoldersDisposable.dispose()
        foldersReadyDisposable.dispose()
        context.cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
}



