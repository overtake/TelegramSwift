//
//  WallpaperPreviewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox

import CoreGraphics

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
                return dimensions.size
            }
             return NSMakeSize(300, 300)
        case let .image(representations, _):
            let largest = largestImageRepresentation(representations)
            return largest!.dimensions.size
        case let .custom(representation, _):
            return representation.dimensions.size
        case .color:
            return NSMakeSize(300, 300)
        default:
            return NSZeroSize
        }
       
    }
}

let WallpaperDimensions: NSSize = NSMakeSize(1040, 1580)




private enum WallpaperPreviewState  {
    case color
    case pattern
    case normal
}


enum WallpaperColorSelectMode : Equatable {
    case single(NSColor)
    case gradient([NSColor], Int, Int32?)
    
    var colors: [NSColor] {
        switch self {
        case let .single(color):
            return [color]
        case let .gradient(colors, _, _):
            return colors
        }
    }
    var rotation: Int32? {
        switch self {
        case .single:
            return nil
        case let .gradient(_, _, rotation):
            return rotation
        }
    }
    
    func withRemovedColor(_ index: Int) -> WallpaperColorSelectMode {
        switch self {
        case .single:
            return self
        case let .gradient(colors, selected, rotation):
            var colors = colors
            if colors.count == 1 {
                return .gradient(colors, 0, rotation)
            }
            colors.remove(at: index)
            return .gradient(colors, min(selected, colors.count - 1), rotation)
        }
    }
    func withAddedColor(_ color: NSColor, at index: Int) -> WallpaperColorSelectMode {
        switch self {
        case let .single(current):
            return .gradient([current, color], 1, nil)
        case let .gradient(colors, _, rotation):
            var colors = colors
            colors.insert(color, at: index)
            return .gradient(colors, index + 1, rotation)
        }
    }
    func withUpdatedRotatation(_ rotation: Int32?) -> WallpaperColorSelectMode {
        switch self {
        case .single:
            return self
        case let .gradient(colors, index, _):
            return .gradient(colors, index, rotation)
        }
    }
    
    func withUpdatedColor(_ color: NSColor) -> WallpaperColorSelectMode {
        switch self {
        case .single:
            return .single(color)
        case let .gradient(colors, index, rotation):
            var colors = colors
            colors[index] = color
            return .gradient(colors, index, rotation)
        }
    }
    func withUpdatedIndex(_ index: Int) -> WallpaperColorSelectMode {
        switch self {
        case let .single(current):
            return .single(current)
        case let .gradient(colors, _, rotation):
            return .gradient(colors, index, rotation)
        }
    }

}


private final class WallpaperPreviewView: View {
    private let updateStateDisposable = MetaDisposable()
    private let backgroundView: BackgroundView = BackgroundView(frame: NSZeroRect)
    private var image: CGImage?
    private let disposable = MetaDisposable()
    private let loadImageDisposable = MetaDisposable()

    private var progressView: RadialProgressView?
    private let tableView: TableView
    private let documentView: NSView
    
    let blurCheckbox = WallpaperCheckboxView(frame: NSMakeRect(0, 0, 70, 28), title: L10n.wallpaperPreviewBlurred)
    let patternCheckbox = WallpaperCheckboxView(frame: NSMakeRect(0, 0, 70, 28), title: L10n.chatWPPattern)
    let colorCheckbox = WallpaperCheckboxView(frame: NSMakeRect(0, 0, 70, 28), title: L10n.chatWPColor)
    
    private let rotateColors: WallpaperPlayRotateView = WallpaperPlayRotateView(frame: NSMakeRect(0, 0, 40, 40))
    
    let checkboxContainer: View = View()
    
    let patternsController: WallpaperPatternPreviewController
    let colorPicker = WallpaperColorPickerContainerView(frame: NSZeroRect)
    private let controlsBg = View()
    
    private var previewState: WallpaperPreviewState = .normal
    private var imageSize: NSSize = NSZeroSize
    private let context: AccountContext
    
    fileprivate var ready:(()->Void)? = nil
    
    private(set) var wallpaper: Wallpaper {
        didSet {
            if oldValue != wallpaper {
                let signal = Signal<NoValue, NoError>.complete() |> delay(0.05, queue: .mainQueue())
                updateStateDisposable.set(signal.start(completed: { [weak self] in
                    self?.updateState(synchronousLoad: false)
                }))
            }
        }
    }
    
    
    
    required init(frame frameRect: NSRect, context: AccountContext, wallpaper: Wallpaper) {
        self.context = context
        self.wallpaper = wallpaper
        self.tableView = TableView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height), isFlipped: false, drawBorder: false)
        self.documentView = tableView.documentView!
        self.patternsController = WallpaperPatternPreviewController(context: context)
        super.init(frame: frameRect)
        backgroundView.useSharedAnimationPhase = false
        addSubview(backgroundView)
        documentView.removeFromSuperview()
        addSubview(documentView)
        checkboxContainer.addSubview(blurCheckbox)
        checkboxContainer.addSubview(patternCheckbox)
        checkboxContainer.addSubview(colorCheckbox)
        checkboxContainer.addSubview(rotateColors)
        addSubview(checkboxContainer)
        
        addSubview(controlsBg)
        addSubview(colorPicker)
        addSubview(patternsController.view)
        
        
        controlsBg.backgroundColor = theme.colors.background
        colorPicker.canUseGradient = true
        
        colorPicker.modeDidUpdate = { [weak self] mode in
            guard let strongSelf = self else {
                return
            }
            let wallpaper = strongSelf.wallpaper
            switch mode {
            case let .single(color):
                switch wallpaper {
                case let .file(_, _, settings, _):
                    strongSelf.wallpaper = wallpaper.withUpdatedSettings(settings.withUpdatedColor(color.argb))
                default:
                    strongSelf.wallpaper = .color(color.argb)
                }
            case let .gradient(colors, _, rotation):
                switch wallpaper {
                case let .file(_, _, settings, _):
                    let updated = WallpaperSettings(blur: settings.blur, motion: settings.motion, colors: colors.map { $0.argb }, intensity: settings.intensity, rotation: rotation)
                    strongSelf.wallpaper = wallpaper.withUpdatedSettings(updated)
                default:
                    strongSelf.wallpaper = .gradient(nil, colors.map { $0.argb }, rotation)
                }
            }
            strongSelf.updateMode(mode, animated: true)
        }
                
        tableView.backgroundColor = .clear
        tableView.layer?.backgroundColor = .clear
        
        addTableItems(context)
        
        self.layout()

        
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
        
        rotateColors.onClick = { [weak self] in
            guard let `self` = self else { return }
            
            let mode = self.colorPicker.mode
            let rotation: Int32?

            if mode.colors.count > 2 {
                rotation = nil
                self.backgroundView.doAction()
            } else {
                switch mode {
                case let .gradient(_, _, r):
                    if let r = r {
                        if r + 45 == 360 {
                            rotation = nil
                        } else {
                            rotation = r + 45
                        }
                    } else {
                        rotation = 45
                    }
                default:
                    rotation = nil
                }
            }
            
            self.colorPicker.modeDidUpdate?(mode.withUpdatedRotatation(rotation))
            
        }
        
        switch wallpaper {
        case let .color(color):
            self.updateMode(.single(NSColor(argb: color)), animated: false)
        case let .file(_, _, settings, _):
            let colors:[NSColor] = settings.colors.map { .init(argb: $0) }
            if !colors.isEmpty {
                if colors.count == 1 {
                    self.updateMode(.single(colors[0]), animated: false)
                } else {
                    self.updateMode(.gradient(colors, colors.count - 1, settings.rotation), animated: false)
                }
            }
        case let .gradient(_, colors, rotation):
            let colors = colors.map { NSColor(argb: $0) }
            self.updateMode(.gradient(colors, 0, rotation), animated: false)
        default:
            break
        }


        colorPicker.colorChanged = { [weak self] mode in
            guard let `self` = self else {return}
            switch mode {
            case let .single(color):
                self.patternsController.colors = ([color], nil)
            case let .gradient(colors, _, rotation):
                self.patternsController.colors = (colors, rotation)
            }
            self.updateMode(mode, animated: true)
        }
        
        patternsController.selected = { [weak self] wallpaper in
            guard let `self` = self else {return}
            if let wallpaper = wallpaper {
                switch self.wallpaper {
                case let .color(color):
                     self.wallpaper = wallpaper.withUpdatedSettings(WallpaperSettings(colors: [color], intensity: self.patternsController.intensity))
                case let .gradient(_, colors, r):
                    self.wallpaper = wallpaper.withUpdatedSettings(WallpaperSettings(colors: colors.map {
                        NSColor(argb: $0).withAlphaComponent(1.0).argb
                    }, intensity: self.patternsController.intensity, rotation: r))
                case let .file(_, _, settings, _):
                    self.wallpaper = wallpaper.withUpdatedSettings(WallpaperSettings(colors: settings.colors, intensity: self.patternsController.intensity, rotation: settings.rotation))
                default:
                    break
                }
            } else {
                switch self.wallpaper {
                case .color:
                    break
                case let .file(_, _, settings, _):
                    if settings.colors.count == 1 {
                        self.wallpaper = .color(settings.colors.first!)
                    } else if settings.colors.count > 1 {
                        self.wallpaper = .gradient(nil, settings.colors, nil)
                    } else {
                        self.wallpaper = .none
                    }
                default:
                    break
                }
            }
        }
        
    
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {
                return
            }
            self.tableView.enumerateVisibleViews(with: { view in
                if let view = view as? ChatRowView {
                    view.updateBackground(animated: false, item: view.item)
                }
            })
        }))
        
    }
    
    private func addTableItems(_ context: AccountContext) {
        
        
        switch wallpaper {
        case .color:
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 50, stableId: 0, backgroundColor: .clear))
        case .file(_, _, _, _):
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 50, stableId: 0, backgroundColor: .clear))
        default:
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 50, stableId: 0, backgroundColor: .clear))
        }
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context, disableSelectAbility: true)
        
        chatInteraction.getGradientOffsetRect = { [weak self] in
            guard let `self` = self else {
                return .zero
            }
            return CGRect(origin: NSMakePoint(0, self.documentView.frame.height), size: self.documentView.frame.size)
        }
        
        
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

        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: firstText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, .bubble, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))

        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: secondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, .bubble, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        
        
        let item1 = ChatRowItem.item(frame.size, from: firstEntry, interaction: chatInteraction, theme: theme)
        let item2 = ChatRowItem.item(frame.size, from: secondEntry, interaction: chatInteraction, theme: theme)
        

        
        _ = tableView.addItem(item: item2)
        _ = tableView.addItem(item: item1)
        
    }
    
    var croppedRect: NSRect {
        let fittedSize = WallpaperDimensions.aspectFitted(imageSize)
        return fittedSize.bounds
    }
    
    deinit {
        updateStateDisposable.dispose()
        disposable.dispose()
        loadImageDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    
    private func updateMode(_ mode: WallpaperColorSelectMode, animated: Bool) {
        self.colorPicker.updateMode(mode, animated: animated)
        patternsController.colors = (mode.colors, mode.rotation)
        self.rotateColors.set(rotation: mode.rotation, animated: animated)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        var checkboxViews:[NSView] = []
        
        if !patternCheckbox.isHidden {
            checkboxViews.append(patternCheckbox)
        }
        if !rotateColors.isHidden {
            checkboxViews.append(rotateColors)
        }
        if !colorCheckbox.isHidden {
            checkboxViews.append(colorCheckbox)
        }
        if !blurCheckbox.isHidden {
            checkboxViews.append(blurCheckbox)
        }
        
        let checkboxWidth: CGFloat = checkboxViews.reduce(0, { current, value in
            return current + value.frame.width
        }) + CGFloat(max(0, checkboxViews.count - 1)) * 10

        
        let colorPickerSize = NSMakeSize(frame.width, 168)
        let patternsSize = NSMakeSize(frame.width, 168)
        let controlsSize = NSMakeSize(frame.width, 168)

        let checkboxSize = NSMakeSize(checkboxWidth, 50)
        let documentSize = NSMakeSize(frame.width, documentView.frame.height)
        
      

        
        transition.updateFrame(view: tableView, frame: bounds)
        
        if let progressView = progressView {
            transition.updateFrame(view: progressView, frame: progressView.centerFrame())
        }
        
        self.tableView.enumerateVisibleViews(with: { view in
            if let view = view as? ChatRowView {
                view.updateBackground(animated: transition.isAnimated, item: view.item)
            }
        })
        
       
        
        let backgroundSize: NSSize
        switch self.previewState  {
        case .color:
            backgroundSize = NSMakeSize(frame.width, frame.height - colorPickerSize.height)
        case .pattern:
            backgroundSize = NSMakeSize(frame.width, frame.height - patternsSize.height)
        default:
            backgroundSize = frame.size
        }
        transition.updateFrame(view: backgroundView, frame: backgroundSize.bounds)
        backgroundView.updateLayout(size: backgroundSize, transition: transition)
        
        switch previewState {
        case .color, .pattern:
            transition.updateFrame(view: documentView, frame: .init(origin: .init(x: 0, y: frame.height - colorPicker.frame.height - tableView.listHeight - 10), size: documentSize))
            
            let checkboxRect = CGRect(origin: NSMakePoint(focus(checkboxSize).minX, frame.height - colorPicker.frame.height - checkboxSize.height - 10), size: checkboxSize)
            
            transition.updateFrame(view: checkboxContainer, frame: checkboxRect)
        case .normal:
            let checkboxRect = CGRect(origin: NSMakePoint(focus(checkboxSize).minX, frame.height - checkboxSize.height - 10), size: checkboxSize)
            
            transition.updateFrame(view: checkboxContainer, frame: checkboxRect)
            transition.updateFrame(view: documentView, frame: .init(origin: .init(x: 0, y: frame.height - tableView.listHeight - 10), size: documentSize))

            transition.updateFrame(view: colorPicker, frame: CGRect(origin: NSMakePoint(0, frame.height), size: colorPickerSize))
            
            transition.updateFrame(view: patternsController.view, frame: .init(origin: NSMakePoint(0, frame.height), size: patternsSize))
            
            transition.updateFrame(view: controlsBg, frame: .init(origin: NSMakePoint(0, frame.height), size: controlsSize))

        }
        
        switch previewState {
        case .color:
            let pickerRect = CGRect(origin: .init(x: 0, y: frame.height - colorPickerSize.height), size: colorPickerSize)
            transition.updateFrame(view: colorPicker, frame: pickerRect)
            
            transition.updateFrame(view: patternsController.view, frame: .init(origin: NSMakePoint(0, frame.height), size: patternsSize))

            transition.updateFrame(view: controlsBg, frame: pickerRect)
        case .pattern:
            transition.updateFrame(view: colorPicker, frame: CGRect.init(origin: .init(x: 0, y: frame.height), size: colorPickerSize))
            
            let patternsRect: CGRect = .init(origin: NSMakePoint(0, frame.height - patternsSize.height), size: patternsSize)
            
            transition.updateFrame(view: patternsController.view, frame: patternsRect)
            transition.updateFrame(view: controlsBg, frame: patternsRect)

        default:
            break
        }
        
        patternsController.genericView.updateLayout(size: patternsSize, transition: transition)
        colorPicker.updateLayout(size: colorPickerSize, transition: transition)
        
      
        var x: CGFloat = 0
        for view in checkboxViews {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: x))
            x += view.frame.width + 10
        }

    }
    
    func updateModifyState(_ state: WallpaperPreviewState, animated: Bool) {
        
        self.previewState = state
        switch state {
        case .color:
            patternCheckbox.isSelected = false
            colorCheckbox.isSelected = true
            updateBackground(wallpaper, image: self.image)
        case .normal:
            patternCheckbox.isSelected = false
            colorCheckbox.isSelected = false
            updateBackground(wallpaper, image: self.image)
        case .pattern:
            if let selected = patternsController.pattern {
                self.wallpaper = selected.withUpdatedSettings(self.wallpaper.settings)
            }
            patternCheckbox.isSelected = true
            colorCheckbox.isSelected = false
            
            updateBackground(wallpaper, image: self.image)
        }
        rotateColors.set(rotation: wallpaper.settings.rotation, animated: animated)
        updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
    }
    
    private func updateBackground(_ wallpaper: Wallpaper, image: CGImage?) {
        switch wallpaper {
        case .builtin:
            backgroundView.backgroundMode = .plain
        case let .color(color):
            backgroundView.backgroundMode = .color(color: NSColor(UInt32(color)))
        case let .gradient(_, colors, rotation):
            backgroundView.backgroundMode = .gradient(colors: colors.map { NSColor(argb: $0) }, rotation: rotation)
        case .image:
            if let image = image {
                backgroundView.backgroundMode = .background(image: NSImage(cgImage: image, size: image.size), intensity: nil, colors: nil, rotation: nil)
            } else {
                backgroundView.backgroundMode = .plain
            }
        case let .file(_, _, settings, isPattern):
            if isPattern, settings.colors.count > 2 {
                if let image = image {
                    backgroundView.backgroundMode = .background(image: NSImage(cgImage: image, size: image.size), intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                } else {
                    backgroundView.backgroundMode = .gradient(colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                }
            } else {
                if let image = image {
                    backgroundView.backgroundMode = .background(image: NSImage(cgImage: image, size: image.size), intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                } else {
                    backgroundView.backgroundMode = .gradient(colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                }
            }
        default:
            backgroundView.backgroundMode = .plain
        }
    }
    
    private func loadImage(_ signal:Signal<ImageDataTransformation, NoError>, palette: ColorPalette, boundingSize: NSSize) {
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets())
        
        
        let intense = CGFloat(abs(wallpaper.settings.intensity ?? 0)) / 100.0
        let signal: Signal<CGImage?, NoError> = signal |> map { result in
            var image = result.execute(arguments, result.data)?.generateImage()
            if palette.isDark, let img = image {
                image = generateImage(img.size, contextGenerator: { size, ctx in
                    ctx.clear(size.bounds)
                    ctx.setFillColor(NSColor.black.cgColor)
                    ctx.fill(size.bounds)
                    ctx.clip(to: size.bounds, mask: img)
                    
                    ctx.clear(size.bounds)
                    
                    ctx.setFillColor(NSColor.black.withAlphaComponent(1 - intense).cgColor)
                    ctx.fill(size.bounds)
                })
            }
            return image
        } |> deliverOnMainQueue
        
        loadImageDisposable.set(signal.start(next: { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            strongSelf.image = image
            strongSelf.updateBackground(strongSelf.wallpaper, image: image)
            strongSelf.ready?()
        }))
    }
    
    func updateState(synchronousLoad: Bool) {
        let maximumSize: NSSize = WallpaperDimensions
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        
        switch wallpaper {
        case let .color(color):
            self.image = nil
            blurCheckbox.isHidden = true
            colorCheckbox.isHidden = false
            patternCheckbox.isHidden = false
            self.patternCheckbox.hasPattern = false
            rotateColors.isHidden = true
            self.colorCheckbox.colorsValue = [color].map { NSColor($0) }
        case let .gradient(_, colors, _):
            self.image = nil
            blurCheckbox.isHidden = true
            colorCheckbox.isHidden = false
            patternCheckbox.isHidden = false
            rotateColors.isHidden = false
            self.patternCheckbox.hasPattern = false
            self.colorCheckbox.colorsValue = colors.map { NSColor($0) }
            self.rotateColors.update(colors.count > 2 ? theme.icons.wallpaper_color_play : theme.icons.wallpaper_color_rotate)
        case let .image(representations, settings):
            self.patternCheckbox.hasPattern = false
            blurCheckbox.isHidden = false
            colorCheckbox.isHidden = true
            patternCheckbox.isHidden = true
            rotateColors.isHidden = true
            let dimensions = largestImageRepresentation(representations)!.dimensions.size
            let boundingSize = dimensions.fitted(maximumSize)
            self.imageSize = dimensions
            
            loadImage(chatWallpaper(account: context.account, representations: representations, mode: .screen, isPattern: false, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: settings.blur, synchronousLoad: synchronousLoad, drawPatternOnly: true), palette: theme.colors, boundingSize: boundingSize)

            
            updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(largestImageRepresentation(representations)!.resource, approximateSynchronousValue: synchronousLoad) |> deliverOnMainQueue

        case let .file(_, file, settings, isPattern):
            blurCheckbox.isHidden = isPattern

            colorCheckbox.isHidden = !isPattern
            patternCheckbox.isHidden = !isPattern
            rotateColors.isHidden = !isPattern
            
            if isPattern {
                self.colorCheckbox.colorsValue = settings.colors.map { NSColor($0) }
            }

            self.patternCheckbox.hasPattern = isPattern
            
            var representations:[TelegramMediaImageRepresentation] = []
            representations.append(contentsOf: file.previewRepresentations)
            if let dimensions = file.dimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
            } else {
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(maximumSize), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
            }
            
            if isPattern {
                self.rotateColors.update(settings.colors.count > 2 ? theme.icons.wallpaper_color_play : theme.icons.wallpaper_color_rotate)
            }
            
            let dimensions = largestImageRepresentation(representations)!.dimensions.size
            let boundingSize = dimensions.aspectFilled(frame.size)

            
            loadImage(chatWallpaper(account: context.account, representations: representations, file: file, mode: .thumbnail, isPattern: isPattern, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred:  settings.blur, synchronousLoad: synchronousLoad, drawPatternOnly: true), palette: theme.colors, boundingSize: boundingSize)

                        
            self.imageSize = dimensions

            updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(largestImageRepresentation(representations)!.resource, approximateSynchronousValue: synchronousLoad) |> deliverOnMainQueue
        default:
            break
        }
        
        updateBackground(self.wallpaper, image: self.image)

        
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
        
        let serviceColor = self.serviceColor
        
        self.blurCheckbox.update(by: serviceColor)
        self.colorCheckbox.update(by: serviceColor)
        self.patternCheckbox.update(by: serviceColor)
        self.rotateColors.update(by: serviceColor)
        
        needsLayout = true
    }
    
    var serviceColor: NSColor {
        switch wallpaper {
        case .builtin, .file, .color, .gradient:
            switch backgroundView.backgroundMode {
            case let .background(image, _, colors, _):
                if let colors = colors, let first = colors.first {
                    let blended = colors.reduce(first, { color, with in
                        return color.blended(withFraction: 0.5, of: with)!
                    })
                    return getAverageColor(blended)
                } else {
                    return getAverageColor(image)
                }
            case let .color(color):
                return getAverageColor(color)
            case let .gradient(colors, _):
                if !colors.isEmpty {
                    let blended = colors.reduce(colors.first!, { color, with in
                        return color.blended(withFraction: 0.5, of: with)!
                    })
                    return getAverageColor(blended)
                } else {
                    return getAverageColor(theme.colors.chatBackground)
                }
                
            case let .tiled(image):
                return getAverageColor(image)
            case .plain:
                return getAverageColor(theme.colors.chatBackground)
            }
        default:
            return getAverageColor(theme.colors.chatBackground)
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
            if let color = settings.colors.first {
                if let intensity = settings.intensity {
                    patternIntensity = CGFloat(intensity) / 100.0
                }
                _patternColor = NSColor(rgb: color, alpha: patternIntensity)
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
    }, opaque: false, scale: 1.0)!
    
}

private func cropWallpaperIfNeeded(_ wallpaper: Wallpaper, account: Account, rect: NSRect, magnify: CGFloat = 1.0) -> Signal<Wallpaper, NoError> {
    return Signal { subscriber in
        
        let disposable = MetaDisposable()
        switch wallpaper {
        case let .image(representations, _):
            if let representation = largestImageRepresentation(representations), let resource = representation.resource as? LocalFileReferenceMediaResource {
                if let image = NSImage(contentsOfFile: resource.localFilePath)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    
                    let fittedImage = cropWallpaperImage(image, dimensions: representation.dimensions.size, rect: rect, magnify: magnify, settings: nil)

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
                            result.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(fittedImage.backingSize.aspectFitted(NSMakeSize(90, 90))), resource: thumdResource, progressiveSizes: [], immediateThumbnailData: nil))
                        }
                    }
                    
                    let fittedDimensions = WallpaperDimensions.aspectFitted(representation.dimensions.size)
                    
                     disposable.set(putToTemp(image: NSImage(cgImage: fittedImage, size: fittedDimensions), compress: false).start(next: { path in
                        copyToClipboard(path)
                        let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                        result.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(fittedDimensions), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                        
                        let wallpaper: Wallpaper = .image(result, settings: wallpaper.settings)
                        subscriber.putNext(wallpaper)
                        subscriber.putCompletion()
                    }))
                }
            }
        case let .file(slug, file, settings, isPattern):
            
            let dimensions = file.dimensions?.size ?? WallpaperDimensions
            if isPattern {
                
                let path = account.postbox.mediaBox.cachedRepresentationCompletePath(file.resource.id, representation: CachedPatternWallpaperMaskRepresentation(size: nil))
                
                if let image = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                    let size = image.size.aspectFilled(WallpaperDimensions)
                    
                    let image = generateImage(size, contextGenerator: { size, ctx in
                        let imageRect = NSMakeRect(0, 0, size.width, size.height)
                        
                        let colors:[NSColor]
                        var intensity: CGFloat = 0.5
                        
                        if settings.colors.count == 1 {
                            let combinedColor = NSColor(settings.colors.first!)
                            if let i = settings.intensity {
                                intensity = CGFloat(i) / 100.0
                            }
                            intensity = combinedColor.alpha
                            colors = [combinedColor.withAlphaComponent(1.0)]
                        } else if settings.colors.count > 1 {
                            if let i = settings.intensity {
                                intensity = CGFloat(i) / 100.0
                            }
                            colors = settings.colors.map { NSColor(argb: $0) }.reversed().map { $0.withAlphaComponent(1.0) }
                        } else {
                            colors = [NSColor(rgb: 0xd6e2ee, alpha: 0.5)]
                        }
                        
                        ctx.setBlendMode(.copy)
                        if colors.count == 1, let color = colors.first {
                            ctx.setFillColor(color.cgColor)
                            ctx.fill(imageRect)
                        } else {
                            let gradientColors = colors.map { $0.cgColor } as CFArray
                            let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)

                            var locations: [CGFloat] = []
                            for i in 0 ..< colors.count {
                                locations.append(delta * CGFloat(i))
                            }
                            let colorSpace = CGColorSpaceCreateDeviceRGB()
                            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                            ctx.saveGState()
                            ctx.translateBy(x: imageRect.width / 2.0, y: imageRect.height / 2.0)
                            ctx.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / -180.0)
                            ctx.translateBy(x: -imageRect.width / 2.0, y: -imageRect.height / 2.0)

                            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                            ctx.restoreGState()
                        }
                        
                        
                        ctx.setBlendMode(.normal)
                        ctx.interpolationQuality = .medium
                        ctx.clip(to: imageRect, mask: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
                        
                        if colors.count == 1, let color = colors.first {
                            ctx.setFillColor(patternColor(for: color, intensity: intensity).cgColor)
                            ctx.fill(imageRect)
                        } else {
                            let gradientColors = colors.map { patternColor(for: $0, intensity: intensity).cgColor } as CFArray
                            let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                            
                            var locations: [CGFloat] = []
                            for i in 0 ..< colors.count {
                                locations.append(delta * CGFloat(i))
                            }
                            let colorSpace = CGColorSpaceCreateDeviceRGB()
                            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                            
                            ctx.translateBy(x: imageRect.width / 2.0, y: imageRect.height / 2.0)
                            ctx.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / -180.0)
                            ctx.translateBy(x: -imageRect.width / 2.0, y: -imageRect.height / 2.0)
                            
                            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                        }
                        
                    })!
                    
                    disposable.set(putToTemp(image: NSImage(cgImage: image, size: size), compress: false).start(next: { path in
                        let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                        
                        var attributes = file.attributes
                        loop: for (i, attr) in attributes.enumerated() {
                            switch attr {
                            case .ImageSize:
                                attributes[i] = .ImageSize(size: PixelDimensions(size))
                                break loop
                            default:
                                break
                            }
                        }
                        let wallpaper: Wallpaper = .file(slug: slug, file: file.withUpdatedResource(resource).withUpdatedAttributes(attributes), settings: settings, isPattern: isPattern)
                        subscriber.putNext(wallpaper)
                        subscriber.putCompletion()
                    }))
                }
                
                subscriber.putNext(wallpaper.withUpdatedSettings(settings))
                subscriber.putCompletion()
            } else {
                if let path = account.postbox.mediaBox.completedResourcePath(file.resource), let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
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
                            result.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(fittedImage.backingSize.aspectFitted(NSMakeSize(90, 90))), resource: thumdResource, progressiveSizes: [], immediateThumbnailData: nil))
                        }
                    }
                    
                    let fittedDimensions = WallpaperDimensions.aspectFitted(dimensions)
                    
                    disposable.set(putToTemp(image: NSImage(cgImage: fittedImage, size: fittedDimensions), compress: false).start(next: { path in
                        let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                        
                        var attributes = file.attributes
                        loop: for (i, attr) in attributes.enumerated() {
                            switch attr {
                            case .ImageSize:
                                attributes[i] = .ImageSize(size: PixelDimensions(fittedDimensions))
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
        return genericView.colorPicker.colorEditor.textView.inputView
    }
    
    private let wallpaper: Wallpaper
    private let context: AccountContext

    let source: WallpaperSource
    
    init(_ context: AccountContext, wallpaper: Wallpaper, source: WallpaperSource) {
        self.wallpaper = wallpaper.isSemanticallyEqual(to: theme.wallpaper.wallpaper) ? wallpaper.withUpdatedBlurrred(theme.wallpaper.wallpaper.isBlurred) : wallpaper
        self.context = context
        self.source = source
        super.init(frame: NSMakeRect(0, 0, 380, 300))
        bar = .init(height: 0)
    }
    public override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        let hasShare: Bool
        switch self.wallpaper {
        case .color, .gradient, .file:
            hasShare = true
        default:
            hasShare = false
        }
        
        return (left: ModalHeaderData.init(image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: L10n.wallpaperPreviewHeader), right: !hasShare ? nil : ModalHeaderData(image: theme.icons.modalShare, handler: { [weak self] in
            self?.share()
        }))
    }

    private func share() {
        //close()
        
        switch genericView.wallpaper {
        case let .file(slug, _, settings, isPattern):
            var options: [String] = []
            if settings.blur {
                options.append("mode=blur")
            }
            
            if isPattern {
                
               

                
                if !settings.colors.isEmpty {
                    let colors:[String] = settings.colors.map { value in
                        let color = NSColor(argb: value).hexString.lowercased()
                        return String(color[color.index(after: color.startIndex) ..< color.endIndex])
                    }
                    let bg = "bg_color=\(colors.joined(separator: "~"))"
                    options.append(bg)
                }
                if let intensity = settings.intensity {
                    options.append("intensity=\(intensity)")
                } else {
                    options.append("intensity=\(50)")
                }
                if let r = settings.rotation {
                    options.append("rotation=\(r)")
                }
            }
            
            var optionsString = ""
            if !options.isEmpty {
                optionsString = "?\(options.joined(separator: "&"))"
            }
            
            showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/bg/\(slug)\(optionsString)")), for: context.window)
        case let .color(color):
            var color = NSColor(argb: color).hexString.lowercased()
            color = String(color[color.index(after: color.startIndex) ..< color.endIndex])
            showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/bg/\(color)")), for: context.window)
        case let .gradient(_, colors, r):
            
            let colors:[String] = colors.map { value in
                let color = NSColor(argb: value).hexString.lowercased()
                return String(color[color.index(after: color.startIndex) ..< color.endIndex])
            }
            
            var rotation: String = ""
            if let r = r {
                rotation = "&rotation=\(r)"
            }
            
            let t = colors.joined(separator: "~")
            
            showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/bg/\(t)" + rotation)), for: context.window)

            
        default:
            break
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.ready = { [weak self] in
            self?.readyOnce()
        }
        
        genericView.updateState(synchronousLoad: true)

        
        genericView.blurCheckbox.isSelected = wallpaper.isBlurred
       
        switch wallpaper {
        case let .color(color):
            genericView.patternsController.colors = ([NSColor(argb: color)], nil)
        case let .gradient(_, colors, rotation):
            genericView.patternsController.colors = (colors.map { NSColor(argb: $0) }, rotation)
        case let .file(_, _, settings, isPattern):
            if isPattern {
                var colors:[NSColor] = settings.colors.map { NSColor(argb: $0) }
                if colors.isEmpty {
                    colors.append(NSColor(rgb: 0xd6e2ee, alpha: 0.5))
                }
                genericView.patternsController.colors = (colors, settings.rotation)
            }
        default:
            break
        }
       
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
       
    }
    

    private func applyAndClose() {
        let context = self.context
        closeAllModals()
        
        let signal = cropWallpaperIfNeeded(genericView.wallpaper, account: context.account, rect: genericView.croppedRect) |> mapToSignal { wallpaper in
            return moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wallpaper)
        }
        
        _ = showModalProgress(signal: signal, for: context.window).start(next: { wallpaper in
            _ = (updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.updateWallpaper { $0.withUpdatedWallpaper(wallpaper) }.saveDefaultWallpaper().withSavedAssociatedTheme().withUpdatedBubbled(true)
            }) |> deliverOnMainQueue).start(completed: {
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
            })
        })
        
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.wallpaperPreviewApply, accept: { [weak self] in
            self?.applyAndClose()
        }, drawBorder: true, height: 50, singleButton: true)
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
