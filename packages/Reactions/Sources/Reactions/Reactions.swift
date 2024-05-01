import TelegramCore
import SwiftSignalKit
import Postbox
import Foundation
import InAppSettings

public final class Reactions {
    
    private let engine: TelegramEngine
    
    private let disposable = MetaDisposable()
    private let downloadable = DisposableSet()
    private let state: Promise<AvailableReactions?> = Promise()
    private let reactable = DisposableDict<MessageId>()
    
    public struct Interactive {
        public let messageId: MessageId
        public let rect: NSRect?
    }
    public struct InteractiveStatus {
        public let fileId: Int64?
        public let previousFileId: Int64?
        public let rect: NSRect?
    }
    
    private(set) public var available: AvailableReactions?
        
    public var stateValue: Signal<AvailableReactions?, NoError> {
        return state.get() |> distinctUntilChanged |> deliverOnMainQueue
    }
    
    public var isPremium: Bool = false
    
    private let _isInteractive = Atomic<Interactive?>(value: nil)
    public var interactive: Interactive? {
        return _isInteractive.swap(nil)
    }
    
    private let _interactiveStatus = Atomic<InteractiveStatus?>(value: nil)
    public var interactiveStatus: InteractiveStatus? {
        return _interactiveStatus.swap(nil)
    }
    
    public init(_ engine: TelegramEngine) {
        self.engine = engine
        
        self.restartState()
        
        disposable.set(self.stateValue.start(next: { [weak self] state in
            self?.available = state
            if state == nil {
                Queue.mainQueue().after(5.0, {
                    self?.restartState()
                })
            }
        }))
    }
    
    private func restartState() {
        state.set((engine.stickers.availableReactions() |> then(.complete() |> suspendAwareDelay(1 * 60 * 60, queue: .concurrentDefaultQueue()))) |> restart)
    }
    
    public func react(_ messageId: MessageId, values: [UpdateMessageReaction], fromRect: NSRect? = nil, storeAsRecentlyUsed: Bool = false) {
        _ = _isInteractive.swap(.init(messageId: messageId, rect: fromRect))
        reactable.set(updateMessageReactionsInteractively(account: self.engine.account, messageIds: [messageId], reactions: values, isLarge: false, storeAsRecentlyUsed: storeAsRecentlyUsed).start(), forKey: messageId)
    }
    
    public func updateQuick(_ value: MessageReaction.Reaction) {
        _ = self.engine.stickers.updateQuickReaction(reaction: value).start()
    }
    
    public func setStatus(_ file: TelegramMediaFile, peer: Peer, timestamp: Int32, timeout: Int32?, fromRect: NSRect?, handleInteractive: Bool = true) {
        
        let emojiStatus = (peer as? TelegramUser)?.emojiStatus
        
        let expiryDate: Int32?
        if let timeout = timeout {
            expiryDate = timestamp + timeout
        } else {
            expiryDate = nil
        }
        if file.mimeType.hasPrefix("bundle") {
            if handleInteractive {
                if emojiStatus != nil {
                    _ = _interactiveStatus.swap(.init(fileId: nil, previousFileId: emojiStatus?.fileId, rect: fromRect))
                } else {
                    _ = _interactiveStatus.swap(nil)
                }
            }
            
            _ = engine.accountData.setEmojiStatus(file: nil, expirationDate: expiryDate).start()
        } else {
            if file.fileId.id == emojiStatus?.fileId {
                if handleInteractive {
                    _ = _interactiveStatus.swap(nil)
                }
                _ = engine.accountData.setEmojiStatus(file: nil, expirationDate: expiryDate).start()
            } else {
                if handleInteractive {
                    _ = _interactiveStatus.swap(.init(fileId: file.fileId.id, previousFileId: emojiStatus?.fileId, rect: fromRect))
                }
                _ = engine.accountData.setEmojiStatus(file: file, expirationDate: expiryDate).start()
            }
        }
        _ = updateSomeSettingsInteractively(postbox: self.engine.account.postbox, { current in
            var current = current
            current.focusIntentStatusFallback = nil
            current.focusIntentStatusEnabled = false
            return current
        }).startStandalone()
    }
    
    deinit {
        downloadable.dispose()
        disposable.dispose()
        reactable.dispose()
    }
    
}
