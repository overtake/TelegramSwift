//
//  AccountContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit

struct TemporaryPasswordContainer {
    let date: TimeInterval
    let password: String
    
    var isActive: Bool {
        return date + 15 * 60 > Date().timeIntervalSince1970
    }
}


final class AccountContextBindings {
    #if !SHARE
    let rootNavigation: () -> MajorNavigationController
    let mainController: () -> MainViewController
    let showControllerToaster: (ControllerToaster, Bool) -> Void
    let globalSearch:(String)->Void
    let switchSplitLayout:(SplitViewState)->Void
    let entertainment:()->EntertainmentViewController
    let needFullsize:()->Void
    init(rootNavigation: @escaping() -> MajorNavigationController = { fatalError() }, mainController: @escaping() -> MainViewController = { fatalError() }, showControllerToaster: @escaping(ControllerToaster, Bool) -> Void = { _, _ in fatalError() }, globalSearch: @escaping(String) -> Void = { _ in fatalError() }, entertainment: @escaping()->EntertainmentViewController = { fatalError() }, switchSplitLayout: @escaping(SplitViewState)->Void = { _ in fatalError() }, needFullsize: @escaping() -> Void = { fatalError() }) {
        self.rootNavigation = rootNavigation
        self.mainController = mainController
        self.showControllerToaster = showControllerToaster
        self.globalSearch = globalSearch
        self.entertainment = entertainment
        self.switchSplitLayout = switchSplitLayout
        self.needFullsize = needFullsize
    }
    #endif
}

final class AccountContext {
    let sharedContext: SharedAccountContext
    let account: Account
    let window: Window

    #if !SHARE
    let fetchManager: FetchManager
    #endif
    private(set) var timeDifference:TimeInterval  = 0
    #if !SHARE
    let peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager()
    let chatUndoManager = ChatUndoManager()
    #endif
    
    let cancelGlobalSearch:ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    

    
    var isCurrent: Bool = false {
        didSet {
            if !self.isCurrent {
                //self.callManager = nil
            }
        }
    }
    
    
    let globalPeerHandler:Promise<ChatLocation?> = Promise()
    
    let hasPassportSettings: Promise<Bool> = Promise(false)

    private var _recentlyPeerUsed:[PeerId] = []

    private(set) var recentlyPeerUsed:[PeerId] {
        set {
            _recentlyPeerUsed = newValue
        }
        get {
            if _recentlyPeerUsed.count > 2 {
                return Array(_recentlyPeerUsed.prefix(through: 2))
            } else {
                return _recentlyPeerUsed
            }
        }
    }
    
    var peerId: PeerId {
        return account.peerId
    }
    
    private let updateDifferenceDisposable = MetaDisposable()
    private let temporaryPwdDisposable = MetaDisposable()
    private let limitsDisposable = MetaDisposable()
    private let _limitConfiguration: Atomic<LimitsConfiguration> = Atomic(value: LimitsConfiguration.defaultValue)
    
    var limitConfiguration: LimitsConfiguration {
        return _limitConfiguration.with { $0 }
    }
    
    init(sharedContext: SharedAccountContext, window: Window, account: Account) {
        self.sharedContext = sharedContext
        self.account = account
        self.window = window
        #if !SHARE
        self.fetchManager = FetchManager(postbox: account.postbox)
        #endif
        
        
        let limitConfiguration = _limitConfiguration
        
        limitsDisposable.set(account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]).start(next: { view in
            _ = limitConfiguration.swap(view.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration ?? LimitsConfiguration.defaultValue)
        }))
        
        
        globalPeerHandler.set(.single(nil))
        
        if account.network.globalTime > 0 {
            timeDifference = account.network.globalTime - Date().timeIntervalSince1970
        }
        
        updateDifferenceDisposable.set((Signal<Void, NoError>.single(Void())
            |> delay(5 * 60, queue: Queue.mainQueue()) |> restart).start(next: { [weak self, weak account] in
                if let account = account, account.network.globalTime > 0 {
                    self?.timeDifference = account.network.globalTime - Date().timeIntervalSince1970
                }
        }))
    }
    

    private var _temporartPassword: String?
    var temporaryPassword: String? {
        return _temporartPassword
    }
    
    func resetTemporaryPwd() {
        _temporartPassword = nil
        temporaryPwdDisposable.set(nil)
    }
    
    func setTemporaryPwd(_ password: String) -> Void {
        _temporartPassword = password
        let signal = Signal<Void, NoError>.single(Void()) |> delay(30 * 60, queue: Queue.mainQueue())
        temporaryPwdDisposable.set(signal.start(next: { [weak self] in
            self?._temporartPassword = nil
        }))
    }
    
    deinit {
       cleanup()
    }
    
    
    func cleanup() {
        updateDifferenceDisposable.dispose()
        temporaryPwdDisposable.dispose()
        limitsDisposable.dispose()
    }
   
    
    func checkFirstRecentlyForDuplicate(peerId:PeerId) {
        if let index = recentlyPeerUsed.index(of: peerId), index == 0 {
            recentlyPeerUsed.remove(at: index)
        }
    }
    
    func addRecentlyUsedPeer(peerId:PeerId) {
        if let index = recentlyPeerUsed.index(of: peerId) {
            recentlyPeerUsed.remove(at: index)
        }
        recentlyPeerUsed.insert(peerId, at: 0)
        if recentlyPeerUsed.count > 4 {
            recentlyPeerUsed = Array(recentlyPeerUsed.prefix(through: 4))
        }
    }
    
    
    #if !SHARE
    func composeCreateGroup() {
        createGroup(with: self, for: sharedContext.bindings.rootNavigation())
    }
    func composeCreateChannel() {
        createChannel(with: self, for: sharedContext.bindings.rootNavigation())
    }
    func composeCreateSecretChat() {
        let account = self.account
        let confirmationImpl:([PeerId])->Signal<Bool, NoError> = { peerIds in
            if let first = peerIds.first, peerIds.count == 1 {
                return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                    return confirmSignal(for: mainWindow, information: L10n.composeConfirmStartSecretChat(peer.displayTitle))
                }
            }
            return confirmSignal(for: mainWindow, information: L10n.peerInfoConfirmAddMembers1Countable(peerIds.count))
        }
        let select = selectModalPeers(context: self, title: L10n.composeSelectSecretChat, limit: 1, confirmation: confirmationImpl)
        
        let create = select |> map { $0.first! } |> mapToSignal { peerId in
            return createSecretChat(account: account, peerId: peerId) |> `catch` {_ in .complete()}
            } |> deliverOnMainQueue |> mapToSignal{ peerId -> Signal<PeerId, NoError> in
                return showModalProgress(signal: .single(peerId), for: mainWindow)
        }
        
        _ = create.start(next: { [weak self] peerId in
            guard let `self` = self else {return}
            self.sharedContext.bindings.rootNavigation().push(ChatController(context: self, chatLocation: .peer(peerId)))
        })
    }
    #endif
}
