//
//  SharedNotificationManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore

import TGUIKit

func getNotificationMessageId(userInfo:[AnyHashable: Any], for prefix: String) -> MessageId? {
    if let msgId = userInfo["\(prefix).message.id"] as? Int32, let msgNamespace = userInfo["\(prefix).message.namespace"] as? Int32, let namespace = userInfo["\(prefix).peer.namespace"] as? Int32, let id = userInfo["\(prefix).peer.id"] as? Int32 {
        return MessageId(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(namespace), id: PeerId.Id._internalFromInt32Value(id)), namespace: msgNamespace, id: msgId)
    }
    return nil
}

struct LockNotificationsData : Equatable {
    let screenLock:Bool
    let passcodeLock:Bool
    
    init() {
        self.screenLock = false
        self.passcodeLock = false
    }
    
    init(screenLock: Bool, passcodeLock: Bool) {
        self.screenLock = screenLock
        self.passcodeLock = passcodeLock
    }
    
    func withUpdatedScreenLock(_ lock: Bool) -> LockNotificationsData {
        return LockNotificationsData(screenLock: lock, passcodeLock: passcodeLock)
    }
    func withUpdatedPasscodeLock(_ lock: Bool) -> LockNotificationsData {
        return LockNotificationsData(screenLock: screenLock, passcodeLock: lock)
    }
    
    static func ==(lhs:LockNotificationsData, rhs: LockNotificationsData) -> Bool {
        return lhs.screenLock == rhs.screenLock && lhs.passcodeLock == rhs.screenLock
    }
    
    var isLocked: Bool {
        return screenLock || passcodeLock
    }
}

final class SharedNotificationBindings {
    let navigateToChat:(Account, PeerId) -> Void
    let navigateToThread:(Account, MessageId, MessageId) -> Void // threadId, fromId
    let updateCurrectController:()->Void
    let applyMaxReadIndexInteractively:(MessageIndex)->Void
    init(navigateToChat: @escaping(Account, PeerId) -> Void, navigateToThread: @escaping(Account, MessageId, MessageId) -> Void, updateCurrectController: @escaping()->Void, applyMaxReadIndexInteractively:@escaping(MessageIndex)->Void) {
        self.navigateToChat = navigateToChat
        self.navigateToThread = navigateToThread
        self.updateCurrectController = updateCurrectController
        self.applyMaxReadIndexInteractively = applyMaxReadIndexInteractively
    }
}


final class SharedNotificationManager : NSObject, NSUserNotificationCenterDelegate {

    private let screenLocked:Promise<LockNotificationsData> = Promise(LockNotificationsData())
    private(set) var _lockedValue:LockNotificationsData = LockNotificationsData() {
        didSet {
            didUpdateLocked?(_lockedValue)
        }
    }
    
    var didUpdateLocked:((LockNotificationsData)->Void)? = nil
    
    private let _passlock = Promise<Bool>()

    var passlocked: Signal<Bool, NoError> {
        return _passlock.get()
    }

    
    private func updateLocked(_ f:(LockNotificationsData) -> LockNotificationsData) {
        _lockedValue = f(_lockedValue)
        screenLocked.set(.single(_lockedValue))
    }
    
    private let disposableDict: DisposableDict<AccountRecordId> = DisposableDict()
    let accountManager: AccountManager<TelegramAccountManagerTypes>
    var resignTimestamp:Int32? = nil
    let window: Window
    
    var activeAccounts: (primary: Account?, accounts: [(AccountRecordId, Account)]) = (primary: nil, accounts: [])
    let bindings: SharedNotificationBindings
    private let appEncryption: AppEncryptionParameters
    init(activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, appEncryption: AppEncryptionParameters, accountManager: AccountManager<TelegramAccountManagerTypes>, window: Window, bindings: SharedNotificationBindings) {
        self.accountManager = accountManager
        self.window = window
        self.bindings = bindings
        self.appEncryption = appEncryption
        
        
        super.init()
        
        UNUserNotifications.initialize(manager: self)

     
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)

        
        _ = (_passlock.get() |> mapToSignal { show in additionalSettings(accountManager: accountManager) |> map { (show, $0) }} |> deliverOnMainQueue |> mapToSignal { show, settings -> Signal<Bool, NoError> in
            if show {
                let controller = PasscodeLockController(accountManager, useTouchId: settings.useTouchId, logoutImpl: {
                    return self.logout()
                }, updateCurrectController: bindings.updateCurrectController)
                closeAllModals()
                closeInstantView()
                closeGalleryViewer(false)
                showModal(with: controller, for: window, isOverlay: true)
                return .single(show) |> then( controller.doneValue |> map {_ in return false} |> take(1) )
            }
            return .never()
            } |> deliverOnMainQueue).start(next: { [weak self] lock in
                for subview in window.contentView!.subviews {
                    if let subview = subview as? SplitView {
                        subview.isHidden = lock
                        break
                    }
                }
                self?.updateLocked { previous -> LockNotificationsData in
                    return previous.withUpdatedPasscodeLock(lock)
                }
            })
        
        _ = (activeAccounts |> deliverOnMainQueue).start(next: { accounts in
            for account in accounts.accounts {
                self.startNotifyListener(with: account.1, primary: account.0 == accounts.primary?.id)
            }
            self.activeAccounts = accounts
        })
        
        
        let passlock = Signal<Void, NoError>.single(Void()) |> delay(10, queue: Queue.concurrentDefaultQueue()) |> restart |> mapToSignal { () -> Signal<Int32?, NoError> in
            return accountManager.transaction { transaction -> Int32? in
                if transaction.getAccessChallengeData().isLockable {
                    return passcodeSettings(transaction).timeout
                } else {
                    return nil
                }
            }
            } |> map { [weak self] timeout -> Bool in
                if let timeout = timeout {
                    if let resignTimestamp = self?.resignTimestamp  {
                        let current = Int32(Date().timeIntervalSince1970)
                        if current - resignTimestamp > timeout {
                            return true
                        }
                    }
                    return Int64(timeout) < SystemIdleTime()
                } else  {
                    return false
                }
            }
            |> filter { _ in
                return !self._lockedValue.passcodeLock
            }
            |> deliverOnMainQueue
        
        window.set(handler: { _ -> KeyHandlerResult in
            
            if !self._lockedValue.passcodeLock {
                self._passlock.set(accountManager.transaction { transaction -> Bool in
                    switch transaction.getAccessChallengeData() {
                    case .none:
                        return false
                    default:
                        return true
                    }
                })
            }
            
            return .invoked
        }, with: self, for: .L, priority: .modal, modifierFlags: [.command])

        _passlock.set(passlock)
        
    }
    
    
    func logout() -> Signal<Never, NoError> {
        let accountManager = self.accountManager
        let signal = combineLatest(self.activeAccounts.accounts.map { logoutFromAccount(id: $0.0, accountManager: self.accountManager, alreadyLoggedOutRemotely: false) }) |> deliverOnMainQueue
        appEncryption.remove()
        let removePasscode = accountManager.transaction { $0.setAccessChallengeData(.none) }  |> deliverOnMainQueue
        return combineLatest(removePasscode, signal) |> ignoreValues
    }
    
    
    @objc public func windowDidBecomeKey() {
        self.resignTimestamp = nil
    }
    
    @objc public func windowDidResignKey() {
        self.resignTimestamp = Int32(Date().timeIntervalSince1970)
    }
    
    @objc func screenIsLocked() {
        
        if !_lockedValue.passcodeLock {
            _passlock.set(accountManager.transaction { transaction -> Bool in
                switch transaction.getAccessChallengeData() {
                case .none:
                    return false
                default:
                    return true
                }
            })
        }
        
        updateLocked { (previous) -> LockNotificationsData in
            return previous.withUpdatedScreenLock(true)
        }
    }
    
    @objc func screenIsUnlocked() {
        updateLocked { (previous) -> LockNotificationsData in
            return previous.withUpdatedScreenLock(false)
        }
    }
    
    
    var isLocked: Bool {
        return _lockedValue.isLocked
    }
    
    private(set) var snoofEnabled: Bool = true
    private(set) var requestUserAttention: Bool = false
    
    func startNotifyListener(with account: Account, primary: Bool) {
        let screenLocked = self.screenLocked
        var alreadyNotified:Set<MessageId> = Set()
        
        disposableDict.set((account.stateManager.notificationMessages |> mapToSignal { messages -> Signal<([([Message], PeerGroupId)], InAppNotificationSettings), NoError> in
            return appNotificationSettings(accountManager: self.accountManager) |> take(1) |> mapToSignal { inAppSettings -> Signal<([([Message], PeerGroupId)], InAppNotificationSettings), NoError> in
                self.snoofEnabled = inAppSettings.showNotificationsOutOfFocus
                self.requestUserAttention = inAppSettings.requestUserAttention
                if inAppSettings.enabled && inAppSettings.muteUntil < Int32(Date().timeIntervalSince1970) {
                    
                    return .single((messages.filter({$0.2 || ($0.0.isEmpty || $0.0[0].wasScheduled)}).map {($0.0, $0.1)}, inAppSettings))
                } else {
                    return .complete()
                }
                
            }
        }
        |> mapToSignal { messages, inAppSettings -> Signal<([([Message], PeerGroupId)],[MessageId:NSImage], InAppNotificationSettings), NoError> in
                
                var photos:[Signal<(MessageId, CGImage?),NoError>] = []
                for message in messages.reduce([], { current, value in return current + value.0}) {
                    var peer = message.author
                    if let mainPeer = messageMainPeer(message) {
                        if mainPeer is TelegramChannel || mainPeer is TelegramGroup || message.wasScheduled {
                            peer = mainPeer
                        }
                    }
                    if message.id.peerId == repliesPeerId {
                        peer = message.chatPeer(account.peerId)
                    }
                    if let peer = peer {
                        photos.append(peerAvatarImage(account: account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, message), genCap: false) |> map { data in return (message.id, data.0)})
                    }
                }
                
                return  combineLatest(photos) |> map { resources in
                    var images:[MessageId:NSImage] = [:]
                    for (messageId,image) in resources {
                        if let image = image {
                            images[messageId] = NSImage(cgImage: image, size: NSMakeSize(50,50))
                        }
                    }
                    return (messages, images, inAppSettings)
                }
            } |> mapToSignal { messages, images, inAppSettings -> Signal<([([Message], PeerGroupId)],[MessageId:NSImage], InAppNotificationSettings, Bool), NoError> in
                return screenLocked.get()
                    |> take(1)
                    |> map { data in return (messages, images, inAppSettings, data.isLocked)}
            }
            |> mapToSignal { values in
                return account.postbox.loadedPeerWithId(account.peerId) |> map { peer in
                    return (values.0, values.1, values.2, values.3, peer)
                }
            } |> deliverOnMainQueue).start(next: { messages, images, inAppSettings, screenIsLocked, accountPeer in
                
                if !primary, !inAppSettings.notifyAllAccounts {
                    return
                }
                
                for (messages, groupId) in messages {
                    for message in messages {
                        
                        if alreadyNotified.contains(message.id) {
                            continue
                        }

                        if message.isImported {
                            continue
                        }
                        
                        if message.author?.id != account.peerId || message.wasScheduled {
                            var title:String = message.author?.displayTitle ?? ""
                            var hasReplyButton:Bool = !screenIsLocked
                            if let peer = message.peers[message.id.peerId] {
                                if peer.isSupergroup || peer.isGroup {
                                    title = peer.displayTitle
                                    hasReplyButton = peer.canSendMessage(false)
                                } else if message.id.peerId == repliesPeerId {
                                    if let peerId = message.sourceReference?.messageId.peerId, let sourcePeer = message.peers[peerId] {
                                        hasReplyButton = sourcePeer.canSendMessage(true)
                                    }
                                } else if peer.isChannel {
                                    hasReplyButton = false
                                }
                            }
                            
                            if message.wasScheduled {
                                hasReplyButton = false
                            }
                            
                            if screenIsLocked {
                                title = appName
                            }
                            
                           
                           
                            
                            var text = chatListText(account: account, for: message, applyUserName: true).string.nsstring
                            var subText:String?
                            if text.contains("\n") {
                                let parts = text.components(separatedBy: "\n")
                                text = parts[1] as NSString
                                subText = parts[0]
                            }
                            
                            if message.wasScheduled {
                                if message.id.peerId == account.peerId {
                                    title = L10n.notificationReminder
                                } else {
                                    title = "📆 \(title)"
                                }
                                subText = nil
                            }
                            if message.id.peerId == repliesPeerId {
                                subText = message.chatPeer(account.peerId)?.displayTitle
                            }
                            
                            
                            if !inAppSettings.displayPreviews || message.peers[message.id.peerId] is TelegramSecretChat || screenIsLocked {
                                text = L10n.notificationLockedPreview.nsstring
                                subText = nil
                            }
                            
                            let notification = NSUserNotification()
                            
                            notification.identifier = "msg_\(message.id.toInt64())"
                            
                            if localizedString(inAppSettings.tone) != tr(L10n.notificationSettingsToneNone) {
                                notification.soundName = inAppSettings.tone
                            } else {
                                notification.soundName = nil
                            }
                            
                            if message.muted {
                                notification.soundName = nil
                                title += " 🔕"
                            }
                            
                   
                            
                            if self.activeAccounts.accounts.count > 1 && !screenIsLocked {
                                title += " → \(accountPeer.addressName ?? accountPeer.displayTitle)"
                            }
                            
                            notification.title = title
                            notification.informativeText = text as String
                            notification.subtitle = subText
                            notification.contentImage = screenIsLocked ? nil : images[message.id]
                            notification.hasReplyButton = hasReplyButton
                            
                            notification.hasActionButton = !message.wasScheduled
                            notification.otherButtonTitle = L10n.notificationMarkAsRead
                            
                            var dict: [String : Any] = [:]
                            
                            if message.wasScheduled {
                                dict["wasScheduled"] = true
                            }
                            
                            if let sourceReference = message.sourceReference, let threadId = message.replyAttribute?.threadMessageId, message.id.peerId == repliesPeerId {
                                dict["source.message.id"] = sourceReference.messageId.id
                                dict["source.message.namespace"] = sourceReference.messageId.namespace
                                dict["source.peer.id"] = sourceReference.messageId.peerId.id._internalGetInt32Value()
                                dict["source.peer.namespace"] = sourceReference.messageId.peerId.namespace._internalGetInt32Value()
                                
                                dict["thread.message.id"] = threadId.id
                                dict["thread.message.namespace"] = threadId.namespace
                                dict["thread.peer.id"] = threadId.peerId.id._internalGetInt32Value()
                                dict["thread.peer.namespace"] = threadId.peerId.namespace._internalGetInt32Value()
                            }
                            
                            dict["reply.message.id"] =  message.id.id
                            dict["reply.message.namespace"] =  message.id.namespace
                            dict["reply.peer.id"] =  message.id.peerId.id._internalGetInt32Value()
                            dict["reply.peer.namespace"] =  message.id.peerId.namespace._internalGetInt32Value()
                            
                            dict["groupId"] = groupId.rawValue
                            
                            dict["accountId"] = account.id.int64
                            dict["timestamp"] = Int32(Date().timeIntervalSince1970)

                            alreadyNotified.insert(message.id)
                            
                            notification.userInfo = dict
//                            NSUserNotificationCenter.default.deliver(notification)
                            
                            if self.shouldPresent(dict) {
                                UNUserNotifications.current?.add(notification)
                            }
                        }
                    }
                }
            }), forKey: account.id)
    }

  
    private func shouldPresent(_ userInfo:[AnyHashable : Any]?) -> Bool {
        guard let id = userInfo?["accountId"] as? Int64 else {
            return false
        }
        let accountId = AccountRecordId(rawValue: id)
        
        if accountId != self.activeAccounts.primary?.id {
            return true
        }
        
        let wasScheduled = userInfo?["wasScheduled"] as? Bool ?? false
        
        let result = !snoofEnabled || !window.isKeyWindow || wasScheduled
        
        return result
    }

    
}
