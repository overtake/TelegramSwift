//
//  WidgetStickersController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InAppSettings
import Postbox

private final class WidgetStickerView : Control {
    private let animatedView = MediaAnimatedStickerView(frame: .zero)
    private let nameView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(animatedView)
        addSubview(nameView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        animatedView.userInteractionEnabled = false
        scaleOnClick = true
    }
    
    var data: (FeaturedStickerPackItem, AccountContext)? {
        didSet {
            if let data = data {
                let item = data.0
                let context = data.1
                var file: TelegramMediaFile?
                if let thumbnail = item.info.thumbnail {
                    file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
                } else if let item = item.topItems.first {
                    file = item.file
                }
                if let file = file {
                    self.animatedView.update(with: file, size: NSMakeSize(72, 72), context: context, parent: nil, table: nil, parameters: nil, animated: true, positionFlags: nil, approximateSynchronousValue: false)
                }
                nameView.update(TextViewLayout(.initialize(string: item.info.title, color: theme.colors.text, font: .medium(.short)), maximumNumberOfLines: 2, alignment: .center))
            }
            needsLayout = true
        }
    }
    
    override func layout() {
        super.layout()
        self.animatedView.centerX(y: 6)
        nameView.resize(frame.width - 10)
        nameView.centerX(y: self.animatedView.frame.maxY + 6)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let data = self.data
        self.data = data
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WidgetStickersContainer : View {
    private let title = TextView()
    
    private let stickers: View = View()
    private var timer: SwiftSignalKit.Timer? = nil
    
    var previewPack:((FeaturedStickerPackItem, @escaping()->Void)->Void)?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(stickers)
        title.userInteractionEnabled = false
        title.isSelectable = false
        
    }
    private var state: WidgetStickersController.State?
    private var elements:[FeaturedStickerPackItem]?
    private var context: AccountContext?
    func update(_ state: WidgetStickersController.State, context: AccountContext, animated: Bool) {
        self.state = state
        self.context = context
        
        
        runTimer()
        
        if !animated || stickers.subviews.isEmpty {
            self.reload(state, context: context, animated: animated)
        }
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    private func runTimer() {
        timer = SwiftSignalKit.Timer(timeout: 60, repeat: true, completion: { [weak self] in
            guard let context = self?.context, let state = self?.state else {
                return
            }
            self?.reload(state, context: context, animated: true)
        }, queue: .mainQueue())
        timer?.start()
    }
    
    func reload(ignore: Int? = nil) {
        runTimer()
        guard let context = self.context, let state = self.state else {
            return
        }
        self.reload(state, ignore: ignore, context: context, animated: true)
    }
    
    private func generateRandom(_ state: WidgetStickersController.State, ignore: Int? = nil) -> [FeaturedStickerPackItem] {
        if let ignore = ignore, var elements = self.elements {
            let element = elements.remove(at: ignore)
            while let randomElement = state.stickers.randomElement() {
                if !elements.contains(where: { $0.info.id.id == element.info.id.id }) {
                    elements.insert(randomElement, at: ignore)
                    break
                }
            }
            return elements
        } else {
            return state.stickers.randomElements(3)
        }
    }
    
    private func reload(_ state: WidgetStickersController.State, ignore: Int? = nil, context: AccountContext, animated: Bool) {
        let random = generateRandom(state, ignore: ignore)
        self.elements = random
        var ignore:Set<Int> = Set()
        for (i, sticker) in self.stickers.subviews.enumerated() {
            if let sticker = sticker as? WidgetStickerView {
                if sticker.data?.0.info.id != random[i].info.id {
                    performSubviewRemoval(sticker, animated: animated)
                    sticker.data = nil
                } else {
                    ignore.insert(i)
                }
            }
        }
        for (i, item) in random.enumerated() {
            if !ignore.contains(i) {
                let view = WidgetStickerView(frame: .zero)
                stickers.subviews.insert(view, at: i)
                view.data = (item, context)
                if animated {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                view.set(handler: { [weak self] _ in
                    self?.previewPack?(item, { [weak self] in
                        self?.reload(ignore: i)
                    })
                }, for: .Click)
            }
        }
        needsLayout = true
    }
    
    deinit {
    }
    
    override func layout() {
        super.layout()
        title.resize(frame.width - 20)
        title.centerX()
        
        stickers.frame = NSMakeRect(0, title.frame.maxY + 10, frame.width, frame.height - (title.frame.maxY + 10))
        
        let subviews = stickers.subviews
            .compactMap { $0 as? WidgetStickerView }
            .filter { $0.data != nil }
        
        for (i, sticker) in subviews.enumerated() {
            let width = stickers.frame.width / CGFloat(subviews.count)
            sticker.frame = NSMakeRect(width * CGFloat(i), 0, width, stickers.frame.height)
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)

        let theme = theme as! TelegramPresentationTheme
        
        let titleLayout = TextViewLayout(.initialize(string: strings().emptyChatStickersTrending, color: theme.colors.text, font: .medium(.text)))
        titleLayout.measure(width: frame.width - 20)
        title.update(titleLayout)
            
        needsLayout = true
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WidgetStickersController : TelegramGenericViewController<WidgetView<WidgetStickersContainer>> {

    struct State : Equatable {
        static func == (lhs: State, rhs: State) -> Bool {
            return false
        }
        var settings: StickerSettings
        var stickers:[FeaturedStickerPackItem] = []
    }
    
    private let disposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    override init(_ context: AccountContext) {
        super.init(context)
        self.bar = .init(height: 0)
    }
    
    deinit {
        actionsDisposable.dispose()
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context

        self.genericView.dataView = WidgetStickersContainer(frame: .zero)
        
        self.genericView.dataView?.previewPack = { [weak self] item, f in
            showModal(with: StickerPackPreviewModalController(context, peerId: nil, reference: .id(id: item.info.id.id, accessHash: item.info.accessHash), onAdd: f), for: context.window)
        }
        
        let initialState = State(settings: StickerSettings.defaultSettings)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        var first = true
        
        
        let featured = Promise<[FeaturedStickerPackItem]>()
        featured.set(context.account.viewTracker.featuredStickerPacks())

        let stickerSettingsKey = ApplicationSpecificPreferencesKeys.stickerSettings
        let preferencesKey: PostboxViewKey = .preferences(keys: Set([stickerSettingsKey]))
        let preferencesView = context.account.postbox.combinedView(keys: [preferencesKey])

        let stickerSettings: Signal<StickerSettings, NoError> = preferencesView |> map { preferencesView in
            var stickerSettings = StickerSettings.defaultSettings
            if let view = preferencesView.views[preferencesKey] as? PreferencesView {
                if let value = view.values[stickerSettingsKey] as? StickerSettings {
                    stickerSettings = value
                }
            }
            return stickerSettings
        }
        
        actionsDisposable.add(combineLatest(queue: .mainQueue(), stickerSettings, featured.get()).start(next: { settings, featured in
            updateState { current in
                var current = current
                current.stickers = featured
                current.settings = settings
                return current
            }
        }))
        
        disposable.set((statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            
            var buttons: [WidgetData.Button] = []
            
            let noneSelected = state.settings.emojiStickerSuggestionMode == .none
            let mySetsSelected = state.settings.emojiStickerSuggestionMode == .installed
            let allSetsSelected = state.settings.emojiStickerSuggestionMode == .all

            buttons.append(.init(text: { strings().emptyChatStickersNone }, selected: {
                return noneSelected
            }, image: {
                return noneSelected ? theme.icons.empty_chat_stickers_none_active: theme.icons.empty_chat_stickers_none
            }, click: {
                _ = updateStickerSettingsInteractively(postbox: context.account.postbox, {
                   $0.withUpdatedEmojiStickerSuggestionMode(.none)
                }).start()
            }))
            
            buttons.append(.init(text: { strings().emptyChatStickersMySets }, selected: {
                return mySetsSelected
            }, image: {
                return mySetsSelected ?  theme.icons.empty_chat_stickers_mysets_active : theme.icons.empty_chat_stickers_mysets
            }, click: {
                _ = updateStickerSettingsInteractively(postbox: context.account.postbox, {
                   $0.withUpdatedEmojiStickerSuggestionMode(.installed)
                }).start()
            }))
            
            buttons.append(.init(text: { strings().emptyChatStickersAllSets }, selected: {
                return allSetsSelected
            }, image: {
                return allSetsSelected ? theme.icons.empty_chat_stickers_allsets_active : theme.icons.empty_chat_stickers_allsets
            }, click: {
                _ = updateStickerSettingsInteractively(postbox: context.account.postbox, {
                   $0.withUpdatedEmojiStickerSuggestionMode(.all)
                }).start()
            }))
            
            let data: WidgetData = .init(title: { strings().emptyChatStickers }, desc: { strings().emptyChatStickersDesc }, descClick: {
                context.sharedContext.bindings.rootNavigation().push(FeaturedStickerPacksController(context))
            }, buttons: buttons)
            
            self?.genericView.update(data)
            self?.genericView.dataView?.update(state, context: context, animated: !first)
            first = false
        }))

    }
}
