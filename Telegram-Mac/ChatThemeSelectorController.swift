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
    
    fileprivate var accept: TextButton?
    
    fileprivate let cancel = ImageButton()
    
    private let headerView = TextView()
    private let headerInfoView = TextView()

    private let headerContainer = View()
    
    fileprivate let selectBackground = TextButton()
    fileprivate var resetBackground: TextButton?
    
    fileprivate var resetBg:(()->Void)? = nil
    fileprivate var acceptTheme:(()->Void)? = nil

    private let bubblesTitle = TextView()
    private let bubblesSwitch =  SwitchView(frame: NSMakeRect(0, 0, 32, 20))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(controls)
        addSubview(headerContainer)
        headerContainer.addSubview(headerView)
        headerContainer.addSubview(headerInfoView)
        headerContainer.addSubview(bubblesTitle)
        headerContainer.addSubview(bubblesSwitch)
        
        self.border = [.Top]
                
        
        headerContainer.addSubview(cancel)

      
        addSubview(selectBackground)
        
        selectBackground.autohighlight = false
        selectBackground.scaleOnClick = true
        
        cancel.autohighlight = false
        cancel.scaleOnClick = true
        
        
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        headerInfoView.userInteractionEnabled = false
        headerInfoView.isSelectable = false
        
        bubblesTitle.userInteractionEnabled = false
        bubblesTitle.isSelectable = false
        
        tableView.needUpdateVisibleAfterScroll = true
        
        updateLayout(size: frameRect.size, transition: .immediate)
    }
    
    var colorful: Bool {
        return bubblesSwitch.isOn
    }
    
    fileprivate var wallpaper: ThemeWallpaper?
    private var first: Bool = true
    
    fileprivate func updateThemes(_ peer: Peer?, _ themes: [(String, CGImage, TelegramPresentationTheme)], installedTheme: String?, wallpaper: ThemeWallpaper, bubbled: Bool, emojies: [String: StickerPackItem], context: AccountContext, chatTheme: (String?, TelegramPresentationTheme)?, previewCurrent: @escaping((String?, TelegramPresentationTheme)?) -> Void, updateBubbled:@escaping(Bool)->Void) {
        
        let animated = !first
        first = false
        bubblesSwitch.autoswitch = false
        bubblesSwitch.setIsOn(bubbled)
        
        self.wallpaper = wallpaper

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
        if let selected = chatTheme?.0 {
            tableView.scroll(to: .center(id: selected, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), toVisible: true)
        } else {
            tableView.scroll(to: .center(id: tableView.item(at: 1).stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), toVisible: true)
        }
        
        if chatTheme?.0 != installedTheme {
            let accept: TextButton
            var isNew: Bool = false
            if let view = self.accept {
                accept = view
            } else {
                accept = TextButton()
                accept.autohighlight = false
                accept.scaleOnClick = true
                accept.layer?.cornerRadius = .cornerRadius
                controls.addSubview(accept)
                
                accept.set(handler: { [weak self] _ in
                    self?.acceptTheme?()
                }, for: .SingleClick)
                self.accept = accept
                isNew = true
                if animated {
                    accept.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            accept.set(color: theme.colors.underSelectedColor, for: .Normal)
            accept.set(background: theme.colors.accent, for: .Normal)
            accept.set(font: .medium(.text), for: .Normal)
            accept.set(text: strings().chatChatThemeApplyTheme, for: .Normal)
            accept.sizeToFit(NSMakeSize(20, 15), .zero, thatFit: false)
            
            if isNew {
                accept.center()
            }
        } else if let view = self.accept {
            performSubviewRemoval(view, animated: animated)
            self.accept = nil
        }
        
        cancel.set(image: theme.icons.modalClose, for: .Normal)
        cancel.sizeToFit()
        
        
        selectBackground.set(color: theme.colors.accent, for: .Normal)
        selectBackground.set(background: theme.colors.background, for: .Normal)
        selectBackground.set(font: .medium(.text), for: .Normal)
        selectBackground.set(text: strings().chatChatThemeSelectBackground, for: .Normal)
        selectBackground.sizeToFit()
        
        let header = TextViewLayout(.initialize(string: strings().chatThemeTheme, color: theme.colors.text, font: .medium(.header)))
        header.measure(width: .greatestFiniteMagnitude)
        headerView.update(header)
        
        let headerInfo = TextViewLayout(.initialize(string: strings().chatThemeThemeInfo(peer?.compactDisplayTitle ?? ""), color: theme.colors.grayText, font: .normal(.short)))
        headerInfo.measure(width: frame.width - 100)
        headerInfoView.update(headerInfo)
        
        let switchLayout = TextViewLayout(.initialize(string: strings().chatThemeColorful, color: theme.colors.text, font: .normal(.text)))
        switchLayout.measure(width: .greatestFiniteMagnitude)
        bubblesTitle.update(switchLayout)
        
        
        
        var isBespokeWallpaper: Bool = false
        if let chatTheme = chatTheme {
            if let found = themes.first(where: { $0.0 == chatTheme.0 }) {
                isBespokeWallpaper = found.2.wallpaper != wallpaper
            } else {
                isBespokeWallpaper = theme.wallpaper != wallpaper
            }
        } else {
            isBespokeWallpaper = theme.wallpaper != wallpaper
        }
        
        if isBespokeWallpaper {
            let current: TextButton
            if let view = self.resetBackground {
                current = view
            } else {
                current = TextButton()
                current.autohighlight = false
                current.scaleOnClick = true
                addSubview(current)
                self.resetBackground = current
                
                current.set(handler: { [weak self] _ in
                    self?.resetBg?()
                }, for: .Click)
                
                current.set(color: theme.colors.redUI, for: .Normal)
                current.set(background: theme.colors.background, for: .Normal)
                current.set(font: .medium(.text), for: .Normal)
                current.set(text: strings().chatChatThemeResetToDefault, for: .Normal)
                current.sizeToFit()
                current.centerX(y: controls.frame.maxY)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            
        } else if let view = self.resetBackground {
            performSubviewRemoval(view, animated: animated)
            self.resetBackground = nil
        }
        
        if animated {
            self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
        } else {
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: headerContainer, frame: NSMakeRect(0, 0, frame.width, 50))
        transition.updateFrame(view: headerView, frame: CGRect(origin: NSMakePoint(60, headerContainer.frame.height / 2 - headerView.frame.height + 4), size: headerView.frame.size))

        transition.updateFrame(view: headerInfoView, frame: CGRect(origin: NSMakePoint(60, headerContainer.frame.height / 2 + 4), size: headerInfoView.frame.size))

        transition.updateFrame(view: cancel, frame: cancel.centerFrameY(x: 20))
        transition.updateFrame(view: bubblesSwitch, frame: bubblesSwitch.centerFrameY(x: frame.width - bubblesSwitch.frame.width - 20))
        transition.updateFrame(view: bubblesTitle, frame: bubblesTitle.centerFrameY(x: bubblesSwitch.frame.minX - bubblesTitle.frame.width - 10))
        transition.updateFrame(view: tableView, frame:  NSMakeRect(0, 50, frame.width, 90))
        
        let controlsSize = NSMakeSize(size.width, 60)
        
        transition.updateFrame(view: controls, frame: CGRect(origin: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - controlsSize.width) / 2), tableView.frame.maxY - 5), size: controlsSize))
        
        if let accept = accept {
            transition.updateFrame(view: accept, frame: accept.centerFrame())
        }
        
        var bgY: CGFloat = controls.frame.maxY
        if accept == nil {
            bgY = tableView.frame.maxY + 20
        }
        
        if let view = resetBackground {
            transition.updateFrame(view: selectBackground, frame: CGRect(origin: NSMakePoint(frame.width / 2 + 5, bgY), size: selectBackground.frame.size))
            transition.updateFrame(view: view, frame: CGRect.init(origin: NSMakePoint(frame.width / 2 - view.frame.width - 5, bgY), size: view.frame.size))
        } else {
            transition.updateFrame(view: selectBackground, frame: selectBackground.centerFrameX(y: bgY))
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
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

    var previewCurrent: ((String?, TelegramPresentationTheme?)) -> Void = { _ in }
    
    private let bubbled = ValuePromise(theme.bubbled, ignoreRepeated: true)
    private let installedTheme: String?
    init(_ context: AccountContext, installedTheme: String?, chatTheme: Signal<(String?, TelegramPresentationTheme), NoError>, chatInteraction: ChatInteraction) {
        self.chatTheme = chatTheme
        self.installedTheme = installedTheme
        self.chatInteraction = chatInteraction
        super.init(context)
        self.bar = .init(height: 0)
    }
    
    deinit {
       
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = chatInteraction.peerId
        let installedTheme = self.installedTheme

        guard let peer = chatInteraction.peer else {
            return
        }
        
        
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
        var temprorary: (String?, TelegramPresentationTheme)? = nil

        _ = (currentSelectedValue.get() |> take(1)).start(next: { [weak self] value in
            self?.currentSelected = value
            temprorary = value
        })
        
        let animatedEmojiStickers = context.diceCache.animatedEmojies
        disposable.set(combineLatest(queue: .mainQueue(), themesAndThumbs, chatTheme, currentSelectedValue.get(), animatedEmojiStickers).start(next: { [weak self] themes, chatTheme, currentSelected, emojies in
            
            let selected: (String?, TelegramPresentationTheme)? = temprorary
            let bubbled = themes.1
                        
            self?.genericView.updateThemes(peer, themes.0, installedTheme: installedTheme, wallpaper: chatTheme.1.wallpaper, bubbled: bubbled, emojies: emojies, context: context, chatTheme: selected, previewCurrent: { preview in
                temprorary = preview
                self?.previewCurrent((preview?.0, (preview?.1 ?? theme).withUpdatedChatMode(bubbled)))
                self?.currentSelected = preview
            }, updateBubbled: { value in
                self?.bubbled.set(value)
                self?.previewCurrent((currentSelected?.0, (currentSelected?.1 ?? theme).withUpdatedChatMode(value)))
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
        
        genericView.selectBackground.set(handler: { [weak self] _ in
            if let wallpaper = self?.genericView.wallpaper {
                showModal(with: ChatWallpaperModalController(context, selected: wallpaper.wallpaper, source: .chat(peer, nil), onComplete: { [weak self] _ in
                    self?.close(true)
                }), for: context.window)
            }
        }, for: .Click)
        
        genericView.resetBg = { [weak self] in
            _ = context.engine.themes.setChatWallpaper(peerId: peerId, wallpaper: nil, forBoth: false).start()
            self?.close(true)
        }
        genericView.acceptTheme = { [weak self] in
            
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
            
        }
        

    }
    
}
