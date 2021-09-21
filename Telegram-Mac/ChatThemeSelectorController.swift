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


final class ChatThemeSelectorView : View {
    
    private let tableView: HorizontalTableView = HorizontalTableView(frame: .zero)
    
    private let controls:View = View()
    
    fileprivate let accept = TitleButton()
    fileprivate let cancel = TitleButton()

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(controls)
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
    }
    
    fileprivate func updateThemes(_ themes: [(String, CGImage, TelegramPresentationTheme)], emojies: [String: StickerPackItem], context: AccountContext, chatTheme: (String?, TelegramPresentationTheme)?, previewCurrent: @escaping((String, TelegramPresentationTheme)?) -> Void) {
        tableView.beginTableUpdates()
        tableView.removeAll()
        
        _ = tableView.addItem(item: GeneralRowItem(.zero, height: 10))
        _ = tableView.addItem(item: ChatThemeRowItem(frame.size, context: context, stableId: arc4random(), emojies: emojies, theme: nil, selected: chatTheme?.0 == nil, select: { _ in
            previewCurrent(nil)
        }))
        
        for theme in themes {
            _ = tableView.addItem(item: ChatThemeRowItem(frame.size, context: context, stableId: theme.0, emojies: emojies, theme: theme, selected: chatTheme?.0 == theme.0, select: { theme in
                previewCurrent(theme)
            }))
        }
        _ = tableView.addItem(item: GeneralRowItem(.zero, height: 10))

        tableView.endTableUpdates()
        
        accept.set(color: theme.colors.underSelectedColor, for: .Normal)
        accept.set(background: theme.colors.accent, for: .Normal)
        accept.set(font: .medium(.text), for: .Normal)
        accept.set(text: L10n.chatChatThemeApplyTheme, for: .Normal)
        
        cancel.set(color: theme.colors.text, for: .Normal)
        cancel.set(font: .medium(.text), for: .Normal)
        cancel.set(background: theme.colors.background, for: .Normal)
        cancel.set(text: L10n.chatChatThemeCancel, for: .Normal)
        cancel.layer?.borderColor = theme.colors.border.cgColor
        
        accept.sizeToFit(NSMakeSize(20, 15), .zero, thatFit: false)
        cancel.sizeToFit(.zero, NSMakeSize(accept.frame.width, accept.frame.size.height), thatFit: true)

        needsLayout = true
    }
    
    override func layout() {
        super.layout()
                
        tableView.frame = NSMakeRect(0, 10, frame.width, 90)
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
    
    init(_ context: AccountContext, chatTheme: Signal<(String?, TelegramPresentationTheme), NoError>, chatInteraction: ChatInteraction) {
        self.chatTheme = chatTheme
        self.chatInteraction = chatInteraction
        super.init(context)
        _frameRect = NSMakeRect(0, 0, 0, 160)
        self.bar = .init(height: 0)
    }
    
    deinit {
       
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = chatInteraction.peerId
        
        let readySignal = self.ready.get() |> take(1) |> deliverOnMainQueue
        
        let themesAndThumbs: Signal<[(String, CGImage, TelegramPresentationTheme)], NoError> = context.chatThemes |> mapToSignal { themes in
            var signals:[Signal<(String, CGImage, TelegramPresentationTheme), NoError>] = []
            
            for theme in themes {
                signals.append(generateChatThemeThumb(palette: theme.1.colors, bubbled: theme.1.bubbled, backgroundMode: theme.1.controllerBackgroundMode) |> map {
                    (theme.0, $0, theme.1)
                })
            }
            return combineLatest(signals)
        } |> deliverOnMainQueue
        
        
        currentSelectedValue.set(chatTheme |> take(1) |> map { $0 })
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
            |> map { result -> [String: StickerPackItem] in
                switch result {
                case let .result(_, items, _):
                    var animatedEmojiStickers: [String: StickerPackItem] = [:]
                    for case let item as StickerPackItem in items {
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
            
            self?.genericView.updateThemes(themes, emojies: emojies, context: context, chatTheme: selected, previewCurrent: { preview in
                self?.previewCurrent(preview?.1 ?? theme)
                self?.currentSelected = preview
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
            let updateSignal = context.engine.themes.setChatTheme(peerId: peerId, emoticon: self?.currentSelected?.0)
            |> deliverOnMainQueue
            _ = updateSignal.start(next: { [weak self] in
                self?.close(true)
            })
            self?.close(false)
        }, for: .SingleClick)
    }
    
}
