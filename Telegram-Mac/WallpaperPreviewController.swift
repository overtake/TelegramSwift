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

private func availableColors() -> [Int32] {
    return [
        0xffffff,
        0xd4dfea,
        0xb3cde1,
        0x6ab7ea,
        0x008dd0,
        0xd3e2da,
        0xc8e6c9,
        0xc5e1a5,
        0x61b06e,
        0xcdcfaf,
        0xa7a895,
        0x7c6f72,
        0xffd7ae,
        0xffb66d,
        0xde8751,
        0xefd5e0,
        0xdba1b9,
        0xffafaf,
        0xf16a60,
        0xe8bcea,
        0x9592ed,
        0xd9bc60,
        0xb17e49,
        0xd5cef7,
        0xdf506b,
        0x8bd2cc,
        0x3c847e,
        0x22612c,
        0x244d7c,
        0x3d3b85,
        0x65717d,
        0x18222d,
        0x000000
    ]
}



extension Wallpaper {
    var dimensions: NSSize {
        switch self {
        case let .file(_, file, _, _):
            if let dimensions = file.dimensions {
                return dimensions
            }
             return NSMakeSize(300, 300)
        case let .image(representations, _):
            let largest = largestImageRepresentation(representations)
            return largest!.dimensions
        case let .custom(representation, _):
            return representation.dimensions
        case .color:
            return NSMakeSize(300, 300)
        default:
            return NSZeroSize
        }
       
    }
}

private let WallpaperDimensions: NSSize = NSMakeSize(1440, 1980)

private final class blurCheckbox : View {
    
    var isFullFilled: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private(set) var isSelected: Bool = false
    private var timer: SwiftSignalKitMac.Timer?
    func set(isSelected: Bool, animated: Bool) {
        self.isSelected = isSelected
        if animated {
            timer?.invalidate()
            
            let fps: CGFloat = 60

            let tick = isSelected ? ((1 - animationProgress) / (fps * 0.2)) : -(animationProgress / (fps * 0.2))
            
            timer = SwiftSignalKitMac.Timer(timeout: 0.016, repeat: true, completion: { [weak self] in
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
        if !isFullFilled {
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
        }
        

        
//        ctx.round(bounds.size, bounds.height / 2)
//
//        ctx.setStrokeColor(.white)
//        ctx.setLineWidth(2.0)
//        ctx.strokeEllipse(in: bounds)
    }
}

final class ApplyblurCheckbox : View {
    private let title:(TextNodeLayout,TextNode)
    fileprivate let checkbox: blurCheckbox = blurCheckbox(frame: NSMakeRect(0, 0, 16, 16))
    
    var isSelected: Bool {
        get {
            return checkbox.isSelected
        }
        set {
            checkbox.set(isSelected: newValue, animated: false)
        }
    }
    
    required init(frame frameRect: NSRect, title: String) {
        self.title = TextNode.layoutText(NSAttributedString.initialize(string: title, color: .white, font: .medium(.text)), nil, 1, .end, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .left)
        super.init(frame: frameRect)
        addSubview(checkbox)
        layer?.cornerRadius = .cornerRadius
        setFrameSize(self.title.0.size.width + 10 + checkbox.frame.width + 10 + 10, frameRect.height)
    }
    
    override func mouseDown(with event: NSEvent) {
        checkbox.set(isSelected: !checkbox.isSelected, animated: false)
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
        } else {
            backgroundColor = .blackTransparent
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
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private enum WallpaperPreviewState  {
    case color
    case pattern
    case normal
}


final class WallpaperColorPickerContainerView : View, TGModernGrowingDelegate {
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
    }
    
    func textViewEnterPressed(_ event: NSEvent) -> Bool {
        return true
    }
    
    func textViewTextDidChange(_ string: String) {
        var filtered = String(string.unicodeScalars.filter {CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)}).uppercased()
        if string != filtered {
            if filtered.isEmpty {
                filtered = "#"
            } else if filtered.first != "#" {
                filtered = "#" + filtered
            }
            textView.setString(filtered)
        }
        resetButton.isHidden = filtered == defaultColor.hexString
        if filtered.length == maxCharactersLimit(textView) {
            let color = NSColor(hexString: String(filtered[filtered.index(after: filtered.startIndex) ..< filtered.endIndex]))
            if let color = color {
                colorChanged?(color)
            }
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        background = theme.colors.background
        textView.background = theme.colors.background
        textView.textColor = theme.colors.text
        topBorderView.backgroundColor = theme.colors.border
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return textView.frame.size
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 7
    }
    
    var defaultColor: NSColor = NSColor(hexString: "FFFFFF")! {
        didSet {
            textView.setString(defaultColor.hexString)
        }
    }
    
    var colorChanged: ((NSColor) -> Void)? = nil
    
    let colorPicker = WallpaperColorPickerView()
    private let topBorderView: View = View()
    private let resetButton = ImageButton()
    let textView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect, unscrollable: true)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(colorPicker)
        addSubview(textView)
        addSubview(topBorderView)
        textView.delegate = self
        topBorderView.backgroundColor = theme.colors.border
        textView.setString("#")
        textView.textFont = .normal(.title)
        backgroundColor = theme.colors.background
        textView.cursorColor = theme.colors.indicatorColor
        resetButton.set(image: theme.icons.recentDismiss, for: .Normal)
        _ = resetButton.sizeToFit()
        addSubview(resetButton)
        
        resetButton.set(handler: { [weak self] _ in
            guard let `self` = self else { return }
            self.textView.setString(self.defaultColor.hexString)
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        textView.frame = NSMakeRect(10, 0, frame.width - resetButton.frame.width - 20, 30)
        topBorderView.frame = NSMakeRect(0, 0, frame.width, .borderSize)
        colorPicker.frame = NSMakeRect(0, 30, frame.width, frame.height - 30)
        resetButton.setFrameOrigin(NSMakePoint(frame.width - resetButton.frame.width - 10, (30 - resetButton.frame.height) / 2))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WallpaperPreviewView: View {
    private let imageView: TransformImageView = TransformImageView()
    let magnifyView: MagnifyView
    private let disposable = MetaDisposable()
    private var progressView: RadialProgressView?
    private let tableView: TableView
    private let documentView: NSView
    let colorPicker = WallpaperColorPickerContainerView(frame: NSZeroRect)
    let blurCheckbox: ApplyblurCheckbox = ApplyblurCheckbox(frame: NSMakeRect(0, 0, 70, 28), title: L10n.wallpaperPreviewBlurred)
    let patternCheckbox: ApplyblurCheckbox = ApplyblurCheckbox(frame: NSMakeRect(0, 0, 70, 28), title: L10n.chatWPPattern)
    let colorCheckbox: ApplyblurCheckbox = ApplyblurCheckbox(frame: NSMakeRect(0, 0, 70, 28), title: L10n.chatWPColor)
    let checkboxContainer: View = View()
    let patternsController: WallpaperPatternPreviewController
    private var previewState: WallpaperPreviewState = .normal
    private var imageSize: NSSize = NSZeroSize
    private let context: AccountContext
    private(set) var wallpaper: Wallpaper {
        didSet {
            if oldValue != wallpaper {
                updateState(synchronousLoad: false)
            }
        }
    }
    
    override func smartMagnify(with event: NSEvent) {
        magnifyView.smartMagnify(with: event)
    }
    
    override func magnify(with event: NSEvent) {
        magnifyView.magnify(with: event)
    }
    
    required init(frame frameRect: NSRect, context: AccountContext, wallpaper: Wallpaper) {
        self.context = context
        self.wallpaper = wallpaper
        self.tableView = TableView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height), isFlipped: false, drawBorder: false)
        self.magnifyView = MagnifyView(imageView, contentSize: frameRect.size)
        self.documentView = tableView.documentView!
        self.patternsController = WallpaperPatternPreviewController(context: context)
        super.init(frame: frameRect)
        addSubview(patternsController.view)
        addSubview(magnifyView)
        documentView.removeFromSuperview()
        addSubview(documentView)
        checkboxContainer.addSubview(blurCheckbox)
        checkboxContainer.addSubview(patternCheckbox)
        checkboxContainer.addSubview(colorCheckbox)
        addSubview(checkboxContainer)
        addSubview(colorPicker)
        addSubview(patternsController.view)
        imageView.layer?.contentsGravity = .resizeAspectFill
        
        patternCheckbox.checkbox.isFullFilled = true
        colorCheckbox.checkbox.isFullFilled = true
        
        tableView.backgroundColor = .clear
        tableView.layer?.backgroundColor = .clear
        
        addTableItems(context)
        
        imageView.imageUpdated = { [weak self] image in
            self?.blurCheckbox.update(by: image != nil ? (image as! CGImage) : nil)
            self?.colorCheckbox.update(by: image != nil ? (image as! CGImage) : nil)
            self?.patternCheckbox.update(by: image != nil ? (image as! CGImage) : nil)
        }
        
        blurCheckbox.onChangedValue = { [weak self] isSelected in
            guard let `self` = self else { return }
            self.wallpaper = self.wallpaper.withUpdatedBlurrred(isSelected)
        }
        
        colorCheckbox.onChangedValue = { [weak self] isSelected in
            guard let `self` = self else { return }
            switch self.previewState {
            case .color:
                self.updateModifyState(.normal, animated: true)
            default:
                self.updateModifyState(.color, animated: true)
            }
        }
        
        patternCheckbox.onChangedValue = { [weak self] isSelected in
            guard let `self` = self else { return }
            switch self.previewState {
            case .pattern:
                self.updateModifyState(.normal, animated: true)
            default:
                self.updateModifyState(.pattern, animated: true)
            }
        }
        
        switch wallpaper {
        case let .color(color):
            colorPicker.colorPicker.color = NSColor(UInt32(color))
            colorPicker.defaultColor = colorPicker.colorPicker.color
        case let .file(_, _, settings, _):
            colorPicker.colorPicker.color = settings.color != nil ? NSColor(UInt32(settings.color!)) :  NSColor(hexString: "ffffff")!
            colorPicker.defaultColor = colorPicker.colorPicker.color
        default:
            break
        }
        
        colorPicker.colorPicker.colorChanged = { [weak self] color in
            guard let `self` = self else {return}
            let settings = self.wallpaper.settings
            switch self.wallpaper {
            case .color:
                self.wallpaper = .color(Int32(bitPattern: color.rgb))
                self.colorPicker.textView.setString(color.hexString)
            default:
                self.wallpaper = self.wallpaper.withUpdatedSettings(settings.withUpdatedColor(Int32(bitPattern: color.rgb)))
                self.colorPicker.textView.setString(color.hexString)
            }
        }
        
        colorPicker.colorChanged = { [weak self] color in
            guard let `self` = self else {return}
            if self.colorPicker.colorPicker.color != color {
                self.colorPicker.colorPicker.color = color
                self.colorPicker.colorPicker.colorChanged?(color)
                self.patternsController.color = color
                self.colorPicker.colorPicker.needsLayout = true
            }
        }
        
        colorPicker.colorPicker.colorChangeEnded = { [weak self] color in
            self?.patternsController.color = color
        }
        
        patternsController.color = colorPicker.colorPicker.color
        
        patternsController.selected = { [weak self] wallpaper in
            guard let `self` = self else {return}
            if let wallpaper = wallpaper {
                switch self.wallpaper {
                case let .color(color):
                     self.wallpaper = wallpaper.withUpdatedSettings(WallpaperSettings(color: color, intensity: self.patternsController.intensity))
                case let .file(_, _, settings, _):
                    self.wallpaper = wallpaper.withUpdatedSettings(WallpaperSettings(color: settings.color, intensity: self.patternsController.intensity))
                default:
                    break
                }
            } else {
                switch self.wallpaper {
                case .color:
                    break
                case let .file(_, _, settings, _):
                    if let color = settings.color {
                        self.wallpaper = Wallpaper.color(color)
                    }
                default:
                    break
                }
            }
        }
        
        updateState(synchronousLoad: true)
    }
    
    private func addTableItems(_ context: AccountContext) {
        switch wallpaper {
        case .color:
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 50, stableId: 0))
        case .file(_, _, _, _):
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 50, stableId: 0))
        default:
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 50, stableId: 0))
        }
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context, disableSelectAbility: true)
        
        let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        

        let firstText: String
        let secondText: String
        switch wallpaper {
        case let .file(_, _, _, isPattern):
            if isPattern {
                firstText = L10n.chatWPColorFirstMessage
                secondText = L10n.chatWPColorSecondMessage
            } else {
                firstText = L10n.chatWPFirstMessage
                secondText = L10n.chatWPSecondMessage
            }
        case .image:
            firstText = L10n.chatWPFirstMessage
            secondText = L10n.chatWPSecondMessage
        default:
            firstText = L10n.chatWPColorFirstMessage
            secondText = L10n.chatWPColorSecondMessage
        }

        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: firstText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, .bubble, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)

        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: secondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, .bubble, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
        
        
        let item1 = ChatRowItem.item(frame.size, from: firstEntry, interaction: chatInteraction, theme: theme)
        let item2 = ChatRowItem.item(frame.size, from: secondEntry, interaction: chatInteraction, theme: theme)
        

        
        _ = tableView.addItem(item: item2)
        _ = tableView.addItem(item: item1)
        
    }
    
    var croppedRect: NSRect {
        
        let fittedSize = WallpaperDimensions.aspectFitted(imageSize)
        
       // let imageFitted = imageSize.aspectFitted(WallpaperDimensions)
        let multiplier = NSMakeSize( imageSize.width / magnifyView.contentFrame.width, imageSize.height / magnifyView.contentFrame.height)
        let magnifyRect = magnifyView.contentFrame.apply(multiplier: multiplier)
        let fittedRect = NSMakeRect(abs(magnifyRect.minX), abs(magnifyRect.minY), fittedSize.width, fittedSize.height)
    
        return fittedRect.offsetBy(dx:(magnifyView.contentFrame.minX - magnifyView.contentFrameMagnified.minX) * multiplier.width, dy: (magnifyView.contentFrame.minY - magnifyView.contentFrameMagnified.minY) * multiplier.height)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func layout() {
        super.layout()
        
        var checkboxWidth: CGFloat = blurCheckbox.isHidden ? 0 : blurCheckbox.frame.width
        if !patternCheckbox.isHidden {
            checkboxWidth += (checkboxWidth != 0 ? 10 + patternCheckbox.frame.width : patternCheckbox.frame.width)
        }
        if !colorCheckbox.isHidden {
            checkboxWidth += (checkboxWidth != 0 ? 10 + colorCheckbox.frame.width : colorCheckbox.frame.width)
        }
        
        checkboxContainer.setFrameSize(NSMakeSize(checkboxWidth, 28))
        
        var point: NSPoint = NSZeroPoint
    
        blurCheckbox.setFrameOrigin(point)
        if !colorCheckbox.isHidden {
            colorCheckbox.setFrameOrigin(point)
            point.x += colorCheckbox.frame.width
        }
        if point.x != 0 {
            point.x += 10
        }
        patternCheckbox.setFrameOrigin(point)
        
        
        
        magnifyView.frame = bounds
        switch wallpaper {
        case let .file(_, _, _, isPattern):
            if isPattern {
                magnifyView.contentSize = frame.size
            } else {
                magnifyView.contentSize = imageSize.aspectFilled(frame.size)
            }
        default:
            magnifyView.contentSize = imageSize.aspectFilled(frame.size)//NSMakeSize(magnifyView.contentSize.width, frame.height)
        }
        //imageView.frame = bounds
        tableView.frame = bounds
        documentView.setFrameSize(NSMakeSize(frame.width, documentView.frame.height))
        
        self.progressView?.center()
        colorPicker.setFrameSize(NSMakeSize(frame.width, 160))
        patternsController.view.setFrameSize(NSMakeSize(frame.width, 160))
        
        updateModifyState(self.previewState, animated: false)
    }
    
    
    func updateModifyState(_ state: WallpaperPreviewState, animated: Bool) {
        self.previewState = state
        switch state {
        case .color:
            patternCheckbox.isSelected = false
            colorCheckbox.isSelected = true
            colorPicker.change(pos: NSMakePoint(0, frame.height - colorPicker.frame.height), animated: animated)
            documentView._change(pos: NSMakePoint(0, frame.height - colorPicker.frame.height - tableView.listHeight), animated: animated)
            checkboxContainer.change(pos: NSMakePoint(focus(checkboxContainer.frame.size).minX, frame.height - colorPicker.frame.height - checkboxContainer.frame.height - 10), animated: animated)
            patternsController.view._change(pos: NSMakePoint(0, frame.height), animated: animated)
        case .normal:
            patternCheckbox.isSelected = false
            colorCheckbox.isSelected = false
            checkboxContainer.change(pos: NSMakePoint(focus(checkboxContainer.frame.size).minX, frame.height - checkboxContainer.frame.height - 10), animated: animated)
            documentView._change(pos: NSMakePoint(0, frame.height - tableView.listHeight), animated: animated)
            colorPicker.change(pos: NSMakePoint(0, frame.height), animated: animated)
            patternsController.view._change(pos: NSMakePoint(0, frame.height), animated: animated)
        case .pattern:
            patternsController.pattern = self.wallpaper
            patternCheckbox.isSelected = true
            colorCheckbox.isSelected = false
            colorPicker.change(pos: NSMakePoint(0, frame.height), animated: animated)
            documentView._change(pos: NSMakePoint(0, frame.height - patternsController.view.frame.height - tableView.listHeight), animated: animated)
            checkboxContainer.change(pos: NSMakePoint(focus(checkboxContainer.frame.size).minX, frame.height - patternsController.view.frame.height - checkboxContainer.frame.height - 10), animated: animated)
            patternsController.view._change(pos: NSMakePoint(0, frame.height - patternsController.view.frame.height), animated: animated)
        }
    }
    
    func updateState(synchronousLoad: Bool) {
        

        let maximumSize: NSSize = WallpaperDimensions
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        
        switch wallpaper {
        case .builtin:
            self.imageView.isHidden = false
            blurCheckbox.isHidden = false
            colorCheckbox.isHidden = true
            patternCheckbox.isHidden = true
            
            let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: -1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: CGSize(), intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor))
            self.imageView.setSignal(settingsBuiltinWallpaperImage(account: context.account, scale: backingScaleFactor))
            self.imageView.set(arguments: arguments)
        case let .color(color):
            self.imageView.isHidden = true
            blurCheckbox.isHidden = true
            colorCheckbox.isHidden = false
            patternCheckbox.isHidden = false
            backgroundColor = NSColor(UInt32(color))
            
            let image = generateImage(NSMakeSize(1, 1), contextGenerator: { size, ctx in
                ctx.setFillColor(NSColor(UInt32(color)).cgColor)
                ctx.fill(NSMakeRect(0, 0, size.width, size.height))
            })
            self.blurCheckbox.update(by: image)
            self.colorCheckbox.update(by: image)
            self.patternCheckbox.update(by: image)
            
        case let .image(representations, settings):
            self.imageView.isHidden = false
            blurCheckbox.isHidden = false
            colorCheckbox.isHidden = true
            patternCheckbox.isHidden = true
            let dimensions = largestImageRepresentation(representations)!.dimensions
            let boundingSize = dimensions.fitted(maximumSize)
            self.imageSize = dimensions

            self.imageView.setSignal(chatWallpaper(account: context.account, representations: representations, mode: .screen, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: settings.blur, synchronousLoad: synchronousLoad), animate: true, synchronousLoad: synchronousLoad)
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
            
            updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(largestImageRepresentation(representations)!.resource, approximateSynchronousValue: synchronousLoad) |> deliverOnMainQueue
            magnifyView.maxMagnify = 3.0

        case let .file(_, file, settings, isPattern):
            self.imageView.isHidden = false
            blurCheckbox.isHidden = isPattern
            
            colorCheckbox.isHidden = !isPattern
            patternCheckbox.isHidden = !isPattern
            
            var patternColor: NSColor? = nil// = NSColor(rgb: 0xd6e2ee, alpha: 0.5)
            
            if isPattern {
                var patternIntensity: CGFloat = 0.5
                if let color = settings.color {
                    if let intensity = settings.intensity {
                        patternIntensity = CGFloat(intensity) / 100.0
                    }
                    patternColor = NSColor(rgb: UInt32(bitPattern: color), alpha: patternIntensity)
                }
            }
            magnifyView.maxMagnify = !isPattern ? 3.0 : 1.0
            
            var representations:[TelegramMediaImageRepresentation] = []
            representations.append(contentsOf: file.previewRepresentations)
            if let dimensions = file.dimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource))
            }
            
            let dimensions = largestImageRepresentation(representations)!.dimensions
            let boundingSize = dimensions.fitted(maximumSize)
            self.imageSize = dimensions

            updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(largestImageRepresentation(representations)!.resource, approximateSynchronousValue: synchronousLoad) |> deliverOnMainQueue
            
            self.imageView.setSignal(chatWallpaper(account: context.account, representations: representations, mode: .screen, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred:  settings.blur, synchronousLoad: synchronousLoad), animate: true, synchronousLoad: synchronousLoad)
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets(), emptyColor: patternColor))
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
        needsLayout = true
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

private func cropWallpaperImage(_ image: CGImage, dimensions: NSSize, rect: NSRect, magnify: CGFloat, settings: WallpaperSettings?) -> CGImage {
    let fittedSize = NSMakeSize(dimensions.width * magnify, dimensions.height * magnify)//WallpaperDimensions.aspectFitted(representation.dimensions)
    
    let image = generateImage(rect.size, contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.interpolationQuality = .high
        ctx.setBlendMode(.normal)
        let imageRect = NSMakeRect(-rect.minX, -rect.minY, fittedSize.width, fittedSize.height)
        ctx.draw(image, in: imageRect)
    }, opaque: false, scale: 1.0)!
    
    let fitted = WallpaperDimensions.aspectFitted(dimensions)
    
    return generateImage(fitted, contextGenerator: { size, ctx in
        let imageRect = NSMakeRect(0, 0, fitted.width, fitted.height)
        ctx.clear(imageRect)
        if let settings = settings {
            
          var _patternColor: NSColor = NSColor(rgb: 0xd6e2ee, alpha: 0.5)
            
            var patternIntensity: CGFloat = 0.5
            if let color = settings.color {
                if let intensity = settings.intensity {
                    patternIntensity = CGFloat(intensity) / 100.0
                }
                _patternColor = NSColor(rgb: UInt32(bitPattern: color), alpha: patternIntensity)
            }
            
            let color = _patternColor.withAlphaComponent(1.0)
            let intensity = _patternColor.alpha
            
            ctx.setBlendMode(.copy)
            ctx.setFillColor(color.cgColor)
            ctx.fill(imageRect)
            
            ctx.setBlendMode(.normal)
            ctx.interpolationQuality = .high

            ctx.clip(to: imageRect, mask: image)
            ctx.setFillColor(patternColor(for: color, intensity: intensity).cgColor)
            ctx.fill(imageRect)
        } else {
            ctx.draw(image, in: imageRect)
        }
        
        //ctx.draw(image, in: imageRect)
    }, opaque: false, scale: 1.0)!
    
}

private func cropWallpaperIfNeeded(_ wallpaper: Wallpaper, account: Account, rect: NSRect, magnify: CGFloat = 1.0) -> Signal<Wallpaper, NoError> {
    return Signal { subscriber in
        
        let disposable = MetaDisposable()
        switch wallpaper {
        case let .image(representations, _):
            if let representation = largestImageRepresentation(representations), let resource = representation.resource as? LocalFileReferenceMediaResource {
                if let image = NSImage(contentsOfFile: resource.localFilePath)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    
                    let fittedImage = cropWallpaperImage(image, dimensions: representation.dimensions, rect: rect, magnify: magnify, settings: nil)

                    let options = NSMutableDictionary()
                    options.setValue(90 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
                    var result: [TelegramMediaImageRepresentation] = []
                    let colorQuality: Float = 0.1
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    let mutableData: CFMutableData = NSMutableData() as CFMutableData
                    
                    if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationAddImage(colorDestination, fittedImage, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            let thumdResource = LocalFileMediaResource(fileId: arc4random64())
                            account.postbox.mediaBox.storeResourceData(thumdResource.id, data: mutableData as Data)
                            result.append(TelegramMediaImageRepresentation(dimensions: fittedImage.backingSize.aspectFitted(NSMakeSize(90, 90)), resource: thumdResource))
                        }
                    }
                    
                    let fittedDimensions = WallpaperDimensions.aspectFitted(representation.dimensions)
                    
                     disposable.set(putToTemp(image: NSImage(cgImage: fittedImage, size: fittedDimensions), compress: false).start(next: { path in
                        copyToClipboard(path)
                        let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                        result.append(TelegramMediaImageRepresentation(dimensions: fittedDimensions, resource: resource))
                        
                        let wallpaper: Wallpaper = .image(result, settings: wallpaper.settings)
                        subscriber.putNext(wallpaper)
                        subscriber.putCompletion()
                    }))
                }
            }
        case let .file(slug, file, settings, isPattern):
            if let dimensions = file.dimensions {
                if let path = account.postbox.mediaBox.completedResourcePath(file.resource), let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    if isPattern {
                        subscriber.putNext(wallpaper.withUpdatedSettings(settings))
                        subscriber.putCompletion()
                    } else {
                        let fittedImage = cropWallpaperImage(image, dimensions: dimensions, rect: rect, magnify: magnify, settings: isPattern ? settings : nil)
                        
                        let options = NSMutableDictionary()
                        options.setValue(90 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
                        var result: [TelegramMediaImageRepresentation] = []
                        let colorQuality: Float = 0.1
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        let mutableData: CFMutableData = NSMutableData() as CFMutableData
                        
                        if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) {
                            CGImageDestinationAddImage(colorDestination, fittedImage, options as CFDictionary)
                            if CGImageDestinationFinalize(colorDestination) {
                                let thumdResource = LocalFileMediaResource(fileId: arc4random64())
                                account.postbox.mediaBox.storeResourceData(thumdResource.id, data: mutableData as Data)
                                result.append(TelegramMediaImageRepresentation(dimensions: fittedImage.backingSize.aspectFitted(NSMakeSize(90, 90)), resource: thumdResource))
                            }
                        }
                        
                        let fittedDimensions = WallpaperDimensions.aspectFitted(dimensions)
                        
                        disposable.set(putToTemp(image: NSImage(cgImage: fittedImage, size: fittedDimensions), compress: false).start(next: { path in
                            let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                            
                            var attributes = file.attributes
                            loop: for (i, attr) in attributes.enumerated() {
                                switch attr {
                                case .ImageSize:
                                    attributes[i] = .ImageSize(size: fittedDimensions)
                                    break loop
                                default:
                                    break
                                }
                            }
                            
                            let wallpaper: Wallpaper = .file(slug: slug, file: file.withUpdatedPreviewRepresentations(result).withUpdatedResource(resource).withUpdatedAttributes(attributes), settings: settings, isPattern: isPattern)
                            subscriber.putNext(wallpaper)
                            subscriber.putCompletion()
                        }))
                    }
                    
                }
            }
        default:
            subscriber.putNext(wallpaper)
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            disposable.dispose()
        }
    } |> runOn(resourcesQueue)
}


class WallpaperPreviewController: ModalViewController {

    override func viewClass() -> AnyClass {
        return WallpaperPreviewView.self
    }
    
    override var handleAllEvents: Bool {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.colorPicker.textView
    }
    
    private let wallpaper: Wallpaper
    private let context: AccountContext

    let source: WallpaperSource
    
    init(_ context: AccountContext, wallpaper: Wallpaper, source: WallpaperSource) {
        self.wallpaper = wallpaper.isSemanticallyEqual(to: theme.wallpaper) ? wallpaper.withUpdatedBlurrred(theme.wallpaper.isBlurred) : wallpaper
        self.context = context
        self.source = source
        super.init(frame: NSMakeRect(0, 0, 380, 300))
        bar = .init(height: 0)
    }
    public override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        let hasShare: Bool
        switch genericView.wallpaper {
        case .color, .file:
            hasShare = true
        default:
            hasShare = false
        }
        
        return (left: nil, center: ModalHeaderData(title: L10n.wallpaperPreviewHeader), right: !hasShare ? nil : ModalHeaderData(image: theme.icons.modalShare, handler: { [weak self] in
            self?.share()
        }))
    }

    private func share() {
        close()
        
        switch genericView.wallpaper {
        case let .file(slug, _, settings, isPattern):
            var options: [String] = []
            if settings.blur {
                options.append("mode=blur")
            }
            
            if isPattern {
                if let pattern = settings.color {
                    var color = NSColor(rgb: UInt32(bitPattern: pattern)).hexString.lowercased()
                    color = String(color[color.index(after: color.startIndex) ..< color.endIndex])
                    options.append("bg_color=\(color)")
                }
                if let intensity = settings.intensity {
                    options.append("intensity=\(intensity)")
                }
            }
            
            var optionsString = ""
            if !options.isEmpty {
                optionsString = "?\(options.joined(separator: "&"))"
            }
            showModal(with: ShareModalController.init(ShareLinkObject(context, link: "https://t.me/bg/\(slug)\(optionsString)")), for: mainWindow)
        case let .color(color):
            var color = NSColor(rgb: UInt32(bitPattern: color)).hexString.lowercased()
            color = String(color[color.index(after: color.startIndex) ..< color.endIndex])
            showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/bg/\(color)")), for: mainWindow)
        default:
            break
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.blurCheckbox.isSelected = wallpaper.isBlurred
       
        readyOnce()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.magnifyView.zoomOut()
            return .invoked
        }, with: self, for: .Minus, priority: .modal)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.magnifyView.zoomIn()
            return .invoked
        }, with: self, for: .Equal, priority: .modal)
    }
    

    private func applyAndClose() {
        let context = self.context
        closeAllModals()
        
        let signal = cropWallpaperIfNeeded(genericView.wallpaper, account: context.account, rect: genericView.croppedRect, magnify: genericView.magnifyView.magnify) |> mapToSignal { wallpaper in
            return moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wallpaper) |> delay(0.2, queue: Queue.mainQueue())
        }
        
        _ = showModalProgress(signal: signal, for: mainWindow).start(next: { wallpaper in
            _ = (updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                let c_wallpaper: Wallpaper?
                switch wallpaper {
                case .color:
                    c_wallpaper = wallpaper
                default:
                    c_wallpaper = nil
                }
                
                return settings.withUpdatedWallpaper(wallpaper).withUpdatedCustomWallpaper(c_wallpaper ?? settings.customWallpaper).withUpdatedBubbled(true)
                }) |> delay(0.1, queue: Queue.mainQueue()) |> deliverOnMainQueue).start(completed: {
                    var stats:[Signal<Void, NoError>] = []
                    switch self.source {
                    case let .gallery(wallpaper):
                        stats = [installWallpaper(account: context.account, wallpaper: wallpaper)]
                    case let .link(wallpaper):
                        stats = [installWallpaper(account: context.account, wallpaper: wallpaper), saveWallpaper(account: context.account, wallpaper: wallpaper)]
                    case .none:
                        break
                    }
                    let _ = combineLatest(stats).start()
                    
                    delay(0.3, closure: {
                        _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                    })
                })
        })
        
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.wallpaperPreviewApply, accept: { [weak self] in
            self?.applyAndClose()
        }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    }
    override func initializer() -> NSView {
        return WallpaperPreviewView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), context: context, wallpaper: wallpaper);
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        let chatSize = NSMakeSize(context.sharedContext.bindings.rootNavigation().frame.width, min(500, size.height - 150))
        let contentSize = WallpaperDimensions.aspectFitted(chatSize)
        
        self.modal?.resize(with: contentSize, animated: false)
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
