import TelegramCore
import SwiftSignalKit
import Postbox

public final class Reactions {
    
    private let engine: TelegramEngine
    
    private let disposable = MetaDisposable()
    private let downloadable = DisposableSet()
    private let state: Promise<AvailableReactions?> = Promise()
    private let reactable = DisposableDict<MessageId>()
    public var stateValue: Signal<AvailableReactions?, NoError> {
        return state.get()
    }
    
    public init(_ engine: TelegramEngine) {
        self.engine = engine
        state.set(engine.stickers.availableReactions())
        download()
    }
    
    public func react(_ messageId: MessageId, value: String?) {
        reactable.set(updateMessageReactionsInteractively(account: self.engine.account, messageId: messageId, reaction: value).start(), forKey: messageId)
    }
    
    public func updateQuick(_ value: String) {
        _ = self.engine.stickers.updateQuickReaction(reaction: value).start()
    }
    
    deinit {
        downloadable.dispose()
        disposable.dispose()
        reactable.dispose()
    }
    
    private func download() {
        let engine = self.engine
        let downloadable = self.downloadable
        disposable.set(state.get().start(next: { reactions in
            if let reactions = reactions {
                for reaction in reactions.reactions {
                    
                    let files = [reaction.staticIcon, reaction.selectAnimation, reaction.effectAnimation, reaction.activateAnimation, reaction.appearAnimation]
                    for file in files {
                        downloadable.add(fetchedMediaResource(mediaBox: engine.account.postbox.mediaBox, reference: FileMediaReference.standalone(media: file).resourceReference(file.resource)).start())
                        
                        if let representation = smallestImageRepresentation(file.previewRepresentations) {
                            downloadable.add(fetchedMediaResource(mediaBox: engine.account.postbox.mediaBox, reference: FileMediaReference.standalone(media: file).resourceReference(representation.resource)).start())
                        }
                            
                    }
                }
            }
        }))
    }
}
