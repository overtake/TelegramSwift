//
//  PeerPhotos.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import TelegramCore


private struct PeerPhotos {
    let photos: [TelegramPeerPhoto]
    let time: TimeInterval
}

private var peerAvatars:Atomic<[PeerId: PeerPhotos]> = Atomic(value: [:])


func syncPeerPhotos(peerId: PeerId) -> [TelegramPeerPhoto] {
    return peerAvatars.with { $0[peerId].map { $0.photos } ?? [] }
}

func peerPhotos(context: AccountContext, peerId: PeerId, force: Bool = false) -> Signal<[TelegramPeerPhoto], NoError> {
    let photos = peerAvatars.with { $0[peerId] }
    if let photos = photos, photos.time > Date().timeIntervalSince1970, !force {
        return .single(photos.photos)
    } else {
        if !force {
            return context.account.postbox.peerView(id: peerId) |> map { peerView in
                if let photo = peerView.cachedData?.photo, !force {
                    let photo = TelegramPeerPhoto(image: photo, reference: nil, date: 0, index: 0, totalCount: 0, messageId: nil)
                    return [photo]
                } else {
                    return []
                }
            }
        }
        return .single(peerAvatars.with { $0[peerId]?.photos } ?? []) |> then(combineLatest(context.engine.peers.requestPeerPhotos(peerId: peerId), context.account.postbox.peerView(id: peerId)) |> delay(0.4, queue: .concurrentDefaultQueue()) |> map { photos, peerView in
            return peerAvatars.modify { value in
                var value = value
                var photos = photos
                if let cachedData = peerView.cachedData as? CachedChannelData {
                    if let photo = cachedData.photo {
                        if photos.firstIndex(where: { $0.image.id == photo.id }) == nil {
                            photos.insert(TelegramPeerPhoto(image: photo, reference: nil, date: 0, index: 0, totalCount: photos.first?.totalCount ?? 0, messageId: nil), at: 0)
                        }
                    }
                }
                
                value[peerId] = PeerPhotos(photos: photos, time: Date().timeIntervalSince1970 + 5 * 60)
                return value
            }[peerId]?.photos ?? []
        })
    }
}


func peerPhotosGalleryEntries(context: AccountContext, peerId: PeerId, firstStableId: AnyHashable) -> Signal<(entries: [GalleryEntry], selected:Int), NoError> {
    return combineLatest(queue: prepareQueue, peerPhotos(context: context, peerId: peerId, force: true), context.account.postbox.loadedPeerWithId(peerId)) |> map { photos, peer in
        
        var entries: [GalleryEntry] = []
        
        
        var representations:[TelegramMediaImageRepresentation] = []//peer.profileImageRepresentations
        if let representation = peer.smallProfileImage {
            representations.append(representation)
        }
        if let representation = peer.largeProfileImage {
            representations.append(representation)
        }
        
        let videoRepresentations: [TelegramMediaImage.VideoRepresentation] = []
        
        
        var image:TelegramMediaImage? = nil
        var msg: Message? = nil
        if let base = firstStableId.base as? ChatHistoryEntryId, case let .message(message) = base {
            let action = message.effectiveMedia as! TelegramMediaAction
            switch action.action {
            case let .photoUpdated(updated):
                image = updated
                msg = message
            default:
                break
            }
        }
        
        if image == nil {
            image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 0), representations: representations, videoRepresentations: videoRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        }
        
        
        let firstEntry: GalleryEntry = .photo(index: 0, stableId: firstStableId, photo: image!, reference: nil, peer: peer, message: msg, date: 0)
        
        var foundIndex: Bool = peerId.namespace == Namespaces.Peer.CloudUser && !photos.isEmpty
        var currentIndex: Int = 0
        var foundMessage: Message? = nil
        var photosDate:[TimeInterval] = []
        for i in 0 ..< photos.count {
            let photo = photos[i]
            photosDate.append(TimeInterval(photo.date))
            if let base = firstStableId.base as? ChatHistoryEntryId, case let .message(message) = base {
                let action = message.effectiveMedia as! TelegramMediaAction
                switch action.action {
                case let .photoUpdated(updated):
                    if photo.image.id == updated?.id {
                        currentIndex = i
                        foundIndex = true
                        foundMessage = message
                    }
                default:
                    break
                }
            } else if i == 0 {
                foundIndex = true
                currentIndex = i
                
            }
        }
        for i in 0 ..< photos.count {
            if currentIndex == i && foundIndex {
                let image = TelegramMediaImage(imageId: photos[i].image.imageId, representations: image!.representations, videoRepresentations: photos[i].image.videoRepresentations, immediateThumbnailData: photos[i].image.immediateThumbnailData, reference: photos[i].image.reference, partialReference: photos[i].image.partialReference, flags: photos[i].image.flags)
                
                entries.append(.photo(index: photos[i].index, stableId: firstStableId, photo: image, reference: photos[i].reference, peer: peer, message: foundMessage, date: photosDate[i]))
            } else {
                entries.append(.photo(index: photos[i].index, stableId: photos[i].image.imageId, photo: photos[i].image, reference: photos[i].reference, peer: peer, message: nil, date: photosDate[i]))
            }
        }
        
        if !foundIndex && entries.isEmpty {
            entries.append(firstEntry)
        }
        
        return (entries: entries, selected: currentIndex)
        
    }
}
