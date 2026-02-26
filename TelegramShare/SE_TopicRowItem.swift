//
//  TopicRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import SwiftSignalKit
import Postbox


struct SE_LocalBundleResourceId {
    let name: String
    let ext: String
    
    var uniqueId: String {
        return "local-bundle-\(self.name)-\(self.ext)"
    }
    
    var hashValue: Int {
        return self.name.hashValue
    }

}


class SE_LocalBundleResource: TelegramMediaResource {
    
    
    let name: String
    let ext: String
    let color: NSColor?
    let resize: Bool
    init(name: String, ext: String, color: NSColor? = nil, resize: Bool = true) {
        self.name = name
        self.ext = ext
        self.color = color
        self.resize = resize
    }
    
    var size: Int64? {
        return nil
    }
    
    required init(decoder: PostboxDecoder) {
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.ext = decoder.decodeStringForKey("e", orElse: "")
        if let hexColor = decoder.decodeOptionalStringForKey("c") {
            self.color = NSColor(hexString: hexColor)
        } else {
            self.color = nil
        }
        self.resize = decoder.decodeBoolForKey("nr", orElse: true)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name, forKey: "n")
        encoder.encodeString(self.ext, forKey: "e")
        if let color = self.color {
            encoder.encodeString(color.hexString, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        encoder.encodeBool(self.resize, forKey: "nr")
    }
    
    public var id: MediaResourceId {
        return .init(SE_LocalBundleResourceId(name: self.name, ext: self.ext).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }

    public var path: String? {
        return Bundle.main.path(forResource: name, ofType: ext)
    }
}


public struct SE_ForumTopicIconResourceId {
    public let title: String
    public let bgColors: [NSColor]
    public let strokeColors: [NSColor]
    public let iconColor: Int32
    public var uniqueId: String {
        return "forum-topic-icon-\(self.title)-\(self.bgColors.map { $0.hexString })-\(self.strokeColors.map { $0.hexString })"
    }
    

}
public class SE_ForumTopicIconResource: TelegramMediaResource {
    
    
    public let title: String
    public let iconColor: Int32
    public let bgColors: [NSColor]
    public let strokeColors: [NSColor]

    public init(title: String, bgColors: [NSColor], strokeColors: [NSColor], iconColor: Int32) {
        self.title = title
        self.bgColors = bgColors
        self.strokeColors = strokeColors
        self.iconColor = iconColor
    }
    
    public var size: Int64? {
        return nil
    }
    
    public required init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.iconColor = decoder.decodeInt32ForKey("i", orElse: 0)
        self.bgColors = decoder.decodeStringArrayForKey("b").compactMap {
            .init(hexString: $0)
        }
        self.strokeColors = decoder.decodeStringArrayForKey("s").compactMap {
            .init(hexString: $0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeInt32(self.iconColor, forKey: "i")
        encoder.encodeStringArray(self.bgColors.map { $0.hexString }, forKey: "b")
        encoder.encodeStringArray(self.strokeColors.map { $0.hexString }, forKey: "s")
    }
    
    public var id: MediaResourceId {
        return .init(SE_ForumTopicIconResourceId(title: title, bgColors: bgColors, strokeColors: self.strokeColors, iconColor: iconColor).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }

}

private let SE_topicColors: [([UInt32], [UInt32])] = [
    ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7]),
    ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7]),
    ([0xFFD67E, 0xFC8601], [0xDA9400, 0xFA5F00]),
    ([0xCB86DB, 0x9338AF], [0x812E98, 0x6F2B87]),
    ([0x8EEE98, 0x02B504], [0x02A01B, 0x009716]),
    ([0xFF93B2, 0xE23264], [0xFC447A, 0xC80C46]),
    ([0xFB6F5F, 0xD72615], [0xDC1908, 0xB61506])
]

private func SE_topicColor(_ iconColor: Int32 = 0) -> ([NSColor], [NSColor]) {
    let values = SE_topicColors.first(where: { value in
        let contains = value.0.contains(where: {
            $0 == iconColor
        })
        return contains
    })
    let colors = values ?? SE_topicColors[0]
    return (colors.0.map { NSColor($0) }, colors.1.map { NSColor($0) })
}

private func SE_makeIconFile(title: String, iconColor: Int32 = 0, isGeneral: Bool = false, context: AccountContext, iconId: Int64?) -> Signal<TelegramMediaFile?, NoError> {
    let colors: ([NSColor], [NSColor]) = SE_topicColor(iconColor)
    
    if let iconId {
        return context.engine.stickers.resolveInlineStickers(fileIds: [iconId]) |> map {
            return $0.first?.value
        }
    }
    
    if isGeneral {
        return .single(TelegramMediaFile(fileId: .init(namespace: 0, id: 523134), partialReference: nil, resource: SE_LocalBundleResource(name: "Icon_Topic_General", ext: "", color: theme.chatList.badgeMutedBackgroundColor), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "bundle/jpeg", size: nil, attributes: [], alternativeRepresentations: []))
    }
    
    let resource = SE_ForumTopicIconResource(title: title.prefix(1), bgColors: colors.0, strokeColors: colors.1, iconColor: iconColor)
    let id = Int64(resource.id.stringRepresentation.hashValue)
    return .single(TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "bundle/topic", size: nil, attributes: [], alternativeRepresentations: []))
}


private func SE_generateTopicIcon(size: NSSize, backgroundColors: [NSColor], strokeColors: [NSColor], title: String) -> DrawingContext {
    
    let title = title.isEmpty ? "A" : title.prefix(1).uppercased()
    
    let realSize = NSMakeSize(min(size.width, size.height), min(size.width, size.height))
    
    let context = DrawingContext(size: realSize, scale: 0, clear: false)
    context.withFlippedContext(isHighQuality: true, horizontal: false, vertical: true, { context in
        context.clear(CGRect(origin: .zero, size: realSize))
        
//        context.setFillColor(NSColor.random.cgColor)
//        context.fill(size.bounds)
        
        context.saveGState()
        
        let size = CGSize(width: 32.0, height: 32.0)
                
        let scale: CGFloat = realSize.width / size.width
        context.scaleBy(x: scale, y: scale)
                
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.translateBy(x: -14.0 - 1, y: -14.0 - 1)

        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        context.clip()
        
        let colorsArray = backgroundColors.map { $0.cgColor } as NSArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        if let path = context.path {
            let strokePath = path.copy(strokingWithWidth: 1.0, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
            context.beginPath()
            context.addPath(strokePath)
            context.clip()
            
            let colorsArray = strokeColors.map { $0.cgColor } as NSArray
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        
        context.restoreGState()
        
        let fontSize = round(15.0 * scale)

        
        let attributedString = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font: NSFont.avatar(fontSize), NSAttributedString.Key.foregroundColor: NSColor.white])
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        
       
        var lineOffset = CGPoint(x: 0, y: floor(realSize.height * 0.05) + 1)
        
        if realSize.height == 19 {
            lineOffset.y += 1
        }
        let lineOrigin = CGPoint(x: round(-lineBounds.origin.x + (realSize.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: round(-lineBounds.origin.y + (realSize.height - lineBounds.size.height) / 2.0) + lineOffset.y - 1)
        
        context.translateBy(x: realSize.width / 2.0, y: realSize.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -realSize.width / 2.0, y: -realSize.height / 2.0)
        
        context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
        CTLineDraw(line, context)
        context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)

    })
    return context

}

private func SE_makeTopicIcon(_ title: String, bgColors: [NSColor], strokeColors: [NSColor]) -> Signal<ImageDataTransformation, NoError> {
    return Signal { subscriber in
        let data: ImageRenderData = .init(nil, nil, false)
        subscriber.putNext(ImageDataTransformation(data: data, execute: { arguments, data in
            return SE_generateTopicIcon(size: arguments.boundingSize, backgroundColors: bgColors, strokeColors: strokeColors, title: title)
        }))
        subscriber.putCompletion()
        return ActionDisposable {
            
        }
    } |> runOn(.concurrentBackgroundQueue())
}

private func SE_makeGeneralTopicIcon(_ resource: SE_LocalBundleResource, scale: CGFloat = System.backingScale) -> Signal<ImageDataTransformation, NoError> {
    return Signal { subscriber in
        let data = NSImage(named: resource.name)?.tiffRepresentation
        if let data = data {
            let data: ImageRenderData = .init(nil, data, true)
            subscriber.putNext(ImageDataTransformation(data: data, execute: { arguments, data in
                let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
                
                let drawingRect = arguments.drawingRect
                let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + floorToScreenPixels(scale, (drawingRect.size.width - fittedSize.width) / 2.0), y: drawingRect.origin.y + floorToScreenPixels(scale, (drawingRect.size.height - fittedSize.height) / 2.0)), size: fittedSize)
                
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


private final class SE_LottieLoadView : View {
    private let loadResourceDisposable = MetaDisposable()
    
    private var animationView: SE_LottiePlayerView?
    private var imageView: TransformImageView?

    private var sticker: SE_LottieAnimation? {
        didSet {
            if let sticker {
                let current: SE_LottiePlayerView
                if let view = self.animationView {
                    current = view
                } else {
                    current = SE_LottiePlayerView(frame: self.frame.size.bounds)
                    addSubview(current)
                    self.animationView = current
                }
                current.set(sticker)
            } else {
                if let animationView {
                    performSubviewRemoval(animationView, animated: false)
                    self.animationView = nil
                }
            }
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private var file: TelegramMediaFile?
    
    func update(file: TelegramMediaFile, context: AccountContext) {
        
        guard file != self.file else {
            return
        }
        self.file = file
        self.sticker = nil
        
        let size = frame.size
        let aspectSize: NSSize
        aspectSize = file.dimensions?.size.aspectFilled(size) ?? size

        
        if file.mimeType == "bundle/topic" || file.mimeType == "bundle/jpeg" {
            let current: TransformImageView
            if let view = self.imageView {
                current = view
            } else {
                current = TransformImageView(frame: self.frame.size.bounds)
                self.imageView = current
                addSubview(current)
            }
            
            let signal: Signal<ImageDataTransformation, NoError>
            if let resource = file.resource as? SE_LocalBundleResource {
                signal = SE_makeGeneralTopicIcon(resource)
            } else if let resource = file.resource as? SE_ForumTopicIconResource {
                signal = SE_makeTopicIcon(resource.title, bgColors: resource.bgColors, strokeColors: resource.strokeColors)
            } else {
                signal = .complete()
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: aspectSize, boundingSize: size, intrinsicInsets: NSEdgeInsets(), emptyColor: nil)

            
            current.setSignal(signal)
            current.set(arguments: arguments)
            
        } else {
            
            if let imageView {
                performSubviewRemoval(imageView, animated: false)
                self.imageView = nil
            }
            
            let data = context.account.postbox.mediaBox.resourceData(file.resource, attemptSynchronously: false)
            let size = self.frame.size
            
            self.loadResourceDisposable.set((data |> map { resourceData -> Data? in
                if resourceData.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                    if file.mimeType == "video/webm" {
                        return resourceData.path.data(using: .utf8)!
                    } else {
                        return data
                    }
                }
                return nil
            } |> deliverOnMainQueue).start(next: { [weak self] data in
                if let data = data, let `self` = self {
                    
                    let playPolicy: SE_LottiePlayPolicy = .playCount(2)
                    let maximumFps: Int = 30
                    
                    
                    let type: SE_LottieAnimationType
                    if file.mimeType == "video/webm" {
                        type = .webm
                    } else if file.mimeType == "image/webp" {
                        type = .webp
                    } else {
                        type = .lottie
                    }
                    
                    self.sticker = SE_LottieAnimation(compressed: data, key: SE_LottieAnimationEntryKey(key: .media(file.id), size: size, fitzModifier: nil, mirror: false), type: type, playPolicy: playPolicy, maximumFps: maximumFps, colors: [], postbox: context.account.postbox, metalSupport: false)
                    
                } else {
                    self?.sticker = nil
                }
            }))
        }
        
        
    }
    
}


final class SE_TopicRowItem: GeneralRowItem {
    let item: EngineChatList.Item
    fileprivate let context: AccountContext
    fileprivate let nameLayout: TextViewLayout
    fileprivate let nameSelectedLayout: TextViewLayout
    fileprivate let presentation: TelegramPresentationTheme?
    init(_ initialSize: NSSize, stableId: AnyHashable, item: EngineChatList.Item, context: AccountContext, action: @escaping()->Void = {}, presentation: TelegramPresentationTheme? = nil) {
        self.item = item
        self.context = context
        self.presentation = presentation
        
        let theme = presentation ?? theme
        self.nameLayout = .init(.initialize(string: item.threadData?.info.title, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.nameSelectedLayout = .init(.initialize(string: item.threadData?.info.title, color: theme.colors.underSelectedColor, font: .medium(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 40, stableId: stableId, type: .none, viewType: .legacy, action: action, border: [.Bottom])
        _ = makeSize(initialSize.width)
    }
    
    var threadId: Int64? {
        switch item.id {
        case let .forum(threadId):
            return threadId
        default:
            return nil
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.nameLayout.measure(width: width - 50 - 10)
        self.nameSelectedLayout.measure(width: width - 50 - 10)

        return true
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    override func viewClass() -> AnyClass {
        return SE_TopicRowView.self
    }
}

private class SE_TopicRowView : TableRowView {
    private let nameView = TextView()
    private let borderView = View()
    private let containerView = Control()
    
    private let iconView: SE_LottieLoadView = SE_LottieLoadView(frame: NSMakeRect(0, 0, 24, 24))
    private let disposable = MetaDisposable()
    
    deinit {
        disposable.dispose()
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(iconView)
        addSubview(containerView)
        self.addSubview(nameView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        self.addSubview(borderView)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededDown()
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededUp()
        }, for: .Up)
    }
    
    private func invokeIfNeededUp() {
        if let event = NSApp.currentEvent {
            super.mouseUp(with: event)
            if let item = item as? GeneralRowItem, let table = item.table, table.alwaysOpenRowsOnMouseUp, mouseInside() {
                invokeAction(item, clickCount: event.clickCount)
            }
        }
    }
    
    func invokeAction(_ item: GeneralRowItem, clickCount: Int) {
        if clickCount <= 1 {
            item.action()
        }
    }
    
    private func invokeIfNeededDown() {
        if let event = NSApp.currentEvent {
            super.mouseDown(with: event)
            if let item = item as? GeneralRowItem, let table = item.table, !table.alwaysOpenRowsOnMouseUp, let event = NSApp.currentEvent, mouseInside() {
                if item.enabled {
                    invokeAction(item, clickCount: event.clickCount)
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = self.item as? SE_TopicRowItem else {
            return
        }
        let theme = item.presentation ?? theme
        borderView.backgroundColor = theme.colors.border
    }
    
    override var backdorColor: NSColor {
        guard let item = self.item as? SE_TopicRowItem else {
            return isSelect ? theme.colors.accentSelect : theme.colors.background
        }
        let theme = item.presentation ?? theme
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SE_TopicRowItem else {
            return
        }
        
        self.nameView.update(item.isSelected ? item.nameSelectedLayout : item.nameLayout)
        
        let context = item.context
        if let info = item.item.threadData?.info {
            let signal: Signal<TelegramMediaFile?, NoError>
            signal = SE_makeIconFile(title: info.title, iconColor: info.iconColor, isGeneral: item.threadId == 1, context: item.context, iconId: info.icon) |> deliverOnMainQueue
            disposable.set(signal.startStrict(next: { [weak self] file in
                if let file {
                    self?.iconView.update(file: file, context: context)
                }
            }))
        } else {
            disposable.set(nil)
        }
        
        borderView.isHidden = isSelect
        
    }
    
    override func layout() {
        super.layout()
        containerView.frame = bounds
        iconView.centerY(x: 10)
        nameView.centerY(x: iconView.frame.maxX + 10)
        borderView.frame = NSMakeRect(50, frame.height - .borderSize, frame.width - 50, .borderSize)
    }
    
}
