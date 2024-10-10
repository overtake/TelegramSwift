//
//  StoryStealthModeController.swift
//  Telegram
//
//  Created by Mike Renoir on 27.07.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var stealthMode: Stories.StealthModeState
    var isPremium: Bool
}

private final class StoryStealthModeView : Control {
    
    class InfoView : View {
        let imageView = ImageView()
        let titleView = TextView()
        let descView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            descView.userInteractionEnabled = false
            descView.isSelectable = false

            addSubview(titleView)
            addSubview(descView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func layout(image: CGImage, title: String, text: String, width: CGFloat, presentation: TelegramPresentationTheme) {
            
            self.imageView.image = image
            self.imageView.sizeToFit()
            
            let titleLayout = TextViewLayout(.initialize(string: title, color: presentation.colors.text, font: .medium(.title)))
            titleLayout.measure(width: width - 34)
            self.titleView.update(titleLayout)
            
            
            let infoLayout = TextViewLayout(.initialize(string: text, color: presentation.colors.grayText, font: .normal(.text)))
            infoLayout.measure(width: width - 34)
            self.descView.update(infoLayout)

            setFrameSize(NSMakeSize(max(infoLayout.layoutSize.width, titleLayout.layoutSize.width) + 34, titleLayout.layoutSize.height + infoLayout.layoutSize.height + 3))
        }
        
        override func layout() {
            super.layout()
            imageView.centerY(x: 0)
            titleView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, 0))
            descView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, titleView.frame.maxY + 3))
        }
    }
    
    fileprivate let close = ImageButton()
    
    private let headerImage = ImageView()
    private let titleView = TextView()
    private let descView = TextView()
    
    fileprivate let button = TextButton()
    
    private let infoView1 = InfoView(frame: .zero)
    private let infoView2 = InfoView(frame: .zero)
    private let infoViews = View()
    
    private var state: State?
    private var context: AccountContext?
    private var timer: SwiftSignalKit.Timer?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(close)
        addSubview(headerImage)
        addSubview(titleView)
        addSubview(descView)
        infoViews.addSubview(infoView1)
        infoViews.addSubview(infoView2)
        addSubview(infoViews)
        addSubview(button)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false

        close.scaleOnClick = true
        close.autohighlight = false
        headerImage.image = NSImage(named: "Icon_Story_StealthMode")?.precomposed()
        headerImage.sizeToFit()
        
        button.scaleOnClick = true
        button.autohighlight = false
    }
    
    func initialize(presentation: TelegramPresentationTheme) {
        updateLocalizationAndTheme(theme: presentation)
    }
    
    func update(_ state: State, context: AccountContext, presentation: TelegramPresentationTheme) -> NSSize {
        self.state = state
        self.context = context
        self.updateLocalizationAndTheme(theme: presentation)
        self.layout()
        
        if state.stealthMode.cooldownUntilTimestamp != nil, state.isPremium {
            timer = SwiftSignalKit.Timer.init(timeout: 0.3, repeat: true, completion: { [weak self] in
                self?.updateLocalizationAndTheme(theme: presentation)
                self?.layout()
            }, queue: .mainQueue())
            
            timer?.start()
        } else {
            timer?.invalidate()
            timer = nil
        }
        
        return NSMakeSize(380, button.frame.maxY + 20)
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.background
        let theme = theme as! TelegramPresentationTheme
        close.set(image: theme.icons.modalClose, for: .Normal)
        close.sizeToFit()
        
        guard let state = self.state, let context = self.context else {
            return
        }
        
        let titleLayout = TextViewLayout(.initialize(string: strings().storyStealthModeTitle, color: theme.colors.text, font: .medium(.header)))
        self.titleView.update(titleLayout)
        
        let infoLayout = TextViewLayout(.initialize(string: state.isPremium ? strings().storyStealthModeInfoText : strings().storyStealthModeInfoSubscribe, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        self.descView.update(infoLayout)
        
        infoView1.layout(image: NSImage(named: "Icon_Story_StealthMode_Rewind_5")!.precomposed(theme.colors.accent), title: strings().storyStealthModeFirstTitle, text: strings().storyStealthModeFirstInfo, width: frame.width, presentation: theme)
        
        infoView2.layout(image: NSImage(named: "Icon_Story_StealthMode_Rewind_25")!.precomposed(theme.colors.accent), title: strings().storyStealthModeSecondTitle, text: strings().storyStealthModeSecondInfo, width: frame.width, presentation: theme)

        
        button.set(font: .medium(.text), for: .Normal)
        if state.isPremium {
            if let cooldown = state.stealthMode.cooldownUntilTimestamp {
                button.set(text: strings().storyStealthModeButtonAvailable(smartTimeleftText(Int(cooldown - context.timestamp))), for: .Normal)
                button.isEnabled = false
            } else {
                button.set(text: strings().storyStealthModeButtonEnable, for: .Normal)
                button.isEnabled = true
            }
        } else {
            button.set(text: strings().storyStealthModeButtonUnlock, for: .Normal)
            button.isEnabled = true
        }
        button.set(color: theme.colors.underSelectedColor, for: .Normal)
        button.set(background: theme.colors.accent, for: .Normal)
        
        button.sizeToFit(.zero, NSMakeSize(340, 40), thatFit: true)
        button.layer?.cornerRadius = 10
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        close.setFrameOrigin(NSMakePoint(10, 10))
        headerImage.centerX(y: 32)
        
        titleView.resize(.greatestFiniteMagnitude)
        descView.resize(frame.width - 80)

        titleView.centerX(y: headerImage.frame.maxY + 20)
        descView.centerX(y: titleView.frame.maxY + 10)
        
        infoViews.setFrameSize(NSMakeSize(max(max(infoView1.frame.width, infoView2.frame.width), 236), infoView1.frame.height + infoView2.frame.height + 24))
        infoView1.setFrameOrigin(.zero)
        infoView2.setFrameOrigin(NSMakePoint(0, infoView1.frame.maxY + 24))

        
        infoViews.centerX(y: descView.frame.maxY + 34)
        button.centerX(y: infoViews.frame.maxY + 34)
    }
}

final class StoryStealthModeController: ModalViewController {
    
    private let context: AccountContext
    private let presentation: TelegramPresentationTheme
    private let disposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let enableStealth: ()->Void
    init(_ context: AccountContext, enableStealth: @escaping()->Void, presentation: TelegramPresentationTheme) {
        self.context = context
        self.presentation = presentation
        self.enableStealth = enableStealth
        super.init(frame: NSMakeRect(0, 0, 380, 300))
        self.bar = .init(height: 0)
    }
    
    override var modalTheme: ModalViewController.Theme {
        return .init(presentation: presentation)
    }

    override func viewClass() -> AnyClass {
        return StoryStealthModeView.self
    }
    
    private var genericView: StoryStealthModeView {
        return self.view as! StoryStealthModeView
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: presentation)
    }
    
    deinit {
        disposable.dispose()
        actionsDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let presentation = self.presentation
        
        let initialState = State(stealthMode: .init(activeUntilTimestamp: nil, cooldownUntilTimestamp: nil), isPremium: context.isPremium)
        
        let statePromise = ValuePromise<State>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let stealthData = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState()
        )
        
        self.disposable.set(combineLatest(queue: .mainQueue(), stealthData, getPeerView(peerId: context.peerId, postbox: context.account.postbox)).start(next: { result, peer in
            updateState { current in
                var current = current
                current.stealthMode = result.stealthModeState
                current.isPremium = peer?.isPremium ?? context.isPremium
                return current
            }
        }))
        
        self.genericView.initialize(presentation: presentation)
        
        actionsDisposable.add(statePromise.get().start(next: { [weak self] state in
            guard let `self` = self else {
                return
            }
            let size = self.genericView.update(state, context: context, presentation: presentation)
            self.modal?.resize(with: size, animated: false)
            self.readyOnce()
        }))
        
        genericView.close.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        
        genericView.button.set(handler: { [weak self] _ in
            if context.isPremium {
                self?.enableStealth()
                self?.close()
            } else {
                showModal(with: PremiumBoardingController(context: context, source: .stories__stealth_mode, presentation: darkAppearance), for: context.window)
            }
        }, for: .Click)
    }
    
    override var hasBorder: Bool {
        return false
    }
}



