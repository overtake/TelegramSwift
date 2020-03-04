//
//  SenderController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 31/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import AVFoundation
import QuickLook

let diceSymbol: String = "🎲"


class MediaSenderContainer : Equatable {
    let path:String
    let caption:String
    let isFile:Bool
    public init(path:String, caption:String = "", isFile:Bool = false) {
        self.path = path
        self.caption = caption
        self.isFile = isFile
    }
    
    static func ==(lhs: MediaSenderContainer, rhs: MediaSenderContainer) -> Bool {
        return lhs.path == rhs.path && lhs.caption == rhs.caption && lhs.isFile == rhs.isFile
    }
}

class ArchiverSenderContainer : MediaSenderContainer {
    let files: [URL]
    public init(path:String, caption:String = "", isFile:Bool = true, files: [URL] = []) {
        self.files = files
        super.init(path: path, caption: caption, isFile: isFile)
    }
    
    static func ==(lhs: ArchiverSenderContainer, rhs: ArchiverSenderContainer) -> Bool {
        return lhs.path == rhs.path && lhs.caption == rhs.caption && lhs.isFile == rhs.isFile && lhs.files == rhs.files
    }
}


class VoiceSenderContainer : MediaSenderContainer {
    fileprivate let data:RecordedAudioData
    fileprivate let id:Int64?
    public init(data:RecordedAudioData, id: Int64?) {
        self.data = data
        self.id = id
        super.init(path: data.path)
        
    }
}

class VideoMessageSenderContainer : MediaSenderContainer {
    fileprivate let duration:Int
    fileprivate let size: CGSize
    fileprivate let id:Int64?
    public init(path:String, duration: Int, size: CGSize, id: Int64?) {
        self.duration = duration
        self.size = size
        self.id = id
        super.init(path: path, caption: "", isFile: false)
    }
}


class Sender: NSObject {
    
    private static func previewForFile(_ path: String, account: Account) -> [TelegramMediaImageRepresentation] {
        var preview:[TelegramMediaImageRepresentation] = []
        
//        if isDirectory(path) {
//            let image = NSWorkspace.shared.icon(forFile: path)
//            image.lockFocus()
//            let imageRep = NSBitmapImageRep(focusedViewRect: NSMakeRect(0, 0, image.size.width, image.size.height))
//            image.unlockFocus()
//            
//            let compressedData: Data? = imageRep?.representation(using: .jpeg, properties: [:])
//            if let compressedData = compressedData {
//                let resource = LocalFileMediaResource(fileId: arc4random64())
//                account.postbox.mediaBox.storeResourceData(resource.id, data: compressedData)
//                preview.append(TelegramMediaImageRepresentation(dimensions: image.size, resource: resource))
//            }
//            return preview
//        }
        
        
       
        
        if MIMEType(path).hasPrefix("video") {
            
           
            
            let options = NSMutableDictionary()
            options.setValue(320 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
            
            let colorQuality: Float = 0.8
            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
            
            let asset = AVAsset(url: URL(fileURLWithPath: path))
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.maximumSize = CGSize(width: 320, height: 320)
            imageGenerator.appliesPreferredTrackTransform = true
            let fullSizeImage = try? imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
            
            if let image = fullSizeImage {
                
                let mutableData: CFMutableData = NSMutableData() as CFMutableData
                if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, options) {
                    CGImageDestinationSetProperties(colorDestination, nil)
                    
                    CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        let resource = LocalFileMediaResource(fileId: arc4random64())
                        account.postbox.mediaBox.storeResourceData(resource.id, data: mutableData as Data)
                        preview.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: resource))
                    }
                }
                
                
            }
            
           
        } else if MIMEType(path).hasPrefix("image"), let thumbData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            
            let options = NSMutableDictionary()
            options.setValue(320 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
            
            let colorQuality: Float = 0.7
            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
            
            let sourceOptions = NSMutableDictionary()
            sourceOptions.setValue(320 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
            sourceOptions.setObject(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as NSString)
            
            if let imageSource = CGImageSourceCreateWithData(thumbData as CFData, sourceOptions) {
                let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, sourceOptions)
                if let image = image {
                    
                   let mutableData: CFMutableData = NSMutableData() as CFMutableData
                    
                    if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, options) {
                        CGImageDestinationSetProperties(colorDestination, nil)
                        CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            let resource = LocalFileMediaResource(fileId: arc4random64())
                            account.postbox.mediaBox.storeResourceData(resource.id, data: mutableData as Data)
                            preview.append(TelegramMediaImageRepresentation(dimensions: image.size.pixel, resource: resource))
                        }
                    }
                }
                
            }
        }
        return preview
    }

    public static func enqueue( input:ChatTextInputState, context: AccountContext, peerId:PeerId, replyId:MessageId?, disablePreview:Bool = false, silent: Bool = false, atDate:Date? = nil) ->Signal<[MessageId?],NoError> {
        
        var inset:Int = 0
        
        var input:ChatTextInputState = input
        
        let emojis = Array(input.inputText.fixed.emojiString).map { String($0) }.compactMap {!$0.isEmpty ? $0 : nil}
        if input.attributes.isEmpty {
            input = ChatTextInputState(inputText: input.inputText.trimmed)
        }
        
        
        var mediaReference: AnyMediaReference? = nil
        if input.inputText == diceSymbol {
            mediaReference = AnyMediaReference.standalone(media: TelegramMediaDice(value: nil))
            input = ChatTextInputState(inputText: "")
        }
        
        let mapped = cut_long_message( input.inputText, 4096).map { message -> EnqueueMessage in
            let subState = input.subInputState(from: NSMakeRange(inset, message.length))
            inset += message.length
            

            var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: subState.messageTextEntities)]
            if let date = atDate {
                attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
            }
            if disablePreview {
                attributes.append(OutgoingContentInfoMessageAttribute(flags: [.disableLinkPreviews]))
            }
            if FastSettings.isChannelMessagesMuted(peerId) || silent {
                attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
            }
            return EnqueueMessage.message(text: subState.inputText, attributes: attributes, mediaReference: mediaReference, replyToMessageId: replyId, localGroupingKey: nil)
        }
        
        return enqueueMessages(context: context, peerId: peerId, messages: mapped) |> mapToSignal { value in
            if !emojis.isEmpty {
                return saveUsedEmoji(emojis, postbox: context.account.postbox) |> map {
                    return value
                }
            }
            return .single(value)
        } |> deliverOnMainQueue
        
    }
    
    public static func enqueue(message:EnqueueMessage, context: AccountContext, peerId:PeerId) ->Signal<[MessageId?],NoError> {
        return  enqueueMessages(context: context, peerId: peerId, messages: [message])
            |> deliverOnMainQueue
    }
    
    static func generateMedia(for container:MediaSenderContainer, account: Account) -> Signal<(Media,String), NoError> {
        return Signal { (subscriber) in
            
            let path = container.path
            var media:Media!
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            
            func makeFileMedia(_ isMedia: Bool) {
                let mimeType = MIMEType(path)
                let attrs:[TelegramMediaFileAttribute] = fileAttributes(for:mimeType, path:path, isMedia: isMedia)
                let resource: TelegramMediaResource = path.isDirectory ? LocalFileArchiveMediaResource(randomId: randomId, path: path) : LocalFileReferenceMediaResource(localFilePath:path,randomId:randomId, size: fs(path))
                media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewForFile(path, account: account), immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: attrs)
            }
            
            if !container.isFile {
                let mimeType = MIMEType(path)
                if let container = container as? VoiceSenderContainer {
                    let mimeType = voiceMime
                    var attrs:[TelegramMediaFileAttribute] = []
                    var memoryWaveform:MemoryBuffer?
                    if let waveformData = container.data.waveform {
                        memoryWaveform = MemoryBuffer(data: waveformData)
                    }
                    
                    let resource: TelegramMediaResource
                    if let id = container.id, let data = try? Data.init(contentsOf: URL(fileURLWithPath: path)) {
                        resource = LocalFileMediaResource(fileId: id, size: fileSize(path))
                        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    } else {
                        resource = LocalFileReferenceMediaResource(localFilePath:path, randomId: randomId, isUniquelyReferencedTemporaryFile: true, size: fs(path))
                    }
                    
                    attrs.append(.Audio(isVoice: true, duration: Int(container.data.duration), title: nil, performer: nil, waveform: memoryWaveform))
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: attrs)
                } else if let container = container as? VideoMessageSenderContainer {
                    var attrs:[TelegramMediaFileAttribute] = []
                    
                    let resource: TelegramMediaResource
                    if let id = container.id, let data = try? Data.init(contentsOf: URL(fileURLWithPath: path)) {
                        resource = LocalFileMediaResource(fileId: id, size: fileSize(path))
                        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    } else {
                        resource = LocalFileReferenceMediaResource(localFilePath:path, randomId: randomId, isUniquelyReferencedTemporaryFile: true, size: fs(path))
                    }
                    
                    
                    attrs.append(TelegramMediaFileAttribute.Video(duration: Int(container.duration), size: PixelDimensions(container.size), flags: [.instantRoundVideo]))
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewForFile(path, account: account), immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: attrs)

                } else if mimeType.hasPrefix("image/") && !mimeType.hasSuffix("gif"), let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                   
                    let options = NSMutableDictionary()
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)
                    options.setValue(1280 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)

                    
                    if let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) {
                        
                        let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
                        
                        if let image = image {
                           
                            let size = image.size
                            
                            if size.width / 10 > size.height || size.height < 40 {
                                makeFileMedia(true)
                            } else {
                                let data = NSImage(cgImage: image, size: image.size).tiffRepresentation(using: .jpeg, factor: 0.83)
                                let path = NSTemporaryDirectory() + "tg_image_\(arc4random()).jpeg"
                                
                                if let data = data {
                                    let imageRep = NSBitmapImageRep(data: data)
                                    try? imageRep?.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:])?.write(to: URL(fileURLWithPath: path))
                                }
                                
                                let scaledSize = size.fitted(CGSize(width: 1280.0, height: 1280.0))
                                let resource = LocalFileReferenceMediaResource(localFilePath:path,randomId:randomId, isUniquelyReferencedTemporaryFile: true)
                                
                                media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledSize), resource: resource)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            }
                            
                        } else {
                            makeFileMedia(true)
                        }
                    } else {
                       makeFileMedia(true)
                    }
                    
                    
                } else if mimeType.hasPrefix("video") {
                    let attrs:[TelegramMediaFileAttribute] = fileAttributes(for:mimeType, path:path, isMedia: true)
                    
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: LocalFileVideoMediaResource(randomId: randomId, path: container.path), previewRepresentations: previewForFile(path, account: account), immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: attrs)
                } else if mimeType.hasPrefix("image/gif") {
                    let attrs:[TelegramMediaFileAttribute] = fileAttributes(for:mimeType, path:path, isMedia: true)
                    
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: LocalFileGifMediaResource(randomId: randomId, path: container.path), previewRepresentations: previewForFile(path, account: account), immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: attrs)
                } else {
                    makeFileMedia(true)
                }
            } else {
                makeFileMedia(false)
            }
            
            
            
            subscriber.putNext((media,container.caption))
            subscriber.putCompletion()
            
            return EmptyDisposable
            
        } |> runOn(resourcesQueue)
    }
    
    public static func fileAttributes(for mime:String, path:String, isMedia:Bool = false) -> [TelegramMediaFileAttribute] {
        var attrs:[TelegramMediaFileAttribute] = []
        
        if mime.hasPrefix("audio/") {
            //AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let tags = audioTags(asset)
            let parts = path.nsstring.lastPathComponent.components(separatedBy: "-")
            let defaultTitle:String
            let defaultPerformer:String
            if let title = tags["title"], let performer = tags["performer"] {
                defaultTitle = title
                defaultPerformer = performer
            } else if parts.count == 2 {
                defaultTitle = parts[0]
                defaultPerformer = parts[1]
            } else {
                defaultTitle = "Untitled"
                defaultPerformer = "Unknown Artist"
            }
            attrs.append(.Audio(isVoice: false, duration: Int(CMTimeGetSeconds(asset.duration)), title: defaultTitle, performer: defaultPerformer, waveform: nil))
        }
        if mime.hasPrefix("video"), isMedia {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let video = asset.tracks(withMediaType: AVMediaType.video).first
            let audio = asset.tracks(withMediaType: AVMediaType.audio).first
            if let video = video {
                attrs.append(TelegramMediaFileAttribute.Video(duration: Int(CMTimeGetSeconds(asset.duration)), size: PixelDimensions(video.naturalSize), flags: []))
                attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent.nsstring.deletingPathExtension.appending(".mp4")))
                if audio == nil, let size = fileSize(path), size < Int32(10 * 1024 * 1024) {
                    attrs.append(TelegramMediaFileAttribute.Animated)
                }
                return attrs
            }
        }
        
        if mime.hasSuffix("gif"), isMedia {
            attrs.append(TelegramMediaFileAttribute.Video(duration: 0, size:TGGifConverter.gifDimensionSize(path).pixel, flags: []))
            attrs.append(TelegramMediaFileAttribute.Animated)
            attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent.nsstring.deletingPathExtension.appending(".mp4")))

        } else if mime.hasPrefix("image"), let image = NSImage(contentsOf: URL(fileURLWithPath: path)) {
            attrs.append(TelegramMediaFileAttribute.ImageSize(size: image.size.pixel))
            attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent))
        } else {
            let getname:(String)->String = { path in
                var result: String = path.nsstring.lastPathComponent
                if result.contains("tg_temp_archive_") {
                    result = "Telegram Archive"
                }
                if path.isDirectory {
                    result += ".zip"
                }
                return result
            }
            attrs.append(TelegramMediaFileAttribute.FileName(fileName: getname(path)))
        }
        return attrs
    }
    
    public static func forwardMessages(messageIds:[MessageId], context: AccountContext, peerId:PeerId, silent: Bool = false, atDate: Date? = nil) -> Signal<[MessageId?], NoError> {
        
        var fwdMessages:[EnqueueMessage] = []
        
        let sorted = messageIds.sorted(by: >)
        
        var attributes: [MessageAttribute] = []        
        if FastSettings.isChannelMessagesMuted(peerId) || silent {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        
        if let date = atDate {
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
        }
        
        for msgId in sorted {
            fwdMessages.append(EnqueueMessage.forward(source: msgId, grouping: messageIds.count > 1 ? .auto : .none, attributes: attributes))
        }
        return enqueueMessages(context: context, peerId: peerId, messages: fwdMessages.reversed())
    }
    
    public static func shareContact(context: AccountContext, peerId:PeerId, contact:TelegramUser) -> Signal<[MessageId?], NoError>  {
        
        var attributes:[MessageAttribute] = []
        if FastSettings.isChannelMessagesMuted(peerId) {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        
        return enqueueMessages(context: context, peerId: peerId, messages: [EnqueueMessage.message(text: "", attributes: attributes, mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumber: contact.phone ?? "", peerId: contact.id, vCardData: nil)), replyToMessageId: nil, localGroupingKey: nil)])
    }
    
    public static func enqueue(media:[MediaSenderContainer], context: AccountContext, peerId:PeerId, chatInteraction:ChatInteraction, silent: Bool = false, atDate:Date? = nil) ->Signal<[MessageId?], NoError> {
        var senders:[Signal<[MessageId?], NoError>] = []
        
        
        var attributes:[MessageAttribute] = []
        if FastSettings.isChannelMessagesMuted(peerId) || silent {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if let date = atDate {
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
        }
        
        for path in media {
            senders.append(generateMedia(for: path, account: context.account) |> mapToSignal { media, caption -> Signal< [MessageId?], NoError> in
                return enqueueMessages(context: context, peerId: peerId, messages: [EnqueueMessage.message(text: caption, attributes:attributes, mediaReference: AnyMediaReference.standalone(media: media), replyToMessageId: chatInteraction.presentation.interfaceState.replyMessageId, localGroupingKey: nil)])
            })
        }
        
        return combineLatest(senders) |> deliverOnMainQueue |> mapToSignal { results -> Signal<[MessageId?], NoError> in
            
            let result = results.reduce([], { messageIds, current -> [MessageId?] in
                return messageIds + current
            })
            
            return .single(result)
            
        }  |> take(1) |> afterCompleted {
            chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil)})})
        }
    }
    
    public static func enqueue(media:Media, context: AccountContext, peerId:PeerId, chatInteraction:ChatInteraction, silent: Bool = false, atDate: Date? = nil) ->Signal<[MessageId?],NoError> {
        return enqueue(media: [media], caption: ChatTextInputState(), context: context, peerId: peerId, chatInteraction: chatInteraction, silent: silent, atDate: atDate)
    }
    
    public static func enqueue(media:[Media], caption: ChatTextInputState, context: AccountContext, peerId:PeerId, chatInteraction:ChatInteraction, isCollage: Bool = false, additionText: ChatTextInputState? = nil, silent: Bool = false, atDate: Date? = nil) ->Signal<[MessageId?],NoError> {
                
        var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: caption.messageTextEntities)]
        let caption = Atomic(value: caption)
        if FastSettings.isChannelMessagesMuted(peerId) || silent {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if let date = atDate {
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
        }
        
        let replyId = chatInteraction.presentation.interfaceState.replyMessageId
        
        let localGroupingKey = isCollage ? arc4random64() : nil
        
        var messages = media.map({EnqueueMessage.message(text: caption.swap(ChatTextInputState()).inputText, attributes: attributes, mediaReference: AnyMediaReference.standalone(media: $0), replyToMessageId: replyId, localGroupingKey: localGroupingKey)})
        if let input = additionText {
            var inset:Int = 0
            var input:ChatTextInputState = input
            
            if input.attributes.isEmpty {
                input = ChatTextInputState(inputText: input.inputText.trimmed)
            }
            let mapped = cut_long_message( input.inputText, 4096).map { message -> EnqueueMessage in
                let subState = input.subInputState(from: NSMakeRange(inset, message.length))
                inset += message.length
                
                var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: subState.messageTextEntities)]
                
                if FastSettings.isChannelMessagesMuted(peerId) || silent {
                    attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
                }
                if let date = atDate {
                    attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
                }
                
                return EnqueueMessage.message(text: subState.inputText, attributes: attributes, mediaReference: nil, replyToMessageId: replyId, localGroupingKey: nil)
            }
            messages.insert(contentsOf: mapped, at: 0)
        }
        return enqueueMessages(context: context, peerId: peerId, messages: messages) |> deliverOnMainQueue |> afterNext { _ -> Void in
            chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil)})})
        } |> take(1)
    }
    
    
}
