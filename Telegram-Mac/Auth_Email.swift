//
//  Auth_Email.swift
//  Telegram
//
//  Created by Mike Renoir on 17.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import TGUIKit
import AppKit
import TelegramCore

private final class Auth_EmailHeaderView : View {
    private let playerView:LottiePlayerView = LottiePlayerView()
    private let header: TextView = TextView()
    private let desc: TextView = TextView()
    private var descAttr: NSAttributedString?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playerView)
        addSubview(header)
        addSubview(desc)
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        desc.userInteractionEnabled = false
        desc.isSelectable = false
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        if let data = LocalAnimatedSticker.email_recovery.data {
            self.playerView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("email_recovery"), size: Auth_Insets.logoSize, backingScale: Int(System.backingScale), fitzModifier: nil, colors: []), playPolicy: .onceEnd))
        }
        
        let layout = TextViewLayout(.initialize(string: strings().loginNewEmailHeader, color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        let descAttr: NSAttributedString = .initialize(string: strings().loginNewEmailInfo, color: theme.colors.grayText, font: Auth_Insets.infoFont)
        
        let descLayout = TextViewLayout(descAttr, alignment: .center)
        descLayout.measure(width: frame.width)
        self.desc.update(descLayout)
        
        self.layout()
    }
    
    override func layout() {
        super.layout()
        self.playerView.setFrameSize(Auth_Insets.logoSize)
        self.playerView.centerX(y: 0)
        self.header.centerX(y: self.playerView.frame.maxY + 20)
        self.desc.centerX(y: self.header.frame.maxY + 10)

    }
    
    var height: CGFloat {
        return self.desc.frame.maxY
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func playAnimation() {
        playerView.playAgain()
    }
}


final class Auth_EmailView: View {
    private let container: View = View()
    private let header:Auth_EmailHeaderView
    private let control = Auth_CodeEntryContol(frame: .zero)
    private let nextView = Auth_NextView()
    private let error: LoginErrorStateView = LoginErrorStateView()
    private let reset: TextView = TextView()
    private var locked: Bool = false
    
    private var takeNext:((String)->Void)?
    private var takeReset:(()->Void)?
    
    private var pattern: String = ""
    
    required init(frame frameRect: NSRect) {
        header = Auth_EmailHeaderView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(control)
        container.addSubview(nextView)
        container.addSubview(error)
        container.addSubview(reset)

        reset.isSelectable = false
        addSubview(container)
        nextView.set(handler: { [weak self] _ in
            self?.control.invoke()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        nextView.updateLocalizationAndTheme(theme: theme)
                
        let text = strings().loginNewEmailFooter(self.pattern)
        
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.header), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.header), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  { [weak self] _ in
                self?.takeReset?()
            }))
        }))
        

        let layout = TextViewLayout(attr, alignment: .center)
        layout.measure(width: .greatestFiniteMagnitude)
        layout.interactions = globalLinkExecutor
        reset.update(layout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        container.setFrameSize(NSMakeSize(frame.width, header.height + Auth_Insets.betweenHeader + control.frame.height + Auth_Insets.betweenNextView + Auth_Insets.nextHeight + Auth_Insets.betweenHeader + reset.frame.height))

        header.setFrameSize(NSMakeSize(frame.width, header.height))
        header.centerX(y: 0)
        control.centerX(y: header.frame.maxY + Auth_Insets.betweenHeader)
        error.centerX(y: control.frame.maxY + Auth_Insets.betweenError)
        nextView.centerX(y: control.frame.maxY + Auth_Insets.betweenNextView)
        reset.centerX(y: nextView.frame.maxY + Auth_Insets.betweenHeader)
        container.center()
        
    }
    
    func invoke() {
        if !self.control.value.isEmpty, !locked {
            self.takeNext?(self.control.value)
        }
    }
    
    func firstResponder() -> NSResponder? {
        return control.firstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func update(locked: Bool, error: PasswordRecoveryError?, pattern: String, takeNext: @escaping(String)->Void, takeError:@escaping()->Void, takeReset:@escaping()->Void) {
//        self.input.update(locked: locked, hint: hint, invoke: { [weak self] in
//            self?.invoke()
//        }, takeError: takeError)
        self.pattern = pattern
        self.takeNext = takeNext
        self.takeReset = takeReset
        self.locked = locked
        
        let size = self.control.update(count: 6)
        self.control.setFrameSize(size)
        self.control.takeNext = takeNext
        self.control.takeError = takeError
        self.control.set(locked: locked, animated: true)

        nextView.updateLocked(locked)
        
        if let error = error {
            let text: String
            switch error {
            case .invalidCode:
                text = strings().twoStepAuthEmailCodeInvalid
            case .expired:
                text = strings().twoStepAuthEmailCodeExpired
            case .generic:
                text = strings().unknownError
            case .limitExceeded:
                text = strings().loginFloodWait
            }
            self.error.state.set(.error(text))
            self.control.shake(beep: true)
        } else {
            self.error.state.set(.normal)
        }
        
        needsLayout = true
        updateLocalizationAndTheme(theme: theme)
    }
    
    func playAnimation() {
        header.playAnimation()
    }
}

final class Auth_EmailController : GenericViewController<Auth_EmailView> {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    func update(locked: Bool, error: PasswordRecoveryError?, pattern: String, takeNext: @escaping(String)->Void, takeError:@escaping()->Void, takeReset:@escaping()->Void) {
        self.genericView.update(locked: locked, error: error, pattern: pattern, takeNext: takeNext, takeError: takeError, takeReset: takeReset)
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.firstResponder()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if animated {
            genericView.playAnimation()
        }
    }
}
