//
//  ChannelWallpapersController.swift
//  Telegram
//
//  Created by Mike Renoir on 27.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import ThemeSettings

private let _id_choose = InputDataIdentifier("_id_choose")
private let _id_list = InputDataIdentifier("_id_list")
private let _id_remove = InputDataIdentifier("_id_remove")

private final class Arguments {
    let context: AccountContext
    let premiumConfiguration: PremiumConfiguration
    let select:(ChannelWallpaper)->Void
    let remove:()->Void
    let custom:()->Void
    init(context: AccountContext, select:@escaping(ChannelWallpaper)->Void, remove:@escaping()->Void, custom:@escaping()->Void) {
        self.context = context
        self.select = select
        self.remove = remove
        self.custom = custom
        self.premiumConfiguration = .with(appConfiguration: context.appConfiguration)
    }
}

private struct State : Equatable {
    var boostLevel: Int32
    var wallpapers: [ChannelWallpaper] = []
    var selected: ChannelWallpaper? = nil
}
private let itemSize = NSMakeSize(100, 140)

private struct ChannelWallpaper : Equatable {
    let emoticon: String
    let wallpaper: TelegramWallpaper?
    let theme: TelegramPresentationTheme?
    let stickerItem: StickerPackItem?
}

private final class WallpaperGridItem : GeneralRowItem {
    fileprivate let wallpapers: [ChannelWallpaper]
    fileprivate let context: AccountContext
    fileprivate let callback:(ChannelWallpaper)->Void
    fileprivate let selected: ChannelWallpaper?
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, wallpapers: [ChannelWallpaper], viewType: GeneralViewType, selected: ChannelWallpaper?, callback:@escaping(ChannelWallpaper)->Void) {
        self.wallpapers = wallpapers
        self.context = context
        self.callback = callback
        self.selected = selected
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        return itemSize.height * 3 + viewType.innerInset.top + viewType.innerInset.bottom + viewType.innerInset.bottom * 2 + 10
    }
    
    override func viewClass() -> AnyClass {
        return WallpaperGridView.self
    }
}

private final class WallpaperView : View {
    private var backgroundView: BackgroundView?
    private var emojiView: MediaAnimatedStickerView?
    private var emoticonView: TextViewLabel?
    private var noText: TextView?
    private let overlay = OverlayControl()
    
    var callback:((ChannelWallpaper)->Void)? = nil
    private var wallpaper: ChannelWallpaper?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.layer?.cornerRadius = .cornerRadius
        
        addSubview(overlay)
        
        overlay.set(handler: { [weak self] _ in
            if let wallpaper = self?.wallpaper {
                self?.callback?(wallpaper)
            }
        }, for: .Click)

        overlay.set(handler: { [weak self] _ in
            self?.emojiView?.overridePlayValue = true
        }, for: .Hover)
        
        overlay.set(handler: { [weak self] _ in
            self?.emojiView?.overridePlayValue = false
        }, for: .Normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(_ wallpaper: ChannelWallpaper, selected: Bool, context: AccountContext, animated: Bool, callback: @escaping(ChannelWallpaper)->Void) {
        
        self.callback = callback
        self.wallpaper = wallpaper
        
        if selected {
            self.layer?.borderColor = theme.colors.accent.cgColor
            self.layer?.borderWidth = 2
        } else if wallpaper.theme == nil {
            self.layer?.borderColor = theme.colors.border.cgColor
            self.layer?.borderWidth = 2
        } else {
            self.layer?.borderColor = .clear
            self.layer?.borderWidth = 0
        }
        
        if let theme = wallpaper.theme {
            let current: BackgroundView
            if let view = self.backgroundView {
                current = view
            } else {
                current = BackgroundView(frame: self.bounds)
                self.backgroundView = current
                addSubview(current)
            }
            current.backgroundMode = theme.backgroundMode
        } else if let backgroundView = self.backgroundView {
            performSubviewRemoval(backgroundView, animated: animated)
            self.backgroundView = nil
        }
        
        if let sticker = wallpaper.stickerItem {
            let current: MediaAnimatedStickerView
            if let emojiView = self.emojiView {
                current = emojiView
            } else {
                current = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 30, 30))
                self.addSubview(current, positioned: .below, relativeTo: overlay)
                self.emojiView = current
            }
            let params = ChatAnimatedStickerMediaLayoutParameters(playPolicy: nil, hidePlayer: true, media: sticker.file)
            current.update(with: sticker.file, size: NSMakeSize(30, 30), context: context, table: nil, parameters: params, animated: animated)
            current.userInteractionEnabled = false
            current.overridePlayValue = false
        } else if let emojiView = self.emojiView {
            performSubviewRemoval(emojiView, animated: animated)
            self.emojiView = nil
        }
        
        if wallpaper.stickerItem == nil, !wallpaper.emoticon.isEmpty {
            let current: TextViewLabel
            if let emojiView = self.emoticonView {
                current = emojiView
            } else {
                current = TextViewLabel(frame: NSMakeRect(0, 0, 30, 30))
                self.addSubview(current, positioned: .below, relativeTo: overlay)
                self.emoticonView = current
            }
            current.attributedString = .initialize(string: wallpaper.emoticon, font: .normal(18))
        } else if let emoticonView = self.emoticonView {
            performSubviewRemoval(emoticonView, animated: animated)
            self.emoticonView = nil
        }
        if wallpaper.stickerItem == nil, !wallpaper.emoticon.isEmpty, wallpaper.theme == nil {
            let current: TextView
            if let noText = self.noText {
                current = noText
            } else {
                current = TextView(frame: NSMakeRect(0, 0, 30, 30))
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.addSubview(current, positioned: .below, relativeTo: overlay)
                self.noText = current
            }
            let attributedString: NSAttributedString = .initialize(string: strings().channelWallpaperNoWallpaper, color: theme.colors.grayText, font: .normal(13))

            let layout: TextViewLayout = .init(attributedString, alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            current.update(layout)
        } else if let noText = self.noText {
            performSubviewRemoval(noText, animated: animated)
            self.noText = nil
        }
        needsLayout = true
    }
    override func layout() {
        super.layout()
        backgroundView?.frame = bounds
        overlay.frame = bounds
        if let emojiView = self.emojiView {
            emojiView.centerX(y: bounds.maxY - emojiView.frame.height - 10)
        }
        if let emoticonView = emoticonView {
            emoticonView.centerX(y: bounds.maxY - emoticonView.frame.height - 10)
        }
        if let noText = noText {
            noText.centerX(y: 40)
        }
    }
}

private final class WallpaperGridView : GeneralContainableRowView {
    private let wallpapers = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(wallpapers)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WallpaperGridItem else {
            return
        }
        
        while wallpapers.subviews.count > item.wallpapers.count {
            wallpapers.subviews.first?.removeFromSuperview()
        }
        
        while wallpapers.subviews.count < item.wallpapers.count {
            wallpapers.subviews.insert(WallpaperView(frame: itemSize.bounds), at: 0)
        }
        
        for (i, wallpaper) in item.wallpapers.enumerated() {
            let view = wallpapers.subviews[i] as! WallpaperView
            view.set(wallpaper, selected: item.selected == wallpaper || (i == 0 && item.selected == nil), context: item.context, animated: animated, callback: { wallpaper in
                item.callback(wallpaper)
            })
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        wallpapers.frame = containerView.bounds.insetBy(dx: 5, dy: 5)
        
        var point: NSPoint = NSMakePoint(5, 5)
        for (i, view) in self.wallpapers.subviews.enumerated() {
            view.setFrameOrigin(point)
            point.x += itemSize.width + 5
            if (i + 1) % 3 == 0 {
                point.y += itemSize.height + 5
                point.x = 5
            }
        }
    }
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var afterNameImage_WallpaperIcon: CGImage? = nil
    if state.boostLevel < arguments.premiumConfiguration.minChannelCustomWallpaperLevel {
        afterNameImage_WallpaperIcon = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minChannelCustomWallpaperLevel)))
    }
    
    let hasCustom: Bool
    if let emoticon = state.selected?.emoticon {
        hasCustom = emoticon.isEmpty
    } else {
        hasCustom = false
    }
    
    
  
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_choose, data: .init(name: strings().channelWallpaperChooseFromFile, color: theme.colors.accent, icon: NSImage(named: "Icon_AttachPhoto")?.precomposed(theme.colors.accent, flipVertical: true), type: .none, viewType: hasCustom ? .firstItem : .singleItem, enabled: true, action: arguments.custom, afterNameImage: afterNameImage_WallpaperIcon)))
    
    if hasCustom {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_remove, data: .init(name: strings().channelWallpaperRemoveWallpaper, color: theme.colors.redUI, icon: NSImage(named: "Icon_Editor_Delete")?.precomposed(theme.colors.redUI, flipVertical: true), type: .none, viewType: .lastItem, enabled: true, action: arguments.remove)))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_list, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return WallpaperGridItem(initialSize, stableId: stableId, context: arguments.context, wallpapers: state.wallpapers, viewType: .modern(position: .single, insets: .init(top: 5, left: 5, bottom: 5, right: 5)), selected: state.selected, callback: arguments.select)
    }))
    

    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChannelWallpapersController(context: AccountContext, peerId: PeerId, isGroup: Bool, boostLevel: Int32, selected: (Bool, TelegramWallpaper?), callback: @escaping(TelegramWallpaper?)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(boostLevel: boostLevel)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    let animatedEmojiStickers = context.diceCache.animatedEmojies
    
    let empty: ChannelWallpaper = .init(emoticon: "❌", wallpaper: nil, theme: nil, stickerItem: nil)
    
    let wallpaper: Signal<TelegramWallpaper?, NoError>
    if selected.0 {
        wallpaper = .single(selected.1)
    } else {
        wallpaper = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
        |> map { $0 as? CachedChannelData }
        |> map { $0?.wallpaper }
        |> take(1)
    }
    
    actionsDisposable.add(combineLatest(context.chatThemes, animatedEmojiStickers, wallpaper).start(next: { themes, emoticons, installed in
        updateState { current in
            var current = current
            var wallpapers: [ChannelWallpaper] = []
            if let installed = installed, case .file = installed {
                let theme = generateTheme(palette: theme.colors, cloudTheme: nil, bubbled: theme.bubbled, fontSize: theme.fontSize, wallpaper: .init(wallpaper: .init(installed), associated: nil), backgroundSize: itemSize)
                wallpapers.append(.init(emoticon: "", wallpaper: installed, theme: theme, stickerItem: nil))
            } else {
                wallpapers.append(empty)
            }
            
            for theme in themes {
                wallpapers.append(.init(emoticon: theme.0, wallpaper: .emoticon(theme.0), theme: theme.1, stickerItem: emoticons[theme.0.withoutColorizer]))
                if let installed = installed, current.selected == nil {
                    switch installed {
                    case let .emoticon(emoticon):
                        if theme.0.withoutColorizer == emoticon.withoutColorizer {
                            current.selected = wallpapers[wallpapers.count - 1]
                        }
                    default:
                        break
                    }
                }
            }
            if current.selected == nil {
                current.selected = wallpapers[0]
            }
            current.wallpapers = wallpapers
            return current
        }
    }))

    let arguments = Arguments(context: context, select: { wallpaper in
        updateState { current in
            var current = current
            current.selected = wallpaper
            return current
        }
    }, remove: {
        updateState { current in
            var current = current
            let updated = current.selected == current.wallpapers[0]
            current.wallpapers[0] = empty
            if updated {
                current.selected = current.wallpapers[0]
            }
            return current
        }
    }, custom: {
        filePanel(with: photoExts, allowMultiple: false, for: context.window, completion: { paths in
            if let path = paths?.first {
                let size = fs(path)
                if let size = size, size < 10 * 1024 * 1024, let image = NSImage(contentsOf: URL(fileURLWithPath: path))?.cgImage(forProposedRect: nil, context: nil, hints: nil), image.size.width > 500 && image.size.height > 500 {
                    
                    let options = NSMutableDictionary()
                    options.setValue(90 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
                    var representations: [TelegramMediaImageRepresentation] = []
                    let colorQuality: Float = 0.1
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    let mutableData: CFMutableData = NSMutableData() as CFMutableData
                    
                    if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            let thumdResource = LocalFileMediaResource(fileId: arc4random64())
                            context.account.postbox.mediaBox.storeResourceData(thumdResource.id, data: mutableData as Data)
                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size.aspectFitted(NSMakeSize(90, 90))), resource: thumdResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                        }
                    }
                    
                    let data = try? Data(contentsOf: URL(fileURLWithPath: path))
                    guard let data = data else {
                        return
                    }
                    let resource = LocalFileMediaResource(fileId: arc4random64(), size: Int64(data.count))
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    
                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                    
                    showModal(with: WallpaperPreviewController(context, wallpaper: .image(representations, settings: WallpaperSettings()), source: .custom(stateValue.with { $0.selected?.wallpaper }), onComplete: { wallpaper in
                        
                        
                        let signal: Signal<Wallpaper?, NoError>
                        if let wallpaper = wallpaper {
                            signal = moveWallpaperToCache(postbox: context.account.postbox, wallpaper: .init(wallpaper)) |> map(Optional.init)
                        } else {
                            signal = .single(nil)
                        }
                        
                        _ = signal.startStandalone(next: { _ in
                            updateState { current in
                                var current = current
                                if let wallpaper = wallpaper {
                                    let theme = generateTheme(palette: theme.colors, cloudTheme: nil, bubbled: theme.bubbled, fontSize: theme.fontSize, wallpaper: .init(wallpaper: .init(wallpaper), associated: nil), backgroundSize: itemSize)
                                    current.wallpapers[0] = .init(emoticon: "", wallpaper: wallpaper, theme: theme, stickerItem: nil)
                                } else {
                                    current.wallpapers[0] = empty
                                }
                                current.selected = current.wallpapers[0]
                                return current
                            }
                        })
                        
                        
                        
                    }), for: context.window)
                    
                } else {
                    alert(for: context.window, header: appName, info: strings().appearanceCustomBackgroundFileError)
                }
            }
        })
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: isGroup ? strings().channelWallpaperTitleGroup : strings().channelWallpaperTitle)
    
    controller.validateData = { _ in
        callback(stateValue.with { $0.selected?.wallpaper })
        close?()
        return.none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalApply, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    

    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(320 + 40 + 10, 320))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*

 */



