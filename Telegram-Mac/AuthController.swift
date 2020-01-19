import Foundation
import Cocoa
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import TGUIKit

private let manager = CountryManager()

enum LoginAuthViewState {
    case phoneNumber
    case password
    case code
}


private enum QRTokenState {
    case qr(CGImage)
}

private final class ExportTokenOptionView : View {
    private let textView: TextView = TextView()
    private let optionText = TextView()
    private let cap = View(frame: NSMakeRect(0, 0, 20, 20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        cap.layer?.cornerRadius = cap.frame.height / 2
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        optionText.isSelectable = false
        optionText.userInteractionEnabled = false
        addSubview(cap)
        addSubview(self.textView)
        addSubview(self.optionText)
    }
    
    func update(title: String, number: String) {
        let textAttr = NSMutableAttributedString()
        _ = textAttr.append(string: title, color: theme.colors.text, font: .normal(.text))
        textAttr.detectBoldColorInString(with: .medium(.text))
        let text = TextViewLayout(textAttr, maximumNumberOfLines: 2)
        text.measure(width: frame.width - cap.frame.width - 10)
        textView.update(text)
        
        let option = TextViewLayout(.initialize(string: number, color: theme.colors.underSelectedColor, font: .normal(.text)), maximumNumberOfLines: 2)
        option.measure(width: frame.width)
        optionText.update(option)
        
        cap.backgroundColor = theme.colors.accent
        
        setFrameSize(NSMakeSize(frame.width, max(cap.frame.height, 4 + text.layoutSize.height + 4)))
    }
    
    override func layout() {
        super.layout()
        
        cap.setFrameOrigin(NSZeroPoint)
        let offset: CGFloat = optionText.frame.width == 6 ? 7 : 6
        optionText.setFrameOrigin(NSMakePoint(offset, 2))
        textView.setFrameOrigin(NSMakePoint(cap.frame.maxX + 10, 2))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ExportTokenView : View {
    fileprivate let imageView: ImageView = ImageView()
    fileprivate let logoView = ImageView(frame: NSMakeRect(0, 0, 60, 60))
    private let containerView = View()
    private let titleView = TextView()
    fileprivate let cancelButton = TitleButton()
    
    private let firstHelp: ExportTokenOptionView
    private let secondHelp: ExportTokenOptionView
    private let thridHelp: ExportTokenOptionView

    required init(frame frameRect: NSRect) {
        firstHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        secondHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        thridHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        super.init(frame: frameRect)
        containerView.addSubview(self.imageView)
        
        self.imageView.addSubview(logoView)
        containerView.addSubview(self.titleView)
        containerView.addSubview(firstHelp)
        containerView.addSubview(secondHelp)
        containerView.addSubview(thridHelp)
        containerView.addSubview(cancelButton)
        addSubview(containerView)
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = theme as! TelegramPresentationTheme
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.background
        
        let titleLayout = TextViewLayout(.initialize(string: L10n.loginQRTitle, color: theme.colors.text, font: .normal(.header)), maximumNumberOfLines: 2, alignment: .center)
        titleLayout.measure(width: frame.width)
        titleView.update(titleLayout)
        
        firstHelp.update(title: L10n.loginQRHelp1, number: "1")
        secondHelp.update(title: L10n.loginQRHelp2, number: "2")
        thridHelp.update(title: L10n.loginQRHelp3, number: "3")
        
        cancelButton.set(font: .medium(.text), for: .Normal)
        cancelButton.set(color: theme.colors.accent, for: .Normal)
        cancelButton.set(text: L10n.loginQRCancel, for: .Normal)
        _ = cancelButton.sizeToFit()
        logoView.image = theme.icons.login_qr_cap
        logoView.sizeToFit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func update(state: QRTokenState) {
        switch state {
        case let .qr(image):
            self.imageView.image = image
            imageView.sizeToFit()
        }
        needsLayout = true
    }
    
    override func layout() {
        
        containerView.setFrameSize(NSMakeSize(frame.width, imageView.frame.height + 20 + self.titleView.frame.height + 20 + firstHelp.frame.height + 10 + secondHelp.frame.height + 10 + thridHelp.frame.height + 30 + cancelButton.frame.height))
        containerView.center()
        
        imageView.centerX(y: 0)
        logoView.center()
        titleView.updateWithNewWidth(containerView.frame.width)
        titleView.centerX(y: imageView.frame.maxY + 10)
        firstHelp.centerX(y: titleView.frame.maxY + 10)
        secondHelp.centerX(y: firstHelp.frame.maxY + 10)
        thridHelp.centerX(y: secondHelp.frame.maxY + 10)
        cancelButton.centerX(y: thridHelp.frame.maxY + 20)
        
    }
}

class AuthHeaderView : View {
    fileprivate var isQrEnabled: Bool? = nil {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    
    fileprivate var isLoading: Bool = false
    
    
    private var progressView: ProgressIndicator?
    
    private let containerView = View(frame: NSMakeRect(0, 0, 300, 480))
    
    fileprivate let proxyButton:ImageButton = ImageButton()
    private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 12, 12))
    
    fileprivate var exportTokenView:ExportTokenView?
    
    fileprivate var arguments:LoginAuthViewArguments?
    fileprivate let loginView:LoginAuthInfoView = LoginAuthInfoView(frame: NSZeroRect)
    fileprivate var state: UnauthorizedAccountStateContents = .empty
    fileprivate var qrTokenState: QRTokenState? = nil
    private let logo:ImageView = ImageView()
    private let header:TextView = TextView()
    private let desc:TextView = TextView()
    private let textHeaderView:TextView = TextView()
    let intro:View = View()
    private let switchLanguage:TitleButton = TitleButton()
    fileprivate let nextButton:TitleButton = TitleButton()
    fileprivate let backButton = TitleButton()
    fileprivate let cancelButton = TitleButton()
    
    
    private let animatedLogoView = ImageView()

    fileprivate var needShowSuggestedButton: Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        intro.setFrameSize(containerView.frame.size)
        
        
        updateLocalizationAndTheme(theme: theme)

        intro.addSubview(logo)
        intro.addSubview(header)
        intro.addSubview(desc)
        
        containerView.addSubview(intro)

        
        desc.userInteractionEnabled = false
        desc.isSelectable = false
        
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        textHeaderView.userInteractionEnabled = false
        textHeaderView.isSelectable = false
        
        containerView.addSubview(loginView)

        
        containerView.addSubview(textHeaderView)
        textHeaderView.userInteractionEnabled = false
        textHeaderView.isSelected = false
        
        nextButton.autohighlight = false
        nextButton.style = ControlStyle(font: NSFont.medium(16.0), foregroundColor: .white, backgroundColor: NSColor(0x32A3E2), highlightColor: .white)
        nextButton.set(text: L10n.loginNext, for: .Normal)
        _ = nextButton.sizeToFit(thatFit: true)
        nextButton.setFrameSize(76, 36)
        nextButton.layer?.cornerRadius = 18
        nextButton.disableActions()
        nextButton.set(handler: { [weak self] _ in
           if let strongSelf = self {
                switch strongSelf.state {
                case .phoneEntry, .empty:
                    strongSelf.arguments?.sendCode(strongSelf.loginView.phoneNumber)
                    break
                case .confirmationCodeEntry:
                    strongSelf.arguments?.checkCode(strongSelf.loginView.code)
                case .passwordEntry:
                    strongSelf.arguments?.checkPassword(strongSelf.loginView.password)
                case .signUp:
                     strongSelf.loginView.trySignUp()
                default:
                    break
                }
            }
        }, for: .Click)
        
        containerView.addSubview(nextButton)
        containerView.addSubview(switchLanguage)
        switchLanguage.isHidden = true
        
        switchLanguage.disableActions()
        switchLanguage.set(font: .medium(.title), for: .Normal)
        switchLanguage.set(text: "Continue on English", for: .Normal)
        _ = switchLanguage.sizeToFit()
        
        addSubview(proxyButton)
        proxyButton.addSubview(proxyConnecting)
        containerView.addSubview(backButton)
        
        addSubview(containerView)
        
        
        addSubview(cancelButton)
        
        needsLayout = true
    }
    
    fileprivate func updateProxyPref(_ pref: ProxySettings, _ connection: ConnectionStatus, _ isForceHidden: Bool = true) {
        proxyButton.isHidden = isForceHidden && pref.servers.isEmpty
        switch connection {
        case .connecting:
            proxyConnecting.isHidden = pref.effectiveActiveServer == nil
            proxyButton.set(image: pref.effectiveActiveServer == nil ? theme.icons.proxyEnable : theme.icons.proxyState, for: .Normal)
        case .online:
            proxyConnecting.isHidden = true
            if pref.enabled {
                proxyButton.set(image: theme.icons.proxyEnabled, for: .Normal)
            } else {
                proxyButton.set(image: theme.icons.proxyEnable, for: .Normal)
            }
        case .waitingForNetwork:
            proxyConnecting.isHidden = pref.effectiveActiveServer == nil
            proxyButton.set(image: pref.effectiveActiveServer == nil ? theme.icons.proxyEnable : theme.icons.proxyState, for: .Normal)
        default:
            proxyConnecting.isHidden = true
        }
        proxyConnecting.isEventLess = true
        proxyConnecting.userInteractionEnabled = false
        _ = proxyButton.sizeToFit()
        proxyConnecting.centerX()
        proxyConnecting.centerY(addition: -1)
        needsLayout = true
    }
    
    
    func hideSwitchButton() {
        needShowSuggestedButton = false
        switchLanguage.change(opacity: 0, removeOnCompletion: false) { [weak self] completed in
            self?.switchLanguage.isHidden = true
        }
    }
    
    func showLanguageButton(title: String, callback:@escaping()->Void) -> Void {
        needShowSuggestedButton = true
        switchLanguage.set(text: title, for: .Normal)
        _ = switchLanguage.sizeToFit()
        switchLanguage.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        switchLanguage.set(handler: { _ in
            callback()
        }, for: .Click)
        switchLanguage.isHidden = false
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        switchLanguage.centerX(y: containerView.frame.height - switchLanguage.frame.height - 20)
       
        logo.centerX(y: 0)
        header.centerX(y: logo.frame.maxY + 10)
        desc.centerX(y: header.frame.maxY)
        intro.setFrameSize(containerView.frame.width, desc.frame.maxY)
        intro.centerX(y: 20)
        loginView.setFrameSize(300, containerView.frame.height)
        loginView.centerX(y: intro.frame.maxY)
        nextButton.centerX(y: containerView.frame.height - nextButton.frame.height - 50)
        
        proxyConnecting.centerX()
        proxyConnecting.centerY(addition: -1)
        proxyButton.setFrameOrigin(frame.width - proxyButton.frame.width - 15, 15)
        
        containerView.center()
        
        cancelButton.setFrameOrigin(15, 15)

        self.exportTokenView?.setFrameSize(NSMakeSize(300, 500))
        self.exportTokenView?.center()
        
        self.progressView?.center()
        
        updateState(state, qrTokenState: self.qrTokenState, isLoading: self.isLoading, animated: false)
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        switchLanguage.set(color: theme.colors.accent, for: .Normal)
        
        
        self.animatedLogoView.image = theme.icons.login_cap
        self.animatedLogoView.sizeToFit()
        
        self.logo.image = theme.icons.login_cap
        self.logo.sizeToFit()
        
        let headerLayout = TextViewLayout(.initialize(string: appName, color: theme.colors.text, font: NSFont.normal(30.0)), maximumNumberOfLines: 1)
        headerLayout.measure(width: .greatestFiniteMagnitude)
        header.update(headerLayout)
        
        header.backgroundColor = theme.colors.background
        desc.backgroundColor = theme.colors.background
        textHeaderView.backgroundColor = theme.colors.background
        
        let descLayout = TextViewLayout(.initialize(string: tr(L10n.loginWelcomeDescription), color: theme.colors.grayText, font: .normal(16.0)), maximumNumberOfLines: 2, alignment: .center)
        descLayout.measure(width: 300)
        desc.update(descLayout)
        
        
        if let isQrEnabled = self.isQrEnabled, isQrEnabled {
            nextButton.set(text: L10n.loginQRLogin, for: .Normal)
            _ = nextButton.sizeToFit(NSMakeSize(30, 0), NSMakeSize(0, 36), thatFit: true)
            nextButton.style = ControlStyle(font: .medium(15.0), foregroundColor: theme.colors.accent, backgroundColor: .clear)
        } else {
            nextButton.set(text: L10n.loginNext, for: .Normal)
            _ = nextButton.sizeToFit(NSMakeSize(30, 0), NSMakeSize(0, 36), thatFit: true)
            nextButton.style = ControlStyle(font: .medium(15.0), foregroundColor: theme.colors.underSelectedColor, backgroundColor: theme.colors.accent)
        }
        
        
        proxyConnecting.progressColor = theme.colors.accentIcon
        
        
        backButton.set(font: .medium(.header), for: .Normal)
        backButton.set(color: theme.colors.accent, for: .Normal)
        backButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        backButton.set(text: L10n.navigationBack, for: .Normal)
        _ = backButton.sizeToFit()
        
        cancelButton.set(font: .medium(.header), for: .Normal)
        cancelButton.set(color: theme.colors.accent, for: .Normal)
        cancelButton.set(text: L10n.navigationCancel, for: .Normal)
        _ = cancelButton.sizeToFit()
        
        progressView?.progressColor = theme.colors.text

        
        updateState(self.state, qrTokenState: self.qrTokenState, isLoading: self.isLoading, animated: false)
        needsLayout = true
        
    }
    
    fileprivate func nextButtonAsForQr(_ isQrEnabled: Bool?) -> Void {
        self.isQrEnabled = isQrEnabled
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    private func animateAndCancelQr() {
        
        guard let exportTokenView = self.exportTokenView else {
            return
        }
        CATransaction.begin()
        
        self.containerView.isHidden = false
        
        addSubview(animatedLogoView)
        
        exportTokenView.logoView.isHidden = true
        
        let point = NSMakePoint(exportTokenView.frame.midX - 20, exportTokenView.frame.minY + exportTokenView.imageView.frame.height / 2 - 16)
        
        animatedLogoView.frame = NSMakeRect(point.x, point.y, 60, 60)
        
        exportTokenView.imageView.layer?.animateScaleSpring(from: 1, to: animatedLogoView.frame.width / exportTokenView.imageView.frame.width, duration: 0.4, removeOnCompletion: false, bounce: true)

        animatedLogoView.layer?.animateScaleX(from: 1, to: logo.frame.width / animatedLogoView.frame.width, duration: 0.4, timingFunction: .spring, removeOnCompletion: false)
        animatedLogoView.layer?.animateScaleY(from: 1, to: logo.frame.height / animatedLogoView.frame.height, duration: 0.4, timingFunction: .spring, removeOnCompletion: false)

        self.logo.isHidden = true
        
        animatedLogoView.layer?.animatePosition(from: animatedLogoView.frame.origin, to: NSMakePoint((round(frame.width / 2) - logo.frame.width / 2), containerView.frame.minY + 20), duration: 0.4, timingFunction: .spring, removeOnCompletion: false, completion: { [weak self] _ in
            self?.exportTokenView?.logoView.isHidden = false
            self?.animatedLogoView.removeFromSuperview()
            self?.animatedLogoView.layer?.removeAllAnimations()
            self?.logo.isHidden = false
        })
        
        CATransaction.commit()
        
        self.arguments?.cancelQrAuth()
    }
    
    private func animateAndApplyQr() {
        addSubview(animatedLogoView)
        
        guard let exportTokenView = self.exportTokenView else {
            return
        }
        
        
        exportTokenView.logoView.isHidden = true

        let point = NSMakePoint(frame.width / 2 - logo.frame.width / 2 + 1, containerView.frame.minY + 20)

        animatedLogoView.frame = NSMakeRect(point.x, point.y, 60, 60)
        
        exportTokenView.imageView.layer?.animateScaleSpring(from: animatedLogoView.frame.height / exportTokenView.imageView.frame.width, to: 1, duration: 0.4, removeOnCompletion: false, bounce: true)
        
        animatedLogoView.layer?.animateScaleX(from: logo.frame.width / animatedLogoView.frame.width, to: 1, duration: 0.4, timingFunction: .spring, removeOnCompletion: false)
        animatedLogoView.layer?.animateScaleY(from: logo.frame.height / animatedLogoView.frame.height, to: 1, duration: 0.4, timingFunction: .spring, removeOnCompletion: false)
        
        self.logo.isHidden = true
        
        
        animatedLogoView.layer?.animatePosition(from: point, to: NSMakePoint(exportTokenView.frame.midX - 30, exportTokenView.frame.minY + exportTokenView.imageView.frame.height / 2 - 26), duration: 0.4, timingFunction: .spring, removeOnCompletion: false, completion: { [weak self] _ in
            self?.exportTokenView?.logoView.isHidden = false
            self?.animatedLogoView.removeFromSuperview()
            self?.logo.isHidden = false
            self?.containerView.isHidden = true
            self?.animatedLogoView.layer?.removeAllAnimations()
        })
    }
    
    fileprivate func updateState(_ state:UnauthorizedAccountStateContents, qrTokenState: QRTokenState?, isLoading: Bool, animated: Bool) {
        
        let prevIsLoading = self.isLoading
        
        self.isLoading = isLoading
        self.state = state
        self.qrTokenState = qrTokenState
        
        
        self.loginView.updateState(self.state, animated: animated)
       
        if let qrTokenState = qrTokenState {
            
            self.logo.change(opacity: 0, animated: animated)
            var firstTime: Bool = false
            if self.exportTokenView == nil {
                self.exportTokenView = ExportTokenView(frame: NSMakeRect(0, 0, 300, 500))
                self.addSubview(self.exportTokenView!)
                self.exportTokenView?.center()
                
                self.exportTokenView?.cancelButton.set(handler: { [weak self] _ in
                    self?.animateAndCancelQr()
                }, for: .Click)
                
                if animated {
                    self.exportTokenView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.35, timingFunction: .spring)
                }
                firstTime = true
            }
            
            guard let exportTokenView = self.exportTokenView else {
                return
            }
            exportTokenView.update(state: qrTokenState)
            
            if firstTime && animated {
                self.animateAndApplyQr()
            } else {
                self.containerView.isHidden = true
            }
            
        } else {
            self.containerView.isHidden = false
            if let exportTokenView = self.exportTokenView {
                if animated {
                    self.exportTokenView = nil
                    exportTokenView.layer?.animateAlpha(from: 1, to: 0, duration: 0.35, timingFunction: .spring, removeOnCompletion: false, completion: { [weak exportTokenView] _ in
                        exportTokenView?.removeFromSuperview()
                    })
                } else {
                    exportTokenView.removeFromSuperview()
                    self.exportTokenView = nil
                }
            }
            self.logo.change(opacity: 1, animated: animated)
        }
        
     
        
        
        backButton.isHidden = true
        switch self.state {
        case .phoneEntry, .empty:
            nextButton.change(opacity: 1, animated: animated)
            textHeaderView.change(opacity: 0, animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, 20), animated: animated)
            intro.change(opacity: 1, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, intro.frame.maxY + 30), animated: animated)
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, floorToScreenPixels(backingScaleFactor, (frame.height - textHeaderView.frame.height)/2)), animated: animated)
            switchLanguage.isHidden = !needShowSuggestedButton
        case .confirmationCodeEntry:
            nextButton.change(opacity: 1, animated: animated)
            let headerLayout = TextViewLayout(.initialize(string: L10n.loginHeaderCode, color: theme.colors.text, font: .normal(25)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            textHeaderView.update(headerLayout)
            textHeaderView.centerX()
            textHeaderView.change(opacity: 1, animated: animated)
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, 30), animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, textHeaderView.frame.maxY + 30), animated: animated)
            switchLanguage.isHidden = true
        case .passwordEntry:
            nextButton.change(opacity: 1, animated: animated)
            let headerLayout = TextViewLayout(.initialize(string: L10n.loginHeaderPassword, color: theme.colors.text, font: .normal(25)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            textHeaderView.update(headerLayout)
            textHeaderView.centerX(y: 30)
            textHeaderView.change(opacity: 1, animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, textHeaderView.frame.maxY + 30), animated: animated)
            switchLanguage.isHidden = true
        case .signUp:
            nextButton.change(opacity: 1, animated: animated)
            let headerLayout = TextViewLayout(.initialize(string: L10n.loginHeaderSignUp, color: theme.colors.text, font: .normal(25)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            textHeaderView.update(headerLayout)
            textHeaderView.centerX()
            textHeaderView.change(opacity: 1, animated: animated)
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, 50), animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, textHeaderView.frame.maxY + 50), animated: animated)
            switchLanguage.isHidden = true
            backButton.isHidden = false
            backButton.setFrameOrigin(loginView.frame.minX, textHeaderView.frame.minY + floorToScreenPixels(backingScaleFactor, (textHeaderView.frame.height - backButton.frame.height) / 2))
        case .passwordRecovery:
            break
        case .awaitingAccountReset:
            let headerLayout = TextViewLayout(.initialize(string: L10n.loginResetAccountText, color: theme.colors.text, font: .normal(25)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            switchLanguage.isHidden = true
            
            textHeaderView.update(headerLayout)
            textHeaderView.centerX()
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, 50), animated: animated)
            textHeaderView.change(opacity: 1, animated: animated)
            
            loginView.change(pos: NSMakePoint(loginView.frame.minX, textHeaderView.frame.maxY + 20), animated: animated)
            
            nextButton.change(opacity: 0, animated: animated)
            backButton.isHidden = false
            backButton.setFrameOrigin(loginView.frame.minX, textHeaderView.frame.minY + floorToScreenPixels(backingScaleFactor, (textHeaderView.frame.height - backButton.frame.height) / 2))
        }
        
        if prevIsLoading != isLoading {
            exportTokenView?.layer?.opacity = isLoading ? 0 : 1
            containerView.layer?.opacity = isLoading ? 0 : 1
            
            if animated {
                if isLoading {
                    if let exportTokenView = self.exportTokenView {
                        exportTokenView.layer?.animateAlpha(from: 1, to: 0, duration: 0.35, timingFunction: .spring)
                        exportTokenView.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.35)
                    } else {
                        containerView.layer?.animateAlpha(from: 1, to: 0, duration: 0.35, timingFunction: .spring)
                        containerView.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.35)
                    }
                } else {
                    if let exportTokenView = self.exportTokenView {
                        exportTokenView.layer?.animateAlpha(from: 0, to: 1, duration: 0.35, timingFunction: .spring)
                        exportTokenView.layer?.animateScaleSpring(from: 0.2, to: 1, duration: 0.35)
                    } else {
                        containerView.layer?.animateAlpha(from: 0, to: 1, duration: 0.35, timingFunction: .spring)
                        containerView.layer?.animateScaleSpring(from: 0.2, to: 1, duration: 0.35)
                    }
                }
            }
            
            if isLoading {
                if self.progressView == nil {
                    let progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
                    self.progressView = progressView
                    
                    progressView.progressColor = theme.colors.text
                    addSubview(progressView)
                }
                
                self.progressView?.center()
                
                if animated {
                    progressView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.35, timingFunction: .spring)
                }
            } else {
                if let progressView = self.progressView {
                    self.progressView = nil
                    if animated {
                        progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.35, timingFunction: .spring, removeOnCompletion: false, completion: { [weak progressView] _ in
                            progressView?.removeFromSuperview()
                        })
                    } else {
                        progressView.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class AuthController : GenericViewController<AuthHeaderView> {
    private let disposable:MetaDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    private let proxyDisposable = DisposableSet()
    private let suggestedLanguageDisposable = MetaDisposable()
    private let localizationDisposable = MetaDisposable()
    private let exportTokenDisposable = MetaDisposable()
    private let tokenEventsDisposable = MetaDisposable()
    private let configurationDisposable = MetaDisposable()
    private var account:UnauthorizedAccount
    private let sharedContext: SharedAccountContext
    #if !APP_STORE
    private let updateController: UpdateTabController
    #endif
    
    private var state: UnauthorizedAccountStateContents = .empty
    private var qrType: QRLoginType = .disabled
    private var qrTokenState: (state: QRTokenState?, animated: Bool) = (state: nil, animated: false) {
        didSet {
            self.genericView.updateState(self.state, qrTokenState: self.qrTokenState.state, isLoading: self.isLoading.value, animated: self.qrTokenState.animated)
        }
    }
    private var isLoading: (value: Bool, update: Bool) = (value: true, update: true) {
        didSet {
            if isLoading.update {
                self.genericView.updateState(self.state, qrTokenState: self.qrTokenState.state, isLoading: isLoading.value, animated: !isFirst)
                isFirst = false
            }
        }
    }
    
    
    
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    
    init(_ account:UnauthorizedAccount, sharedContext: SharedAccountContext, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])) {
        self.account = account
        self.sharedContext = sharedContext
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        #if !APP_STORE
        updateController = UpdateTabController(sharedContext)
        #endif
        super.init()
        
        self.disposable.set(combineLatest(account.postbox.stateView() |> deliverOnMainQueue, appearanceSignal).start(next: { [weak self] view, _ in
            self?.updateState(state: view.state ?? UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty))
        }))
        bar = .init(height: 0)
    }

    var isFirst:Bool = true
    
    func updateState(state: PostboxCoding?) {
        if let state = state as? UnauthorizedAccountState {
            self.state = state.contents
            self.genericView.updateState(self.state, qrTokenState: self.qrTokenState.state, isLoading: self.isLoading.value, animated: !isFirst)
        }
        isFirst = false
        readyOnce()
    }

    
    deinit {
        disposable.dispose()
        actionDisposable.dispose()
        suggestedLanguageDisposable.dispose()
        proxyDisposable.dispose()
        exportTokenDisposable.dispose()
        configurationDisposable.dispose()
    }

    override func returnKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if !self.otherAccountPhoneNumbers.1.isEmpty {
            _ = sharedContext.accountManager.transaction({ transaction in
                transaction.removeAuth()
            }).start()
        }
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.exportTokenView ?? genericView.loginView.firstResponder()
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    private func openProxySettings() {
        
        var pushController:((ViewController)->Void)? = nil
        
        let controller = proxyListController(accountManager: sharedContext.accountManager, network: account.network, showUseCalls: false, pushController: {  controller in
            pushController?(controller)
        })
        let navigation:NavigationViewController = NavigationViewController(controller, mainWindow)
        navigation._frameRect = NSMakeRect(0, 0, 350, 440)
        navigation.readyOnce()
        
        pushController = { [weak navigation] controller in
            navigation?.push(controller)
        }
        
        showModal(with: navigation, for: mainWindow)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if !APP_STORE
            addSubview(updateController.view)
        
            updateController.frame = NSMakeRect(0, frame.height - 60, frame.width, 60)
        #endif
        
        var arguments: LoginAuthViewArguments?
        
        let again:(String)-> Void = { number in
            arguments?.sendCode(number)
        }
        
        
        let sharedContext = self.sharedContext
        var forceHide = true
        
      
        
        var settings:(ProxySettings, ConnectionStatus)? = nil
        
        
        let updateProxyUI:()->Void = { [weak self] in
            if let settings = settings {
                self?.genericView.updateProxyPref(settings.0, settings.1, forceHide)
            }
        }
        
        let openProxySettings:()->Void = { [weak self] in
            self?.openProxySettings()
            forceHide = false
            updateProxyUI()
        }
        
        proxyDisposable.add(combineLatest(proxySettings(accountManager: sharedContext.accountManager) |> deliverOnMainQueue, account.network.connectionStatus |> deliverOnMainQueue).start(next: { pref, connection in
            settings = (pref, connection)
            updateProxyUI()
        }))
        
        
        
        let disposable = MetaDisposable()
        proxyDisposable.add(disposable)
        
        
        let defaultProxyVisibles: [String] = ["RU"]
        
        if defaultProxyVisibles.firstIndex(where: {$0 == Locale.current.regionCode}) != nil {
            forceHide = false
            updateProxyUI()
        }
        

        
        let resetState:()->Void = { [weak self] in
            guard let `self` = self else {return}
            _ = resetAuthorizationState(account: self.account, to: .empty).start()
        }
        
        genericView.proxyButton.set(handler: {  _ in
            if let _ = settings {
                openProxySettings()
            }
        }, for: .Click)
        
        arguments = LoginAuthViewArguments(sendCode: { [weak self] phoneNumber in
            if let strongSelf = self {
                
                if let isQrEnabled = strongSelf.genericView.isQrEnabled, isQrEnabled {
                    strongSelf.refreshQrToken(true)
                } else {
                    let logInNumber = formatPhoneNumber(phoneNumber)
                    for (number, accountId, isTestingEnvironment) in strongSelf.otherAccountPhoneNumbers.1 {
                        if isTestingEnvironment == strongSelf.account.testingEnvironment && formatPhoneNumber(number) == logInNumber {
                            confirm(for: mainWindow, information: L10n.loginPhoneNumberAlreadyAuthorized, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.loginPhoneNumberAlreadyAuthorizedSwitch, successHandler: { result in
                                switch result {
                                case .thrid:
                                    _ = (sharedContext.accountManager.transaction({ transaction in
                                        transaction.removeAuth()
                                    }) |> deliverOnMainQueue).start(completed: {
                                        sharedContext.switchToAccount(id: accountId, action: nil)
                                    })
                                default:
                                    break
                                }
                            })
                            return
                        }
                    }
                    
                    
                    self?.actionDisposable.set((showModalProgress(signal: sendAuthorizationCode(accountManager: sharedContext.accountManager, account: strongSelf.account, phoneNumber: phoneNumber, apiId: ApiEnvironment.apiId, apiHash: ApiEnvironment.apiHash, syncContacts: false)
                        |> map {Optional($0)}
                        |> mapError {Optional($0)}
                        |> timeout(20, queue: Queue.mainQueue(), alternate: .fail(nil))
                        |> deliverOnMainQueue, for: mainWindow)
                        |> filter({$0 != nil}) |> map {$0!} |> deliverOnMainQueue).start(next: { [weak strongSelf] account in
                            strongSelf?.account = account
                            }, error: { [weak self] error in
                                if let error = error {
                                    self?.genericView.loginView.updatePhoneError(error)
                                } else {
                                    confirm(for: mainWindow, header: L10n.loginConnectionErrorHeader, information: L10n.loginConnectionErrorInfo, okTitle: L10n.loginConnectionErrorTryAgain, thridTitle: L10n.loginConnectionErrorUseProxy, successHandler: { result in
                                        switch result {
                                        case .basic:
                                            again(phoneNumber)
                                        case .thrid:
                                            openProxySettings()
                                        }
                                    })
                                }
                        }))
                    _ = markSuggestedLocalizationAsSeenInteractively(postbox: strongSelf.account.postbox, languageCode: Locale.current.languageCode ?? "en").start()
                }
            }
        },resendCode: { [weak self] in
            if let strongSelf = self {
                _ = resendAuthorizationCode(account: strongSelf.account).start()
            }
        }, editPhone: {
            resetState()
        }, checkCode: { [weak self] code in
            if let strongSelf = self {
                _ = (authorizeWithCode(accountManager: sharedContext.accountManager, account: strongSelf.account, code: code, termsOfService: nil) |> deliverOnMainQueue ).start(next: { [weak strongSelf] value in
                    if let strongSelf = strongSelf {
                        switch value {
                        case let .signUp(data):
                            _ = beginSignUp(account: strongSelf.account, data: data).start()
                        default:
                            break
                        }
                    }
                }, error: { [weak self] error in
                    self?.genericView.loginView.updateCodeError(error)
                })
            }
            
        }, checkPassword: { [weak self] password in
            if let strongSelf = self {
                _ = (authorizeWithPassword(accountManager: sharedContext.accountManager, account: strongSelf.account, password: password, syncContacts: false)
                    |> map { () -> AuthorizationPasswordVerificationError? in
                        return nil
                    }
                    |> `catch` { error -> Signal<AuthorizationPasswordVerificationError?, AuthorizationPasswordVerificationError> in
                        return .single(error)
                    }
                |> mapError {_ in} |> deliverOnMainQueue).start(next: { [weak self] error in
                    if let error = error {
                        self?.genericView.loginView.updatePasswordError(error)
                    }
                })
            }
        
        }, requestPasswordRecovery: { [weak self] f in
            guard let `self` = self else {return}
            _ = showModalProgress(signal: requestPasswordRecovery(account: self.account) |> deliverOnMainQueue, for: mainWindow).start(next: { [weak self] option in
                guard let `self` = self else {return}
                f(option)
                switch option {
                case let .email(pattern):
                    showModal(with: ForgotUnauthorizedPasswordController(accountManager: sharedContext.accountManager, account: self.account, emailPattern: pattern), for: mainWindow)
                default:
                    break
                }
            }, error: { error in
                var bp:Int = 0
                bp += 1
            })
        }, resetAccount: { [weak self] in
            guard let `self` = self else {return}
            confirm(for: mainWindow, information: L10n.loginResetAccountDescription, okTitle: L10n.loginResetAccount, successHandler: { _ in
                _ = showModalProgress(signal: performAccountReset(account: self.account) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                    alert(for: mainWindow, info: L10n.unknownError)
                })
            })
        }, signUp: { [weak self] firstName, lastName, photo in
            guard let `self` = self else {return}
            _ = showModalProgress(signal: signUpWithName(accountManager: sharedContext.accountManager, account: self.account, firstName: firstName, lastName: lastName, avatarData: photo != nil ? try? Data(contentsOf: photo!) : nil) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                let text: String
                switch error {
                case .limitExceeded:
                    text = L10n.loginFloodWait
                case .codeExpired:
                    text = L10n.phoneCodeExpired
                case .invalidFirstName:
                    text = L10n.loginInvalidFirstNameError
                case .invalidLastName:
                    text = L10n.loginInvalidLastNameError
                case .generic:
                    text = L10n.unknownError
                }
                alert(for: mainWindow, info: text)
            })
        }, cancelQrAuth: { [weak self] in
            self?.cancelQrToken()
        }, updatePhoneNumberField: { [weak self] updated in
            if self?.qrType != .disabled {
                self?.genericView.nextButtonAsForQr(updated.isEmpty)
            }
        })
        
        //
        genericView.loginView.arguments = arguments
        genericView.arguments = arguments

        genericView.backButton.set(handler: { _ in
           resetState()
        }, for: .Click)
        
        
        genericView.cancelButton.isHidden = otherAccountPhoneNumbers.1.isEmpty
        
        genericView.cancelButton.set(handler: { _ in
            _ = sharedContext.accountManager.transaction({ transaction in
                transaction.removeAuth()
            }).start()
        }, for: .Click)
        
        if otherAccountPhoneNumbers.1.isEmpty {
            suggestedLanguageDisposable.set((currentlySuggestedLocalization(network: account.network, extractKeys: ["Login.ContinueOnLanguage"]) |> deliverOnMainQueue).start(next: { [weak self] info in
                if let strongSelf = self, let info = info, info.languageCode != appCurrentLanguage.baseLanguageCode {
                    
                    strongSelf.genericView.showLanguageButton(title: info.localizedKey("Login.ContinueOnLanguage"), callback: { [weak strongSelf] in
                        if let strongSelf = strongSelf {
                            strongSelf.genericView.hideSwitchButton()
                            _ = showModalProgress(signal: downloadAndApplyLocalization(accountManager: sharedContext.accountManager, postbox: strongSelf.account.postbox, network: strongSelf.account.network, languageCode: info.languageCode), for: mainWindow).start()
                        }
                    })
                }
            }))
        }
        
       
        localizationDisposable.set(appearanceSignal.start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme(theme: theme)
        }))
        
        self.tokenEventsDisposable.set((self.account.updateLoginTokenEvents |> deliverOnMainQueue).start(next: { [weak self]  _ in
            self?.refreshQrToken()
        }))
       

        configurationDisposable.set((unauthorizedConfiguration(accountManager: self.sharedContext.accountManager) |> take(1) |> castError(Void.self) |> timeout(25.0, queue: .mainQueue(), alternate: .fail(Void())) |> deliverOnMainQueue).start(next: { [weak self] value in
            
            self?.qrType = value.qr
            self?.genericView.isQrEnabled = value.qr != .disabled
            switch value.qr {
            case .disabled:
                self?.isLoading = (value: false, update: true)
            case .secondary:
                self?.isLoading = (value: false, update: true)
            case .primary:
                self?.refreshQrToken()
            }
            
        }, error: { [weak self] in
            self?.qrType = .disabled
            self?.isLoading = (value: false, update: true)
            forceHide = false
            updateProxyUI()
        }))
        
        
    }
    
    private func cancelQrToken() {
        self.exportTokenDisposable.set(nil)
        self.tokenEventsDisposable.set(nil)
        self.qrTokenState = (state: nil, animated: true)
    }
    
    private func refreshQrToken(_ showProgress: Bool = false) {
        
        let sharedContext = self.sharedContext
        let account = self.account
        
        var tokenSignal: Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> = sharedContext.activeAccounts |> castError(ExportAuthTransferTokenError.self) |> take(1) |> mapToSignal { accounts in
            return exportAuthTransferToken(accountManager: sharedContext.accountManager, account: account, otherAccountUserIds: accounts.accounts.map { $0.1.peerId.id }, syncContacts: false)
        }
        
        if showProgress {
            tokenSignal = showModalProgress(signal: tokenSignal |> take(1), for: mainWindow)
        }
        
        self.exportTokenDisposable.set((tokenSignal
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                switch result {
                case let .displayToken(token):
                    var tokenString = token.value.base64EncodedString()
                    tokenString = tokenString.replacingOccurrences(of: "+", with: "-")
                    tokenString = tokenString.replacingOccurrences(of: "/", with: "_")
                    let urlString = "tg://login?token=\(tokenString)"
                    let _ = (qrCode(string: urlString, color: theme.colors.text, backgroundColor: theme.colors.background, icon: .custom(theme.icons.login_qr_empty_cap))
                        |> deliverOnMainQueue).start(next: { _, generate in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let context = generate(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: 280, height: 280), boundingSize: CGSize(width: 280, height: 280), intrinsicInsets: NSEdgeInsets(), scale: 2.0))
                            if let image = context?.generateImage() {
                                strongSelf.qrTokenState = (state: .qr(image), animated: !strongSelf.isLoading.value)
                                strongSelf.isLoading = (value: false, update: true)
                            }
                        })
                    
                    let timestamp = Int32(Date().timeIntervalSince1970)
                    let timeout = max(5, token.validUntil - timestamp)
                    strongSelf.exportTokenDisposable.set((Signal<Never, NoError>.complete()
                        |> delay(Double(timeout), queue: .mainQueue())).start(completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.refreshQrToken()
                        }))
                case .passwordRequested:
                    strongSelf.genericView.isQrEnabled = false
                    strongSelf.exportTokenDisposable.set(nil)
                    strongSelf.tokenEventsDisposable.set(nil)
                    strongSelf.qrTokenState = (state: nil, animated: true)
                case let .changeAccountAndRetry(account):
                    strongSelf.exportTokenDisposable.set(nil)
                    strongSelf.account = account
                    strongSelf.tokenEventsDisposable.set((account.updateLoginTokenEvents
                        |> deliverOnMainQueue).start(next: { _ in
                            self?.refreshQrToken()
                        }))
                    strongSelf.refreshQrToken()
                    strongSelf.qrTokenState = (state: nil, animated: true)
                case .loggedIn:
                    strongSelf.exportTokenDisposable.set(nil)
                    strongSelf.qrTokenState = (state: nil, animated: true)
                }
            }))
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        #if !APP_STORE
        updateController.updateLocalizationAndTheme(theme: theme)
        #endif
    }
    
}
