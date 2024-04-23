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
import SwiftSignalKit

private struct Localize {
    static func placeholder(_ type: SentAuthorizationCodeType) -> String {
        switch type {
        case .phrase:
            return strings().loginEnterPhrasePlaceholder
        case .word:
            return strings().loginEnterWordPlaceholder
        default:
            fatalError()
        }
    }
    static func title(_ type: SentAuthorizationCodeType) -> String {
        switch type {
        case .phrase:
            return strings().loginEnterPhraseTitle
        case .word:
            return strings().loginEnterWordTitle
        default:
            fatalError()
        }
    }
    
    static func text(_ type: SentAuthorizationCodeType, phonenumber: String) -> String {
        switch type {
        case let .phrase(startsWith):
            if let startsWith {
                return strings().loginEnterPhraseBeginningText(startsWith, phonenumber)
            } else {
                return strings().loginEnterPhraseText(phonenumber)
            }
        case let .word(startsWith):
            if let startsWith {
                return strings().loginEnterWordBeginningText(startsWith, phonenumber)
            } else {
                return strings().loginEnterWordText(phonenumber)
            }
        default:
            fatalError()
        }
    }
}

private final class Auth_WordInputView : View {
    let input: UITextView = .init(frame: .zero)
    private let separator = View()
    
    var isError: Bool = false {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(input)
        addSubview(separator)
        
        
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
        
        separator.backgroundColor = isError ? theme.colors.redUI : theme.colors.border
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
    
    private var codeType: SentAuthorizationCodeType = .word(startsWith: nil)
    private var phonenumber: String = ""
    
    func updateCodeType(_ type: SentAuthorizationCodeType, phonenumber: String) {
        self.codeType = type
        self.phonenumber = phonenumber
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        
        
        let theme = theme as! TelegramPresentationTheme
        if let data = LocalAnimatedSticker.login_word.data {
            self.playerView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("login_word"), size: Auth_Insets.wordSize, backingScale: Int(System.backingScale), fitzModifier: nil, colors: []), playPolicy: .onceEnd))
        }
        
        let layout = TextViewLayout(.initialize(string: Localize.title(codeType), color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        let descAttr: NSAttributedString = .initialize(string: Localize.text(codeType, phonenumber: phonenumber), color: theme.colors.grayText, font: Auth_Insets.infoFont).detectBold(with: .medium(Auth_Insets.infoFont.pointSize))
        
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
    private var takeError:(()->Void)?
    private var takeResend:(()->Void)?
    private var takeNextType:(()->Void)?
    
    private var makeError:((AuthorizationCodeVerificationError)->Void)?

    private var codeType: SentAuthorizationCodeType = .word(startsWith: nil)
    private let interactions = TextView_Interactions()
    
    private var nextTextView: TextView?
    private let disposable = MetaDisposable()

    
    required init(frame frameRect: NSRect) {
        header = Auth_WordHeaderView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(control)
        container.addSubview(nextView)
        container.addSubview(error)

        addSubview(container)
        nextView.set(handler: { [weak self] _ in
            self?.invoke()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        nextView.updateLocalizationAndTheme(theme: theme)
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
        
        if let nextTextView {
            transition.updateFrame(view: nextTextView, frame: nextTextView.centerFrameX(y: container.frame.maxY + Auth_Insets.betweenHeader))
        }

    }
    
    func invoke() {
        if !self.control.input.isEmpty, !locked {
            self.takeNext?(self.control.input.string())
        }
    }
    
    func firstResponder() -> NSResponder? {
        return control.firstResponder
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateInputState(_ state: Updated_ChatTextInputState) {
        
        switch self.codeType {
        case let .word(startsWith), let .phrase(startsWith):
            if let startsWith {
                if !state.inputText.string.hasPrefix(startsWith), !state.inputText.string.isEmpty {
                    self.makeError?(.invalidCode)
                } else {
                    self.takeError?()
                }
            } else {
                self.takeError?()
            }
        default:
            break
        }
    }
    
    func update(locked: Bool, error: AuthorizationCodeVerificationError?, phonenumber: String, timeout: Int32?, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, takeNext: @escaping(String)->Void, takeError:@escaping()->Void, makeError:@escaping(AuthorizationCodeVerificationError)->Void, takeReset:@escaping()->Void, takeResend: @escaping()->Void, takeNextType: @escaping()->Void) {
        
        
        self.header.updateCodeType(codeType, phonenumber: phonenumber)
        self.control.input.placeholder = Localize.placeholder(codeType)
        
        
        interactions.inputIsEnabled = !locked
        interactions.inputDidUpdate = { [weak self] state in
            guard let self else {
                return
            }
            self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
            self.updateInputState(state)
        }
        interactions.processEnter = { [weak self] _ in
            self?.invoke()
            return true
        }
        
        self.control.input.interactions = interactions
        
        self.codeType = codeType
        self.takeNext = takeNext
        self.takeReset = takeReset
        self.makeError = makeError
        self.takeError = takeError
        self.takeResend = takeResend
        self.takeNextType = takeNextType
        self.locked = locked
        
        
        nextView.updateLocked(locked)
        
        if let error = error {
            let textError:String
            switch error {
            case .limitExceeded:
                textError = strings().loginFloodWait
            case .invalidCode:
                textError = strings().loginWrongPhraseError
            case .generic:
                textError = strings().phoneCodeExpired
            case .codeExpired:
                textError = strings().phoneCodeExpired
            case .invalidEmailToken:
                fatalError()
            case .invalidEmailAddress:
                fatalError()
            }
            self.error.state.set(.error(textError))
            self.control.shake(beep: true)
            self.control.isError = true
        } else {
            self.error.state.set(.normal)
            self.control.isError = false
        }
        
        needsLayout = true
        
        
        if let timeout = timeout {
            runNextTimer(codeType, nextType, timeout)
        }
        updateAfterTick(codeType, nextType, timeout)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    deinit {
        disposable.dispose()
    }
    
    func runNextTimer(_ type:SentAuthorizationCodeType, _ nextType:AuthorizationCodeNextType?, _ timeout:Int32) {
        disposable.set(countdown(Double(timeout), delay: 1).start(next: { [weak self] value in
            self?.updateAfterTick(type, nextType, Int32(value))
        }, completed: {
            
        }))
    }

    func updateAfterTick(_ type:SentAuthorizationCodeType, _ nextType:AuthorizationCodeNextType?, _ timeout:Int32?) {
                
        var nextText:String = ""
        
        switch type {
        case .otherSession, .word, .phrase:
            nextText = strings().loginSendSmsIfNotReceivedAppCode
        default:
            break
        }
        
        if let nextType = nextType, nextText.isEmpty {
            if let timeout = timeout {
                let timeout = Int(timeout)
                let minutes = timeout / 60;
                let sec = timeout % 60;
                let secValue = sec > 9 ? "\(sec)" : "0\(sec)"
                if timeout > 0 {
                    switch nextType {
                    case .call:
                        nextText = strings().loginWillCall(minutes, secValue)
                        break
                    case .sms:
                        nextText = strings().loginWillSendSms(minutes, secValue)
                        break
                    default:
                        break
                    }
                } else {
                    switch nextType {
                    case .call:
                        nextText = strings().loginPhoneDialed
                        break
                    default:
                        break
                    }
                }
                
            } else {
                nextText = strings().loginSendSmsIfNotReceivedAppCode
            }
        }
        
        var nextLayout: TextViewLayout? = nil
        if !nextText.isEmpty {
            let attr = NSMutableAttributedString()
            
            _ = attr.append(string: nextText, color: theme.colors.link , font: .normal(.title))
            attr.add(link: inAppLink.callback("resend", { [weak self] _ in
                self?.takeResend?()
            }), for: attr.range)
            
            attr.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: attr.range)

            let layout = TextViewLayout(attr)
            layout.interactions = globalLinkExecutor
            layout.measure(width: frame.width - 40)
            nextLayout = layout
        }
        
        if let nextLayout = nextLayout {
            let current: TextView
            if let nextTextView = nextTextView {
                current = nextTextView
            } else {
                current = TextView()
                self.nextTextView = current
                addSubview(current)
            }
            var point = focus(nextLayout.layoutSize).origin
            point.y = container.frame.maxY + 30
            current.update(nextLayout, origin: point)
        } else if let nextTextView = nextTextView {
            performSubviewRemoval(nextTextView, animated: true)
            self.nextTextView = nil
        }
        
        needsLayout = true
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
    
    func update(locked: Bool, error: AuthorizationCodeVerificationError?, phonenumber: String, timeout: Int32?, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, takeNext: @escaping(String)->Void, takeError:@escaping()->Void, makeError: @escaping(AuthorizationCodeVerificationError)->Void, takeReset:@escaping()->Void, takeResend: @escaping()->Void, takeNextType:@escaping()->Void) {
        self.genericView.update(locked: locked, error: error, phonenumber: phonenumber, timeout: timeout, codeType: codeType, nextType: nextType, takeNext: takeNext, takeError: takeError, makeError: makeError, takeReset: takeReset, takeResend: takeResend, takeNextType: takeNextType)
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
