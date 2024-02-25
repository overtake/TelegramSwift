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
import BuildConfig
import TGUIKit
import ObjcUtils
import InAppSettings

func getNotificationMessageId(userInfo:[AnyHashable: Any], for prefix: String) -> MessageId? {
    if let msgId = userInfo["\(prefix).message.id"] as? Int32, let msgNamespace = userInfo["\(prefix).message.namespace"] as? Int32, let namespace = userInfo["\(prefix).peer.namespace"] as? Int32, let id = userInfo["\(prefix).peer.id"] as? Int64 {
        return MessageId(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(namespace), id: PeerId.Id._internalFromInt64Value(id)), namespace: msgNamespace, id: msgId)
    }
    return nil
}

func getNotificationToneFile(account: Account, sound: PeerMessageSound) -> Signal<String?, NoError> {
    let engine = TelegramEngine(account: account)
    return engine.peers.notificationSoundList() |> take(1) |> mapToSignal { list in
        return fileNameForNotificationSound(postbox: account.postbox, sound: sound, defaultSound: nil, list: list?.sounds) |> map { resource in
            if let resource = resource {
                return resourcePath(account.postbox, resource)
            } else {
                return "default"
            }
        }
    }
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
    let navigateToThread:(Account, MessageId, MessageId?, MessageHistoryThreadData?) -> Void // threadId, fromId
    let updateCurrectController:()->Void
    let applyMaxReadIndexInteractively:(MessageIndex)->Void
    init(navigateToChat: @escaping(Account, PeerId) -> Void, navigateToThread: @escaping(Account, MessageId, MessageId?, MessageHistoryThreadData?) -> Void, updateCurrectController: @escaping()->Void, applyMaxReadIndexInteractively:@escaping(MessageIndex)->Void) {
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
    
    var activeAccounts: (primary: Account?, accounts: [(AccountRecordId, Account)]) = (primary: nil, accounts: [])
    let bindings: SharedNotificationBindings
    private let appEncryption: AppEncryptionParameters
    
    private var lockers:[PasscodeLockController] = []
    
    init(activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, appEncryption: AppEncryptionParameters, accountManager: AccountManager<TelegramAccountManagerTypes>, bindings: SharedNotificationBindings) {
        self.accountManager = accountManager
        self.bindings = bindings
        self.appEncryption = appEncryption
        
        
        super.init()
        
        UNUserNotifications.initialize(manager: self)

        UNUserNotifications.current?.authorize(completion: { value in
            
        })
        
//        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
//        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)

        
        _ = (_passlock.get() |> mapToSignal { show in additionalSettings(accountManager: accountManager) |> map { (show, $0) }} |> deliverOnMainQueue |> mapToSignal { show, settings -> Signal<Bool, NoError> in
            if show {
                closeInstantView()
                closeGalleryViewer(false)
                
                var signals:[Signal<Bool, NoError>] = []
                
                appDelegate?.enumerateAccountContexts({ context in
                    closeAllModals(window: context.window)
                    _ = context.sharedContext.getAudioPlayer()?.pause()
                    let controller = PasscodeLockController(accountManager, useTouchId: settings.useTouchId, logoutImpl: {
                        return self.logout()
                    }, updateCurrectController: bindings.updateCurrectController)
                    
                    self.lockers.append(controller)
                    showModal(with: controller, for: context.window, isOverlay: true)
                    signals.append(controller.doneValue)
                })
                let signal: Signal<Bool, NoError> = combineLatest(signals)
                |> map { values in
                    if values.contains(true) {
                        return false
                    } else {
                        return true
                    }
                }
                return .single(show) |> then(signal)
            }
            return .never()
        } |> deliverOnMainQueue).start(next: { lock in
                
                appDelegate?.enumerateAccountContexts({ context in
                    for subview in context.window.contentView!.subviews {
                        if let subview = subview as? SplitView {
                            subview.isHidden = lock
                            break
                        }
                    }
                })
                if !lock {
                    while !self.lockers.isEmpty {
                        self.lockers.removeLast().close()
                    }
                }
                
                self.updateLocked { previous -> LockNotificationsData in
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
        

        _passlock.set(passlock)
        
    }
    
    func updatePasslock(_ signal: Signal<Bool, NoError>) {
        _passlock.set(signal)
    }
    
    func find(_ id: AccountRecordId?) -> AccountContext? {
        return appDelegate?.activeContext(for: id)
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
        _isLockedValue.set(true)
    }
    
    @objc func screenIsUnlocked() {
        updateLocked { (previous) -> LockNotificationsData in
            return previous.withUpdatedScreenLock(false)
        }
        _isLockedValue.set(false)
    }
    
    private let _isLockedValue = ValuePromise(false, ignoreRepeated: true)
    var isLockedValue: Signal<Bool, NoError> {
        return _isLockedValue.get()
    }

    
    var isLocked: Bool {
        return _lockedValue.isLocked
    }
    
    private(set) var showNotificationsOutOfFocus: Bool = true
    private(set) var requestUserAttention: Bool = false
    
    enum Source {
        case messages([Message], PeerGroupId, MessageHistoryThreadData?)
        case reaction(Message, Peer, MessageReaction.Reaction, Int32, TelegramMediaFile?, MessageHistoryThreadData?)
        
        var messages:[Message] {
            switch self {
            case let .messages(messages, _, _):
                return messages
            case let .reaction(message, _, _, _, _, _):
                return [message]
            }
        }
        
        var threadData: MessageHistoryThreadData? {
            switch self {
            case let .messages(_, _, threadData):
                return threadData
            case let .reaction(_, _, _, _, _, threadData):
                return threadData
            }
        }
        
        var groupId: PeerGroupId? {
            switch self {
            case let .messages(_, groupId, _):
                return groupId
            case .reaction:
                return nil
            }
        }
        func key(for message: Message) -> String {
            switch self {
            case let .reaction(_, peer, value, timestamp, _, _):
                return "reaction_\(message.id.string)_\(peer.id.toInt64())_\(value)_\(timestamp)"
            case .messages:
                return "message_\(message.id.string)"
            }
        }
    }
    
    func startNotifyListener(with account: Account, primary: Bool) {
        let screenLocked = self.screenLocked
        var alreadyNotified:Set<String> = Set()
        
        let engine = TelegramEngine(account: account)
        
        struct ReactionTuple {
            var reactionAuthor: Peer
            var reaction: MessageReaction.Reaction
            var message: Message
            var timestamp: Int32
            var file: TelegramMediaFile?
            var threadData: MessageHistoryThreadData?
        }
        
        let reactions: Signal<[ReactionTuple], NoError> = account.stateManager.reactionNotifications |> mapToSignal { reactions in
            
            
            var fileIds: Set<Int64> = Set()
            for reaction in reactions {
                switch reaction.reaction {
                case let .custom(fileId):
                    fileIds.insert(fileId)
                default:
                    break
                }
            }
            
            return engine.stickers.resolveInlineStickers(fileIds: Array(fileIds)) |> mapToSignal { files in
                return engine.account.postbox.transaction { transaction in
                    var reactions:[ReactionTuple] = reactions.map { .init(reactionAuthor: $0, reaction: $1, message: $2, timestamp: $3) }
                    
                    for (i, reaction) in reactions.enumerated() {
                        var threadData: MessageHistoryThreadData?
                        let message = reaction.message
                        for attr in message.attributes {
                            if let attribute = attr as? ReplyMessageAttribute {
                                if let threadId = attribute.threadMessageId {
                                    threadData = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: Int64(threadId.id))?.data.get(MessageHistoryThreadData.self)
                                }
                            }
                        }
                        reactions[i].threadData = threadData
                    }
                    
                    for (i, reaction) in reactions.enumerated() {
                        sw: switch reaction.reaction {
                            case let .custom(fileId):
                                reactions[i].file = files[fileId]
                            default:
                                break sw
                        }
                    }
                    return reactions
                }
                
            }
        }
        
        disposableDict.set((combineLatest(account.stateManager.notificationMessages, reactions) |> mapToSignal { messages, reactions -> Signal<([Source], InAppNotificationSettings), NoError> in
            return appNotificationSettings(accountManager: self.accountManager) |> take(1) |> mapToSignal { inAppSettings -> Signal<([Source], InAppNotificationSettings), NoError> in
                self.showNotificationsOutOfFocus = inAppSettings.showNotificationsOutOfFocus
                self.requestUserAttention = inAppSettings.requestUserAttention
                if inAppSettings.enabled && inAppSettings.muteUntil < Int32(Date().timeIntervalSince1970) {
                    
                    let msgs:[Source] = messages.filter
                    {
                        $0.2 || ($0.0.isEmpty || $0.0[0].wasScheduled)
                    }.map {
                        return .messages($0.0, $0.1, $0.3)
                    }
                    let rctns:[Source] = reactions.map {
                        .reaction($0.message, $0.reactionAuthor, $0.reaction, $0.timestamp, $0.file, $0.threadData)
                    }

                    return .single((msgs + rctns, inAppSettings))
                } else {
                    return .complete()
                }
                
            }
        }
        |> mapToSignal { sources, inAppSettings -> Signal<([Source],[MessageId:NSImage], InAppNotificationSettings), NoError> in
                
                var photos:[Signal<(MessageId, CGImage?),NoError>] = []
            
                for source in sources {
                    for message in source.messages {
                        var peer = message.author
                        if let mainPeer = coreMessageMainPeer(message) {
                            if mainPeer is TelegramChannel || mainPeer is TelegramGroup || message.wasScheduled {
                                peer = mainPeer
                            }
                        }
                        if message.id.peerId == repliesPeerId {
                            peer = message.chatPeer(account.peerId)
                        }
                        if let peer = peer {
                            if let threadData = source.threadData {
                                photos.append(peerAvatarImage(account: account, photo: .topic(threadData.info, message.threadId == 1), genCap: false) |> map { data in return (message.id, data.0)})
                            } else {
                                photos.append(peerAvatarImage(account: account, photo: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, message), genCap: false) |> map { data in return (message.id, data.0)})
                            }
                        }
                    }
                }
                return  combineLatest(photos) |> take(1) |> map { resources in
                    var images:[MessageId:NSImage] = [:]
                    for (messageId,image) in resources {
                        if let image = image {
                            images[messageId] = NSImage(cgImage: image, size: NSMakeSize(50,50))
                        }
                    }
                    return (sources, images, inAppSettings)
                }
            } |> mapToSignal { sources, images, inAppSettings -> Signal<([Source], [MessageId:NSImage], InAppNotificationSettings, Bool), NoError> in
                return screenLocked.get()
                    |> take(1)
                    |> map { data in return (sources, images, inAppSettings, data.isLocked)}
            }
            |> mapToSignal { values -> Signal<([Source], [MessageId:NSImage], InAppNotificationSettings, Bool, Peer, String?, TelegramPeerNotificationSettings?), NoError> in
            
                return account.postbox.loadedPeerWithId(account.peerId) |> mapToSignal { peer in
                    if let message = values.0.first?.messages.first {
                        return account.postbox.transaction { transaction -> Signal<([Source], [MessageId:NSImage], InAppNotificationSettings, Bool, Peer, String?, TelegramPeerNotificationSettings?), NoError> in
                            let notifications = transaction.getPeerNotificationSettings(id: message.id.peerId) as? TelegramPeerNotificationSettings
                            
                            if let messageSound = notifications?.messageSound {
                                switch messageSound {
                                case .none:
                                    return .single((values.0, values.1, values.2, values.3, peer, nil, notifications))
                                case .default:
                                    return getNotificationToneFile(account: account, sound: values.2.tone) |> map { soundPath in
                                        return (values.0, values.1, values.2, values.3, peer, soundPath, notifications)
                                    }
                                default:
                                    return getNotificationToneFile(account: account, sound: messageSound) |> map { soundPath in
                                        return (values.0, values.1, values.2, values.3, peer, soundPath, notifications)
                                    }
                                }
                            } else {
                                return getNotificationToneFile(account: account, sound: values.2.tone) |> map { soundPath in
                                    return (values.0, values.1, values.2, values.3, peer, soundPath, notifications)
                                }
                            }
                        } |> switchToLatest
                    }
                    return .complete()
                }
            } |> deliverOnMainQueue).start(next: { sources, images, inAppSettings, screenIsLocked, accountPeer, soundPath, notifications in
                
                if !primary, !inAppSettings.notifyAllAccounts {
                    return
                }

                for source in sources {
                    loop: for message in source.messages {
                        
                        if alreadyNotified.contains(source.key(for: message)) {
                            continue
                        }

                        if message.isImported {
                            continue
                        }
                        if let notifications = notifications, notifications.isMuted {
                            if message.consumableMention == nil {
                                continue
                            }
                        }
                        if let thread = source.threadData, thread.notificationSettings.isMuted {
                            if message.consumableMention == nil {
                                continue
                            }
                        }
                        
                        if message.author?.id != account.peerId || message.wasScheduled {
                            var title:String = message.author?.displayTitle ?? ""
                            var hasReplyButton:Bool = !screenIsLocked
                            if let peer = message.peers[message.id.peerId] {
                                if peer.isSupergroup || peer.isGroup {
                                    title = peer.displayTitle
                                    hasReplyButton = peer.canSendMessage(false, threadData: source.threadData)
                                } else if message.id.peerId == repliesPeerId {
                                    if let peerId = message.sourceReference?.messageId.peerId, let sourcePeer = message.peers[peerId] {
                                        hasReplyButton = sourcePeer.canSendMessage(true, threadData: source.threadData)
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
                            
                            var text: String
                            var subText:String? = nil
                            switch source {
                            case let .reaction(message, peer, value, _, file, _):
                                
                                let reactionText: String
                                switch value {
                                case let .builtin(emoji):
                                    reactionText = emoji
                                case let .custom(fileId):
                                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                    let file = file ?? message.associatedMedia[mediaId] as? TelegramMediaFile
                                    reactionText = (file?.customEmojiText ?? file?.stickerText ?? "").normalizedEmoji
                                }
                                
                                let msg = pullText(from: message).string as String
                                title = message.peers[message.id.peerId]?.displayTitle ?? ""
                                if message.id.peerId.namespace == Namespaces.Peer.CloudUser {
                                    text = strings().notificationContactReacted(reactionText.fixed, msg)
                                } else {
                                    text = strings().notificationGroupReacted(peer.displayTitle, reactionText.fixed, msg)
                                }
                            case .messages:
                                text = chatListText(account: account, for: message, applyUserName: true, notifications: true).string
                                if text.contains("\r") {
                                    let parts = text.components(separatedBy: "\r")
                                    text = parts[1]
                                    subText = parts[0]
                                }
                            }
                           
                            
                            if message.wasScheduled {
                                if message.id.peerId == account.peerId {
                                    title = strings().notificationReminder
                                } else {
                                    title = "📆 \(title)"
                                }
                                subText = nil
                            }
                            if message.id.peerId == repliesPeerId {
                                subText = message.chatPeer(account.peerId)?.displayTitle
                            }
                            
                            if let threadData = source.threadData, let txt = subText {
                                subText = "\(txt) → \(threadData.info.title)"
                            }
                            
                            if !inAppSettings.displayPreviews || message.peers[message.id.peerId] is TelegramSecretChat || screenIsLocked {
                                text = strings().notificationLockedPreview
                                subText = nil
                            }
                            
                            let notification = NSUserNotification()
                            
                            notification.identifier = "msg_\(message.id.string)"
                            
                            
                            if #available(macOS 10.14, *) {
                                switch inAppSettings.tone {
                                case .none:
                                    notification.soundName = nil
                                default:
                                    notification.soundName = soundPath
                                }
                            } else {
                                switch inAppSettings.tone {
                                case .none:
                                    notification.soundName = nil
                                default:
                                    break
                                }
                            }

                            switch source {
                            case .messages:
                                if message.muted {
                                    notification.soundName = nil
                                    title += " 🔕"
                                }
                            case .reaction:
                                notification.soundName = nil
                                title += " 🔕"
                            }
                           
                            if screenIsLocked {
                                notification.soundName = nil
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
                            notification.otherButtonTitle = strings().notificationMarkAsRead
                            
                            var dict: [String : Any] = [:]
                            
                            if message.wasScheduled {
                                dict["wasScheduled"] = true
                            }
                            
                            if let sourceReference = message.sourceReference, message.id.peerId == repliesPeerId {
                                dict["source.message.id"] = sourceReference.messageId.id
                                dict["source.message.namespace"] = sourceReference.messageId.namespace
                                dict["source.peer.id"] = sourceReference.messageId.peerId.id._internalGetInt64Value()
                                dict["source.peer.namespace"] = sourceReference.messageId.peerId.namespace._internalGetInt32Value()
                            }
                            if message.sourceReference != nil || source.threadData != nil {
                                dict["is_thread"] = true
                            }
                            if let threadId = message.replyAttribute?.threadMessageId {
                                dict["thread.message.id"] = threadId.id
                                dict["thread.message.namespace"] = threadId.namespace
                                dict["thread.peer.id"] = threadId.peerId.id._internalGetInt64Value()
                                dict["thread.peer.namespace"] = threadId.peerId.namespace._internalGetInt32Value()
                            } else if message.threadId == 1 {
                                dict["thread.message.id"] = 1
                                dict["thread.message.namespace"] = message.id.namespace
                                dict["thread.peer.id"] = message.id.peerId.id._internalGetInt64Value()
                                dict["thread.peer.namespace"] = message.id.peerId.namespace._internalGetInt32Value()
                            }
                            if let threadData = source.threadData, let data = CodableEntry(threadData)?.data {
                                dict["thread_data"] = data
                            }
                            
                            dict["reply.message.id"] =  message.id.id
                            dict["reply.message.namespace"] =  message.id.namespace
                            dict["reply.peer.id"] =  message.id.peerId.id._internalGetInt64Value()
                            dict["reply.peer.namespace"] =  message.id.peerId.namespace._internalGetInt32Value()
                            
                            if let groupId = source.groupId {
                                dict["groupId"] = groupId.rawValue
                            }
                            
                            dict["accountId"] = account.id.int64
                            dict["timestamp"] = Int32(Date().timeIntervalSince1970)

                            alreadyNotified.insert(source.key(for: message))
                            
                            notification.userInfo = dict
                            
                            if self.shouldPresent(dict) {
                                _ = UNUserNotifications.authorizationStatus.start(next: { status in
                                    switch status {
                                    case .authorized:
                                        UNUserNotifications.current?.add(notification)
                                    case .notDetermined:
                                        UNUserNotifications.current?.authorize { manager in
                                            manager.add(notification)
                                        }
                                    default:
                                        break
                                    }
                                })
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
        guard let context = find(accountId) else {
            return false
        }
        let result = !showNotificationsOutOfFocus || !context.window.isKeyWindow || wasScheduled
        
        return result
    }

    
}
