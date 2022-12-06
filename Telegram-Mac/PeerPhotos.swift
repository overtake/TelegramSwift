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
    let photos: [TelegramPeerPhotoHolder]
    let time: TimeInterval
}

struct TelegramPeerPhotoHolder {
    let value: TelegramPeerPhoto
    let caption: String?
}

private var peerAvatars:Atomic<[PeerId: PeerPhotos]> = Atomic(value: [:])


func syncPeerPhotos(peerId: PeerId) -> [TelegramPeerPhotoHolder] {
    return peerAvatars.with { $0[peerId].map { $0.photos } ?? [] }
}

func peerPhotos(context: AccountContext, peerId: PeerId, force: Bool = false) -> Signal<[TelegramPeerPhotoHolder], NoError> {
    let photos = peerAvatars.with { $0[peerId] }
    if let photos = photos, photos.time > Date().timeIntervalSince1970, !force {
        return .single(photos.photos)
    } else {
        if !force {
            
            return getCachedDataView(peerId: peerId, postbox: context.account.postbox) |> take(1) |> map { cachedData in
                if let photo = cachedData?.photo, !force {
                    let photo = TelegramPeerPhoto(image: photo, reference: nil, date: 0, index: 0, totalCount: 0, messageId: nil)
                    return [.init(value: photo, caption: nil)]
                } else {
                    return []
                }
            }
        }
        return .single(peerAvatars.with { $0[peerId]?.photos } ?? []) |> then(combineLatest(context.engine.peers.requestPeerPhotos(peerId: peerId), getCachedDataView(peerId: peerId, postbox: context.account.postbox) |> take(1), getPeerView(peerId: peerId, postbox: context.account.postbox) |> take(1)) |> delay(0.4, queue: .concurrentDefaultQueue()) |> map { photos, cachedData, peer in
            return peerAvatars.modify { value in
                var value = value
                var photos:[TelegramPeerPhotoHolder] = photos.map {
                    return .init(value: $0, caption: nil)
                }
                if let cachedData = cachedData, let value = cachedData.photo {
                    if photos.firstIndex(where: { $0.value.image.id == value.id }) == nil {
                        photos.insert(.init(value: TelegramPeerPhoto(image: value, reference: nil, date: 0, index: 0, totalCount: photos.first?.value.totalCount ?? 0, messageId: nil), caption: nil), at: 0)
                    }
                }
                if let peer = peer as? TelegramUser {
                    if peer.photo.contains(where: { $0.isPersonal }) {
                        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: peer.photo, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: TelegramMediaImageFlags())
                        
                        photos.insert(.init(value: TelegramPeerPhoto(image: image, reference: nil, date: 0, index: 0, totalCount: photos.first?.value.totalCount ?? 0, messageId: nil), caption: strings().galleryContactPhotoByYou), at: 0)
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
        
        let isPersonal = image!.representations.contains(where: { $0.isPersonal })
        
        
        let firstEntry: GalleryEntry = .photo(index: 0, stableId: firstStableId, photo: image!, reference: nil, peer: peer, message: msg, date: 0, caption: isPersonal ? strings().galleryContactPhotoByYou : nil)
        
        var foundIndex: Bool = peerId.namespace == Namespaces.Peer.CloudUser && !photos.isEmpty
        var currentIndex: Int = 0
        var foundMessage: Message? = nil
        var photosDate:[TimeInterval] = []
        for i in 0 ..< photos.count {
            let photo = photos[i].value
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
            let photo = photos[i].value
            if currentIndex == i && foundIndex {
                let image = TelegramMediaImage(imageId: photo.image.imageId, representations: image!.representations, videoRepresentations: photo.image.videoRepresentations, immediateThumbnailData: photo.image.immediateThumbnailData, reference: photo.image.reference, partialReference: photo.image.partialReference, flags: photo.image.flags)
                
                entries.append(.photo(index: photo.index, stableId: firstStableId, photo: image, reference: photo.reference, peer: peer, message: foundMessage, date: photosDate[i], caption: photos[i].caption))
            } else {
                entries.append(.photo(index: photo.index, stableId: photo.image.imageId, photo: photo.image, reference: photo.reference, peer: peer, message: nil, date: photosDate[i], caption: photos[i].caption))
            }
        }
        
        if !foundIndex && entries.isEmpty {
            entries.append(firstEntry)
        }
        
        return (entries: entries, selected: currentIndex)
        
    }
}
