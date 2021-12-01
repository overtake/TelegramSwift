import TelegramCore
import SwiftSignalKit

public final class Reactions {
    
    private let engine: TelegramEngine
    
    private let disposable = MetaDisposable()
    private let downloadable = DisposableSet()
    private let state: Promise<AvailableReactions?> = Promise()
    
    public var stateValue: Signal<AvailableReactions?, NoError> {
        return state.get()
    }
    
    public init(_ engine: TelegramEngine) {
        self.engine = engine
        state.set(engine.stickers.availableReactions())
        download()
    }
    
    deinit {
        downloadable.dispose()
        disposable.dispose()
    }
    
    private func download() {
        let engine = self.engine
        let downloadable = self.downloadable
        disposable.set(state.get().start(next: { reactions in
            if let reactions = reactions {
                for reaction in reactions.reactions {
                    
                    let files = [reaction.staticIcon, reaction.selectAnimation, reaction.effectAnimation, reaction.activateAnimation]
                    for file in files {
                        downloadable.add(fetchedMediaResource(mediaBox: engine.account.postbox.mediaBox, reference: FileMediaReference.standalone(media: file).resourceReference(file.resource)).start())
                    }
                }
            }
        }))
    }
}
