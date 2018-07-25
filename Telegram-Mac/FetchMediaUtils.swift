
import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

func freeMediaFileInteractiveFetched(account: Account, fileReference: FileMediaReference) -> Signal<FetchResourceSourceType, NoError> {
    return fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(fileReference.media.resource), statsCategory: fileReference.media.isVideo ? .video : .file)
}

func cancelFreeMediaFileInteractiveFetch(account: Account, resource: MediaResource) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(resource)
}

func messageMediaFileInteractiveFetched(account: Account, messageId: MessageId, fileReference: FileMediaReference) -> Signal<Void, NoError> {
    return account.context.fetchManager.interactivelyFetched(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), reference: fileReference.resourceReference(fileReference.media.resource), fetchTag: fileReference.media.isVideo ? .video : .file, elevatedPriority: false, userInitiated: true)
}

func messageMediaFileCancelInteractiveFetch(account: Account, messageId: MessageId, fileReference: FileMediaReference) {
    account.context.fetchManager.cancelInteractiveFetches(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), reference: fileReference.resourceReference(fileReference.media.resource))
    
}

func messageMediaFileStatus(account: Account, messageId: MessageId, fileReference: FileMediaReference) -> Signal<MediaResourceStatus, NoError> {
    return account.context.fetchManager.fetchStatus(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), reference: fileReference.resourceReference(fileReference.media.resource))
}
