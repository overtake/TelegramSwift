
import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

func freeMediaFileInteractiveFetched(account: Account, file: TelegramMediaFile) -> Signal<FetchResourceSourceType, NoError> {
    return account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: file.isVideo ? .video : .file))
}

func cancelFreeMediaFileInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
}

func messageMediaFileInteractiveFetched(account: Account, messageId: MessageId, file: TelegramMediaFile) -> Signal<Void, NoError> {
    return account.context.fetchManager.interactivelyFetched(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource, fetchTag: TelegramMediaResourceFetchTag(statsCategory: file.isVideo ? .video : .file), elevatedPriority: false, userInitiated: true)
}

func messageMediaFileCancelInteractiveFetch(account: Account, messageId: MessageId, file: TelegramMediaFile) {
    account.context.fetchManager.cancelInteractiveFetches(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
    
}

func messageMediaFileStatus(account: Account, messageId: MessageId, file: TelegramMediaFile) -> Signal<MediaResourceStatus, NoError> {
    return account.context.fetchManager.fetchStatus(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}
