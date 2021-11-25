//
//  ChatThemeSelectorController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import ThemeSettings

final class ChatThemeSelectorView : View {
    
    private let tableView: HorizontalTableView = HorizontalTableView(frame: .zero)
    
    private let controls:View = View()
    
    fileprivate let accept = TitleButton()
    fileprivate let cancel = TitleButton()
    
    private let headerView = TextView()

    private let headerContainer = View()
    
    private let bubblesTitle = TextView()
    private let bubblesSwitch =  SwitchView(frame: NSMakeRect(0, 0, 32, 20))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(controls)
        addSubview(headerContainer)
        headerContainer.addSubview(headerView)
        headerContainer.addSubview(bubblesTitle)
        headerContainer.addSubview(bubblesSwitch)
        self.border = [.Top]
                
        controls.addSubview(cancel)
        controls.addSubview(accept)
        
        cancel.autohighlight = false
        cancel.scaleOnClick = true
        
        accept.autohighlight = false
        accept.scaleOnClick = true
        
        accept.layer?.cornerRadius = 4
        cancel.layer?.cornerRadius = 4

        
        cancel.layer?.borderWidth = 1
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        bubblesTitle.userInteractionEnabled = false
        bubblesTitle.isSelectable = false
        
        tableView.needUpdateVisibleAfterScroll = true
    }
    
    var colorful: Bool {
        return bubblesSwitch.isOn
    }
    
    fileprivate func updateThemes(_ themes: [(String, CGImage, TelegramPresentationTheme)], bubbled: Bool, emojies: [String: StickerPackItem], context: AccountContext, chatTheme: (String?, TelegramPresentationTheme)?, previewCurrent: @escaping((String?, TelegramPresentationTheme)?) -> Void, updateBubbled:@escaping(Bool)->Void) {
        
        bubblesSwitch.setIsOn(bubbled)

        bubblesSwitch.stateChanged = {
            let updatedValue = !bubbled
            updateBubbled(updatedValue)
        }

        tableView.beginTableUpdates()
        tableView.removeAll()
        
        _ = tableView.addItem(item: GeneralRowItem(.zero, height: 10))
        _ = tableView.addItem(item: SmartThemePreviewRowItem(frame.size, context: context, stableId: arc4random(), bubbled: bubbled, emojies: emojies, theme: nil, selected: chatTheme?.0 == nil, select: { _ in
            previewCurrent(nil)
        }))
                
        for theme in themes {
            _ = tableView.addItem(item: SmartThemePreviewRowItem(frame.size, context: context, stableId: theme.0, bubbled: bubbled, emojies: emojies, theme: theme, selected: chatTheme?.0 == theme.0, select: { theme in
                previewCurrent(theme)
            }))
        }
        _ = tableView.addItem(item: GeneralRowItem(.zero, height: 10))

        tableView.endTableUpdates()
        
        accept.set(color: theme.colors.underSelectedColor, for: .Normal)
        accept.set(background: theme.colors.accent, for: .Normal)
        accept.set(font: .medium(.text), for: .Normal)
        accept.set(text: strings().chatChatThemeApplyTheme, for: .Normal)
        
        cancel.set(color: theme.colors.text, for: .Normal)
        cancel.set(font: .medium(.text), for: .Normal)
        cancel.set(background: theme.colors.background, for: .Normal)
        cancel.set(text: strings().chatChatThemeCancel, for: .Normal)
        cancel.layer?.borderColor = theme.colors.border.cgColor
        
        accept.sizeToFit(NSMakeSize(20, 15), .zero, thatFit: false)
        cancel.sizeToFit(.zero, NSMakeSize(accept.frame.width, accept.frame.size.height), thatFit: true)

        
        let header = TextViewLayout(.initialize(string: "Chat Theme", color: theme.colors.text, font: .medium(.header)))
        header.measure(width: .greatestFiniteMagnitude)
        headerView.update(header)
        
        let switchLayout = TextViewLayout(.initialize(string: "Colorful", color: theme.colors.text, font: .normal(.text)))
        switchLayout.measure(width: .greatestFiniteMagnitude)
        bubblesTitle.update(switchLayout)
        
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        headerContainer.frame = NSMakeRect(0, 0, frame.width, 50)
        headerView.centerY(x: 20)
        
        bubblesSwitch.centerY(x: frame.width - bubblesSwitch.frame.width - 20)
        bubblesTitle.centerY(x: bubblesSwitch.frame.minX - bubblesTitle.frame.width - 10)
        
        tableView.frame = NSMakeRect(0, 50, frame.width, 90)
        controls.setFrameSize(NSMakeSize(accept.frame.width + 10 + cancel.frame.width, 60))

        cancel.centerY(x: 0)
        accept.centerY(x: cancel.frame.maxX + 10)

        
        controls.centerX(y: tableView.frame.maxY - 5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ChatThemeSelectorController : TelegramGenericViewController<ChatThemeSelectorView> {
    private let chatInteraction: ChatInteraction
    private let readyDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    
    private let chatTheme: Signal<(String?, TelegramPresentationTheme), NoError>
    private var currentSelected: (String?, TelegramPresentationTheme)? {
        didSet {
            currentSelectedValue.set(.single(currentSelected))
        }
    }
    
    private let currentSelectedValue: Promise<(String?, TelegramPresentationTheme)?> = Promise(nil)
    
    var onReady:(ChatThemeSelectorController)->Void = { _ in }
    var close: (Bool)->Void = { _ in }

    var previewCurrent: (TelegramPresentationTheme?) -> Void = { _ in }
    
    private let bubbled = ValuePromise(theme.bubbled, ignoreRepeated: true)
    
    init(_ context: AccountContext, chatTheme: Signal<(String?, TelegramPresentationTheme), NoError>, chatInteraction: ChatInteraction) {
        self.chatTheme = chatTheme
        self.chatInteraction = chatInteraction
        super.init(context)
        _frameRect = NSMakeRect(0, 0, 0, 200)
        self.bar = .init(height: 0)
    }
    
    deinit {
       
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = chatInteraction.peerId
        
        
        let readySignal = self.ready.get() |> take(1) |> deliverOnMainQueue
        
        let themesAndThumbs: Signal<([(String, CGImage, TelegramPresentationTheme)], Bool), NoError> = combineLatest(context.chatThemes, bubbled.get()) |> mapToSignal { themes, bubbled in
            var signals:[Signal<(String, CGImage, TelegramPresentationTheme), NoError>] = []
            for theme in themes {
                signals.append(generateChatThemeThumb(palette: theme.1.colors, bubbled: bubbled, backgroundMode: bubbled ? theme.1.backgroundMode : .color(color: theme.1.colors.chatBackground)) |> map {
                    (theme.0, $0, theme.1)
                })
            }
            return combineLatest(signals) |> map { ($0, bubbled) }
        } |> deliverOnMainQueue
        
        
        currentSelectedValue.set(chatTheme |> take(1) |> map { $0 })
        
        _ = (currentSelectedValue.get() |> take(1)).start(next: { [weak self] value in
            self?.currentSelected = value
        })
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
            |> map { result -> [String: StickerPackItem] in
                switch result {
                case let .result(_, items, _):
                    var animatedEmojiStickers: [String: StickerPackItem] = [:]
                    for case let item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji] = item
                        }
                    }
                    return animatedEmojiStickers
                default:
                    return [:]
                }
        } |> deliverOnMainQueue
                
        disposable.set(combineLatest(queue: .mainQueue(), themesAndThumbs, chatTheme, currentSelectedValue.get(), animatedEmojiStickers).start(next: { [weak self] themes, chatTheme, currentSelected, emojies in
            
            let selected: (String?, TelegramPresentationTheme)? = currentSelected
            let bubbled = themes.1
                        
            self?.genericView.updateThemes(themes.0, bubbled: bubbled, emojies: emojies, context: context, chatTheme: selected, previewCurrent: { preview in
                self?.previewCurrent((preview?.1 ?? theme).withUpdatedChatMode(bubbled))
                self?.currentSelected = preview
            }, updateBubbled: { value in
                self?.bubbled.set(value)
                self?.previewCurrent((currentSelected?.1 ?? theme).withUpdatedChatMode(value))
            })
            
            self?.readyOnce()
        }))
        
        readyDisposable.set(readySignal.start(next: { [weak self] _ in
            guard let controller = self else {
                return
            }
            self?.onReady(controller)
        }))
        
        genericView.cancel.set(handler: { [weak self] _ in
            self?.close(true)
        }, for: .Click)
        
        genericView.accept.set(handler: { [weak self] _ in
            
            let isBubbled = self?.genericView.colorful ?? theme.bubbled
            
            let updateSignal = context.engine.themes.setChatTheme(peerId: peerId, emoticon: self?.currentSelected?.0)
            |> deliverOnMainQueue
            _ = updateSignal.start(next: { [weak self] in
                self?.close(true)
            })
            self?.close(false)
            
            if theme.bubbled != isBubbled {
                delay(0.5, closure: {
                    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings -> ThemePaletteSettings in
                        return settings.withUpdatedBubbled(isBubbled)
                    }).start()
                })
            }
            
        }, for: .SingleClick)

    }
    
}
