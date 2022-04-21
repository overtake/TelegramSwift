
import Cocoa
import TelegramCore

import Postbox
import SwiftSignalKit
import FetchManager

private func fetchCategoryForFile(_ file: TelegramMediaFile) -> FetchManagerCategory {
    if file.isVoice || file.isInstantVideo {
        return .voice
    } else if file.isAnimated {
        return .animation
    } else {
        return .file
    }
}


func freeMediaFileInteractiveFetched(context: AccountContext, fileReference: FileMediaReference, range: Range<Int>? = nil) -> Signal<FetchResourceSourceType, NoError> {
    return fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource), range: range != nil ? (range!, .default) : nil, statsCategory: fileReference.media.isVideo ? .video : .file) |> `catch` { _ in return .complete() }
}

func cancelFreeMediaFileInteractiveFetch(context: AccountContext, resource: MediaResource) {
    context.account.postbox.mediaBox.cancelInteractiveResourceFetch(resource)
}
func messageMediaFileInteractiveFetched(context: AccountContext, messageId: MessageId, messageReference: MessageReference, file: TelegramMediaFile, ranges: IndexSet = IndexSet(integersIn: 0 ..< Int(Int32.max) as Range<Int>), userInitiated: Bool, priority: FetchManagerPriority = .userInitiated) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: messageReference, media: file)
    return context.fetchManager.interactivelyFetched(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(file.resource), ranges: ranges, statsCategory: statsCategoryForFileWithAttributes(file.attributes), elevatedPriority: false, userInitiated: userInitiated, priority: priority, storeToDownloadsPeerType: nil)
}

func messageMediaFileCancelInteractiveFetch(context: AccountContext, messageId: MessageId, file: TelegramMediaFile) {
    context.fetchManager.cancelInteractiveFetches(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}

func toggleInteractiveFetchPaused(context: AccountContext, file: TelegramMediaFile, isPaused: Bool) {
    context.fetchManager.toggleInteractiveFetchPaused(resourceId: file.resource.id.stringRepresentation, isPaused: isPaused)
}

func messageMediaFileStatus(context: AccountContext, messageId: MessageId, fileReference: FileMediaReference) -> Signal<MediaResourceStatus, NoError> {
    return context.fetchManager.fetchStatus(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: fileReference.media.resource)
}
