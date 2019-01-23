//
//  WallpaperPreviewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

enum WallpaperPreviewMode : Equatable {
    case plain
    case blurred
}

private final class CheckboxView : View {
    
    
    
    private(set) var isSelected: Bool = false
    private var timer: SwiftSignalKitMac.Timer?
    func set(isSelected: Bool, animated: Bool) {
        self.isSelected = isSelected
        if animated {
            timer?.invalidate()
            
            let fps: CGFloat = 60

            let tick = isSelected ? ((1 - animationProgress) / (fps * 0.2)) : -(animationProgress / (fps * 0.2))
            
            timer = SwiftSignalKitMac.Timer.init(timeout: 0.016, repeat: true, completion: { [weak self] in
                guard let `self` = self else {return}
                self.animationProgress += tick
                
                if self.animationProgress <= 0 || self.animationProgress >= 1 {
                    self.timer?.invalidate()
                    self.timer = nil
                }
                
            }, queue: .mainQueue())
            
            timer?.start()
        } else {
            animationProgress = isSelected ? 1.0 : 0.0
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var animationProgress: CGFloat = 0.0 {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        let borderWidth: CGFloat = 2.0
        
        context.setStrokeColor(.white)
        context.setLineWidth(borderWidth)
        context.strokeEllipse(in: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0))
        
        let progress: CGFloat = animationProgress
        let diameter = bounds.width
        let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)

        
        context.setFillColor(.white)
        context.fillEllipse(in: bounds.insetBy(dx: (diameter - borderWidth) * (1.0 - animationProgress), dy: (diameter - borderWidth) * (1.0 - animationProgress)))
        
        let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
        let s = CGPoint(x: center.x - 4.0, y: center.y + 1.0)
        let p1 = CGPoint(x: 3.0, y: 3.0)
        let p2 = CGPoint(x: 5.0, y: -6.0)
        
        if !firstSegment.isZero {
            if firstSegment < 1.0 {
                context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                context.addLine(to: s)
            } else {
                let secondSegment = (progress - 0.33) * 1.5
                context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                context.addLine(to: s)
            }
        }
        
//        context.setStrokeColor(.white)
//        if parameters.theme.strokeColor == .clear {
            context.setBlendMode(.clear)
//        }
        context.setLineWidth(borderWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setMiterLimit(10.0)
        
        
        context.strokePath()

        
//        ctx.round(bounds.size, bounds.height / 2)
//
//        ctx.setStrokeColor(.white)
//        ctx.setLineWidth(2.0)
//        ctx.strokeEllipse(in: bounds)
    }
}

private final class ApplyBlurCheckboxView : View {
    private let title:(TextNodeLayout,TextNode) = TextNode.layoutText(NSAttributedString.initialize(string: L10n.wallpaperPreviewBlurred, color: .white, font: .medium(.text)), nil, 1, .end, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .left)
    private let checkbox: CheckboxView = CheckboxView(frame: NSMakeRect(0, 0, 16, 16))
    
    var isSelected: Bool {
        get {
            return checkbox.isSelected
        }
        set {
            checkbox.set(isSelected: newValue, animated: false)
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(checkbox)
        layer?.cornerRadius = .cornerRadius
        setFrameSize(title.0.size.width + 10 + checkbox.frame.width + 10 + 10, frameRect.height)
    }
    
    override func mouseDown(with event: NSEvent) {
        checkbox.set(isSelected: !checkbox.isSelected, animated: true)
        onChangedValue?(checkbox.isSelected)
    }
    var onChangedValue:((Bool)->Void)?
    
    override func layout() {
        super.layout()
        checkbox.centerY(x: 10)
    }
    
    func update(by image: CGImage?) -> Void {
        if let image = image {
            let color = getAverageColor(NSImage(cgImage: image, size: image.backingSize))
            backgroundColor = color
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        let rect = focus(title.0.size)
        title.1.draw(NSMakeRect(frame.width - rect.width - 10, rect.minY, rect.width, rect.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
    }
    
    deinit {
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WallpaperPreviewView: View {
    private let imageView: TransformImageView = TransformImageView()
    private let magnifyView: MagnifyView
    private let disposable = MetaDisposable()
    private var progressView: RadialProgressView?
    private let tableView = TableView(frame: NSZeroRect, isFlipped: false, drawBorder: false)
    let checkboxView: ApplyBlurCheckboxView = ApplyBlurCheckboxView(frame: NSMakeRect(0, 0, 70, 28))
    private let account: Account
    private(set) var wallpaper: Wallpaper {
        didSet {
            if oldValue != wallpaper {
                updateState()
            }
        }
    }
    
    required init(frame frameRect: NSRect, account: Account, wallpaper: Wallpaper) {
        self.account = account
        self.wallpaper = wallpaper
        self.magnifyView = MagnifyView(imageView, contentSize: frameRect.size)
        super.init(frame: frameRect)
        addSubview(magnifyView)
        addSubview(tableView)
        addSubview(checkboxView)
        imageView.layer?.contentsGravity = .resizeAspectFill
        
        tableView.backgroundColor = .clear
        tableView.layer?.backgroundColor = .clear
        
        
        addTableItems(account)
        
        imageView.imageUpdated = { [weak self] image in
            self?.checkboxView.update(by: image != nil ? (image as! CGImage) : nil)
        }
        
        checkboxView.onChangedValue = { [weak self] isSelected in
            guard let `self` = self else { return }
            self.wallpaper = self.wallpaper.withUpdatedBlurrred(isSelected)
        }
        
        updateState()
    }
    
    private func addTableItems(_ account: Account) {
        switch wallpaper {
        case .color:
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 30, stableId: 0))
        default:
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 80, stableId: 0))
        }
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), account: account, disableSelectAbility: true)
        
        let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        


        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, .bubble, .Full(isAdmin: false), nil, nil, nil)

        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, .bubble, .Full(isAdmin: false), nil, nil, nil)
        
        
        let item1 = ChatRowItem.item(frame.size, from: firstEntry, with: account, interaction: chatInteraction)
        let item2 = ChatRowItem.item(frame.size, from: secondEntry, with: account, interaction: chatInteraction)
        
        _ = item1.makeSize(frame.width, oldWidth: 0)
        _ = item2.makeSize(frame.width, oldWidth: 0)
        
        _ = tableView.addItem(item: item2)
        _ = tableView.addItem(item: item1)
        

    }
    
    deinit {
        disposable.dispose()
    }
    
    override func layout() {
        super.layout()
        magnifyView.frame = bounds
        magnifyView.contentSize = NSMakeSize(magnifyView.contentSize.width, frame.height)
        //imageView.frame = bounds
        tableView.frame = NSMakeRect(0, frame.height - tableView.listHeight, frame.width, tableView.listHeight)
        checkboxView.centerX(y: frame.height - checkboxView.frame.height - 30)
        self.progressView?.center()
    }
    
    func updateState() {
        

        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        
        switch wallpaper {
        case .builtin:
            self.imageView.isHidden = false
            checkboxView.isHidden = false

            let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: -1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: CGSize(), intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor))
            
            self.imageView.setSignal(settingsBuiltinWallpaperImage(account: account, scale: backingScaleFactor))
            
            self.imageView.set(arguments: arguments)
        case let .color(color):
            self.imageView.isHidden = true
            checkboxView.isHidden = true
            backgroundColor = NSColor(UInt32(color))
        case let .image(representations, blurred):
            self.imageView.isHidden = false
            checkboxView.isHidden = false
            let dimensions = largestImageRepresentation(representations)!.dimensions
            let boundingSize = dimensions.fitted(NSMakeSize(1500, 1500))

            self.imageView.setSignal(chatWallpaper(account: account, representations: representations, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: blurred, synchronousLoad: true), animate: true, synchronousLoad: true)
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
            
            self.magnifyView.contentSize = NSMakeSize(boundingSize.width, frame.height)
            
            updatedStatusSignal = account.postbox.mediaBox.resourceStatus(largestImageRepresentation(representations)!.resource, approximateSynchronousValue: true) |> deliverOnMainQueue
            
        case let .file(_, file, blurred):
            self.imageView.isHidden = false
            checkboxView.isHidden = false
            var representations:[TelegramMediaImageRepresentation] = []
            representations.append(contentsOf: file.previewRepresentations)
            if let dimensions = file.dimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource))
            }
            
            let dimensions = largestImageRepresentation(representations)!.dimensions
            let boundingSize = dimensions.fitted(NSMakeSize(frame.width, 1500))
            
            updatedStatusSignal = account.postbox.mediaBox.resourceStatus(largestImageRepresentation(representations)!.resource, approximateSynchronousValue: true) |> deliverOnMainQueue
            
            self.imageView.setSignal(chatWallpaper(account: account, representations: representations, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred:  blurred, synchronousLoad: true), animate: true, synchronousLoad: true)
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
        case let .custom(representation, blurred):
            self.imageView.isHidden = false
            checkboxView.isHidden = false

            let dimensions = representation.dimensions
            let boundingSize = dimensions.fitted(NSMakeSize(frame.width, 1500))

            updatedStatusSignal = account.postbox.mediaBox.resourceStatus(representation.resource, approximateSynchronousValue: true) |> deliverOnMainQueue
            
            self.imageView.setSignal(chatWallpaper(account: account, representations: [representation], autoFetchFullSize: true, scale: backingScaleFactor, isBlurred:  blurred, synchronousLoad: true), animate: true, synchronousLoad: true)
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
        default:
            break
        }
        
        
        if let updatedStatusSignal = updatedStatusSignal {
            disposable.set(updatedStatusSignal.start(next: { [weak self] status in
                guard let `self` = self else { return }
                switch status {
                case let .Fetching(_, progress):
                    if self.progressView == nil {
                        self.progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white), twist: true, size: NSMakeSize(40, 40))
                        self.addSubview(self.progressView!)
                        self.progressView?.center()
                    }
                    self.progressView?.state = .ImpossibleFetching(progress: progress, force: false)
                    break
                case .Local:
                    if let progressView = self.progressView {
                        progressView.state = .ImpossibleFetching(progress:1.0, force: false)
                        self.progressView = nil
                        progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                            if completed {
                                progressView?.removeFromSuperview()
                            }
                        })
                    }
                    
                case .Remote:
                    break
                }
            }))
        } else {
            progressView?.removeFromSuperview()
            progressView = nil
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

enum WallpaperSource {
    case link(TelegramWallpaper)
    case gallery(TelegramWallpaper)
    case none
}


class WallpaperPreviewController: ModalViewController {

    override func viewClass() -> AnyClass {
        return WallpaperPreviewView.self
    }
    
    private let wallpaper: Wallpaper
    private let account: Account

    let source: WallpaperSource
    
    init(account: Account, wallpaper: Wallpaper, source: WallpaperSource) {
        self.wallpaper = wallpaper.isSemanticallyEqual(to: theme.wallpaper) ? theme.wallpaper : wallpaper
        self.account = account
        self.source = source
        super.init(frame: NSMakeRect(0, 0, 380, 300))
        bar = .init(height: 0)
    }
    
    override var modalHeader: String? {
        return L10n.wallpaperPreviewHeader
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.checkboxView.isSelected = wallpaper.isBlurred
        readyOnce()
    }
    
    private func applyAndClose() {
        let postbox = self.account.postbox
        let account = self.account

        closeAllModals()
        
        _ = showModalProgress(signal: moveWallpaperToCache(postbox: account.postbox, wallpaper: genericView.wallpaper) |> delay(0.2, queue: .concurrentDefaultQueue()) |> mapToSignal { wallpaper in
            return updateThemeInteractivetly(postbox: postbox, f: { settings in
                return settings.withUpdatedWallpaper(wallpaper).withUpdatedBubbled(true)
            })
        }, for: mainWindow).start(completed: {
            
            
            var stats:[Signal<Void, NoError>] = []
            switch self.source {
            case let .gallery(wallpaper):
                stats = [installWallpaper(account: account, wallpaper: wallpaper)]
            case let .link(wallpaper):
                stats = [installWallpaper(account: account, wallpaper: wallpaper), saveWallpaper(account: account, wallpaper: wallpaper)]
            case .none:
                break
            }
            let _ = combineLatest(stats).start()

            delay(0.3, closure: {
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
            })
        })
        
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.wallpaperPreviewApply, accept: { [weak self] in
            self?.applyAndClose()
        }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    }
    override func initializer() -> NSView {
        return WallpaperPreviewView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), account: account, wallpaper: wallpaper);
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, size.height - 150), animated: false)
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, contentSize.height - 150), animated: animated)
        }
    }
    
    private var genericView: WallpaperPreviewView {
        return self.view as! WallpaperPreviewView
    }
    
}
