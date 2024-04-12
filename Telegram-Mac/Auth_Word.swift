//
//  Auth_Word.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import TGUIKit
import AppKit
import TelegramCore
import TelegramMedia
import InputView

private final class Auth_WordInputView : View {
    private let input: UITextView = .init(frame: .zero)
    private let separator = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(input)
        addSubview(separator)
        self.input.placeholder = "Enter Word from SMS"
        
        
        input.interactions.min_height = 34
        input.interactions.max_height = 40
                
        input.interactions.inputDidUpdate = { [weak self] _ in
            guard let `self` = self else {
                return
            }
            self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
        }
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        separator.backgroundColor = theme.colors.border
    }
    
    var textWidth: CGFloat {
        return frame.width
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = input.height(for: w)
        return (NSMakeSize(w, min(max(height, input.min_height), input.max_height)), height)
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    private func set(_ state: Updated_ChatTextInputState) {
        
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let (textSize, textHeight) = textViewSize()
                
        transition.updateFrame(view: input, frame: CGRect(origin: CGPoint(x: 0, y: 0), size: textSize))
        input.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        
        transition.updateFrame(view: separator, frame: NSMakeRect(0, size.height - .borderSize, size.width, .borderSize))

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var firstResponder:NSResponder {
        return self.input.inputView
    }
}

private final class Auth_WordHeaderView : View {
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
        if let data = LocalAnimatedSticker.business_links.data {
            self.playerView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("business_links"), size: Auth_Insets.wordSize, backingScale: Int(System.backingScale), fitzModifier: nil, colors: []), playPolicy: .onceEnd))
        }
        
        let layout = TextViewLayout(.initialize(string: "Enter Word", color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        let descAttr: NSAttributedString = .initialize(string: "We've sent you an SMS with a secret word to your phone **+971 12 345 6789**.", color: theme.colors.grayText, font: Auth_Insets.infoFont).detectBold(with: .medium(Auth_Insets.infoFont.pointSize))
        
        let descLayout = TextViewLayout(descAttr, alignment: .center)
        descLayout.measure(width: frame.width)
        self.desc.update(descLayout)
        
        self.layout()
    }
    
    override func layout() {
        super.layout()
        self.playerView.setFrameSize(Auth_Insets.wordSize)
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


final class Auth_WordView: View {
    private let container: View = View()
    private let header:Auth_WordHeaderView
    private let control = Auth_WordInputView(frame: .zero)
    private let nextView = Auth_NextView()
    private let error: LoginErrorStateView = LoginErrorStateView()
    private var locked: Bool = false
    
    private var takeNext:((String)->Void)?
    private var takeReset:(()->Void)?
    
    private var pattern: String = ""
    
    required init(frame frameRect: NSRect) {
        header = Auth_WordHeaderView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(control)
        container.addSubview(nextView)
        container.addSubview(error)

        addSubview(container)
        nextView.set(handler: { [weak self] _ in
            //self?.control.invoke()
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
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: container, frame: focus(NSMakeSize(frame.width, header.height + Auth_Insets.betweenHeader + 40 + Auth_Insets.betweenNextView + Auth_Insets.nextHeight + Auth_Insets.betweenHeader)))

        
        transition.updateFrame(view: header, frame: CGRect(origin: .zero, size: NSMakeSize(frame.width, header.height)))
        transition.updateFrame(view: control, frame: CGRect(origin: NSMakePoint(20, header.frame.maxY + Auth_Insets.betweenHeader), size: NSMakeSize(frame.width - 40, 40)))
        control.updateLayout(size: control.frame.size, transition: transition)
        transition.updateFrame(view: error, frame: error.centerFrameX(y: control.frame.maxY + Auth_Insets.betweenError))
        transition.updateFrame(view: nextView, frame: nextView.centerFrameX(y: control.frame.maxY + Auth_Insets.betweenNextView))
        

    }
    
    func invoke() {
//        if !self.control.value.isEmpty, !locked {
//            self.takeNext?(self.control.value)
//        }
    }
    
    func firstResponder() -> NSResponder? {
        return control.firstResponder
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
        
//        let size = self.control.update(count: 6)
//        self.control.setFrameSize(size)
//        self.control.takeNext = takeNext
//        self.control.takeError = takeError
//        self.control.set(locked: locked, animated: true)

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

final class Auth_WordController : GenericViewController<Auth_WordView> {
    
    
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
