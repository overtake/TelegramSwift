//
//  FileUtils.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore
import FastBlur
import Postbox
import TGUIKit
import AVFoundation
import Accelerate
import GZIP
import Svg
import ColorPalette
import ThemeSettings
import RangeSet



let progressiveRangeMap: [(Int, [Int])] = [
    (100, [0]),
    (400, [1]),
    (400, [3]),
    (600, [4]),
    (Int(Int32.max), [2, 3, 4])
]

func chatMessageFileStatus(context: AccountContext, message: Message, file: TelegramMediaFile, approximateSynchronousValue: Bool = false, useVideoThumb: Bool = false) -> Signal<MediaResourceStatus, NoError> {
    if let _ = file.resource as? LocalFileReferenceMediaResource {
        return .single(.Local)
    }
    
    if useVideoThumb, let videoThumb = file.videoThumbnails.first {
        return combineLatest(context.fetchManager.fetchStatus(category: .file, location: .chat(message.id.peerId), locationKey: .messageId(message.id), resource: file.resource), context.fetchManager.fetchStatus(category: .file, location: .chat(message.id.peerId), locationKey: .messageId(message.id), resource: videoThumb.resource)) |> map { file, thumb in
            switch thumb {
            case .Local, .Fetching, .Paused:
                return thumb
            default:
                return file
            }
        }
    }
    return context.fetchManager.fetchStatus(category: .file, location: .chat(message.id.peerId), locationKey: .messageId(message.id), resource: file.resource)
}

func chatMessageFileInteractiveFetched(account: Account, fileReference: FileMediaReference) -> Signal<FetchResourceSourceType, NoError> {
    return fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: fileReference.userLocation, userContentType: fileReference.userContentType, reference: fileReference.resourceReference(fileReference.media.resource), statsCategory: .file, reportResultStatus: true) |> `catch` { _ in return .complete() }  //account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .file), implNext: true)
}

func chatMessageFileCancelInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
}

func largestRepresentationForPhoto(_ photo: TelegramMediaImage) -> TelegramMediaImageRepresentation? {
    return photo.representationForDisplayAtSize(PixelDimensions(1280, 1280))
}

func smallestImageRepresentation(_ representation:[TelegramMediaImageRepresentation]) -> TelegramMediaImageRepresentation? {
    return representation.first
}

public func representationFetchRangeForDisplayAtSize(representation: TelegramMediaImageRepresentation, dimension: Int?) -> Range<Int64>? {
    if representation.progressiveSizes.count > 1, let dimension = dimension {
        var largestByteSize = Int64(representation.progressiveSizes[0])
        for (maxDimension, byteSizes) in progressiveRangeMap {
            largestByteSize = Int64(representation.progressiveSizes[min(representation.progressiveSizes.count - 1, byteSizes.last!)])
            if maxDimension >= dimension {
                break
            }
        }
        return 0 ..< largestByteSize
    }
    return nil
}

func chatMessagePhotoDatas(postbox: Postbox, imageReference: ImageMediaReference, fullRepresentationSize: CGSize = CGSize(width: 1280.0, height: 1280.0), autoFetchFullSize: Bool = false, tryAdditionalRepresentations: Bool = false, synchronousLoad: Bool = false, secureIdAccessContext: SecureIdAccessContext? = nil, peer: Peer? = nil, useMiniThumbnailIfAvailable: Bool = false, onlyThumbnail: Bool = false) -> Signal<ImageRenderData, NoError> {
    
    if let progressiveRepresentation = progressiveImageRepresentation(imageReference.media.representations), progressiveRepresentation.progressiveSizes.count > 1, !onlyThumbnail {
        enum SizeSource {
            case miniThumbnail(data: Data)
            case image(size: Int64)
            case resource(TelegramMediaResource)
        }
        
        var sources: [SizeSource] = []
        if let miniThumbnail = imageReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail) {
            sources.append(.miniThumbnail(data: miniThumbnail))
        }
        let thumbnailByteSize = Int64(progressiveRepresentation.progressiveSizes[0])
        var largestByteSize = Int64(progressiveRepresentation.progressiveSizes[0])
        for (maxDimension, byteSizes) in progressiveRangeMap {
            if Int(fullRepresentationSize.width) > 100 && maxDimension <= 100 {
                continue
            }
            sources.append(contentsOf: byteSizes.compactMap { sizeIndex -> SizeSource? in
                if progressiveRepresentation.progressiveSizes.count - 1 < sizeIndex {
                    return nil
                }
                return .image(size: Int64(progressiveRepresentation.progressiveSizes[sizeIndex]))
            })
            largestByteSize = Int64(progressiveRepresentation.progressiveSizes[min(progressiveRepresentation.progressiveSizes.count - 1, byteSizes.last!)])
            if maxDimension >= Int64(fullRepresentationSize.width) {
                break
            }
        }


        if let miniThumbnail = imageReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail) {
            sources.insert(.miniThumbnail(data: miniThumbnail), at: 0)
        }
        if let largest = imageReference.media.representationForDisplayAtSize(.init(fullRepresentationSize)) {
            sources.append(.resource(largest.resource))
        }
        
        return Signal { subscriber in
            let signals: [Signal<(SizeSource, Data?), NoError>] = sources.map { source -> Signal<(SizeSource, Data?), NoError> in
                switch source {
                case let .miniThumbnail(data):
                    return .single((source, data))
                case let .image(size):
                    return postbox.mediaBox.resourceData(progressiveRepresentation.resource, size: Int64(progressiveRepresentation.progressiveSizes.last!), in: 0 ..< size, mode: .incremental, notifyAboutIncomplete: true, attemptSynchronously: synchronousLoad)
                    |> map { (data, _) -> (SizeSource, Data?) in
                        return (source, data)
                    }
                case let .resource(resource):
                    let size = resource.size ?? 0
                    return postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< size, mode: .complete, notifyAboutIncomplete: true, attemptSynchronously: synchronousLoad)
                    |> map { (data, _) -> (SizeSource, Data?) in
                        return (source, data)
                    }
                }
            }
            
            let dataDisposable = combineLatest(signals).start(next: { results in
                var foundData = false
                loop: for i in (0 ..< results.count).reversed() {
                    let isLastSize = i == results.count - 1
                    switch results[i].0 {
                    case .image:
                        if let data = results[i].1, data.count != 0 {
                            subscriber.putNext(ImageRenderData(nil, data, isLastSize))
                            foundData = true
                            if isLastSize {
                                subscriber.putCompletion()
                            }
                            break loop
                        }
                    case let .miniThumbnail(thumbnailData):
                        subscriber.putNext(ImageRenderData(thumbnailData, nil, false))
                        foundData = true
                        break loop
                    case .resource:
                        if let data = results[i].1, data.count != 0 {
                            subscriber.putNext(ImageRenderData(nil, data, isLastSize))
                            foundData = true
                            if isLastSize {
                                subscriber.putCompletion()
                            }
                            break loop
                        }
                    }
                }
                if !foundData {
                    subscriber.putNext(ImageRenderData(nil, nil, false))
                }
            })
            var fetchDisposable: Disposable?
            if autoFetchFullSize {
                fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: imageReference.userLocation, userContentType: imageReference.userContentType, reference: imageReference.resourceReference(progressiveRepresentation.resource), range: (0 ..< largestByteSize, .default), statsCategory: .image).start()
            } else if useMiniThumbnailIfAvailable {
                fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: imageReference.userLocation, userContentType: imageReference.userContentType, reference: imageReference.resourceReference(progressiveRepresentation.resource), range: (0 ..< thumbnailByteSize, .default), statsCategory: .image).start()
            }
            
            return ActionDisposable {
                dataDisposable.dispose()
                fetchDisposable?.dispose()
            }
        }
    }

    
    if let smallestRepresentation = smallestImageRepresentation(imageReference.media.representations), let largestRepresentation = imageReference.media.representationForDisplayAtSize(PixelDimensions(fullRepresentationSize)) {
        
        
        let maybeFullSize = postbox.mediaBox.resourceData(largestRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)

        let signal = maybeFullSize
            |> take(1)
            |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
                if maybeData.complete && !onlyThumbnail {
                    let loadedData: Data?
                    if largestRepresentation.resource is EncryptedMediaResource, let secureIdAccessContext = secureIdAccessContext {
                        loadedData = decryptedResourceData(data: maybeData, resource: largestRepresentation.resource, params: secureIdAccessContext)
                    } else {
                        loadedData = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                    }
                    return .single(ImageRenderData(nil, loadedData, true))
                } else {


                    let decodedThumbnailData = imageReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail)
                    let fetchedThumbnail: Signal<FetchResourceSourceType, NoError>
                    if let _ = decodedThumbnailData {
                        fetchedThumbnail = .complete()
                    } else {
                        let reference: MediaResourceReference
                        if let peer = peer, let peerReference = PeerReference(peer) {
                            reference = MediaResourceReference.avatar(peer: peerReference, resource: smallestRepresentation.resource)
                        } else {
                            reference = imageReference.resourceReference(smallestRepresentation.resource)
                        }
                        fetchedThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: imageReference.userLocation, userContentType: imageReference.userContentType, reference: reference, statsCategory: .image) |> `catch` { _ in return .complete() }
                    }
                    let reference: MediaResourceReference
                    if let peer = peer, let peerReference = PeerReference(peer) {
                        reference = MediaResourceReference.avatar(peer: peerReference, resource: largestRepresentation.resource)
                    } else {
                        reference = imageReference.resourceReference(largestRepresentation.resource)
                    }
                    let fetchedFullSize = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: imageReference.userLocation, userContentType: imageReference.userContentType, reference: reference, statsCategory: .image)

                    let anyThumbnail: [Signal<MediaResourceData, NoError>]
                    if tryAdditionalRepresentations {
                        anyThumbnail = imageReference.media.representations.filter({ representation in
                            return representation != largestRepresentation
                        }).map({ representation -> Signal<MediaResourceData, NoError> in
                            return postbox.mediaBox.resourceData(representation.resource)
                                |> take(1)
                        })
                    } else {
                        anyThumbnail = []
                    }

                    let mainThumbnail = Signal<Data?, NoError> { subscriber in
                        if let decodedThumbnailData = decodedThumbnailData {
                            subscriber.putNext(decodedThumbnailData)
                            subscriber.putCompletion()
                            return EmptyDisposable
                        } else {
                            let fetchedDisposable = fetchedThumbnail.start()
                            let thumbnailDisposable = postbox.mediaBox.resourceData(smallestRepresentation.resource, attemptSynchronously: synchronousLoad).start(next: { next in
                                if next.complete {
                                    subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                                }
                            }, error: subscriber.putError, completed: subscriber.putCompletion)

                            return ActionDisposable {
                                fetchedDisposable.dispose()
                                thumbnailDisposable.dispose()
                            }
                        }
                    }

                    let thumbnail = combineLatest(anyThumbnail)
                        |> mapToSignal { thumbnails -> Signal<Data?, NoError> in
                            for thumbnail in thumbnails {
                                if thumbnail.size != 0, let data = try? Data(contentsOf: URL(fileURLWithPath: thumbnail.path), options: []) {
                                    return .single(data)
                                }
                            }
                            return mainThumbnail
                    }

                    let fullSizeData: Signal<ImageRenderData, NoError>

                    if autoFetchFullSize {
                        fullSizeData = Signal<ImageRenderData, NoError> { subscriber in
                            let fetchedFullSizeDisposable = fetchedFullSize.start()
                            let fullSizeDisposable = postbox.mediaBox.resourceData(largestRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad).start(next: { next in
                                subscriber.putNext(ImageRenderData(nil, next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                            }, error: subscriber.putError, completed: subscriber.putCompletion)

                            return ActionDisposable {
                                fetchedFullSizeDisposable.dispose()
                                fullSizeDisposable.dispose()
                            }
                        }
                    } else {
                        fullSizeData = postbox.mediaBox.resourceData(largestRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)
                            |> map { next -> ImageRenderData in
                                return ImageRenderData(nil, next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                        }
                    }

                    return thumbnail
                        |> mapToSignal { thumbnailData in
                            if let _ = thumbnailData {
                                return fullSizeData
                                    |> map { fullSizeData in
                                        return ImageRenderData(thumbnailData, fullSizeData.fullSizeData, fullSizeData.fullSizeComplete)
                                }
                            } else {
                                return .single(ImageRenderData(nil, nil, false))
                            }
                    }
//
//                    return combineLatest(thumbnail, fullSizeData)
//                        |> map { thumbnailData, fullSizeData -> ImageRenderData in
//                            return ImageRenderData(fullSizeData.fullSizeComplete ? nil : thumbnailData, fullSizeData.fullSizeData, fullSizeData.fullSizeComplete)
//                    }
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if (lhs.thumbnailData == nil && lhs.fullSizeData == nil) && (rhs.thumbnailData == nil && rhs.fullSizeData == nil) {
                    return true
                } else {
                    return false
                }
            })

        return signal
    } else if let immediateThumbnailData = imageReference.media.immediateThumbnailData {
        return Signal { subscriber in
            let decodedThumbnailData = decodeTinyThumbnail(data: immediateThumbnailData)
            if let data = decodedThumbnailData {
                subscriber.putNext(.init(data, nil, true))
                subscriber.putCompletion()
            } else {
                subscriber.putCompletion()
            }
            return ActionDisposable {
                
            }
        }
    } else {
        return .never()
    }
}


func svgIconImageFile(account: Account, fileReference: FileMediaReference?, scale:CGFloat = 2, stickToTop: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let data: Signal<MediaResourceData, NoError>
    if let fileReference = fileReference {
        data = account.postbox.mediaBox.cachedResourceRepresentation(fileReference.media.resource, representation: CachedPreparedSvgRepresentation(), complete: false, fetch: true)
    } else {
        data = Signal { subscriber in
            if let url = Bundle.main.url(forResource: "durgerking", withExtension: "placeholder"), let data = try? Data(contentsOf: url, options: .mappedRead) {
                subscriber.putNext(MediaResourceData(path: url.path, offset: 0, size: Int64(data.count), complete: true))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    return data
    |> map { value in
        let fullSizePath = value.path
        let fullSizeComplete = value.complete
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            
            var fullSizeImage: CGImage?
            let imageOrientation: ImageOrientation = .up
            
            if fullSizeComplete, let data = try? Data(contentsOf: URL(fileURLWithPath: fullSizePath)) {
                let renderSize: CGSize
                if stickToTop {
                    renderSize = .zero
                } else {
                    renderSize = CGSize(width: 90.0, height: 90.0)
                }
                fullSizeImage = renderPreparedImage(data, renderSize, .clear, scale)?._cgImage
                if let image = fullSizeImage {
                    fittedSize = image.size.aspectFitted(arguments.boundingSize)
                }
            }
            
            var fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            if stickToTop {
                fittedRect.origin.y = drawingRect.size.height - fittedSize.height
            }
            
            context.withFlippedContext { c in
                if let fullSizeImage = fullSizeImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        }
    }
}


private func chatMessageWebFilePhotoDatas(account: Account, photo: TelegramMediaWebFile, synchronousLoad: Bool = false) -> Signal<ImageRenderData, NoError> {
    let maybeFullSize = account.postbox.mediaBox.resourceData(photo.resource, attemptSynchronously: synchronousLoad)
    
    let signal = maybeFullSize |> take(1) |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            
            return .single(ImageRenderData(nil, loadedData, true))
        } else {
            return account.postbox.mediaBox.resourceData(photo.resource, attemptSynchronously: synchronousLoad)
                |> map { next -> ImageRenderData in
                    return ImageRenderData(nil, next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
            }
        }
    } |> filter({ $0.fullSizeData != nil })
    
    return signal
}



private func chatMessageFileDatas(account: Account, fileReference: FileMediaReference, pathExtension: String? = nil, progressive: Bool = false, justThumbail: Bool = false, synchronousLoad: Bool = false) -> Signal<ImageRenderData, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
        let thumbnailResource = smallestRepresentation.resource
        let fullSizeResource = largestImageRepresentation(fileReference.media.previewRepresentations)?.resource ?? smallestRepresentation.resource
        
        let maybeFullSize = account.postbox.mediaBox.resourceData(fullSizeResource, pathExtension: pathExtension, attemptSynchronously: synchronousLoad)
        
        let signal = maybeFullSize |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
            
           if maybeData.complete && !justThumbail {
            let fullData = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path))
            return .single(ImageRenderData(nil, fullData, fullData != nil))
        } else {
                let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: fileReference.userLocation, userContentType: fileReference.userContentType, reference: fileReference.resourceReference(thumbnailResource))
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource, pathExtension: pathExtension, attemptSynchronously: synchronousLoad).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                
                let fullSizeDataAndPath = account.postbox.mediaBox.resourceData(fullSizeResource, option: !progressive ? .complete(waitUntilFetchStatus: false) : .incremental(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad) |> map { next -> Data? in
                    return next.size == 0 || !next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path))
                }
            
                //TODO
                return thumbnail |> mapToSignal { thumbnailData in
                    return fullSizeDataAndPath |> take(1) |> map { fullSizeData in
                        return ImageRenderData(thumbnailData, fullSizeData, fullSizeData != nil)
                    }
                } |> then(Signal({ subscriber -> Disposable in
                    if !maybeData.complete, let fullSizeResource = fullSizeResource as? LocalFileReferenceMediaResource {
                        let thumbnailData = justThumbail ? try? Data(contentsOf: URL(fileURLWithPath: fullSizeResource.localFilePath)) : nil
                        let fulleSizeData = try? Data(contentsOf: URL(fileURLWithPath: fullSizeResource.localFilePath))
                        subscriber.putNext(ImageRenderData(thumbnailData, fulleSizeData, true))
                    }
                    subscriber.putCompletion()
                    return EmptyDisposable
                }))
            }
            } |> filter({ $0.thumbnailData != nil || $0.fullSizeData != nil })
        
        return signal
    } else {
        return .never()
    }
}


func chatGalleryPhoto(account: Account, imageReference: ImageMediaReference, toRepresentationSize:NSSize = NSMakeSize(1280, 1280), peer: Peer? = nil, scale:CGFloat, secureIdAccessContext: SecureIdAccessContext? = nil, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> CGImage?, NoError> {
    let signal = chatMessagePhotoDatas(postbox: account.postbox, imageReference: imageReference, fullRepresentationSize:toRepresentationSize, synchronousLoad: synchronousLoad, secureIdAccessContext: secureIdAccessContext, peer: peer)
    
    return signal |> map { data in
        return { arguments in
            
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            
            let fullSizeData = data.fullSizeData
            let thumbnailData = data.thumbnailData
            
            let options = NSMutableDictionary()
            
            options.setValue(max(fittedSize.width * scale, fittedSize.height * scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
            options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCache as String)
            options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCacheImmediately as String)
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)

            
            
            if let fullSizeData = fullSizeData {
                if data.fullSizeData != nil {
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        return generateImage(image.size, contextGenerator: { (size, ctx) in
                            ctx.setFillColor(theme.colors.transparentBackground.cgColor)
                            ctx.fill(NSMakeRect(0, 0, size.width, size.height))
                            ctx.draw(image, in: NSMakeRect(0, 0, size.width, size.height))
                        })
                        
                    }
                    
                }
            }
            
            options.setValue(150 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)

            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                thumbnailImage = image
            }
            
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                return generateImage(fittedSize, contextGenerator: { size, ctx in
                    ctx.draw(thumbnailContext.generateImage()!, in: NSMakeRect(0, 0, size.width, size.height))
                })
                
            }
            return generateImage(fittedSize, contextGenerator: { (size, ctx) in
                ctx.setFillColor(theme.colors.transparentBackground.cgColor)
                ctx.fill(NSMakeRect(0, 0, size.width, size.height))
            })
            
        }
    }
}

func chatMessagePhoto(account: Account, imageReference: ImageMediaReference, toRepresentationSize:NSSize = NSMakeSize(1280, 1280), peer: Peer? = nil, scale:CGFloat, synchronousLoad: Bool = false, autoFetchFullSize: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessagePhotoDatas(postbox: account.postbox, imageReference: imageReference, fullRepresentationSize: toRepresentationSize, autoFetchFullSize: autoFetchFullSize, synchronousLoad: synchronousLoad, peer: peer)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale:scale, clear: true)
            
            let fullSizeData = data.fullSizeData
            let thumbnailData = data.thumbnailData
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize)
            switch arguments.resizeMode {
            case .none:
                break
            default:
                fittedSize = fittedSize.fitted(arguments.imageSize)
            }
            let fittedRect = CGRect(origin: CGPoint(x: floorToScreenPixels(System.backingScale, drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0), y: floorToScreenPixels(System.backingScale, drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0)), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if data.fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCache as String)

                       options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                    
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, data.fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                
                let initialThumbnailContextFittingSize = fittedSize.fitted(CGSize(width: 90.0, height: 90.0))
                
                let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                    thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                }
                
                if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                    let additionalContextSize = thumbnailContextFittingSize
                    let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0)
                    additionalBlurContext.withFlippedContext { c in
                        c.interpolationQuality = .default
                        if let image = thumbnailContext.generateImage() {
                            c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                        }
                    }
                    telegramFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                    blurredThumbnailImage = additionalBlurContext.generateImage()
                } else {
                    blurredThumbnailImage = thumbnailContext.generateImage()
                }
            }
            
            
            context.withContext(isHighQuality: data.fullSizeComplete, { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    switch arguments.resizeMode {
                    case .blurBackground:
                        let blurSourceImage = thumbnailImage ?? fullSizeImage
                        
                        if let fullSizeImage = blurSourceImage {
                            let thumbnailSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height)
                            let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 74.0, height: 74.0))
                            let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                            thumbnailContext.withFlippedContext { c in
                                c.interpolationQuality = .none
                                c.draw(fullSizeImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                            }
                            // telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                            telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                            
                            if let blurredImage = thumbnailContext.generateImage() {
                                let filledSize = thumbnailSize.aspectFilled(arguments.drawingRect.size)
                                c.interpolationQuality = .medium
                                c.draw(blurredImage, in: CGRect(origin: CGPoint(x: arguments.drawingRect.minX + (arguments.drawingRect.width - filledSize.width) / 2.0, y: arguments.drawingRect.minY + (arguments.drawingRect.height - filledSize.height) / 2.0), size: filledSize))
                                c.setBlendMode(.normal)
                                c.setFillColor(theme.colors.background.withAlphaComponent(0.5).cgColor)
                                c.fill(arguments.drawingRect)
                                c.setBlendMode(.copy)
                            }
                        } else {
                            c.fill(arguments.drawingRect)
                        }
                    case let .fill(color):
                        c.setFillColor(color.cgColor)
                        c.fill(arguments.drawingRect)
                    case .fillTransparent:
                        c.setFillColor(theme.colors.transparentBackground.cgColor)
                        c.fill(arguments.drawingRect)
                    case .none:
                        break
                    case .imageColor:
                        break
                    }
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(blurredThumbnailImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
                
            })
            
            
            addCorners(context, arguments: arguments, scale:scale)
            
            return context
        })
    }
}

func chatMessageWebFilePhoto(account: Account, photo: TelegramMediaWebFile, toRepresentationSize:NSSize = NSMakeSize(1280, 1280), scale:CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessageWebFilePhotoDatas(account: account, photo: photo, synchronousLoad: synchronousLoad)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale:scale, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = data.fullSizeData {
                if data.fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                    
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, data.fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            
            
            
            context.withContext(isHighQuality: fullSizeImage != nil, { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                   // c.setFillColor(theme.colors.grayBackground.cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
                
            })
            
            
            addCorners(context, arguments: arguments, scale:scale)
            
            return context
        })
    }
}


enum StickerDatasType {
    case thumb
    case small
    case chatMessage
    case full
}

func chatMessageStickerResource(file: TelegramMediaFile, small: Bool) -> MediaResource {
    let resource: MediaResource
    if small, let smallest = smallestImageRepresentation(file.previewRepresentations) {
        resource = smallest.resource
    } else {
        resource = file.resource
    }
    return resource
}






private func chatMessageStickerDatas(postbox: Postbox, file: FileMediaReference, small: Bool, fetched: Bool, onlyFullSize: Bool, synchronousLoad: Bool) -> Signal<ImageRenderData, NoError> {
    
    let thumbnailResource = chatMessageStickerResource(file: file.media, small: true)
    let resource = chatMessageStickerResource(file: file.media, small: small)

    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: small ? CGSize(width: 120.0, height: 120.0) : nil), complete: false, fetch: false, attemptSynchronously: synchronousLoad) |> runOn(synchronousLoad ? .mainQueue() : resourcesQueue)
    
    
    return maybeFetched
        |> take(1)
        |> mapToSignal { maybeData in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                
                return .single(ImageRenderData(nil, loadedData, true))
            } else {
                
                /*
                 let thumbnailData:Signal<MediaResourceData?, NoError> = .single(nil) |> then( postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedAnimatedStickerRepresentation(thumb: true, size: size.aspectFitted(NSMakeSize(60, 60)), fitzModifier: file.media.animatedEmojiFitzModifier), complete: true) |> map(Optional.init))

                 */
                
                var thumbnailData:Signal<MediaResourceData?, NoError> = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedStickerAJpegRepresentation(size: nil), complete: true) |> map(Optional.init)
                if resource is LocalFileReferenceMediaResource {
                    thumbnailData = .single(nil)
                } 
                let fullSizeData:Signal<ImageRenderData, NoError> = .single(ImageRenderData(nil, nil, false)) |> then(postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: small ? CGSize(width: 120.0, height: 120.0) : nil), complete: true)
                    |> map { next in
                        return ImageRenderData(nil, !next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
                })


                return Signal { subscriber in
                    var fetch: Disposable?
                    if fetched {
                        fetch = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: file.userLocation, userContentType: file.userContentType, reference: file.resourceReference(resource)).start()
                    }

                    var fetchThumbnail: Disposable?
                    fetchThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: file.userLocation, userContentType: file.userContentType, reference: file.resourceReference(thumbnailResource)).start()

                    let disposable = (combineLatest(thumbnailData, fullSizeData)
                        |> map { thumbnailData, fullSizeData -> ImageRenderData in
                            if let thumbnailData = thumbnailData {
                                return ImageRenderData(thumbnailData.complete && !fullSizeData.fullSizeComplete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil, fullSizeData.fullSizeData, fullSizeData.fullSizeComplete)
                            } else {
                                return fullSizeData
                            }
                        }).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        })

                    return ActionDisposable {
                        fetch?.dispose()
                        fetchThumbnail?.dispose()
                        disposable.dispose()
                    }
                }
            }
    }
}



public func chatMessageSticker(postbox: Postbox, file: FileMediaReference, small: Bool, scale: CGFloat, fetched: Bool = true, onlyFullSize: Bool = false, thumbnail: Bool = false, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal: Signal<ImageRenderData, NoError>
    signal = chatMessageStickerDatas(postbox: postbox, file: file, small: small, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: synchronousLoad)
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: arguments.emptyColor == nil)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            //let fittedRect = arguments.drawingRect
            
            var fullSizeImage: CGImage?
            if let fullSizeData = data.fullSizeData, data.fullSizeComplete {
                if let image = NSImage(data: fullSizeData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    fullSizeImage = image
                }
            }
            
            var thumbnailImage: CGImage?
            if fullSizeImage == nil, let thumbnailData = data.thumbnailData {
                if let image = NSImage(data: thumbnailData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    thumbnailImage = image
                }
            }
            
            var blurredThumbnailImage: CGImage?
            let thumbnailInset: CGFloat = 10.0
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = thumbnailImage.size
                var thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailDrawingSize = thumbnailContextSize
                thumbnailContextSize.width += thumbnailInset * 2.0
                thumbnailContextSize.height += thumbnailInset * 2.0
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: true)
                thumbnailContext.withFlippedContext(isHighQuality: false, horizontal: arguments.mirror, { c in
                    let cgImage = thumbnailImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: thumbnailInset, y: thumbnailInset), size: thumbnailDrawingSize))
                })
                stickerThumbnailAlphaBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, horizontal: arguments.mirror, { c in
                c.clear(drawingRect)
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    switch color {
                    case let .color(color):
                        c.setFillColor(color.cgColor)
                        c.fill(drawingRect)
                    default:
                        break
                    }
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    let thumbnailScaledInset = thumbnailInset * (fittedRect.width / blurredThumbnailImage.size.width)
                    c.draw(blurredThumbnailImage, in: fittedRect.insetBy(dx: -thumbnailScaledInset, dy: -thumbnailScaledInset))
                }
                
                if let fullSizeImage = fullSizeImage {
                    let cgImage = fullSizeImage
                    if case let .fill(color) = arguments.emptyColor {
                        c.clip(to: fittedRect, mask: cgImage)
                        c.setFillColor(color.cgColor)
                        c.fill(fittedRect)
                    } else {
                        c.draw(cgImage, in: fittedRect)
                    }
                }
            })
            
            return context
        })
    }
}






private func chatMessageAnimatedStickerDatas(postbox: Postbox, file: FileMediaReference, small: Bool, fetched: Bool, onlyFullSize: Bool, synchronousLoad: Bool, size: NSSize, thumbAtFrame: Int = 0, isVideo: Bool = false) -> Signal<ImageRenderData, NoError> {
    let thumbnailResource = chatMessageStickerResource(file: file.media, small: true)
    let resource = chatMessageStickerResource(file: file.media, small: small)
    
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedAnimatedStickerRepresentation(thumb: small, size: size, fitzModifier: file.media.animatedEmojiFitzModifier, frame: thumbAtFrame, isVideo: isVideo), complete: false, fetch: false, attemptSynchronously: synchronousLoad) |> runOn(synchronousLoad ? .mainQueue() : resourcesQueue)
    
    return maybeFetched
        |> take(1)
        |> mapToSignal { maybeData in
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [.mappedIfSafe])
            if maybeData.complete, let loadedData = loadedData, loadedData.count > 0 {
                return .single(ImageRenderData(nil, loadedData, true))
            } else {
                let thumbnailData:Signal<MediaResourceData?, NoError> =  postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedAnimatedStickerRepresentation(thumb: true, size: size.aspectFitted(NSMakeSize(60, 60)), fitzModifier: file.media.animatedEmojiFitzModifier, frame: thumbAtFrame, isVideo: false), complete: true) |> map(Optional.init)
                
                
                let fullSizeData:Signal<ImageRenderData, NoError> = .single(ImageRenderData(nil, nil, false)) |> then(postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedAnimatedStickerRepresentation(thumb: false, size: size, fitzModifier: file.media.animatedEmojiFitzModifier, frame: thumbAtFrame, isVideo: isVideo), complete: true)
                     |> map { next in
                         return ImageRenderData(nil, !next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
                     })
                
                return Signal { subscriber in
                    var fetch: Disposable?
                    if fetched {
                        fetch = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: file.userLocation, userContentType: file.userContentType, reference: file.resourceReference(resource)).start()
                    }
                    
                    var fetchThumbnail: Disposable?
                    fetchThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: file.userLocation, userContentType: file.userContentType, reference: file.resourceReference(thumbnailResource)).start()

                    let disposable = (combineLatest(thumbnailData, fullSizeData)
                        |> map { thumbnailData, fullSizeData -> ImageRenderData in
                            if let thumbnailData = thumbnailData {
                                return ImageRenderData(thumbnailData.complete && !fullSizeData.fullSizeComplete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil, fullSizeData.fullSizeData, fullSizeData.fullSizeComplete)
                            } else {
                                return ImageRenderData(nil, fullSizeData.fullSizeData, fullSizeData.fullSizeComplete)
                            }
                        }).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                    
                    return ActionDisposable {
                        fetch?.dispose()
                        fetchThumbnail?.dispose()
                        disposable.dispose()
                    }
                }
            }
    }
}





private func chatMessageAnimatedStickerThumbnailData(postbox: Postbox, file: FileMediaReference, synchronousLoad: Bool) -> Signal<Data?, NoError> {
    let thumbnailResource = chatMessageStickerResource(file: file.media, small: true)
    var size: NSSize = NSMakeSize(60, 60)
    size = file.media.dimensions?.size.aspectFitted(size) ?? size
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedAnimatedStickerRepresentation(thumb: true, size: size), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
        |> take(1)
        |> mapToSignal { maybeData in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(loadedData)
            } else {
                let thumbnailData = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedAnimatedStickerRepresentation(thumb: true, size: size), complete: false)
                
                return Signal { subscriber in
                    let fetchThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: file.userLocation, userContentType: file.userContentType, reference: file.resourceReference(thumbnailResource)).start()
                    
                    let disposable = (thumbnailData
                        |> map { thumbnailData -> Data? in
                            return thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil
                        }).start(next: { next in
                            subscriber.putNext(next)
                        }, error: { error in
                            subscriber.putError(error)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                    
                    return ActionDisposable {
                        fetchThumbnail.dispose()
                        disposable.dispose()
                    }
                }
            }
    }
}


public func chatMessageAnimatedSticker(postbox: Postbox, file: FileMediaReference, small: Bool, scale: CGFloat, size: NSSize, fetched: Bool = false, onlyFullSize: Bool = false, synchronousLoad: Bool = false, thumbAtFrame: Int = 0, isVideo: Bool) -> Signal<ImageDataTransformation, NoError> {
    let signal: Signal<ImageRenderData, NoError> = chatMessageAnimatedStickerDatas(postbox: postbox, file: file, small: small, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: synchronousLoad, size: size, thumbAtFrame: thumbAtFrame, isVideo: isVideo)
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: arguments.emptyColor == nil)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            //let fittedRect = arguments.drawingRect
            
            var fullSizeImage: CGImage?
            if let fullSizeData = data.fullSizeData, data.fullSizeComplete {
                if let image = NSImage(data: fullSizeData)?._cgImage {
                    fullSizeImage = image
                }
            }
            
            var thumbnailImage: CGImage?
            if fullSizeImage == nil, let thumbnailData = data.thumbnailData {
                if let image = NSImage(data: thumbnailData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    thumbnailImage = image
                }
            }
            
            var blurredThumbnailImage: CGImage?
            let thumbnailInset: CGFloat = 10.0
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = thumbnailImage.size
                var thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailDrawingSize = thumbnailContextSize
                thumbnailContextSize.width += thumbnailInset * 2.0
                thumbnailContextSize.height += thumbnailInset * 2.0
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: true)
                thumbnailContext.withFlippedContext(isHighQuality: false, horizontal: arguments.mirror, { c in
                    let cgImage = thumbnailImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: thumbnailInset, y: thumbnailInset), size: thumbnailDrawingSize))
                })
                stickerThumbnailAlphaBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, horizontal: arguments.mirror, { c in
                c.clear(drawingRect)
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    switch color {
                    case let .color(color):
                        c.setFillColor(color.cgColor)
                        c.fill(drawingRect)
                    default:
                        break
                    }
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage, fullSizeImage == nil {
                    c.interpolationQuality = .low
                    let thumbnailScaledInset = thumbnailInset * (fittedRect.width / blurredThumbnailImage.size.width)
                    let rect = fittedRect.insetBy(dx: -thumbnailScaledInset, dy: -thumbnailScaledInset)
                    if case let .fill(color) = arguments.emptyColor {
                        c.clip(to: rect, mask: blurredThumbnailImage)
                        c.setFillColor(color.cgColor)
                        c.fill(rect)
                    } else {
                        c.draw(blurredThumbnailImage, in: rect)
                    }
                }
                
                if let fullSizeImage = fullSizeImage {
                    let cgImage = fullSizeImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    if case let .fill(color) = arguments.emptyColor {
                        c.clip(to: fittedRect, mask: cgImage)
                        c.setFillColor(color.cgColor)
                        c.fill(fittedRect)
                    } else {
                        c.draw(cgImage, in: fittedRect)
                    }
                    
                   // c.setFillColor(NSColor.random.cgColor)
                   // c.fill(fittedRect)
                }
            })
            
            return context
        })
    }
}

func chatMessageSlotSticker(postbox: Postbox, value: SlotMachineValue, scale: CGFloat, size: NSSize, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    
    let signal: Signal<ImageRenderData, NoError> = postbox.mediaBox.cachedResourceRepresentation(LocalFileReferenceMediaResource(localFilePath: "", randomId: 0), representation: CachedSlotMachineRepresentation(value: value, size: size), complete: true, fetch: true, attemptSynchronously: synchronousLoad) |> map { data in
        if data.complete {
            return ImageRenderData(nil, try? Data(contentsOf: URL(fileURLWithPath: data.path)), true)
        } else {
            return ImageRenderData(nil, nil, false)
        }
        } |> runOn(synchronousLoad ? .mainQueue() : resourcesQueue)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: arguments.emptyColor == nil)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            //let fittedRect = arguments.drawingRect
            
            var fullSizeImage: CGImage?
            if let fullSizeData = data.fullSizeData, data.fullSizeComplete {
                if let image = NSImage(data: fullSizeData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    fullSizeImage = image
                }
            }
            
            var thumbnailImage: CGImage?
            if fullSizeImage == nil, let thumbnailData = data.thumbnailData {
                if let image = NSImage(data: thumbnailData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    thumbnailImage = image
                }
            }
            
            var blurredThumbnailImage: CGImage?
            let thumbnailInset: CGFloat = 10.0
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = thumbnailImage.size
                var thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailDrawingSize = thumbnailContextSize
                thumbnailContextSize.width += thumbnailInset * 2.0
                thumbnailContextSize.height += thumbnailInset * 2.0
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: true)
                thumbnailContext.withFlippedContext(isHighQuality: false, { c in
                    let cgImage = thumbnailImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: thumbnailInset, y: thumbnailInset), size: thumbnailDrawingSize))
                })
                stickerThumbnailAlphaBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, { c in
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    switch color {
                    case let .color(color):
                        c.setFillColor(color.cgColor)
                    default:
                        break
                    }
                    c.fill(drawingRect)
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage, fullSizeImage == nil {
                    c.interpolationQuality = .low
                    let thumbnailScaledInset = thumbnailInset * (fittedRect.width / blurredThumbnailImage.size.width)
                    c.draw(blurredThumbnailImage, in: fittedRect.insetBy(dx: -thumbnailScaledInset, dy: -thumbnailScaledInset))
                }
                
                if let fullSizeImage = fullSizeImage {
                    let cgImage = fullSizeImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    c.draw(cgImage, in: fittedRect)
                }
            })
            
            return context
        })
    }
}

public func chatMessageDiceSticker(postbox: Postbox, file: TelegramMediaFile, emoji: String, value: String, scale: CGFloat, size: NSSize, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    
    
    let signal: Signal<ImageRenderData, NoError> = postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedDiceRepresentation(emoji: emoji, value: value, size: size), complete: true, fetch: true, attemptSynchronously: synchronousLoad) |> map { data in
        if data.complete {
            return ImageRenderData(nil, try? Data(contentsOf: URL(fileURLWithPath: data.path)), true)
        } else {
            return ImageRenderData(nil, nil, false)
        }
    } |> runOn(synchronousLoad ? .mainQueue() : resourcesQueue)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: arguments.emptyColor == nil)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            //let fittedRect = arguments.drawingRect
            
            var fullSizeImage: CGImage?
            if let fullSizeData = data.fullSizeData, data.fullSizeComplete {
                if let image = NSImage(data: fullSizeData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    fullSizeImage = image
                }
            }
            
            var thumbnailImage: CGImage?
            if fullSizeImage == nil, let thumbnailData = data.thumbnailData {
                if let image = NSImage(data: thumbnailData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    thumbnailImage = image
                }
            }
            
            var blurredThumbnailImage: CGImage?
            let thumbnailInset: CGFloat = 10.0
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = thumbnailImage.size
                var thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailDrawingSize = thumbnailContextSize
                thumbnailContextSize.width += thumbnailInset * 2.0
                thumbnailContextSize.height += thumbnailInset * 2.0
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: true)
                thumbnailContext.withFlippedContext(isHighQuality: false, { c in
                    let cgImage = thumbnailImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: thumbnailInset, y: thumbnailInset), size: thumbnailDrawingSize))
                })
                stickerThumbnailAlphaBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, { c in
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    switch color {
                    case let .color(color):
                        c.setFillColor(color.cgColor)
                    default:
                        break
                    }
                    c.fill(drawingRect)
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage, fullSizeImage == nil {
                    c.interpolationQuality = .low
                    let thumbnailScaledInset = thumbnailInset * (fittedRect.width / blurredThumbnailImage.size.width)
                    c.draw(blurredThumbnailImage, in: fittedRect.insetBy(dx: -thumbnailScaledInset, dy: -thumbnailScaledInset))
                }
                
                if let fullSizeImage = fullSizeImage {
                    let cgImage = fullSizeImage
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    c.draw(cgImage, in: fittedRect)
                }
            })
            
            return context
        })
    }
}


private func chatMessageStickerPackThumbnailData(postbox: Postbox, representation: TelegramMediaImageRepresentation, synchronousLoad: Bool) -> Signal<Data?, NoError> {
    let resource = representation.resource
    
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: CGSize(width: 120.0, height: 120.0)), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
        |> take(1)
        |> mapToSignal { maybeData in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(loadedData)
            } else {
                let fullSizeData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: CGSize(width: 120.0, height: 120.0)), complete: false)
                    |> map { next in
                        return (!next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
                }
                
                return Signal { subscriber in
                    let fetch: Disposable? = nil
                    let disposable = fullSizeData.start(next: { next in
                        subscriber.putNext(next.0)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    
                    return ActionDisposable {
                        fetch?.dispose()
                        disposable.dispose()
                    }
                }
            }
    }
}




public func chatMessageStickerPackThumbnail(postbox: Postbox, representation: TelegramMediaImageRepresentation, scale: CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessageStickerPackThumbnailData(postbox: postbox, representation: representation, synchronousLoad: synchronousLoad)
    
    return signal
        |> map { fullSizeData in
            return ImageDataTransformation(data: ImageRenderData.init(nil, fullSizeData, fullSizeData != nil), execute: { arguments, data in
                let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: arguments.emptyColor == nil)
                
                let drawingRect = arguments.drawingRect
                let fittedSize = arguments.imageSize
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                var fullSizeImage: CGImage?
                if let fullSizeData = fullSizeData {
                    if let image = NSImage(data: fullSizeData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        fullSizeImage = image
                    }
                }
                
                context.withFlippedContext(isHighQuality: fullSizeImage != nil, { c in
                    if let color = arguments.emptyColor {
                        c.setBlendMode(.normal)
                        switch color {
                        case let .color(color):
                            c.setFillColor(color.cgColor)
                        default:
                            break
                        }
                        c.fill(drawingRect)
                    } else {
                        c.setBlendMode(.copy)
                    }
                    
                    if let fullSizeImage = fullSizeImage {
                        let cgImage = fullSizeImage
                        c.setBlendMode(.normal)
                        c.interpolationQuality = .medium
                        c.draw(cgImage, in: fittedRect)
                    }
                })
                
                return context
            })
    }
}



func chatWebpageSnippetPhotoData(account: Account, imageRefence: ImageMediaReference, small:Bool) -> Signal<Data?, NoError> {
    if let closestRepresentation = (small ? imageRefence.media.representationForDisplayAtSize(PixelDimensions(120, 120)) : largestImageRepresentation(imageRefence.media.representations)) {
        let resourceData = account.postbox.mediaBox.resourceData(closestRepresentation.resource) |> map { next in
            return !next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
        }
        
        return Signal { subscriber in
            let disposable = DisposableSet()
            
            disposable.add(resourceData.start(next: { data in
                subscriber.putNext(data)
                }, completed: {
                    subscriber.putCompletion()
            }))
            //account.postbox.mediaBox.fetchedResource(closestRepresentation.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .file)
            
            disposable.add(fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: imageRefence.userLocation, userContentType: imageRefence.userContentType, reference: imageRefence.resourceReference(closestRepresentation.resource), statsCategory: .file).start())
            return disposable
        }
    } else {
        return .never()
    }
}

func chatWebpageSnippetPhoto(account: Account, imageReference: ImageMediaReference, scale:CGFloat, small:Bool, synchronousLoad: Bool = false, secureIdAccessContext: SecureIdAccessContext? = nil, autoFetchFullSize: Bool = true) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessagePhotoDatas(postbox: account.postbox, imageReference: imageReference, autoFetchFullSize: autoFetchFullSize, synchronousLoad: synchronousLoad, secureIdAccessContext: secureIdAccessContext)
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale:scale, clear: true)
            
            let fullSizeData = data.fullSizeData
            let thumbnailData = data.thumbnailData
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize)
            switch arguments.resizeMode {
            case .none:
                break
            default:
                fittedSize = fittedSize.fitted(arguments.imageSize)
            }
            var fittedRect = CGRect(origin: CGPoint(x: floorToScreenPixels(System.backingScale, drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0), y: floorToScreenPixels(System.backingScale, drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0)), size: fittedSize)
            //
            //            let drawingRect = arguments.drawingRect
            //            var fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            //            var fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if data.fullSizeComplete {
                    let options = NSMutableDictionary()
                    //   options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                        switch arguments.resizeMode {
                        case .none:
                            fittedSize = image.backingSize.aspectFilled(arguments.boundingSize)//.fitted(image.backingSize)
                            fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                        default:
                            break
                        }
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, data.fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                        switch arguments.resizeMode {
                        case .none:
                            fittedSize = image.backingSize.aspectFilled(arguments.boundingSize)//.fitted(image.backingSize)
                            fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                        default:
                            break
                        }
                    }
                }
            }
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber

            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, { c in
                c.setBlendMode(.copy)
                
                if arguments.boundingSize != arguments.imageSize {
                    switch arguments.resizeMode {
                    case .blurBackground:
                        let blurSourceImage = thumbnailImage ?? fullSizeImage
                        
                        if let fullSizeImage = blurSourceImage {
                            let thumbnailSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height)
                            let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 74.0, height: 74.0))
                            let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                            thumbnailContext.withFlippedContext { c in
                                c.interpolationQuality = .none
                                c.draw(fullSizeImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                            }
                            telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                            
                            if let blurredImage = thumbnailContext.generateImage() {
                                let filledSize = thumbnailSize.aspectFilled(arguments.drawingRect.size)
                                c.interpolationQuality = .low
                                c.draw(blurredImage, in: CGRect(origin: CGPoint(x: arguments.drawingRect.minX + (arguments.drawingRect.width - filledSize.width) / 2.0, y: arguments.drawingRect.minY + (arguments.drawingRect.height - filledSize.height) / 2.0), size: filledSize))
                                c.setBlendMode(.normal)
                                c.setFillColor(theme.colors.background.withAlphaComponent(0.5).cgColor)
                                c.fill(arguments.drawingRect)
                                c.setBlendMode(.copy)
                            }
                        } else {
                            c.setBlendMode(.normal)
                            c.setFillColor(theme.colors.grayForeground.cgColor)
                            c.fill(arguments.drawingRect)
                        }
                    case let .fill(color):
                        c.setBlendMode(.normal)
                        c.setFillColor(color.cgColor)
                        c.fill(arguments.drawingRect)
                    case .fillTransparent:
                        c.setBlendMode(.normal)
                        c.setFillColor(theme.colors.transparentBackground.cgColor)
                        c.fill(arguments.drawingRect)
                    case .none:
                        c.setBlendMode(.normal)
                        c.setFillColor(theme.colors.grayForeground.cgColor)
                        c.fill(arguments.drawingRect)
                    case .imageColor:
                        break
                    }
                }
                
                c.setBlendMode(.copy)
                if let cgImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
                
                if blurredThumbnailImage == nil && fullSizeImage == nil && arguments.boundingSize == arguments.imageSize {
                    c.setBlendMode(.normal)
                    c.setFillColor(theme.colors.grayForeground.cgColor)
                    c.fill(arguments.drawingRect)
                }
            })
            
            addCorners(context, arguments: arguments, scale:scale)
            
            return context
        })
    }
}



func chatMessagePhotoStatus(account: Account, photo: TelegramMediaImage, approximateSynchronousValue: Bool = false, dimension: NSSize = NSMakeSize(1280, 1280)) -> Signal<MediaResourceStatus, NoError> {
    if let largest = photo.representationForDisplayAtSize(PixelDimensions(dimension)) {
        if largest.resource is LocalFileReferenceMediaResource {
            return .single(.Local)
        } else {
            return account.postbox.mediaBox.resourceStatus(largest.resource, approximateSynchronousValue: approximateSynchronousValue)
        }
    } else {
        return .never()
    }
}



func chatMessagePhotoInteractiveFetched(account: Account, imageReference: ImageMediaReference, toRepresentationSize: NSSize = NSMakeSize(1280, 1280)) -> Signal<Void, NoError> {
    
    if let large = imageReference.media.representationForDisplayAtSize(.init(toRepresentationSize)) {
        let rangeValue = representationFetchRangeForDisplayAtSize(representation: large, dimension: nil)
        let range: (Range<Int64>, MediaBoxFetchPriority)?
        if let rangeValue = rangeValue {
            range = (rangeValue, .elevated)
        } else {
            range = nil
        }
        return fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: imageReference.userLocation, userContentType: imageReference.userContentType, reference: imageReference.resourceReference(large.resource), range: range, statsCategory: .image) |> `catch` { _ in return .complete() } |> map {_ in}
    } else {
        return .never()
    }
}

func chatMessagePhotoCancelInteractiveFetch(account: Account, photo: TelegramMediaImage, toRepresentationSize: NSSize = NSMakeSize(1280, 1280)) {
    if let large = photo.representationForDisplayAtSize(.init(toRepresentationSize)) {
        return account.postbox.mediaBox.cancelInteractiveResourceFetch(large.resource)
    }
}

func fileInteractiveFetched(account: Account, fileReference: FileMediaReference) -> Signal<Void, NoError> {
    return fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: fileReference.userLocation, userContentType: fileReference.userContentType, reference: fileReference.resourceReference(fileReference.media.resource), statsCategory: .file) |> `catch` { _ in return .complete() } |> map {_ in}
}

func fileCancelInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
}


public func blurImage(_ data:Data?, _ s:NSSize, cornerRadius:CGFloat = 0) -> CGImage? {
    
    let options = NSMutableDictionary()
    options[kCGImageSourceShouldCache as NSString] = false as NSNumber

    
    var thumbnailImage: CGImage?
    if let idata = data, let imageSource = CGImageSourceCreateWithData(idata as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
        thumbnailImage = image
    }
    var blurredThumbnailImage: CGImage?

    if let thumbnailImage = thumbnailImage {
        let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
        let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 300.0, height: 300.0))
        let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
        thumbnailContext.withContext { ctx in
            ctx.interpolationQuality = .none
            
            ctx.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
        }
        telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
        
        blurredThumbnailImage = thumbnailContext.generateImage()

        if cornerRadius > 0 {
            
           let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 2.0)

            thumbnailContext.withContext({ (ctx) in
                let minx:CGFloat = 0, midx = thumbnailContextSize.width/2.0, maxx = thumbnailContextSize.width
                let miny:CGFloat = 0, midy = thumbnailContextSize.height/2.0, maxy = thumbnailContextSize.height
                
                ctx.move(to: NSMakePoint(minx, midy))
                ctx.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: cornerRadius)
                ctx.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: cornerRadius)
                ctx.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: cornerRadius)
                ctx.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: cornerRadius)
                
                ctx.closePath()
                ctx.clip()
   
                ctx.draw(blurredThumbnailImage!, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                
            })
            
            blurredThumbnailImage = thumbnailContext.generateImage()
        }
    }
    
    return blurredThumbnailImage
}



private func chatMessageVideoDatas(postbox: Postbox, fileReference: FileMediaReference, thumbnailSize: Bool = false, onlyFullSize: Bool = false, synchronousLoad: Bool = false) -> Signal<ImageRenderData, NoError> {
    
    let fetchedFullSize = postbox.mediaBox.cachedResourceRepresentation(fileReference.media.resource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: true, attemptSynchronously: synchronousLoad)
    
    let maybeFullSize = postbox.mediaBox.cachedResourceRepresentation(fileReference.media.resource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    let signal = maybeFullSize
        |> take(1)
        |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
            if maybeData.complete {
                let loadedData: Data?
                loadedData = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(ImageRenderData(nil, loadedData, true))
            } else {
                let decodedThumbnailData = fileReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail)
                let fetchedThumbnail: Signal<FetchResourceSourceType, NoError>
                if let smallestRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                    fetchedThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: fileReference.userLocation, userContentType: fileReference.userContentType, reference: fileReference.resourceReference(smallestRepresentation.resource), statsCategory: .image) |> `catch` { _ in return .complete() }
                } else {
                    fetchedThumbnail = .complete()
                }
                
                let mainThumbnail = Signal<ImageRenderData, NoError> { subscriber in
                    if let decodedThumbnailData = decodedThumbnailData {
                        subscriber.putNext(ImageRenderData(decodedThumbnailData, nil, true))
                    }
                    
                    let fetchedDisposable = fetchedThumbnail.start()
                    var thumbnailDisposable: Disposable? = nil
                    if let smallestRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        thumbnailDisposable = postbox.mediaBox.resourceData(smallestRepresentation.resource, attemptSynchronously: synchronousLoad).start(next: { next in
                            subscriber.putNext(ImageRenderData(!next.complete ? decodedThumbnailData : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), nil, !next.complete))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                    } else if decodedThumbnailData == nil {
                        subscriber.putNext(ImageRenderData(nil, nil, true))
                    }
                   
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable?.dispose()
                    }
                }
                
                let thumbnail = mainThumbnail
                
                let fullSizeData: Signal<ImageRenderData, NoError>
                
                fullSizeData = fetchedFullSize
                    |> map { next -> ImageRenderData in
                        return ImageRenderData(nil, next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                }
                
                return thumbnail
                    |> mapToSignal { thumbnailData in
                        let isThumb = thumbnailData.fullSizeComplete
                        return fullSizeData
                            |> map { fullSizeData in
                                if !isThumb && !fullSizeData.fullSizeComplete {
                                    return ImageRenderData(nil, thumbnailData.thumbnailData, false)
                                } else {
                                    return ImageRenderData(fullSizeData.fullSizeComplete ? nil : thumbnailData.thumbnailData, fullSizeData.fullSizeData, fullSizeData.fullSizeComplete)
                                }
                            }
                }
            }
    }
    return signal
    
    
//    let image = TelegramMediaImage(imageId: fileReference.media.id ?? MediaId(namespace: 0, id: 0), representations: fileReference.media.previewRepresentations, immediateThumbnailData: fileReference.media.immediateThumbnailData, reference: nil, partialReference: fileReference.media.partialReference)
//    let imageReference: ImageMediaReference
//    switch fileReference {
//    case let .message(message, _):
//        imageReference = ImageMediaReference.message(message: message, media: image)
//    case .savedGif:
//        imageReference = ImageMediaReference.savedGif(media: image)
//    case .standalone:
//        imageReference = ImageMediaReference.standalone(media: image)
//    case let .stickerPack(stickerPack, _):
//        imageReference = ImageMediaReference.stickerPack(stickerPack: stickerPack, media: image)
//    case let .webPage(webPage, _):
//        imageReference = ImageMediaReference.webPage(webPage: webPage, media: image)
//    }
//
//    return chatMessagePhotoDatas(postbox: postbox, imageReference: imageReference, autoFetchFullSize: true, synchronousLoad: synchronousLoad)
//
//    let fullSizeResource = fileReference.media.resource
//
//    let thumbnailResource = smallestImageRepresentation(fileReference.media.previewRepresentations)?.resource
//
//    let maybeFullSize = postbox.mediaBox.cachedResourceRepresentation(fullSizeResource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
//    let fetchedFullSize = postbox.mediaBox.cachedResourceRepresentation(fullSizeResource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: true, attemptSynchronously: synchronousLoad)
//
//    let signal = maybeFullSize
//        |> take(1)
//        |> mapToSignal { maybeData -> Signal<(Atomic<Data?>, (Atomic<Data>, String)?, Bool), NoError> in
//            if maybeData.complete {
//                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
//
//                return .single((Atomic(value: nil), loadedData == nil ? nil : (Atomic(value: loadedData!), maybeData.path), true))
//            } else {
//                let thumbnail: Signal<Atomic<Data?>, NoError>
//                if onlyFullSize {
//                    thumbnail = .single(Atomic(value: nil))
//                } else if let decodedThumbnailData = fileReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail) {
//                    thumbnail = .single(Atomic(value: decodedThumbnailData))
//                } else if let thumbnailResource = thumbnailResource {
//                    thumbnail = Signal { subscriber in
//                        let fetchedDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource), statsCategory: .video).start()
//                        let thumbnailDisposable = postbox.mediaBox.resourceData(thumbnailResource, attemptSynchronously: synchronousLoad).start(next: { next in
//                            subscriber.putNext(Atomic(value: next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: [])))
//                        }, error: subscriber.putError, completed: subscriber.putCompletion)
//
//                        return ActionDisposable {
//                            fetchedDisposable.dispose()
//                            thumbnailDisposable.dispose()
//                        }
//                    }
//                } else {
//                    thumbnail = .single(Atomic(value: nil))
//                }
//
//                let fullSizeDataAndPath = Signal<MediaResourceData, NoError> { subscriber in
//                    let dataDisposable = fetchedFullSize.start(next: { next in
//                        subscriber.putNext(next)
//                    }, completed: {
//                        subscriber.putCompletion()
//                    })
//                    //let fetchedDisposable = fetchedPartialVideoThumbnailData(postbox: postbox, fileReference: fileReference).start()
//                    return ActionDisposable {
//                        dataDisposable.dispose()
//                        //fetchedDisposable.dispose()
//                    }
//                } |> map { next -> ((Atomic<Data>, String)?, Bool) in
//                    let data = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
//                    return (data == nil ? nil : (Atomic(value: data!), next.path), next.complete)
//                }
//
//                return thumbnail
//                    |> mapToSignal { thumbnailData in
//                        return fullSizeDataAndPath
//                            |> map { (dataAndPath, complete) in
//                                return (thumbnailData, dataAndPath, complete)
//                        }
//                }
//            }
//        } |> filter({
//            if onlyFullSize {
//                return $0.1 != nil || $0.2
//            } else {
//                return true//$0.0 != nil || $0.1 != nil || $0.2
//            }
//        })
//
//    return signal
}



func chatMessageVideo(postbox: Postbox, fileReference: FileMediaReference, scale: CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    return mediaGridMessageVideo(postbox: postbox, fileReference: fileReference, scale: scale, synchronousLoad: synchronousLoad)
}


private func chatSecretMessageVideoData(account: Account, fileReference: FileMediaReference, synchronousLoad: Bool = false) -> Signal<ImageRenderData, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
        let thumbnailResource = smallestRepresentation.resource
        
        let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: fileReference.userLocation, userContentType: fileReference.userContentType, reference: fileReference.resourceReference(thumbnailResource), statsCategory: .video)
        
        let thumbnail = Signal<ImageRenderData, NoError> { subscriber in
            let fetchedDisposable = fetchedThumbnail.start()
            let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource, attemptSynchronously: synchronousLoad).start(next: { next in
                subscriber.putNext(ImageRenderData(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path)), nil, true))
            }, error: subscriber.putError, completed: subscriber.putCompletion)
            
            return ActionDisposable {
                fetchedDisposable.dispose()
                thumbnailDisposable.dispose()
            }
        }
        return thumbnail
    } else {
        return .single(ImageRenderData(nil, nil, false))
    }
}

func chatSecretMessageVideo(account: Account, fileReference: FileMediaReference, scale:CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatSecretMessageVideoData(account: account, fileReference: fileReference, synchronousLoad: synchronousLoad)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            if arguments.drawingSize.width.isLessThanOrEqualTo(0.0) || arguments.drawingSize.height.isLessThanOrEqualTo(0.0) {
                return context
            }
            
            let thumbnailData = data.thumbnailData
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var blurredImage: CGImage?
            
            if blurredImage == nil {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber

                if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                    let thumbnailSize = CGSize(width: image.width, height: image.height)
                    let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withContext { c in
                        c.interpolationQuality = .none
                        c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                    let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0)
                    thumbnailContext2.withContext { c in
                        c.interpolationQuality = .none
                        if let image = thumbnailContext.generateImage() {
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                        }
                    }
                    telegramFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                    
                    blurredImage = thumbnailContext2.generateImage()
                }
            }
            
            context.withContext({ c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    //c.setFillColor(NSColor(white: 0.0, alpha: 0.4).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let cgImage = blurredImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                }
                
                if !arguments.insets.left.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(), size: CGSize(width: arguments.insets.left, height: context.size.height)))
                }
                if !arguments.insets.right.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(x: context.size.width - arguments.insets.right, y: 0.0), size: CGSize(width: arguments.insets.right, height: context.size.height)))
                }
            })
            
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        })
    }
}



private enum Corner: Hashable {
    case TopLeft(Int), TopRight(Int), BottomLeft(Int), BottomRight(Int)
    
    var hashValue: Int {
        switch self {
        case let .TopLeft(radius):
            return radius | (1 << 24)
        case let .TopRight(radius):
            return radius | (2 << 24)
        case let .BottomLeft(radius):
            return radius | (3 << 24)
        case let .BottomRight(radius):
            return radius | (2 << 24)
        }
    }
    
    var radius: Int {
        switch self {
        case let .TopLeft(radius):
            return radius
        case let .TopRight(radius):
            return radius
        case let .BottomLeft(radius):
            return radius
        case let .BottomRight(radius):
            return radius
        }
    }
}



private enum Tail: Hashable {
    case BottomLeft(Int)
    case BottomRight(Int)
    
    var hashValue: Int {
        switch self {
        case let .BottomLeft(radius):
            return radius | (1 << 24)
        case let .BottomRight(radius):
            return radius | (2 << 24)
        }
    }
    
    var radius: Int {
        switch self {
        case let .BottomLeft(radius):
            return radius
        case let .BottomRight(radius):
            return radius
        }
    }
}

private func ==(lhs: Tail, rhs: Tail) -> Bool {
    switch lhs {
    case let .BottomLeft(lhsRadius):
        switch rhs {
        case let .BottomLeft(rhsRadius) where rhsRadius == lhsRadius:
            return true
        default:
            return false
        }
    case let .BottomRight(lhsRadius):
        switch rhs {
        case let .BottomRight(rhsRadius) where rhsRadius == lhsRadius:
            return true
        default:
            return false
        }
    }
}


private func cornerContext(_ corner: Corner, scale:CGFloat) -> DrawingContext {
    var cached: DrawingContext?

    
    let context = DrawingContext(size: CGSize(width: CGFloat(corner.radius), height: CGFloat(corner.radius)), scale: scale, clear: true)
    
    context.withContext { c in
        c.setBlendMode(.copy)
        c.setFillColor(NSColor.black.cgColor)
        let rect: CGRect
        switch corner {
        case let .TopLeft(radius):
            rect = CGRect(origin: CGPoint(x: 0.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
        case let .TopRight(radius):
            rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
        case let .BottomLeft(radius):
            rect = CGRect(origin: CGPoint(), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
        case let .BottomRight(radius):
            rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: 0.0), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
        }
        c.fillEllipse(in: rect)
    }
    return context
}

private func tailContext(_ tail: Tail, scale:CGFloat) -> DrawingContext {
    var cached: DrawingContext?

    
    if let cached = cached {
        return cached
    } else {
        let context = DrawingContext(size: CGSize(width: CGFloat(tail.radius) + 3.0, height: CGFloat(tail.radius)), scale:scale, clear: true)
        
        context.withContext { c in
            c.setBlendMode(.copy)
            c.setFillColor(NSColor.black.cgColor)
            let rect: CGRect
            switch tail {
            case let .BottomLeft(radius):
                rect = CGRect(origin: CGPoint(x: 3.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                
                c.move(to: CGPoint(x: 3.0, y: 0.0))
                c.addLine(to: CGPoint(x: 3.0, y: 8.7))
                c.addLine(to: CGPoint(x: 2.0, y: 11.7))
                c.addLine(to: CGPoint(x: 1.5, y: 12.7))
                c.addLine(to: CGPoint(x: 0.8, y: 13.7))
                c.addLine(to: CGPoint(x: 0.2, y: 14.4))
                c.addLine(to: CGPoint(x: 3.5, y: 13.8))
                c.addLine(to: CGPoint(x: 5.0, y: 13.2))
                c.addLine(to: CGPoint(x: 3.0 + CGFloat(radius) - 9.5, y: 11.5))
                c.closePath()
                c.fillPath()
            case let .BottomRight(radius):
                rect = CGRect(origin: CGPoint(x: -CGFloat(radius) + 3.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                
                /*CGContextMoveToPoint(c, 3.0, 0.0)
                 CGContextAddLineToPoint(c, 3.0, 8.7)
                 CGContextAddLineToPoint(c, 2.0, 11.7)
                 CGContextAddLineToPoint(c, 1.5, 12.7)
                 CGContextAddLineToPoint(c, 0.8, 13.7)
                 CGContextAddLineToPoint(c, 0.2, 14.4)
                 CGContextAddLineToPoint(c, 3.5, 13.8)
                 CGContextAddLineToPoint(c, 5.0, 13.2)
                 CGContextAddLineToPoint(c, 3.0 + CGFloat(radius) - 9.5, 11.5)
                 CGContextClosePath(c)
                 CGContextFillPath(c)*/
            }
            c.fillEllipse(in: rect)
        }
        
        return context
    }
}



func addCorners(_ context: DrawingContext, arguments: TransformImageArguments, scale:CGFloat) {
    let corners = arguments.corners
    let drawingRect = arguments.drawingRect
    
    if case let .Corner(radius) = corners.topLeft, radius > CGFloat.ulpOfOne {
        let corner = cornerContext(.TopLeft(Int(radius)), scale:scale)
        context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.minY))
    }
    
    if case let .Corner(radius) = corners.topRight, radius > CGFloat.ulpOfOne {
        let corner = cornerContext(.TopRight(Int(radius)), scale:scale)
        context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.minY))
    }
    
    switch corners.bottomLeft {
    case let .Corner(radius):
        if radius > CGFloat.ulpOfOne {
            let corner = cornerContext(.BottomLeft(Int(radius)), scale:scale)
            context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.maxY - radius))
        }
    case let .Tail(radius):
        if radius > CGFloat.ulpOfOne {
            let tail = tailContext(.BottomLeft(Int(radius)), scale:scale)
            let color = context.colorAt(CGPoint(x: drawingRect.minX, y: drawingRect.maxY - 1.0))
            context.withContext { c in
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: 0.0, y: drawingRect.maxY - 6.0, width: 3.0, height: 6.0))
            }
            context.blt(tail, at: CGPoint(x: drawingRect.minX - 3.0, y: drawingRect.maxY - radius))
        }
        
    }
    
    switch corners.bottomRight {
    case let .Corner(radius):
        if radius > CGFloat.ulpOfOne {
            let corner = cornerContext(.BottomRight(Int(radius)), scale:scale)
            context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.maxY - radius))
        }
    case let .Tail(radius):
        if radius > CGFloat.ulpOfOne {
            let tail = tailContext(.BottomRight(Int(radius)), scale:scale)
            context.blt(tail, at: CGPoint(x: drawingRect.maxX - radius - 3.0, y: drawingRect.maxY - radius))
        }
    }
}


func mediaGridMessagePhoto(account: Account, imageReference: ImageMediaReference, scale:CGFloat, autoFetchFullSize: Bool = true) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessagePhotoDatas(postbox: account.postbox, imageReference: imageReference, fullRepresentationSize: CGSize(width: 240, height: 240), autoFetchFullSize: autoFetchFullSize)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, scale:scale, clear: true)
            
            let thumbnailData = data.thumbnailData
            let fullSizeData = data.fullSizeData
            let fullSizeComplete = data.fullSizeComplete
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber

                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber

            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withContext(isHighQuality: fullSizeImage != nil, { c in
                c.setBlendMode(.copy)
             //   c.setFillColor(theme.colors.grayBackground.cgColor)
                if arguments.boundingSize != arguments.imageSize {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(blurredThumbnailImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
                
                if arguments.boundingSize == arguments.imageSize && fullSizeImage == nil && blurredThumbnailImage == nil {
                    c.setBlendMode(.normal)
                    c.fill(arguments.drawingRect)
                }
            })
            
            addCorners(context, arguments: arguments, scale:scale)
            
            return context
        })
    }
}



func chatMessageVideoThumbnail(account: Account, fileReference: FileMediaReference, scale: CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessageVideoDatas(postbox: account.postbox, fileReference: fileReference, thumbnailSize: true, synchronousLoad: synchronousLoad)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let thumbnailData = data.thumbnailData
            let fullSizeData = data.fullSizeData
            let fullSizeComplete = data.fullSizeComplete
            
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber

            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    //c.setFillColor(NSColor(white: 0.0, alpha: 0.4).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let cgImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            })
            
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        })
    }
}


func mediaGridMessageVideo(postbox: Postbox, fileReference: FileMediaReference, scale: CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessageVideoDatas(postbox: postbox, fileReference: fileReference, synchronousLoad: synchronousLoad)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let thumbnailData = data.thumbnailData
            let fullSizeData = data.fullSizeData
            let fullSizeComplete = data.fullSizeComplete
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            if fittedSize.width < drawingRect.size.width && fittedSize.width >= drawingRect.size.width - 2.0 {
                fittedSize.width = drawingRect.size.width
            }
            if fittedSize.height < drawingRect.size.height && fittedSize.height >= drawingRect.size.height - 2.0 {
                fittedSize.height = drawingRect.size.height
            }
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber

            var thumbnailImage: CGImage?
            if fullSizeImage == nil, let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: fullSizeImage != nil, { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    switch arguments.resizeMode {
                    case .blurBackground:
                        let blurSourceImage = thumbnailImage ?? fullSizeImage
                        
                        if let image = blurSourceImage {
                            let thumbnailSize = CGSize(width: image.width, height: image.height)
                            let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 74.0, height: 74.0))
                            let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                            thumbnailContext.withFlippedContext { c in
                                c.interpolationQuality = .none
                                c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                            }
                            //   telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                            telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                            
                            if let blurredImage = thumbnailContext.generateImage() {
                                let filledSize = thumbnailSize.aspectFilled(arguments.drawingRect.size)
                                c.interpolationQuality = .medium
                                c.draw(blurredImage, in: CGRect(origin: CGPoint(x: arguments.drawingRect.minX + (arguments.drawingRect.width - filledSize.width) / 2.0, y: arguments.drawingRect.minY + (arguments.drawingRect.height - filledSize.height) / 2.0), size: filledSize))
                                c.setBlendMode(.normal)
                                c.setFillColor(theme.colors.background.withAlphaComponent(0.5).cgColor)
                                c.fill(arguments.drawingRect)
                                c.setBlendMode(.copy)
                            }
                            
                            let value = arguments.imageSize.aspectFitted(arguments.boundingSize)
                            
                            if let fullSizeImage = fullSizeImage {
                                c.interpolationQuality = .medium
                                c.draw(fullSizeImage, in: NSMakeRect((arguments.boundingSize.width - value.width) / 2, (arguments.boundingSize.height - value.height) / 2, value.width, value.height))
                            }

                            
                        } else {
                            c.fill(arguments.drawingRect)
                        }
                    case let .fill(color):
                        c.setFillColor(color.cgColor)
                        c.fill(arguments.drawingRect)
                    case .fillTransparent:
                        c.setFillColor(theme.colors.transparentBackground.cgColor)
                        c.fill(arguments.drawingRect)
                    case .none:
                        c.setBlendMode(.copy)
                        if let cgImage = blurredThumbnailImage {
                            c.interpolationQuality = .low
                            c.draw(cgImage, in: fittedRect)
                            c.setBlendMode(.normal)
                        }
                        
                        if let fullSizeImage = fullSizeImage {
                            c.interpolationQuality = .medium
                            c.draw(fullSizeImage, in: fittedRect)
                        }
                    case .imageColor:
                        break
                    }
                } else {
                    c.setBlendMode(.copy)
                    if let cgImage = blurredThumbnailImage {
                        c.interpolationQuality = .low
                        c.draw(cgImage, in: fittedRect)
                        c.setBlendMode(.normal)
                    }
                    
                    if let fullSizeImage = fullSizeImage {
                        c.interpolationQuality = .medium
                        c.draw(fullSizeImage, in: fittedRect)
                    }
                }
            })
            
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        })
    }
}


private func imageFromAJpeg(data: Data) -> (CGImage, CGImage)? {
    if let (colorData, alphaData) = data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> (Data, Data)? in
        var colorSize: Int32 = 0
        memcpy(&colorSize, bytes, 4)
        if colorSize < 0 || Int(colorSize) > data.count - 8 {
            return nil
        }
        var alphaSize: Int32 = 0
        memcpy(&alphaSize, bytes.advanced(by: 4 + Int(colorSize)), 4)
        if alphaSize < 0 || Int(alphaSize) > data.count - Int(colorSize) - 8 {
            return nil
        }
        //let colorData = Data(bytesNoCopy: UnsafeMutablePointer(mutating: bytes).advanced(by: 4), count: Int(colorSize), deallocator: .none)
        //let alphaData = Data(bytesNoCopy: UnsafeMutablePointer(mutating: bytes).advanced(by: 4 + Int(colorSize) + 4), count: Int(alphaSize), deallocator: .none)
        let colorData = data.subdata(in: 4 ..< (4 + Int(colorSize)))
        let alphaData = data.subdata(in: (4 + Int(colorSize) + 4) ..< (4 + Int(colorSize) + 4 + Int(alphaSize)))
        return (colorData, alphaData)
    }) {
        let options = NSMutableDictionary()
        options[kCGImageSourceShouldCache as NSString] = false as NSNumber

        let sourceColor:CGImageSource? = CGImageSourceCreateWithData(colorData as CFData, options);
        let sourceAlpha:CGImageSource? = CGImageSourceCreateWithData(alphaData as CFData, options);
        
         if let sourceColor = sourceColor, let sourceAlpha = sourceAlpha {
            
            let colorImage =  CGImageSourceCreateImageAtIndex(sourceColor, 0, options);
            let alphaImage =  CGImageSourceCreateImageAtIndex(sourceAlpha, 0, options);
            if let colorImage = colorImage, let alphaImage = alphaImage {
                return (colorImage, alphaImage)
            }
        }
    }
    return nil
}


public func putToTemp(image:NSImage, compress: Bool = true) -> Signal<String, NoError> {
    return Signal { (subscriber) in

        
        let path = NSTemporaryDirectory() + "tg_image_\(arc4random()).jpeg"
        if compress {
            if let data = compressImageToJPEG(image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, quality: compress ? 0.83 : 1.0) {
                let path = NSTemporaryDirectory() + "tg_image_\(arc4random()).jpeg"
                try? data.write(to: URL(fileURLWithPath: path))
                subscriber.putNext(path)
            }
        } else {
            let options = NSMutableDictionary()
            let mutableData: CFMutableData = NSMutableData() as CFMutableData
            if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) {
                CGImageDestinationAddImage(colorDestination, image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, options as CFDictionary)
                if CGImageDestinationFinalize(colorDestination) {
                    try? (mutableData as Data).write(to: URL(fileURLWithPath: path))
                    subscriber.putNext(path)
                }
            }
        }
        
       
            

        
        
        
        
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(resourcesQueue)
}


public func filethumb(with url:URL, account:Account, scale:CGFloat) -> Signal<ImageDataTransformation, NoError> {
    return Signal<Data?, NoError> { (subscriber) in
        
        let data = try? Data(contentsOf: url)
        subscriber.putNext(data)
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> map { data in
        return ImageDataTransformation(data: ImageRenderData(data, nil, true), execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale:scale, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var thumb: CGImage?
            if let thumbnailData = data.thumbnailData {
                let options = NSMutableDictionary()
                options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber

                if let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                    thumb = image
                }
            }
            
            if let thumb = thumb {
                context.withContext({ (ctx) in
                    ctx.setBlendMode(.copy)
                    ctx.interpolationQuality = .medium
                    ctx.draw(thumb, in: fittedRect)
                })
            }
            addCorners(context, arguments: arguments, scale:scale)
            
            return context
        })
    }
    
}



func chatSecretPhoto(account: Account, imageReference: ImageMediaReference, scale:CGFloat, synchronousLoad: Bool = false, onlyThumbnail: Bool = true) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessagePhotoDatas(postbox: account.postbox, imageReference: imageReference, fullRepresentationSize: NSMakeSize(100, 100), synchronousLoad: synchronousLoad, useMiniThumbnailIfAvailable: true, onlyThumbnail: onlyThumbnail)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let fullSizeData: Data? = data.fullSizeData
            let thumbnailData = data.thumbnailData
            let fullSizeComplete = data.fullSizeComplete
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var blurredImage: CGImage?
            
            if let fullSizeData = fullSizeData, !onlyThumbnail || thumbnailData == nil {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        let thumbnailSize = CGSize(width: image.width, height: image.height)
                        let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
                        let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                        thumbnailContext.withContext { c in
                            c.interpolationQuality = .none
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                        }
                        telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                        
                        let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                        let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0)
                        thumbnailContext2.withContext { c in
                            c.interpolationQuality = .none
                            if let image = thumbnailContext.generateImage() {
                                c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                            }
                        }
                        telegramFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                        
                        blurredImage = thumbnailContext2.generateImage()
                    }
                }/* else {
                 let imageSource = CGImageSourceCreateIncremental(nil)
                 CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                 
                 let options = NSMutableDictionary()
                 options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                 if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                 fullSizeImage = image
                 }
                 }*/
            }
            
            if blurredImage == nil {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber

                if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                    let thumbnailSize = CGSize(width: image.width, height: image.height)
                    let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                    let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0)
                    thumbnailContext2.withFlippedContext { c in
                        c.interpolationQuality = .none
                        if let image = thumbnailContext.generateImage() {
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                        }
                    }
                    telegramFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                    
                    blurredImage = thumbnailContext2.generateImage()
                }
            }
            
            context.withContext { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    //c.setFillColor(NSColor(white: 0.0, alpha: 0.4).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let cgImage = blurredImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                }
                
                if !arguments.insets.left.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(), size: CGSize(width: arguments.insets.left, height: context.size.height)))
                }
                if !arguments.insets.right.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(x: context.size.width - arguments.insets.right, y: 0.0), size: CGSize(width: arguments.insets.right, height: context.size.height)))
                }
            }
            
            addCorners(context, arguments: arguments, scale:scale)
            
            return context
        })
    }
}


func chatMessageImageFile(account: Account, fileReference: FileMediaReference, progressive: Bool = false, scale: CGFloat, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessageFileDatas(account: account, fileReference: fileReference, progressive: progressive, justThumbail: true, synchronousLoad: synchronousLoad)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize)//.fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: floorToScreenPixels(System.backingScale, drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0), y: floorToScreenPixels(System.backingScale, drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0)), size: fittedSize)
            
            
            
            var fullSizeImage: CGImage?
            
            if let fullSizeData = data.fullSizeData {
                let options = NSMutableDictionary()
               // options.setValue(max(fittedSize.width * 3, fittedSize.height * 3) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCache as String)
                options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCacheImmediately as String)
              //  options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)

                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options) {
                    if let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    } else if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                        fullSizeImage = image
                    }
                }
            }
            
            let options = NSMutableDictionary()
          //  options.setValue(max(fittedSize.width * 3, fittedSize.height * 3) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
            options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCache as String)
            options.setValue(false as NSNumber, forKey: kCGImageSourceShouldCacheImmediately as String)
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)

            
            var thumbnailImage: CGImage?
            if let thumbnailData = data.thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage, fullSizeImage == nil {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: data.fullSizeData != nil, { c in
                //c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    c.setFillColor(theme.colors.transparentBackground.cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                //  c.setBlendMode(.copy)
                if let cgImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    if arguments.emptyColor == nil {
                        c.interpolationQuality = .medium
                        c.setFillColor(theme.colors.transparentBackground.cgColor)
                        c.fill(fittedRect)
                    }
                    c.draw(fullSizeImage, in: fittedRect)
                }
            })
            
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        })
    }
}


private func chatMessagePhotoThumbnailDatas(account: Account, imageReference: ImageMediaReference, synchronousLoad: Bool = false, secureIdAccessContext: SecureIdAccessContext? = nil) -> Signal<ImageRenderData, NoError> {
    let fullRepresentationSize: CGSize = CGSize(width: 1280.0, height: 1280.0)
    if let smallestRepresentation = smallestImageRepresentation(imageReference.media.representations), let largestRepresentation = imageReference.media.representationForDisplayAtSize(PixelDimensions(fullRepresentationSize)) {
        
        let size = CGSize(width: 160.0, height: 160.0)
        let maybeFullSize: Signal<MediaResourceData, NoError>
            
        if largestRepresentation.resource is EncryptedMediaResource {
            maybeFullSize = account.postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: synchronousLoad)
        } else {
            maybeFullSize = account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedScaledImageRepresentation(size: size), complete: false, attemptSynchronously: synchronousLoad)
        }
        
        let signal = maybeFullSize
            |> take(1)
            |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
            if maybeData.complete {
                if largestRepresentation.resource is EncryptedMediaResource, let secureIdAccessContext = secureIdAccessContext {
                    let loadedData: Data? = decryptedResourceData(data: maybeData, resource: largestRepresentation.resource, params: secureIdAccessContext)
                    return .single(ImageRenderData(nil, loadedData, true))
                } else {
                    let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                    return .single(ImageRenderData(nil, loadedData, true))
                }
                
            } else {
                
                let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: imageReference.userLocation, userContentType: imageReference.userContentType, reference: imageReference.resourceReference(smallestRepresentation.resource), statsCategory: .image)//account.postbox.mediaBox.fetchedResource(smallestRepresentation.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image))
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(smallestRepresentation.resource, attemptSynchronously: synchronousLoad).start(next: { next in
                        subscriber.putNext(!next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                let maybeFullData: Signal<MediaResourceData, NoError>
                
                if largestRepresentation.resource is EncryptedMediaResource {
                    maybeFullData = account.postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: synchronousLoad)
                } else {
                    maybeFullData = account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedScaledImageRepresentation(size: size), complete: false, attemptSynchronously: synchronousLoad)
                }
                
                let fullSizeData: Signal<ImageRenderData, NoError> = maybeFullData
                    |> map { next -> ImageRenderData in
                        return ImageRenderData(nil, !next.complete ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                }
                
                return thumbnail |> mapToSignal { thumbnailData in
                    return fullSizeData |> map { fullData in
                        return ImageRenderData(thumbnailData, fullData.fullSizeData, fullData.fullSizeComplete)
                    }
                }
            }
            } |> filter({ $0.thumbnailData != nil || $0.fullSizeData != nil })
        
        return signal
    } else {
        return .never()
    }
}

func chatMessagePhotoThumbnail(account: Account,  imageReference: ImageMediaReference, scale: CGFloat = System.backingScale, synchronousLoad: Bool = false, secureIdAccessContext: SecureIdAccessContext? = nil) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMessagePhotoThumbnailDatas(account: account, imageReference: imageReference, synchronousLoad: synchronousLoad, secureIdAccessContext: secureIdAccessContext)
    
    return signal |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let fullSizeData = data.fullSizeData
            let thumbnailData = data.thumbnailData
            let fullSizeComplete = data.fullSizeComplete
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    /*let options = NSMutableDictionary()
                     options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                     options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                     if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                     fullSizeImage = image
                     }*/
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber

                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber

            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext(isHighQuality: fullSizeImage != nil, { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    //c.setFillColor(NSColor(white: 0.0, alpha: 0.4).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                
                c.setBlendMode(.copy)
                if let cgImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            })
            
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        })
    }
}

private func builtinWallpaperData() -> Signal<ImageRenderData, NoError> {
    return Signal { subscriber in
        if let filePath = Bundle.main.path(forResource: "builtin-wallpaper-svg", ofType: nil), let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            if let data = TGGUnzipData(data, 8 * 1024 * 1024) {
                subscriber.putNext(ImageRenderData(nil, data, true))
            }
        }
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}

func settingsBuiltinWallpaperImage(account: Account, scale: CGFloat = 2.0) -> Signal<ImageDataTransformation, NoError> {
    return builtinWallpaperData() |> map { data in
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            var fullSizeImage: CGImage?
            if let data = data.fullSizeData, let image = drawSvgImageNano(data, arguments.drawingSize) {
                fullSizeImage = image._cgImage
            }
            if let fullSizeImage = fullSizeImage {
                let drawingRect = arguments.drawingRect
                var fittedSize = fullSizeImage.size.aspectFilled(drawingRect.size)
                if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                    fittedSize.width = arguments.boundingSize.width
                }
                if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                    fittedSize.height = arguments.boundingSize.height
                }
                
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                
                context.withFlippedContext { c in
                    
                    
                    let preview = AnimatedGradientBackgroundView.generatePreview(size: arguments.drawingSize.fitted(.init(width: 30, height: 30)), colors: [0xdbddbb, 0x6ba587, 0xd5d88d, 0x88b884].map { .init(argb: $0) })

                    c.setBlendMode(.normal)
                    c.draw(preview, in: fittedRect)
                    
                    c.interpolationQuality = .medium
                    c.setBlendMode(.softLight)
                    c.setAlpha(0.25)
                    c.draw(fullSizeImage, in: fittedRect)
                }
            }
           
            addCorners(context, arguments: arguments, scale: scale)
            
            return context
        })
    }
}

private func chatWallpaperDatas(account: Account, representations: [TelegramMediaImageRepresentation], file: TelegramMediaFile? = nil, webpage: TelegramMediaWebpage? = nil, slug: String? = nil, autoFetchFullSize: Bool = false, isBlurred: Bool = false, synchronousLoad: Bool = false) -> Signal<ImageRenderData, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(representations), let largestRepresentation = largestImageRepresentation(representations) {
        let maybeFullSize: Signal<MediaResourceData, NoError>
        if isBlurred {
            maybeFullSize = account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedBlurredWallpaperRepresentation(), complete: false, attemptSynchronously: synchronousLoad)
        } else {
            maybeFullSize = account.postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: synchronousLoad)
        }
        
        let signal = maybeFullSize |> take(1) |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(ImageRenderData(nil, loadedData, true))
            } else {
                let smallReference: MediaResourceReference
                let fullReference: MediaResourceReference
                if let webpage = webpage, let file = file {
                    smallReference = MediaResourceReference.media(media: AnyMediaReference.webPage(webPage: WebpageReference(webpage), media: file), resource: smallestRepresentation.resource)
                    fullReference = MediaResourceReference.media(media: AnyMediaReference.webPage(webPage: WebpageReference(webpage), media: file), resource: largestRepresentation.resource)
                } else {
                    smallReference = MediaResourceReference.wallpaper(wallpaper: slug != nil ? .slug(slug!) : nil, resource: smallestRepresentation.resource)
                    fullReference = MediaResourceReference.wallpaper(wallpaper: slug != nil ? .slug(slug!) : nil, resource: largestRepresentation.resource)
                }
                
                let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: smallReference, statsCategory: .image)
                let fetchedFullSize = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: fullReference, statsCategory: .image)
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(smallestRepresentation.resource, attemptSynchronously: synchronousLoad).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                let fullSizeData: Signal<ImageRenderData, NoError>
                
                if autoFetchFullSize {
                    fullSizeData = Signal<ImageRenderData, NoError> { subscriber in
                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                        
                        let fetchData: Signal<MediaResourceData, NoError>
                        if isBlurred {
                            fetchData =  account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedBlurredWallpaperRepresentation(), complete: false, attemptSynchronously: synchronousLoad)
                        } else {
                            fetchData = account.postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: synchronousLoad)
                        }
                        
                        let fullSizeDisposable = fetchData.start(next: { next in
                            subscriber.putNext(ImageRenderData(nil, next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedFullSizeDisposable.dispose()
                            fullSizeDisposable.dispose()
                        }
                    }
                } else {
                    fullSizeData = account.postbox.mediaBox.resourceData(largestRepresentation.resource)
                        |> map { next -> ImageRenderData in
                            return ImageRenderData(nil, next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                    }
                }
                
                
                return thumbnail |> mapToSignal { thumbnailData in
                    return fullSizeData |> map { fullData in
                        return ImageRenderData(thumbnailData, fullData.fullSizeData, fullData.fullSizeComplete)
                    }
                }
            }
        } |> filter({ $0.thumbnailData != nil || $0.fullSizeData != nil })
        
        return signal
    } else {
        return .never()
    }
}

enum PatternWallpaperDrawMode {
    case thumbnail
    case fastScreen
    case screen
}


func crossplatformPreview(accountContext: AccountContext, palette: ColorPalette, wallpaper: Wallpaper, webpage: TelegramMediaWebpage? = nil, mode: PatternWallpaperDrawMode, autoFetchFullSize: Bool = false, scale: CGFloat = 2.0, isBlurred: Bool = false, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal: Signal<Wallpaper, NoError> = moveWallpaperToCache(postbox: accountContext.account.postbox, wallpaper: wallpaper)
    
    return signal |> map { wallpaper in
        return ImageDataTransformation(data: ImageRenderData(nil, nil, false), execute: { arguments, data in
            
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            let preview = generateThemePreview(for: palette, wallpaper: wallpaper, backgroundMode: generateBackgroundMode(wallpaper, palette: palette, maxSize: WallpaperDimensions.aspectFilled(NSMakeSize(600, 600)), emoticonThemes: accountContext.emoticonThemes))
            
            context.withContext { ctx in
                ctx.draw(preview, in: arguments.drawingRect)
            }
            
            addCorners(context, arguments: arguments, scale: arguments.scale)
            
            return context
        })
    }
}

func wallpaperPreview(accountContext: AccountContext, palette: ColorPalette, wallpaper: Wallpaper, mode: PatternWallpaperDrawMode, autoFetchFullSize: Bool = false, scale: CGFloat = 2.0, isBlurred: Bool = false, synchronousLoad: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    let signal: Signal<Wallpaper, NoError> = moveWallpaperToCache(postbox: accountContext.account.postbox, wallpaper: wallpaper)
    
    return signal |> map { wallpaper in
        return ImageDataTransformation(data: ImageRenderData(nil, nil, false), execute: { arguments, data in
            
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            let preview = generateBackgroundMode(wallpaper, palette: palette, maxSize: WallpaperDimensions.aspectFilled(arguments.boundingSize), emoticonThemes: accountContext.emoticonThemes)
            
            
            context.withContext { ctx in
                ctx.translateBy(x: arguments.drawingSize.width / 2.0, y: arguments.drawingSize.height / 2.0)
                ctx.rotate(by: 180 * CGFloat.pi / -180.0)
                ctx.scaleBy(x: -1, y: 1)
                ctx.translateBy(x: -arguments.drawingSize.width / 2.0, y: -arguments.drawingSize.height / 2.0)
                
                drawBg(preview, palette: palette, bubbled: true, rect: arguments.drawingRect, in: ctx)
            }
            
            addCorners(context, arguments: arguments, scale: arguments.scale)
            
            return context
        })
    }
}



private func patternWallpaperDatas(account: Account, representations: [ImageRepresentationWithReference], mode: PatternWallpaperDrawMode, autoFetchFullSize: Bool = false) -> Signal<ImageRenderData, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(representations.map({ $0.representation })), let largestRepresentation = largestImageRepresentation(representations.map({ $0.representation })), let smallestIndex = representations.firstIndex(where: { $0.representation == smallestRepresentation }), let largestIndex = representations.firstIndex(where: { $0.representation == largestRepresentation }) {
        
        let size: CGSize?
        switch mode {
        case .thumbnail:
            size = largestRepresentation.dimensions.size.fitted(CGSize(width: 640.0, height: 640.0))
        default:
            size = nil
        }
        let maybeFullSize = account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedPatternWallpaperMaskRepresentation(size: size), complete: false, fetch: false)
        
        let signal = maybeFullSize
            |> take(1)
            |> mapToSignal { maybeData -> Signal<ImageRenderData, NoError> in
                if maybeData.complete {
                    let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                    return .single(ImageRenderData(nil, loadedData, true))
                } else {
                    let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: representations[smallestIndex].reference)
                    let fetchedFullSize = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: representations[largestIndex].reference)
                    
                    let thumbnailData = Signal<Data?, NoError> { subscriber in
                        let fetchedDisposable = fetchedThumbnail.start()
                        let thumbnailDisposable = account.postbox.mediaBox.cachedResourceRepresentation(representations[smallestIndex].representation.resource, representation: CachedPatternWallpaperMaskRepresentation(size: size), complete: false, fetch: true).start(next: { next in
                            subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedDisposable.dispose()
                            thumbnailDisposable.dispose()
                        }
                    }
                    
                    let fullSizeData = Signal<(Data?, Bool), NoError> { subscriber in
                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                        let fullSizeDisposable = account.postbox.mediaBox.cachedResourceRepresentation(representations[largestIndex].representation.resource, representation: CachedPatternWallpaperMaskRepresentation(size: size), complete: false, fetch: true).start(next: { next in
                            subscriber.putNext((next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedFullSizeDisposable.dispose()
                            fullSizeDisposable.dispose()
                        }
                    }
                    
                    return thumbnailData |> mapToSignal { thumbnailData in
                        return fullSizeData |> map { (fullSizeData, complete) in
                            return ImageRenderData(thumbnailData, fullSizeData, complete)
                        }
                    }
                }
        }
        
        return signal
    } else {
        return .never()
    }
}




private func chatWallpaperInternal(_ signal: Signal<ImageRenderData, NoError>, prominent: Bool, scale: CGFloat, drawPatternOnly: Bool, palette: ColorPalette) -> Signal<ImageDataTransformation, NoError> {

    return signal |> map { data in
        
        var fullSizeImage: CGImage? = nil
        if let fullSizeData = data.fullSizeData, data.fullSizeComplete {
            
            if prominent {
                let options = NSMutableDictionary()
                options.setValue(960 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                    fullSizeImage = image
                }
            } else {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    fullSizeImage = image
                }
            }
        }

        
        return ImageDataTransformation(data: data, execute: { arguments, data in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let thumbnailData = data.thumbnailData
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
        
            
            var thumbnailImage: CGImage?
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber
            
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, options), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: CGImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            
            if let combinedColor = arguments.emptyColor {
                
                let colors:[NSColor]
                let intensity: CGFloat
                let rotation: Int32?
                switch combinedColor {
                case let .color(combinedColor):
                    let color = combinedColor.withAlphaComponent(1.0)
                    intensity = combinedColor.alpha
                    colors = [color]
                    rotation = nil
                case let .gradient(_colors, _intensity, _rotation):
                    intensity = _intensity
                    colors = _colors.reversed().map { $0.withAlphaComponent(1.0) }
                    rotation = _rotation
                default:
                    fatalError()
                }
                
                let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
                context.withFlippedContext { c in
                    c.setBlendMode(.normal)

                    if !drawPatternOnly {
                        
                        if palette.isDark, let image = fullSizeImage {
                            let size = image.size.aspectFilled(arguments.drawingRect.size)
                            let rect = arguments.drawingRect.focus(size)

                            c.clear(rect)
                            c.setFillColor(NSColor.black.cgColor)
                            c.fill(rect)
                            c.clip(to: rect, mask: image)
                            
                            c.clear(rect)
                            c.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
                            c.fill(rect)
                        }
                        
                        if !colors.isEmpty {
                            if colors.count == 1, let color = colors.first {
                                c.setFillColor(color.cgColor)
                                c.fill(arguments.drawingRect)
                            } else {
                                if colors.count <= 2 {
                                    let gradientColors = colors.map { $0.cgColor } as CFArray
                                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)

                                    var locations: [CGFloat] = []
                                    for i in 0 ..< colors.count {
                                        locations.append(delta * CGFloat(i))
                                    }
                                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                    
                                    c.saveGState()
                                    c.translateBy(x: arguments.drawingSize.width / 2.0, y: arguments.drawingSize.height / 2.0)
                                    c.rotate(by: CGFloat(rotation ?? 0) * CGFloat.pi / -180.0)
                                    c.translateBy(x: -arguments.drawingSize.width / 2.0, y: -arguments.drawingSize.height / 2.0)
                                    
                                    c.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: arguments.drawingSize.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                                    c.restoreGState()
                                } else {
                                    let preview = AnimatedGradientBackgroundView.generatePreview(size: arguments.drawingSize.fitted(.init(width: 30, height: 30)), colors: colors)

                                    c.saveGState()
                                    c.translateBy(x: arguments.drawingSize.width / 2.0, y: arguments.drawingSize.height / 2.0)
                                    c.scaleBy(x: 1.0, y: -1.0)
                                    c.translateBy(x: -arguments.drawingSize.width / 2.0, y: -arguments.drawingSize.height / 2.0)
                                    c.draw(preview, in: arguments.drawingSize.bounds)
                                    c.restoreGState()
                                }
                            }
                        }
                    }
                    
                    if let fullSizeImage = fullSizeImage, !palette.isDark {
                        if !drawPatternOnly {
                            c.setBlendMode(.softLight)
                            c.setAlpha(intensity)
                        }
                        c.draw(fullSizeImage, in: fittedRect)
                    }
                    
                }
                addCorners(context, arguments: arguments, scale: scale)
                return context
               
            } else {
                context.withFlippedContext(isHighQuality: fullSizeImage != nil, { c in
                    c.setBlendMode(.copy)
                    if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                        //c.setFillColor(NSColor(white: 0.0, alpha: 0.4).cgColor)
                        c.fill(arguments.drawingRect)
                    }
                    
                    c.setBlendMode(.copy)
                    if let blurredThumbnailImage = blurredThumbnailImage {
                        c.interpolationQuality = .low
                        c.draw(blurredThumbnailImage, in: fittedRect)
                        c.setBlendMode(.normal)
                    }
                    
                    if let fullSizeImage = fullSizeImage {
                        c.interpolationQuality = .medium
                        c.draw(fullSizeImage, in: fittedRect)
                    }
                })
                
                addCorners(context, arguments: arguments, scale: scale)
                
                return context
            }
        })
    }
}


func patternWallpaperImage(account: Account, representations: [ImageRepresentationWithReference], mode: PatternWallpaperDrawMode, scale: CGFloat = 2.0, autoFetchFullSize: Bool = false, drawPatternOnly: Bool, palette: ColorPalette) -> Signal<ImageDataTransformation, NoError> {
    var prominent = false
    if case .thumbnail = mode {
        prominent = false
    }
    return chatWallpaperInternal(patternWallpaperDatas(account: account, representations: representations, mode: mode, autoFetchFullSize: autoFetchFullSize), prominent: prominent, scale: scale, drawPatternOnly: drawPatternOnly, palette: palette)
}


func chatWallpaper(account: Account, representations: [TelegramMediaImageRepresentation], file: TelegramMediaFile? = nil, webpage: TelegramMediaWebpage? = nil, slug: String? = nil, mode: PatternWallpaperDrawMode, isPattern: Bool, autoFetchFullSize: Bool = false, scale: CGFloat = 2.0, isBlurred: Bool = false, synchronousLoad: Bool = false, drawPatternOnly: Bool = false, palette: ColorPalette = theme.colors) -> Signal<ImageDataTransformation, NoError> {
    var prominent = false
    if case .thumbnail = mode {
        prominent = false
    }
    let signal: Signal<ImageRenderData, NoError>
    if isPattern {
        let reps = representations.map { rep -> ImageRepresentationWithReference in
            if let webpage = webpage, let file = file {
                return ImageRepresentationWithReference(representation: rep, reference: MediaResourceReference.media(media: AnyMediaReference.webPage(webPage: WebpageReference(webpage), media: file), resource: rep.resource))
            } else {
                return ImageRepresentationWithReference(representation: rep, reference: MediaResourceReference.wallpaper(wallpaper: slug != nil ? .slug(slug!) : nil, resource: rep.resource))
            }
        }
        signal = patternWallpaperDatas(account: account, representations: reps, mode: mode, autoFetchFullSize: autoFetchFullSize)
    } else {
        signal = chatWallpaperDatas(account: account, representations: representations, file: file, webpage: webpage, autoFetchFullSize: autoFetchFullSize, isBlurred: isBlurred, synchronousLoad: synchronousLoad)
    }
    return chatWallpaperInternal(signal, prominent: prominent, scale: scale, drawPatternOnly: drawPatternOnly, palette: palette)
}


func instantPageImageFile(account: Account, fileReference: FileMediaReference, scale: CGFloat, fetched: Bool = false) -> Signal<ImageDataTransformation, NoError> {
    return chatMessageFileDatas(account: account, fileReference: fileReference, progressive: false)
        |> map { data in
            return ImageDataTransformation(data: data, execute: { arguments, data in
                assertNotOnMainThread()
                let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
                
                let drawingRect = arguments.drawingRect
                let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
                
                var fullSizeImage: CGImage?
                var imageOrientation: ImageOrientation = .up
                if let fullSizeData = data.fullSizeData {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber

                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
                
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                context.withFlippedContext { c in
                    if var fullSizeImage = fullSizeImage {
                        if let color = arguments.emptyColor {
                            switch color {
                            case let .color(color):
                                if imageRequiresInversion(fullSizeImage), let tintedImage = generateTintedImage(image: fullSizeImage, color: color) {
                                   fullSizeImage = tintedImage
                                }
                            default:
                                break
                            }
                        }
                        
                        c.setBlendMode(.normal)
                        c.interpolationQuality = .medium
                        
                        drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                    }
                }
                
                addCorners(context, arguments: arguments, scale: scale)
                
                return context
            })
    }
}

private func rotationFor(_ orientation: ImageOrientation) -> CGFloat {
    switch orientation {
    case .left:
        return CGFloat.pi / 2.0
    case .right:
        return -CGFloat.pi / 2.0
    case .down:
        return -CGFloat.pi
    default:
        return 0.0
    }
}

func drawImage(context: CGContext, image: CGImage, orientation: ImageOrientation, in rect: CGRect) {
    var restore = true
    var drawRect = rect
    switch orientation {
    case .left:
        fallthrough
    case .right:
        fallthrough
    case .down:
        let angle = rotationFor(orientation)
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: angle)
        context.translateBy(x: -rect.midX, y: -rect.midY)
        var t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        t = t.rotated(by: angle)
        t = t.translatedBy(x: -rect.midX, y: -rect.midY)
        
        drawRect = rect.applying(t)
    case .leftMirrored:
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: -CGFloat.pi / 2.0)
        context.translateBy(x: -rect.midX, y: -rect.midY)
        var t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        t = t.rotated(by: -CGFloat.pi / 2.0)
        t = t.translatedBy(x: -rect.midX, y: -rect.midY)
        
        drawRect = rect.applying(t)
    default:
        restore = false
    }
    context.draw(image, in: drawRect)
    if restore {
        context.restoreGState()
    }
}





func mapResourceToAvatarSizes(postbox: Postbox, resource: MediaResource, representations: [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError> {
    return postbox.mediaBox.resourceData(resource)
        |> take(1)
        |> map { data -> [Int: Data] in
            guard data.complete, let image = NSImage(contentsOfFile: data.path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return [:]
            }
            
            let options = NSMutableDictionary()
            options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
            
            let colorQuality: Float = 0.6
            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
            
            var result: [Int: Data] = [:]
            for i in 0 ..< representations.count {
                if let scaledImage = generateScaledImage(image: image, size: representations[i].dimensions.size, scale: 1.0) {
                    
                    let mutableData: CFMutableData = NSMutableData() as CFMutableData
                    if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, options) {
                        CGImageDestinationSetProperties(colorDestination, nil)
                        
                        CGImageDestinationAddImage(colorDestination, scaledImage, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                           
                        }
                    }
                    
                    result[i] = mutableData as Data
                }
            }
            return result
    }
}


public func generateScaledImage(image: CGImage?, size: CGSize, scale: CGFloat? = nil) -> CGImage? {
    guard let image = image else {
        return nil
    }
    
    return generateImage(size, contextGenerator: { size, context in
        context.draw(image, in: CGRect(origin: CGPoint(), size: size))
    }, opaque: true)
}


private func imageBuffer(from data: UnsafeMutableRawPointer!, width: vImagePixelCount, height: vImagePixelCount, rowBytes: Int) -> vImage_Buffer {
    return vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
}

func blurredImage(_ image: CGImage, radius: CGFloat, iterations: Int = 3) -> CGImage? {
    guard let providerData = image.dataProvider?.data else {
        return nil
    }
    
    if image.size.width <= 0.0 || image.size.height <= 0 || radius <= 0 {
        return image
    }
    
    var boxSize = UInt32(radius)
    if boxSize % 2 == 0 {
        boxSize += 1
    }
    
    let bytes = image.bytesPerRow * image.height
    let inData = malloc(bytes)
    var inBuffer = imageBuffer(from: inData, width: vImagePixelCount(image.width), height: vImagePixelCount(image.height), rowBytes: image.bytesPerRow)
    
    let outData = malloc(bytes)
    var outBuffer = imageBuffer(from: outData, width: vImagePixelCount(image.width), height: vImagePixelCount(image.height), rowBytes: image.bytesPerRow)
    
    let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize))
    let tempData = malloc(tempSize)
    
    defer {
        free(inData)
        free(outData)
        free(tempData)
    }
    
    let source = CFDataGetBytePtr(providerData)
    memcpy(inBuffer.data, source, bytes)
    
    for _ in 0 ..< iterations {
        vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempData, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend))
        
        let temp = inBuffer.data
        inBuffer.data = outBuffer.data
        outBuffer.data = temp
    }
    
    let context = image.colorSpace.flatMap {
        CGContext(data: inBuffer.data, width: image.width, height: image.height, bitsPerComponent: image.bitsPerComponent, bytesPerRow: image.bytesPerRow, space: $0, bitmapInfo: image.bitmapInfo.rawValue)
    }
    
    let blurredCGImage = context?.makeImage()
    if let blurredCGImage = blurredCGImage {
        return blurredCGImage
    } else {
        return nil
    }
}





func patternColor(for color: NSColor, intensity: CGFloat, prominent: Bool = false) -> NSColor {
    var hue:  CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    if brightness > 0.5 {
        brightness = max(0.0, brightness * 0.65)
    } else {
        brightness = max(0.0, min(1.0, 1.0 - brightness * 0.65))
    }
    saturation = min(1.0, saturation + 0.05 + 0.1 * (1.0 - saturation))
    alpha = (prominent ? 0.5 : 0.4) * intensity
    return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
}




func prepareTextAttachments(_ attachments: [NSTextAttachment]) -> Signal<[URL], NoError> {
    return Signal { subscriber in
        
        var cancelled: Bool = false
        
        resourcesQueue.async {
            var urls:[URL] = []

            for attachment in attachments {
                if cancelled {
                    for url in urls {
                        try? FileManager.default.removeItem(at: url)
                    }
                    subscriber.putCompletion()
                    return
                }
                if let fileWrapper = attachment.fileWrapper, fileWrapper.isRegularFile {
                    if let data = fileWrapper.regularFileContents {
                        if let fileName = fileWrapper.filename {
                            let path = NSTemporaryDirectory() + fileName
                            var newPath = path
                            var i:Int = 0
                            if FileManager.default.fileExists(atPath: newPath) {
                                newPath = path.nsstring.deletingPathExtension + "\(i)." + path.nsstring.pathExtension
                                i += 1
                            }
                            let url = URL(fileURLWithPath: newPath)
                            do {
                                try data.write(to: url)
                                urls.append(url)
                            } catch {}
                        }
                    }
                }
            }
            subscriber.putNext(urls)
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            cancelled = true
        }
    } |> runOn(prepareQueue)
}




func chatMapSnapshotData(account: Account, resource: MapSnapshotMediaResource) -> Signal<Data?, NoError> {
    return Signal<Data?, NoError> { subscriber in
        let dataDisposable = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: MapSnapshotMediaResourceRepresentation(), complete: true).start(next: { next in
            if next.size != 0 {
                subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
            }
        }, error: subscriber.putError, completed: subscriber.putCompletion)
        
        return ActionDisposable {
            dataDisposable.dispose()
        }
    }
}


public func chatMapSnapshotImage(account: Account, resource: MapSnapshotMediaResource) -> Signal<ImageDataTransformation, NoError> {
    let signal = chatMapSnapshotData(account: account, resource: resource)
    
    return signal |> map { data in
        return ImageDataTransformation(data: ImageRenderData(nil, data, data != nil), execute: { arguments, data in
            
            let fullSizeData = data.fullSizeData

            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale, clear: true)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    fullSizeImage = image
                }
                
                if let fullSizeImage = fullSizeImage {
                    let drawingRect = arguments.drawingRect
                    var fittedSize = CGSize(width: CGFloat(fullSizeImage.width), height: CGFloat(fullSizeImage.height)).aspectFilled(drawingRect.size)
                    if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.width = arguments.boundingSize.width
                    }
                    if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.height = arguments.boundingSize.height
                    }
                    
                    let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                    
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                            c.fill(arguments.drawingRect)
                        }
                        
                        c.setBlendMode(.copy)
                        
                        c.interpolationQuality = .medium
                        c.draw(fullSizeImage, in: fittedRect)
                        
                        c.setBlendMode(.normal)
                    }
                } else {
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        if let empty = arguments.emptyColor {
                            switch empty {
                            case let .color(color):
                                c.setFillColor(color.cgColor)
                            default:
                                c.setFillColor(.white)
                            }
                        } else {
                            c.setFillColor(.white)
                        }
                        c.fill(arguments.drawingRect)
                        
                        c.setBlendMode(.normal)
                    }
                }
            }
            addCorners(context, arguments: arguments, scale: arguments.scale)
            
            return context
        })
    }
}




func generateEmoji(_ emoji: NSAttributedString) -> Signal<CGImage?, NoError> {
    return Signal { subscriber in
        
        
        
        let node = TextNode.layoutText(maybeNode: nil, emoji, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)

        
        if node.0.size == .zero {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let image = generateImage(node.0.size, scale: System.backingScale, rotatedContext: { size, ctx in
            ctx.clear(size.bounds)
            node.1.draw(size.bounds, in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
            
        })
        
        subscriber.putNext(image)
        subscriber.putCompletion()
        
        return ActionDisposable {
            
        }
    } |> runOn(.concurrentBackgroundQueue())
}




func makeTopicIcon(_ title: String, bgColors: [NSColor], strokeColors: [NSColor]) -> Signal<ImageDataTransformation, NoError> {
    return Signal { subscriber in
        let data: ImageRenderData = .init(nil, nil, false)
        subscriber.putNext(ImageDataTransformation(data: data, execute: { arguments, data in
            return generateTopicIcon(size: arguments.boundingSize, backgroundColors: bgColors, strokeColors: strokeColors, title: title)
        }))
        subscriber.putCompletion()
        return ActionDisposable {
            
        }
    } |> runOn(.concurrentBackgroundQueue())
}

func makeGeneralTopicIcon(_ resource: LocalBundleResource, scale: CGFloat = System.backingScale) -> Signal<ImageDataTransformation, NoError> {
    return Signal { subscriber in
        let data = NSImage(named: resource.name)?.tiffRepresentation
        if let data = data {
            let data: ImageRenderData = .init(nil, data, true)
            subscriber.putNext(ImageDataTransformation(data: data, execute: { arguments, data in
                let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
                
                let drawingRect = arguments.drawingRect
                let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                var fullSizeImage: CGImage?
                if let fullSizeData = data.fullSizeData {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, options), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
                
                context.withContext(isHighQuality: fullSizeImage != nil, { c in

                    c.setBlendMode(.copy)
                    if let fullSizeImage = fullSizeImage {
                        c.interpolationQuality = .medium
                        if let color = resource.color {
                            c.clip(to: fittedRect, mask: fullSizeImage)
                            c.setFillColor(color.cgColor)
                            c.fill(fittedRect)
                        } else {
                            c.draw(fullSizeImage, in: fittedRect)
                        }
                    }
                    
                })
                                
                return context
            }))
        }
        
        subscriber.putCompletion()
        return ActionDisposable {
            
        }
    } |> runOn(.concurrentBackgroundQueue())
}
