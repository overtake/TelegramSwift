import TelegramCore
import SwiftSignalKit
import Postbox
import Foundation

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
    
    private let _isInteractive = Atomic<Interactive?>(value: nil)
    private(set) public var available: AvailableReactions?
    public var stateValue: Signal<AvailableReactions?, NoError> {
        return state.get() |> distinctUntilChanged |> deliverOnMainQueue
    }
    
    public var isPremium: Bool = false
    
    public var interactive: Interactive? {
        return _isInteractive.swap(nil)
    }
    
    public init(_ engine: TelegramEngine) {
        self.engine = engine
        
        state.set((engine.stickers.availableReactions() |> then(.complete() |> suspendAwareDelay(5.0, queue: .concurrentDefaultQueue()))) |> restart)
        
        disposable.set(self.stateValue.start(next: { [weak self] state in
            self?.available = state
        }))
    }
    
    public func react(_ messageId: MessageId, values: [UpdateMessageReaction], fromRect: NSRect? = nil, storeAsRecentlyUsed: Bool = false) {
        _ = _isInteractive.swap(.init(messageId: messageId, rect: fromRect))
        reactable.set(updateMessageReactionsInteractively(account: self.engine.account, messageId: messageId, reactions: values, isLarge: false, storeAsRecentlyUsed: storeAsRecentlyUsed).start(), forKey: messageId)
    }
    
    public func updateQuick(_ value: MessageReaction.Reaction) {
        _ = self.engine.stickers.updateQuickReaction(reaction: value).start()
    }
    
    deinit {
        downloadable.dispose()
        disposable.dispose()
        reactable.dispose()
    }
    
}
