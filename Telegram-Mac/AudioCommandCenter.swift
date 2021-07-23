//
//  AudioCommandCenter.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18.06.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import MediaPlayer
import SwiftSignalKit
import TelegramCore

import Postbox
import TGUIKit


@available(macOS 10.12.2, *)
final class AudioCommandCenter : NSObject, APDelegate {
    
    
    let commandor: MPRemoteCommandCenter = MPRemoteCommandCenter.shared()
    let center: MPNowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private let disposable = MetaDisposable()
    private weak var controller: APController?
    private var cache:[MessageId : NSImage] = [:]
        
    init(_ controller: APController) {
        self.controller = controller
        super.init()
        controller.add(listener: self)

        
        commandor.pauseCommand.addTarget(handler: { [weak controller] event in
            _ = controller?.pause()
            return .success
        })
        commandor.playCommand.addTarget(handler: { [weak controller] event in
            _ = controller?.play()
            return .success
        })
        commandor.stopCommand.addTarget(handler: { [weak controller] event in
            controller?.stop()
            return .success
        })
        commandor.togglePlayPauseCommand.addTarget(handler: { [weak controller] event in
            controller?.playOrPause()
            return .success
        })
        commandor.nextTrackCommand.addTarget(handler: { [weak controller] event in
            controller?.next()
            return .success
        })
        commandor.previousTrackCommand.addTarget(handler: { [weak controller] event in
            controller?.prev()
            return .success
        })

        commandor.changePlaybackPositionCommand.addTarget(handler: { [weak controller] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                if let duration = controller?.currentSong?.duration {
                    controller?.set(trackProgress: Float(event.positionTime / TimeInterval(duration)))
                }
            }
            return .success
        })
    }

    
    deinit {
        commandor.pauseCommand.removeTarget(self)
        commandor.playCommand.removeTarget(self)
        commandor.stopCommand.removeTarget(self)
        commandor.togglePlayPauseCommand.removeTarget(self)
        commandor.nextTrackCommand.removeTarget(self)
        commandor.previousTrackCommand.removeTarget(self)
        commandor.changePlaybackPositionCommand.removeTarget(self)
        
        center.nowPlayingInfo = [:]
        center.playbackState = .stopped
    }
    
    private var song: APSongItem?
    private var status: APController.State.Status?
    private func update(_ controller: APController) {
        commandor.nextTrackCommand.isEnabled = controller.nextEnabled
        commandor.previousTrackCommand.isEnabled = controller.prevEnabled
       

        if let song = controller.currentSong, self.song?.entry != song.entry {
            
            self.song = song
            
            var info:[String : Any] = [:]
            
            info[MPMediaItemPropertyTitle] = song.performerName
            info[MPMediaItemPropertyArtist] = song.songName
            info[MPMediaItemPropertyPlaybackDuration] = song.duration
            if #available(macOS 10.13.2, *) {
                
                switch song.entry {
                case let .song(message):
                    let file = message.media.first as! TelegramMediaFile
                    let resource: TelegramMediaResource?
                    if file.previewRepresentations.isEmpty {
                        if !file.mimeType.contains("ogg") {
                            resource = ExternalMusicAlbumArtResource(title: file.musicText.0, performer: file.musicText.1, isThumbnail: true)
                        } else {
                            resource = nil
                        }
                    } else {
                        resource = file.previewRepresentations.first!.resource
                    }
                    
                    if let resource = resource {
                        let iconSize = NSMakeSize(50, 50)

                        let arguments = TransformImageArguments(corners: .init(), imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
                                                
                        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: message.id.toInt64()), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(iconSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        
                        
                        let signal = chatMessagePhotoThumbnail(account: controller.context.account, imageReference: .message(message: MessageReference(message), media: image)) |> deliverOnMainQueue
                        
                        if let image = cache[message.id] {
                            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: iconSize, requestHandler: { size in
                                return image
                            })
                        } else {
                            self.disposable.set(signal.start(next: { [weak self] data in
                                let image = data.execute(arguments, data.data)?.generateImage()
                                if let image = image {
                                    let image = NSImage(cgImage: image, size: iconSize)
                                    self?.center.nowPlayingInfo?[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: iconSize, requestHandler: { size in
                                        return image
                                    })
                                    self?.cache[message.id] = image
                                }
                            }))
                        }

                    } else {
                        disposable.set(nil)
                    }
                    
                default:
                    disposable.set(nil)
                }
                
            }
            center.nowPlayingInfo = info
        }
        

        if self.status != controller.state.status {
            self.status = controller.state.status
            switch controller.state.status {
            case .paused:
                center.playbackState = .paused
            case .playing:
                center.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = controller.currentTime
                center.playbackState = .playing
            case .stopped:
                center.playbackState = .stopped
            case .waiting:
                center.playbackState = .unknown
            }
        }

    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        update(controller)
    }
    
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        update(controller)
    }
    
    func songDidStartPlaying(song: APSongItem, for controller: APController, animated: Bool) {
        update(controller)
    }
    
    func songDidStopPlaying(song: APSongItem, for controller: APController, animated: Bool) {
        update(controller)
    }
    
    func playerDidChangedTimebase(song: APSongItem, for controller: APController, animated: Bool) {
        update(controller)
    }
    
    func audioDidCompleteQueue(for controller: APController, animated: Bool) {
        update(controller)
    }
    
}
