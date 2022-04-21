//
//  Auth_CodeEntry.swift
//  Telegram
//
//  Created by Mike Renoir on 15.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import AppKit
import KeyboardKey
import SwiftSignalKit


private final class Auth_CodeEntryHeaderView : View {
    
    enum IconType {
        case phone
        case desktop
        
        
        var header: String {
            switch self {
            case .phone:
                return strings().loginNewCodeEnterSms
            case .desktop:
                return strings().loginNewCodeEnterCode
            }
        }
    }
    
    private let playerView:LottiePlayerView = LottiePlayerView()


    private let header: TextView = TextView()
    private let desc: TextView = TextView()
    private var type: IconType = .phone
    private var descAttr: NSAttributedString?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playerView)

        addSubview(header)
        addSubview(desc)
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        desc.isSelectable = false
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        
        
        let layout = TextViewLayout(.initialize(string: self.type.header, color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        if let descAttr = descAttr {
            let layout = TextViewLayout(descAttr, alignment: .center)
            layout.interactions = globalLinkExecutor
            layout.measure(width: frame.width)
            self.desc.update(layout)
        }
        
        if let data = LocalAnimatedSticker.code_note.data {
            var colors:[LottieColor] = []
            colors.append(.init(keyPath: "Bubble.Group 1.Fill 1", color: theme.colors.accent))
            colors.append(.init(keyPath: "Note.Path.Fill 1", color: theme.colors.grayText))
            colors.append(.init(keyPath: "Note.Path-2.Stroke 1", color: theme.colors.grayText))
            colors.append(.init(keyPath: "Phone.Combined-Shape.Fill 1", color: theme.colors.grayText))

            self.playerView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("code_note"), size: Auth_Insets.logoSize, backingScale: Int(System.backingScale), fitzModifier: nil), playPolicy: .onceEnd, colors: colors))
        }

        self.layout()
    }
    
    func update(desc: NSAttributedString, type: IconType) {
        self.descAttr = desc
        self.type = type
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func layout() {
        super.layout()
        self.playerView.setFrameSize(Auth_Insets.logoSize)
        self.playerView.centerX(y: 0)
        self.header.centerX(y: self.playerView.frame.maxY + 20)
        self.desc.centerX(y: self.header.frame.maxY + 10)

    }

    func playAnimation() {
        playerView.playAgain()
    }
    
    var height: CGFloat {
        return self.desc.frame.maxY
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class Auth_CodeEntryView: View {
    private let header: Auth_CodeEntryHeaderView
    private let container = View()
    private let control = Auth_CodeEntryContol(frame: .zero)
    private let error: LoginErrorStateView = LoginErrorStateView()
    private let nextView: Auth_NextView = Auth_NextView()
    
    private let disposable = MetaDisposable()
    
    private var takeResend:(()->Void)?
    
    private var nextTextView: TextView?
    
    required init(frame frameRect: NSRect) {
        header = Auth_CodeEntryHeaderView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(control)
        container.addSubview(error)
        container.addSubview(nextView)
        

        nextView.set(handler: { [weak self] _ in
            self?.control.invoke()
        }, for: .Click)
        
        addSubview(container)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        nextView.updateLocalizationAndTheme(theme: theme)
    }
    
    override func layout() {
        super.layout()
        
        container.setFrameSize(NSMakeSize(frame.width, header.height + Auth_Insets.betweenHeader + control.frame.height + Auth_Insets.betweenNextView + Auth_Insets.nextHeight))
        
        header.setFrameSize(NSMakeSize(frame.width, header.height))
        header.centerX(y: 0)
        control.centerX(y: header.frame.maxY + Auth_Insets.betweenHeader)
        error.centerX(y: control.frame.maxY + Auth_Insets.betweenError)
        nextView.centerX(y: control.frame.maxY + Auth_Insets.betweenNextView)
        container.center()
        
        nextTextView?.centerX(y: container.frame.maxY + Auth_Insets.betweenHeader)
    }
    
    func update(locked: Bool, error: AuthorizationCodeVerificationError?, number: String, type: SentAuthorizationCodeType, timeout: Int32?, nextType: AuthorizationCodeNextType?, takeEdit:@escaping()->Void, takeNext:@escaping(String)->Void, takeResend: @escaping()->Void, takeError:@escaping()->Void) {
        
        let info: String
        let iconType: Auth_CodeEntryHeaderView.IconType
        let length: Int32
        switch type {
        case let .otherSession(_length):
            length = _length
            info = strings().loginNewCodeCodeInfo(formatPhoneNumber(number))
            iconType = .desktop
        case let .sms(_length):
            length = _length
            info = strings().loginNewCodeSmsInfo(formatPhoneNumber(number))
            iconType = .phone
        case let .call(_length):
            length = _length
            iconType = .phone
            info = strings().loginNewCodeCallInfo(formatPhoneNumber(number))
        default:
            fatalError()
        }
        let attr = parseMarkdownIntoAttributedString(info, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Auth_Insets.infoFont, textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: Auth_Insets.infoFontBold, textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: Auth_Insets.infoFont, textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  { _ in
                takeEdit()
            }))
        })).mutableCopy() as! NSMutableAttributedString
        attr.detectBoldColorInString(with: .medium(.header))
        
        self.header.update(desc: attr, type: iconType)
        let size = self.control.update(count: Int(length))
        self.control.setFrameSize(size)
        self.control.takeNext = takeNext
        self.control.takeError = takeError
        self.control.set(locked: locked, animated: true)
        
        if let error = error {
            let textError:String
            switch error {
            case .limitExceeded:
                textError = strings().loginFloodWait
            case .invalidCode:
                textError = strings().phoneCodeInvalid
            case .generic:
                textError = strings().phoneCodeExpired
            case .codeExpired:
                textError = strings().phoneCodeExpired
            }
            self.error.state.set(.error(textError))
            self.control.shake()
            self.control.moveToStart()
        } else {
            self.error.state.set(.normal)
        }
        
        nextView.updateLocked(locked)
        
        self.takeResend = takeResend
        
        needsLayout = true
        
        if let timeout = timeout {
            runNextTimer(type, nextType, timeout)
        }
        updateAfterTick(type, nextType, timeout)
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
        case .otherSession:
            nextText = strings().loginSendSmsIfNotReceivedAppCode
        default:
            break
        }
        
        if let nextType = nextType {
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
            
            if case .otherSession = type  {
                _ = attr.append(string: nextText, color: theme.colors.link , font: .normal(.title))
                attr.add(link: inAppLink.callback("resend", { [weak self] _ in
                    self?.takeResend?()
                }), for: attr.range)
                
                if  timeout == nil {
                    attr.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: attr.range)
                } else if let timeout = timeout {
                    attr.addAttribute(NSAttributedString.Key.foregroundColor, value: timeout <= 0 ? theme.colors.link : theme.colors.grayText, range: attr.range)
                }
            } else {
                _ = attr.append(string: nextText, color: theme.colors.grayText, font: .normal(.title))
            }
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
        control.moveToStart()
    }
    
    func firstResponder() -> NSResponder? {
        return control.firstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Auth_CodeEntryController : GenericViewController<Auth_CodeEntryView> {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.firstResponder()
    }
    
    func update(locked: Bool, error: AuthorizationCodeVerificationError?, number: String, type: SentAuthorizationCodeType, timeout: Int32?, nextType: AuthorizationCodeNextType?, takeEdit:@escaping()->Void, takeNext:@escaping(String)->Void, takeResend:@escaping()->Void, takeError:@escaping()->Void) {
        self.genericView.update(locked: locked, error: error, number: number, type: type, timeout: timeout, nextType: nextType, takeEdit: takeEdit, takeNext: takeNext, takeResend: takeResend, takeError: takeError)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if animated {
            genericView.playAnimation()
        }
    }
}
