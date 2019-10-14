//
//  SharedNotificationManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit

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
    init(navigateToChat: @escaping(Account, PeerId) -> Void) {
        self.navigateToChat = navigateToChat
    }
}


final class SharedNotificationManager : NSObject, NSUserNotificationCenterDelegate {

    private let screenLocked:Promise<LockNotificationsData> = Promise(LockNotificationsData())
    private var _lockedValue:LockNotificationsData = LockNotificationsData()
    private let _passlock = Promise<Bool>()

    
    private func updateLocked(_ f:(LockNotificationsData) -> LockNotificationsData) {
        _lockedValue = f(_lockedValue)
        screenLocked.set(.single(_lockedValue))
    }
    
    private let disposableDict: DisposableDict<AccountRecordId> = DisposableDict()
    private let accountManager: AccountManager
    private var resignTimestamp:Int32? = nil
    private let window: Window
    
    private var activeAccounts: (primary: Account?, accounts: [(AccountRecordId, Account)]) = (primary: nil, accounts: [])
    private let bindings: SharedNotificationBindings
    init(activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, accountManager: AccountManager, window: Window, bindings: SharedNotificationBindings) {
        self.accountManager = accountManager
        self.window = window
        self.bindings = bindings
        super.init()
        
     
        NSUserNotificationCenter.default.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)

        
        _ = (_passlock.get() |> mapToSignal { show in additionalSettings(accountManager: accountManager) |> map { (show, $0) }} |> deliverOnMainQueue |> mapToSignal { show, settings -> Signal<Bool, NoError> in
            if show {
                let controller = PasscodeLockController(accountManager, useTouchId: settings.useTouchId, logoutImpl: {
                    return self.logout()
                })
                closeAllModals()
                closeGalleryViewer(false)
                showModal(with: controller, for: window, isOverlay: true)
                return .single(show) |> then( controller.doneValue |> map {_ in return false} |> take(1) )
            }
            return .never()
            } |> deliverOnMainQueue).start(next: { [weak self] lock in
                
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
                return transaction.getAccessChallengeData().timeout
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
        
        window.set(handler: { () -> KeyHandlerResult in
            
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

        
        let showPasslock = passlock
        
        
        var access: PostboxAccessChallengeData = .none
        let accessSemaphore = DispatchSemaphore(value: 0)
        _ = (accountManager.transaction { transaction in
            access = transaction.getAccessChallengeData()
            accessSemaphore.signal()
        }).start()
        accessSemaphore.wait()
        
        _passlock.set(.single(access != .none) |> then(showPasslock))
        
    }
    
    
    func logout() -> Signal<Never, NoError> {
        let accountManager = self.accountManager
        let signal = combineLatest(self.activeAccounts.accounts.map { logoutFromAccount(id: $0.0, accountManager: self.accountManager, alreadyLoggedOutRemotely: false) }) |> deliverOnMainQueue
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
    
    private var snoofEnabled: Bool = true
    
    func startNotifyListener(with account: Account, primary: Bool) {
        let screenLocked = self.screenLocked
        var alsoNotified:Set<MessageId> = Set()
        
        disposableDict.set((account.stateManager.notificationMessages |> mapToSignal { messages -> Signal<([([Message], PeerGroupId)], InAppNotificationSettings), NoError> in
            return appNotificationSettings(accountManager: self.accountManager) |> take(1) |> mapToSignal { inAppSettings -> Signal<([([Message], PeerGroupId)], InAppNotificationSettings), NoError> in
                self.snoofEnabled = inAppSettings.showNotificationsOutOfFocus
                
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
                        
                        if alsoNotified.contains(message.id) {
                            continue
                        }
                        
                        if message.author?.id != account.peerId || message.wasScheduled {
                            var title:String = message.author?.displayTitle ?? ""
                            var hasReplyButton:Bool = !screenIsLocked
                            if let peer = message.peers[message.id.peerId] {
                                if peer.isSupergroup || peer.isGroup {
                                    title = peer.displayTitle
                                    hasReplyButton = peer.canSendMessage
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
                            
                           
                           
                            
                            var text = chatListText(account: account, for: message).string.nsstring
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
                            
                            
                            if !inAppSettings.displayPreviews || message.peers[message.id.peerId] is TelegramSecretChat || screenIsLocked {
                                text = L10n.notificationLockedPreview.nsstring
                                subText = nil
                            }
                            
                            let notification = NSUserNotification()
                            
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
                           // notification.additionalActions = [NSUserNotificationAction(identifier: "read", title: "Mark as Read")]
                            
                            var dict: [String : Any] = [:]
                            
                            
                            if message.wasScheduled {
                                dict["wasScheduled"] = true
                            }
                            
                            
                            
                            dict["message.id"] =  message.id.id
                            dict["message.namespace"] =  message.id.namespace
                            dict["peer.id"] =  message.id.peerId.id
                            dict["peer.namespace"] =  message.id.peerId.namespace
                            dict["groupId"] = groupId.rawValue
                            dict["timestamp"] = Int32(Date().timeIntervalSince1970)
                            dict["accountId"] = account.id.int64
                            
                            if screenIsLocked {
                                dict = [:]
                            }
                            
                            alsoNotified.insert(message.id)
                            
                            notification.userInfo = dict
                            NSUserNotificationCenter.default.deliver(notification)
                            
                
                            
                        }
                    }
                }
            }), forKey: account.id)
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        guard let id = notification.userInfo?["accountId"] as? Int64 else {
            return false
        }
        let accountId = AccountRecordId(rawValue: id)
        
        if accountId != self.activeAccounts.primary?.id {
            return true
        }
        
        let wasScheduled = notification.userInfo?["wasScheduled"] as? Bool ?? false
        
        return !snoofEnabled || !NSApp.isActive || wasScheduled
    }
    
    
    @objc func userNotificationCenter(_ center: NSUserNotificationCenter, didDismissAlert notification: NSUserNotification) {
        if let userInfo = notification.userInfo, let msgId = userInfo["message.id"] as? Int32, let timestamp = userInfo["timestamp"] as? Int32, let msgNamespace = userInfo["message.namespace"] as? Int32, let namespace = userInfo["peer.namespace"] as? Int32, let id = userInfo["peer.id"] as? Int32, let accountId = userInfo["accountId"] as? Int64 {
            
            let accountId = AccountRecordId(rawValue: accountId)
            
            let messageId = MessageId(peerId: PeerId(namespace: namespace, id: id), namespace: msgNamespace, id: msgId)
            
            guard let account = activeAccounts.accounts.first(where: {$0.0 == accountId})?.1 else {
                return
            }
            
            _ = applyMaxReadIndexInteractively(postbox: account.postbox, stateManager: account.stateManager, index: MessageIndex(id: messageId, timestamp: timestamp)).start()
        }
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if let userInfo = notification.userInfo, let msgId = userInfo["message.id"] as? Int32, let msgNamespace = userInfo["message.namespace"] as? Int32, let namespace = userInfo["peer.namespace"] as? Int32, let id = userInfo["peer.id"] as? Int32, let accountId = userInfo["accountId"] as? Int64 {
            
            let accountId = AccountRecordId(rawValue: accountId)
            
            let messageId = MessageId(peerId: PeerId(namespace: namespace, id: id), namespace: msgNamespace, id: msgId)
                        
            guard let account = activeAccounts.accounts.first(where: {$0.0 == accountId})?.1 else {
                return
            }
            
            closeAllModals()
            
            if notification.activationType == .replied, let text = notification.response?.string {
                var replyToMessageId:MessageId?
                if messageId.peerId.namespace != Namespaces.Peer.CloudUser {
                    replyToMessageId = messageId
                }
                _ = enqueueMessages(account: account, peerId: messageId.peerId, messages: [EnqueueMessage.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: replyToMessageId, localGroupingKey: nil)]).start()
            } else {
                self.bindings.navigateToChat(account, messageId.peerId)
            }
        }
    }
    

    
}
