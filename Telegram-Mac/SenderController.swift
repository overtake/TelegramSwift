//
//  SenderController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 31/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import ObjcUtils
import Postbox
import SwiftSignalKit
import AVFoundation
import QuickLook
import TGUIKit
import libwebp
import TGGifConverter
import InAppSettings
import TelegramMedia

class MediaSenderContainer : Equatable {
    let path:String
    let caption:String
    let isFile:Bool
    let isOneTime: Bool
    public init(path:String, caption:String = "", isFile:Bool = false, isOneTime: Bool = false) {
        self.path = path
        self.caption = caption
        self.isFile = isFile
        self.isOneTime = isOneTime
    }
    
    static func ==(lhs: MediaSenderContainer, rhs: MediaSenderContainer) -> Bool {
        return lhs.path == rhs.path && lhs.caption == rhs.caption && lhs.isFile == rhs.isFile && lhs.isOneTime == rhs.isOneTime
    }
}

class ArchiverSenderContainer : MediaSenderContainer {
    let files: [URL]
    public init(path:String, caption:String = "", isFile:Bool = true, files: [URL] = []) {
        self.files = files
        super.init(path: path, caption: caption, isFile: isFile, isOneTime: false)
    }
    
    static func ==(lhs: ArchiverSenderContainer, rhs: ArchiverSenderContainer) -> Bool {
        return lhs.path == rhs.path && lhs.caption == rhs.caption && lhs.isFile == rhs.isFile && lhs.files == rhs.files
    }
}


class VoiceSenderContainer : MediaSenderContainer {
    fileprivate let data:RecordedAudioData
    fileprivate let id:Int64?
    public init(data:RecordedAudioData, id: Int64?, isOneTime: Bool) {
        self.data = data
        self.id = id
        let path: String = data.path
        super.init(path: path, isOneTime: isOneTime)
        
    }
}

class VideoMessageSenderContainer : MediaSenderContainer {
    fileprivate let duration:Int
    fileprivate let size: CGSize
    fileprivate let id:Int64?
    public init(path:String, duration: Int, size: CGSize, id: Int64?, isOneTime: Bool) {
        self.duration = duration
        self.size = size
        self.id = id
        super.init(path: path, caption: "", isFile: false, isOneTime: isOneTime)
    }
}


class Sender: NSObject {
    
    private static func previewForFile(_ path: String, isSecretRelated: Bool, account: Account, colorQuality: Float? = nil) -> [TelegramMediaImageRepresentation] {
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
        
        let mimeType = MIMEType(path)
       
        
        if mimeType.hasPrefix("video") {
            
           
            
            let options = NSMutableDictionary()
            options.setValue(320 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)

            let colorQuality: Float = 0.3
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
                        let resource = LocalFileMediaResource(fileId: arc4random64(), isSecretRelated: isSecretRelated)
                        account.postbox.mediaBox.storeResourceData(resource.id, data: mutableData as Data)
                        preview.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                    }
                }
            }
        } else if (mimeType.hasPrefix("image") || mimeType.hasSuffix("pdf") && !mimeType.hasPrefix("image/webp")), let thumbData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            
            let options = NSMutableDictionary()
            options.setValue((colorQuality != nil ? 320 * 2 : 320) as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
            
            let colorQuality: Float = colorQuality ?? 0.7
            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)

            let sourceOptions = NSMutableDictionary()
            sourceOptions.setValue(320 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
            sourceOptions.setObject(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as NSString)
            sourceOptions.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)
            
            if let imageSource = CGImageSourceCreateWithData(thumbData as CFData, sourceOptions) {
                let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, sourceOptions)
                if let image = image {
                    
                   let mutableData: CFMutableData = NSMutableData() as CFMutableData
                    
                    if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, options) {
                        CGImageDestinationSetProperties(colorDestination, nil)
                        CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            let resource = LocalFileMediaResource(fileId: arc4random64(), isSecretRelated: isSecretRelated)
                            account.postbox.mediaBox.storeResourceData(resource.id, data: mutableData as Data)
                            preview.append(TelegramMediaImageRepresentation(dimensions: image.size.pixel, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                        }
                    }
                }
                
            }
        }
        return preview
    }

    public static func enqueue(input:ChatTextInputState, context: AccountContext, peerId:PeerId, replyId:EngineMessageReplySubject?, threadId: Int64?, replyStoryId: StoryId? = nil, disablePreview:Bool = false, linkBelowMessage: Bool = false, largeMedia: Bool? = nil, silent: Bool = false, atDate:Date? = nil, sendAsPeerId: PeerId? = nil, mediaPreview: TelegramMediaWebpage? = nil, emptyHandler:(()->Void)? = nil, customChatContents: ChatCustomContentsProtocol? = nil, messageEffect: AvailableMessageEffects.MessageEffect? = nil, sendPaidMessageStars: StarsAmount? = nil, suggestPost: ChatInterfaceState.ChannelSuggestPost? = nil) -> Signal<[MessageId?],NoError> {
        
        var inset:Int = 0
        let dynamicEmojiOrder = context.stickerSettings.dynamicPackOrder
        
        var input:ChatTextInputState = input
        
        let emojis = Array(input.inputText.fixed.emojiString).map { String($0) }.compactMap {!$0.isEmpty ? $0 : nil}
        if input.attributes.isEmpty {
            input = ChatTextInputState(inputText: input.inputText.trimmed)
        }
        
        
        if FastSettings.isPossibleReplaceEmojies {
            let text = input.attributedString().stringEmojiReplacements
            if text != input.attributedString() {
                input = ChatTextInputState(inputText: text.string, selectionRange: 0 ..< text.string.length, attributes: chatTextAttributes(from: text))
            }
        }
        
        var mediaReference: AnyMediaReference? = nil
        
        
        let dices = InteractiveEmojiConfiguration.with(appConfiguration: context.appConfiguration)
        if dices.emojis.contains(input.inputText), peerId.namespace != Namespaces.Peer.SecretChat {
            mediaReference = AnyMediaReference.standalone(media: TelegramMediaDice(emoji: input.inputText, value: nil))
            input = ChatTextInputState(inputText: "")
        }
        
        if let media = mediaPreview, !disablePreview {
            mediaReference = AnyMediaReference.standalone(media: media)
        }
        
        
        
        
        let parsingUrlType: ParsingType
        if peerId.namespace != Namespaces.Peer.SecretChat {
            parsingUrlType = [.Hashtags]
        } else {
            parsingUrlType = [.Links, .Hashtags]
        }

        let mapped = cut_long_message( input.inputText, 4096).compactMap { message -> EnqueueMessage? in
            let subState = input.subInputState(from: NSMakeRange(inset, message.length))
            inset += message.length
            

            var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: subState.messageTextEntities(parsingUrlType))]
            if let date = atDate {
                attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
            }
            if let attr = suggestPost?.attribute {
                attributes.append(attr)
            }
            if disablePreview {
                attributes.append(OutgoingContentInfoMessageAttribute(flags: [.disableLinkPreviews]))
            }
            if FastSettings.isChannelMessagesMuted(peerId) || silent {
                attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
            }
            if let sendAsPeerId = sendAsPeerId {
                attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
            }
            if let messageEffect {
                attributes.append(EffectMessageAttribute(id: messageEffect.id))
            }
            if let sendPaidMessageStars {
                attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
            }
            attributes.append(WebpagePreviewMessageAttribute(leadingPreview: !linkBelowMessage, forceLargeMedia: largeMedia, isManuallyAdded: false, isSafe: true))

            
           
            if !subState.inputText.isEmpty || mediaReference != nil {
                return .message(text: subState.inputText, attributes: attributes, inlineStickers: subState.inlineMedia, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyId, replyToStoryId: replyStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: dynamicEmojiOrder ? subState.upstairCollections : [])
            } else {
                return nil
            }
        }
        
        if let customChatContents = customChatContents {
            return customChatContents.enqueueMessages(messages: mapped)
        } else {
            
            if !mapped.isEmpty {
                let inlineMedia = input.inlineMedia.map { $0.key }
                return enqueueMessages(account: context.account, peerId: peerId, messages: mapped) |> mapToSignal { value in
                    if !emojis.isEmpty {
                        let es = saveUsedEmoji(emojis, postbox: context.account.postbox)
                        let aes = saveAnimatedUsedEmoji(inlineMedia, postbox: context.account.postbox)
                        return combineLatest(es, aes) |> map { _ in
                            return value
                        }
                    }
                    return .single(value)
                } |> deliverOnMainQueue
            } else {
                DispatchQueue.main.async {
                    emptyHandler?()
                }
                return .complete()
            }
        }
        
    }
    
    public static func enqueue(message:EnqueueMessage, context: AccountContext, peerId:PeerId) ->Signal<[MessageId?],NoError> {
        return  enqueueMessages(account: context.account, peerId: peerId, messages: [message])
            |> deliverOnMainQueue
    }
    
    static func generateMedia(for container:MediaSenderContainer, account: Account, isSecretRelated: Bool, isCollage: Bool = false, isUniquelyReferencedTemporaryFile: Bool = true, customPreview: String? = nil) -> Signal<(Media,String), NoError> {
        return Signal { (subscriber) in
            
            let path = container.path
            var media:Media!
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            
            func makeFileMedia(_ isMedia: Bool) {
                let mimeType = MIMEType(path)
                let attrs:[TelegramMediaFileAttribute] = fileAttributes(for:mimeType, path:path, isMedia: isMedia)
                let resource: TelegramMediaResource = path.isDirectory ? LocalFileArchiveMediaResource(randomId: randomId, path: path) : LocalFileReferenceMediaResource(localFilePath:path,randomId:randomId, size: fileSize(path))
                media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewForFile(path, isSecretRelated: isSecretRelated, account: account), videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: attrs, alternativeRepresentations: [])
            }
            
            if !container.isFile {
                let mimeType = MIMEType(path)
                if let container = container as? VoiceSenderContainer {
                    let mimeType = voiceMime
                    var attrs:[TelegramMediaFileAttribute] = []
                    let memoryWaveform:Data? = container.data.waveform
                    
                    let resource: TelegramMediaResource
                    if let id = container.id, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        resource = LocalFileMediaResource(fileId: id, size: fileSize(path), isSecretRelated: isSecretRelated)
                        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    } else {
                        resource = LocalFileReferenceMediaResource(localFilePath:path, randomId: randomId, isUniquelyReferencedTemporaryFile: isUniquelyReferencedTemporaryFile, size: fileSize(path))
                    }
                    
                    attrs.append(.Audio(isVoice: true, duration: Int(container.data.duration), title: nil, performer: nil, waveform: memoryWaveform))
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: attrs, alternativeRepresentations: [])
                } else if let container = container as? VideoMessageSenderContainer {
                    var attrs:[TelegramMediaFileAttribute] = []
                    
                    let resource: TelegramMediaResource
                    if let id = container.id, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        resource = LocalFileMediaResource(fileId: id, size: fileSize(path), isSecretRelated: isSecretRelated)
                        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    } else {
                        resource = LocalFileReferenceMediaResource(localFilePath:path, randomId: randomId, isUniquelyReferencedTemporaryFile: isUniquelyReferencedTemporaryFile, size: fileSize(path))
                    }
                    
                    
                    attrs.append(TelegramMediaFileAttribute.Video(duration: Double(container.duration), size: PixelDimensions(container.size), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil))
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewForFile(path, isSecretRelated: isSecretRelated, account: account), videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: attrs, alternativeRepresentations: [])

                } else if mimeType.hasPrefix("image/webp") {
                    let resource = LocalFileReferenceMediaResource(localFilePath:path, randomId: randomId, isUniquelyReferencedTemporaryFile: false, size: fileSize(path))
                    
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewForFile(path, isSecretRelated: isSecretRelated, account: account), videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: fileAttributes(for: mimeType, path: path, isMedia: true), alternativeRepresentations: [])
                } else if mimeType.hasPrefix("image/") && !mimeType.hasSuffix("gif"), let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    
                    let dimension: CGFloat = FastSettings.photoDimension
                   
                    let options = NSMutableDictionary()
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)
                    options.setValue(dimension as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)

                    
                    if let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) {
                        
                        let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
                        
                        if let image = image {
                           
                            let size = image.size
                            
                            if size.width / 10 > size.height || size.height < 40 {
                                makeFileMedia(true)
                            } else {
                                let data = compressImageToJPEG(image, quality: 0.75)
                                let path = NSTemporaryDirectory() + "tg_image_\(arc4random()).jpeg"
                                FileManager.default.createFile(atPath: path, contents: data)

                                
                                let scaledSize = size.fitted(CGSize(width: dimension, height: dimension))
                                let resource = LocalFileReferenceMediaResource(localFilePath:path,randomId:randomId, isUniquelyReferencedTemporaryFile: isUniquelyReferencedTemporaryFile)
                                
                                media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            }
                            
                        } else {
                            makeFileMedia(true)
                        }
                    } else {
                       makeFileMedia(true)
                    }
                    
                    
                } else if mimeType.hasPrefix("video") {
                    let attrs:[TelegramMediaFileAttribute] = fileAttributes(for:mimeType, path:path, isMedia: true, inCollage: isCollage)
                    
                    let videoCover: TelegramMediaImage?
                    if let customPreview {
                        let representations = previewForFile(customPreview, isSecretRelated: isSecretRelated, account: account, colorQuality: 1.0)
                        videoCover = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    } else {
                        videoCover = nil
                    }
                    
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: LocalFileVideoMediaResource(randomId: randomId, path: container.path), previewRepresentations: previewForFile(path, isSecretRelated: isSecretRelated, account: account), videoThumbnails: [], videoCover: videoCover, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: attrs, alternativeRepresentations: [])
                } else if mimeType.hasPrefix("image/gif") {
                    let attrs:[TelegramMediaFileAttribute] = fileAttributes(for:mimeType, path:path, isMedia: true, inCollage: isCollage)
                    
                    media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: LocalFileGifMediaResource(randomId: randomId, path: container.path), previewRepresentations: previewForFile(path, isSecretRelated: isSecretRelated, account: account), videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: attrs, alternativeRepresentations: [])
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
    
    public static func fileAttributes(for mime:String, path:String, isMedia:Bool = false, inCollage: Bool = false) -> [TelegramMediaFileAttribute] {
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
                var size = video.naturalSize.applying(video.preferredTransform)
                size = NSMakeSize(floor(abs(size.width)), floor(abs(size.height)))
                attrs.append(TelegramMediaFileAttribute.Video(duration: Double(CMTimeGetSeconds(asset.duration)), size: PixelDimensions(size), flags: [.supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil))
                attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent.nsstring.deletingPathExtension.appending(".mp4")))
                if !inCollage {
                    if audio == nil, let size = fileSize(path), size < Int32(10 * 1024 * 1024), mime.hasSuffix("mp4") {
                        attrs.append(TelegramMediaFileAttribute.Animated)
                    }
                }
                
                if !mime.hasSuffix("mp4") {
                    attrs.append(.hintFileIsLarge)
                }
                return attrs
            }
        }
        
        if mime.hasSuffix("gif"), isMedia {
            attrs.append(TelegramMediaFileAttribute.Video(duration: 0, size:TGGifConverter.gifDimensionSize(path).pixel, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil))
            if !inCollage {
                attrs.append(TelegramMediaFileAttribute.Animated)
            }
            attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent.nsstring.deletingPathExtension.appending(".mp4")))

        } else if mime.hasPrefix("image"), let image = NSImage(contentsOf: URL(fileURLWithPath: path)), !mime.hasPrefix("image/webp") {
            var size = image.size
            if size.width == .infinity || size.height == .infinity {
                size = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!.size
            }
            attrs.append(TelegramMediaFileAttribute.ImageSize(size: size.pixel))
            attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent))
            
            if mime.hasPrefix("image/webp") {
                attrs.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
            }
        } else if mime.hasPrefix("image/webp") {
            var size: NSSize = NSMakeSize(512, 512)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                size = convertFromWebP(data)?.size ?? size
            }
            
            attrs.append(TelegramMediaFileAttribute.ImageSize(size: size.pixel))
            attrs.append(TelegramMediaFileAttribute.FileName(fileName: path.nsstring.lastPathComponent))
            attrs.append(.Sticker(displayText: "", packReference: nil, maskData: nil))

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
    
    public static func forwardMessages(messageIds:[MessageId], context: AccountContext, peerId:PeerId, replyId: EngineMessageReplySubject?, threadId: Int64?, hideNames: Bool = false, hideCaptions: Bool = false, silent: Bool = false, atDate: Date? = nil, sendAsPeerId: PeerId? = nil, sendPaidMessageStars: StarsAmount? = nil) -> Signal<[MessageId?], NoError> {
        
        var fwdMessages:[EnqueueMessage] = []
        
        let sorted = messageIds.sorted(by: >)
        
        var attributes: [MessageAttribute] = []        
        if FastSettings.isChannelMessagesMuted(peerId) || silent {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if hideNames || hideCaptions {
            attributes.append(ForwardOptionsMessageAttribute(hideNames: hideNames || hideCaptions, hideCaptions: hideCaptions))
        }
        
        if let sendPaidMessageStars {
            attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
        }
        
        if let date = atDate {
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
        }
        if let sendAsPeerId = sendAsPeerId {
            attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
        }
        
        var threadId: Int64? = threadId

        for msgId in sorted {
            fwdMessages.append(EnqueueMessage.forward(source: msgId, threadId: threadId, grouping: messageIds.count > 1 ? .auto : .none, attributes: attributes, correlationId: nil))
        }
        return enqueueMessages(account: context.account, peerId: peerId, messages: fwdMessages.reversed())
    }
    
    public static func shareContact(context: AccountContext, peerId:PeerId, media:Media, replyId: EngineMessageReplySubject?, threadId: Int64?, sendAsPeerId: PeerId? = nil, sendPaidMessageStars: StarsAmount? = nil) -> Signal<[MessageId?], NoError>  {
        
        var attributes:[MessageAttribute] = []
        if FastSettings.isChannelMessagesMuted(peerId) {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if let sendAsPeerId = sendAsPeerId {
            attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
        }
        
        return enqueueMessages(account: context.account, peerId: peerId, messages: [EnqueueMessage.message(text: "", attributes: attributes, inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: media), threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
    }
    
    public static func enqueue(media:[MediaSenderContainer], context: AccountContext, peerId:PeerId, replyId: EngineMessageReplySubject?, threadId: Int64?, replyStoryId: StoryId? = nil, silent: Bool = false, atDate:Date? = nil, sendAsPeerId:PeerId? = nil, query: String? = nil, isSpoiler: Bool = false, customChatContents: ChatCustomContentsProtocol? = nil, messageEffect: AvailableMessageEffects.MessageEffect? = nil, leadingText: Bool = false, sendPaidMessageStars: StarsAmount? = nil) ->Signal<[MessageId?], NoError> {
        var senders:[Signal<[MessageId?], NoError>] = []
        
        
       
        
        for path in media {
            
            var attributes:[MessageAttribute] = []
            if FastSettings.isChannelMessagesMuted(peerId) || silent {
                attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
            }
            if let date = atDate {
                attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
            }
            if let sendAsPeerId = sendAsPeerId {
                attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
            }
            if let query = query, !query.isEmpty {
                attributes.append(EmojiSearchQueryMessageAttribute(query: query))
            }
            
            if let sendPaidMessageStars {
                attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
            }
            
            if isSpoiler {
                attributes.append(MediaSpoilerMessageAttribute())
            }
            
            if leadingText {
                attributes.append(InvertMediaMessageAttribute())
            }

            
            if path.isOneTime {
                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: viewOnceTimeout, countdownBeginTime: 0))
            }
            
            if let messageEffect {
                attributes.append(EffectMessageAttribute(id: messageEffect.id))
            }
            
            senders.append(generateMedia(for: path, account: context.account, isSecretRelated: peerId.namespace == Namespaces.Peer.SecretChat) |> mapToSignal { media, caption -> Signal< [MessageId?], NoError> in
                let message = EnqueueMessage.message(text: caption, attributes:attributes, inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: media), threadId: threadId, replyToMessageId: replyId, replyToStoryId: replyStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                if let customChatContents  {
                    return customChatContents.enqueueMessages(messages: [message])
                } else {
                    return enqueueMessages(account: context.account, peerId: peerId, messages: [message])
                }
            })
        }
        
        return combineLatest(senders) |> deliverOnMainQueue |> mapToSignal { results -> Signal<[MessageId?], NoError> in
            
            let result = results.reduce([], { messageIds, current -> [MessageId?] in
                return messageIds + current
            })
            
            return .single(result)
            
        }  |> take(1) 
    }
    
    public static func enqueue(media:Media, context: AccountContext, peerId:PeerId, replyId:EngineMessageReplySubject?, threadId: Int64?, replyStoryId: StoryId? = nil, silent: Bool = false, atDate: Date? = nil, query: String? = nil, collectionId: ItemCollectionId? = nil, customChatContents: ChatCustomContentsProtocol? = nil, sendPaidMessageStars: StarsAmount? = nil) ->Signal<[MessageId?],NoError> {
        return enqueue(media: [media], caption: ChatTextInputState(), context: context, peerId: peerId, replyId: replyId, threadId: threadId, replyStoryId: replyStoryId, silent: silent, atDate: atDate, query: query, collectionId: collectionId, customChatContents: customChatContents, sendPaidMessageStars: sendPaidMessageStars)
    }
    
    public static func enqueue(media:[Media], caption: ChatTextInputState, context: AccountContext, peerId:PeerId, replyId:EngineMessageReplySubject?, threadId: Int64?, replyStoryId: StoryId? = nil, isCollage: Bool = false, additionText: ChatTextInputState? = nil, silent: Bool = false, atDate: Date? = nil, sendAsPeerId: PeerId? = nil, query: String? = nil, collectionId: ItemCollectionId? = nil, isSpoiler: Bool = false, customChatContents: ChatCustomContentsProtocol? = nil, messageEffect: AvailableMessageEffects.MessageEffect? = nil, leadingText: Bool = false, sendPaidMessageStars: StarsAmount? = nil, suggestPost: ChatInterfaceState.ChannelSuggestPost? = nil) ->Signal<[MessageId?],NoError> {
        
        let dynamicEmojiOrder: Bool = context.stickerSettings.dynamicPackOrder
        
        let parsingUrlType: ParsingType
        if peerId.namespace != Namespaces.Peer.SecretChat {
            parsingUrlType = [.Hashtags]
        } else {
            parsingUrlType = [.Links, .Hashtags]
        }
        
        var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: caption.messageTextEntities(parsingUrlType))]
        let caption = Atomic(value: caption)
        if FastSettings.isChannelMessagesMuted(peerId) || silent {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if let date = atDate {
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
        }
        if let sendAsPeerId = sendAsPeerId {
            attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
        }
        if let query = query, !query.isEmpty {
            attributes.append(EmojiSearchQueryMessageAttribute(query: query))
        }
        if let sendPaidMessageStars {
            attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
        }
        if isSpoiler {
            attributes.append(MediaSpoilerMessageAttribute())
        }
        if let messageEffect {
            attributes.append(EffectMessageAttribute(id: messageEffect.id))
        }
        if let attr = suggestPost?.attribute {
            attributes.append(attr)
        }
        if leadingText {
            attributes.append(InvertMediaMessageAttribute())
        }
                
        let localGroupingKey = isCollage ? arc4random64() : nil
        
        var upCollections:[ItemCollectionId] = []
        if let collectionId = collectionId, dynamicEmojiOrder {
            upCollections.append(collectionId)
        }
        
        var messages: [EnqueueMessage] = []
        let count = media.count
        let inlineMdeia = caption.with { $0.inlineMedia }
        for (i, media) in media.enumerated() {
            let text: String
            if media.isInteractiveMedia {
                text = caption.swap(.init()).inputText
            } else if i == count - 1 {
                text =  caption.swap(.init()).inputText
            } else {
                text = ""
            }
            messages.append(EnqueueMessage.message(text: text, attributes: attributes, inlineStickers: inlineMdeia, mediaReference: AnyMediaReference.standalone(media: media), threadId: threadId, replyToMessageId: replyId, replyToStoryId: replyStoryId, localGroupingKey: localGroupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: dynamicEmojiOrder ? upCollections : []))
        }
        
        if let input = additionText {
            var inset:Int = 0
            var input:ChatTextInputState = input
            
            if input.attributes.isEmpty {
                input = ChatTextInputState(inputText: input.inputText.trimmed)
            }
            let mapped = cut_long_message( input.inputText, 4096).map { message -> EnqueueMessage in
                let subState = input.subInputState(from: NSMakeRange(inset, message.length))
                inset += message.length
                
                var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: subState.messageTextEntities(parsingUrlType))]
                
                if FastSettings.isChannelMessagesMuted(peerId) || silent {
                    attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
                }
                if let date = atDate {
                    attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
                }
                if let sendAsPeerId = sendAsPeerId {
                    attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
                }
                if let sendPaidMessageStars {
                    attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
                }
                
                return EnqueueMessage.message(text: subState.inputText, attributes: attributes, inlineStickers: subState.inlineMedia, mediaReference: nil, threadId: threadId, replyToMessageId: replyId, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: dynamicEmojiOrder ? subState.upstairCollections : [])
            }
            messages.insert(contentsOf: mapped, at: 0)
        }
        if let customChatContents {
            return customChatContents.enqueueMessages(messages: messages) |> deliverOnMainQueue |> take(1)
        } else {
            return enqueueMessages(account: context.account, peerId: peerId, messages: messages) |> deliverOnMainQueue |> take(1)
        }
    }
    
    
}
