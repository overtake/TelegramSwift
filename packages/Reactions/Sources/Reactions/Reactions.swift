import TelegramCore
import SwiftSignalKit
import Postbox

public final class Reactions {
    
    private let engine: TelegramEngine
    
    private let disposable = MetaDisposable()
    private let downloadable = DisposableSet()
    private let state: Promise<AvailableReactions?> = Promise()
    private let reactable = DisposableDict<MessageId>()
    private let _isInteractive = Atomic<MessageId?>(value: nil)
    public var stateValue: Signal<AvailableReactions?, NoError> {
        return state.get()
    }
    
    public var interactive: MessageId? {
        return _isInteractive.swap(nil)
    }
    
    public init(_ engine: TelegramEngine) {
        self.engine = engine
        state.set(engine.stickers.availableReactions())
    }
    
    public func react(_ messageId: MessageId, value: String?) {
        _ = _isInteractive.swap(messageId)
        reactable.set(updateMessageReactionsInteractively(account: self.engine.account, messageId: messageId, reaction: value, isLarge: false).start(), forKey: messageId)
    }
    
    public func updateQuick(_ value: String) {
        _ = self.engine.stickers.updateQuickReaction(reaction: value).start()
    }
    
    deinit {
        downloadable.dispose()
        disposable.dispose()
        reactable.dispose()
    }
    
}
