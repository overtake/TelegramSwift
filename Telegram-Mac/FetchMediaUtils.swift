
import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

func freeMediaFileInteractiveFetched(context: AccountContext, fileReference: FileMediaReference, range: Range<Int>? = nil) -> Signal<FetchResourceSourceType, NoError> {
    return fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource), range: range != nil ? (range!, .default) : nil, statsCategory: fileReference.media.isVideo ? .video : .file) |> `catch` { _ in return .complete() }
}

func cancelFreeMediaFileInteractiveFetch(context: AccountContext, resource: MediaResource) {
    context.account.postbox.mediaBox.cancelInteractiveResourceFetch(resource)
}

func messageMediaFileInteractiveFetched(context: AccountContext, messageId: MessageId, fileReference: FileMediaReference, range: Range<Int>? = nil) -> Signal<Void, NoError> {
    return context.fetchManager.interactivelyFetched(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), downloadRange: range, reference: fileReference.resourceReference(fileReference.media.resource), fetchTag: fileReference.media.isVideo ? .video : .file, elevatedPriority: false, userInitiated: true)
}


func messageMediaFileCancelInteractiveFetch(context: AccountContext, messageId: MessageId, fileReference: FileMediaReference) {
    context.fetchManager.cancelInteractiveFetches(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), reference: fileReference.resourceReference(fileReference.media.resource))
    
}

func messageMediaFileStatus(context: AccountContext, messageId: MessageId, fileReference: FileMediaReference) -> Signal<MediaResourceStatus, NoError> {
    return context.fetchManager.fetchStatus(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), reference: fileReference.resourceReference(fileReference.media.resource))
}
