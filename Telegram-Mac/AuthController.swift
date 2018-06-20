import Foundation
import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac
import TGUIKit

private let manager = CountryManager()

enum LoginAuthViewState {
    case phoneNumber
    case password
    case code
}


class AuthHeaderView : View {
    
    fileprivate let proxyButton:ImageButton = ImageButton()
    private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 12, 12))

    
    fileprivate var arguments:LoginAuthViewArguments?
    fileprivate let loginView:LoginAuthInfoView = LoginAuthInfoView(frame: NSZeroRect)
    fileprivate var state: UnauthorizedAccountStateContents = .empty
    private let logo:ImageView = ImageView()
    private let header:TextView = TextView()
    private let desc:TextView = TextView()
    private let textHeaderView:TextView = TextView()
    let intro:View = View()
    private let switchLanguage:TitleButton = TitleButton()
    fileprivate let nextButton:TitleButton = TitleButton()
    fileprivate var needShowSuggestedButton: Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        intro.setFrameSize(frameRect.size)
        addSubview(intro)
        

        
        let logoImage = #imageLiteral(resourceName: "Icon_LegacyIntro").precomposed()
        self.logo.image = logoImage
        self.logo.sizeToFit()
       
        updateLocalizationAndTheme()

        intro.addSubview(logo)
        intro.addSubview(header)
        intro.addSubview(desc)
        
        addSubview(loginView)

        
        addSubview(textHeaderView)
        textHeaderView.userInteractionEnabled = false
        textHeaderView.isSelected = false
        
        nextButton.autohighlight = false
        nextButton.style = ControlStyle(font: NSFont.medium(16.0), foregroundColor: .white, backgroundColor: NSColor(0x32A3E2), highlightColor: .white)
        nextButton.set(text: tr(L10n.loginNext), for: .Normal)
        _ = nextButton.sizeToFit(thatFit: true)
        nextButton.setFrameSize(76, 36)
        nextButton.layer?.cornerRadius = 18
        
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
                default:
                    break
                }
            }
        }, for: .Click)
        
        addSubview(nextButton)
        addSubview(switchLanguage)
        switchLanguage.isHidden = true
        
        switchLanguage.disableActions()
        switchLanguage.set(font: .medium(.title), for: .Normal)
        switchLanguage.set(color: .blueUI, for: .Normal)
        switchLanguage.set(text: "Continue on English", for: .Normal)
        _ = switchLanguage.sizeToFit()
        
        addSubview(proxyButton)
        proxyButton.addSubview(proxyConnecting)
        
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
        switchLanguage.centerX(y: frame.height - switchLanguage.frame.height - 35)
        header.centerX(y: logo.frame.maxY + 10)
        desc.centerX(y: header.frame.maxY + 10)
        logo.centerX()
        intro.centerX(y: 60)
        intro.setFrameSize(frame.width, desc.frame.maxY)
        loginView.setFrameSize(400, frame.height)
        loginView.centerX(y: intro.frame.maxY + 60)
        nextButton.centerX(y: frame.height - nextButton.frame.height - 80)
        updateState(state, animated: false)
        
        proxyConnecting.centerX()
        proxyConnecting.centerY(addition: -1)
        proxyButton.setFrameOrigin(10, 10)

    }
    
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        let headerLayout = TextViewLayout(NSAttributedString.initialize(string: appName, color: NSColor.text, font: NSFont.normal(30.0)), maximumNumberOfLines: 1)
        headerLayout.measure(width: CGFloat.greatestFiniteMagnitude)
        header.update(headerLayout)
        
        
        let descLayout = TextViewLayout(NSAttributedString.initialize(string: tr(L10n.loginWelcomeDescription), color: .grayText, font: .normal(16.0)), maximumNumberOfLines: 1)
        descLayout.measure(width: CGFloat.greatestFiniteMagnitude)
        desc.update(descLayout)
        
        nextButton.set(text: tr(L10n.loginNext), for: .Normal)
        proxyConnecting.progressColor = theme.colors.blueIcon
        proxyConnecting.lineWidth = 1.0
        needsLayout = true
    }
    
    fileprivate func updateState(_ state:UnauthorizedAccountStateContents, animated: Bool) {
        
        
        self.state = state
        
        self.loginView.updateState(self.state, animated: animated)
        
        switch self.state {
        case .phoneEntry, .empty:
            nextButton.change(opacity: 1, animated: animated)
            textHeaderView.change(opacity: 0, animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, 50), animated: animated)
            intro.change(opacity: 1, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, intro.frame.maxY + 50), animated: animated)
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.height - textHeaderView.frame.height)/2)), animated: animated)
            switchLanguage.isHidden = !needShowSuggestedButton
        case .confirmationCodeEntry:
            nextButton.change(opacity: 1, animated: animated)
            let headerLayout = TextViewLayout(.initialize(string: tr(L10n.loginHeaderCode), color: .text, font: .normal(30.0)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            textHeaderView.update(headerLayout)
            textHeaderView.centerX()
            textHeaderView.change(opacity: 1, animated: animated)
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, 90), animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, 160), animated: animated)
            switchLanguage.isHidden = true
            break
        case .passwordEntry:
            nextButton.change(opacity: 1, animated: animated)
            let headerLayout = TextViewLayout(.initialize(string: tr(L10n.loginHeaderPassword), color: .text, font: .normal(30.0)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            textHeaderView.update(headerLayout)
            textHeaderView.centerX(y: 90)
            textHeaderView.change(opacity: 1, animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, 160), animated: animated)
            switchLanguage.isHidden = true
            break
        case .signUp:
            nextButton.change(opacity: 0, animated: animated)
            let headerLayout = TextViewLayout(.initialize(string: tr(L10n.loginHeaderSignUp), color: .text, font: .normal(30.0)))
            headerLayout.measure(width: .greatestFiniteMagnitude)
            textHeaderView.update(headerLayout)
            textHeaderView.centerX()
            textHeaderView.change(opacity: 1, animated: animated)
            textHeaderView.change(pos: NSMakePoint(textHeaderView.frame.minX, 90), animated: animated)
            intro.change(pos: NSMakePoint(intro.frame.minX, -intro.frame.height), animated: animated)
            intro.change(opacity: 0, animated: animated)
            loginView.change(pos: NSMakePoint(loginView.frame.minX, 160), animated: animated)
            switchLanguage.isHidden = true
        case .passwordRecovery(let hint, let number, let code, let emailPattern):
            break
        case .awaitingAccountReset(let protectedUntil, let number):
            break
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
    private var account:UnauthorizedAccount
    init(_ account:UnauthorizedAccount) {
        self.account = account
        super.init()
        
        self.disposable.set((account.postbox.stateView() |> deliverOnMainQueue).start(next: { [weak self] view in
            self?.updateState(state: view.state ?? UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .empty))
        }))
        bar = .init(height: 0)
    }

    var isFirst:Bool = true
    
    func updateState(state: PostboxCoding?) {
        if let state = state as? UnauthorizedAccountState {
            self.genericView.updateState(state.contents, animated: !isFirst)
        }
        isFirst = false
    }

    
    deinit {
        disposable.dispose()
        actionDisposable.dispose()
        suggestedLanguageDisposable.dispose()
        proxyDisposable.dispose()
    }

    
    override func firstResponder() -> NSResponder? {
        return genericView.loginView.firstResponder()
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    private func openProxySettings() {

        
        var navigation:NavigationViewController?
        
        var first: Bool = true
        
        proxyListController(postbox: account.postbox, network: account.network, showUseCalls: false) ({ controller in
            if first {
                navigation = NavigationViewController(controller)
                navigation!._frameRect = NSMakeRect(0, 0, 300, 440)
                navigation!.readyOnce()
                showModal(with: navigation!, for: mainWindow)
                first = false
            } else {
                navigation?.push(controller)
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var arguments: LoginAuthViewArguments?
        
        let again:(String)-> Void = { number in
            arguments?.sendCode(number)
        }
        
        
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
        
        proxyDisposable.add(combineLatest(proxySettingsSignal(account.postbox) |> deliverOnMainQueue, account.network.connectionStatus |> deliverOnMainQueue).start(next: { pref, connection in
            settings = (pref, connection)
            updateProxyUI()
        }))
        
        
        
        let disposable = MetaDisposable()
        proxyDisposable.add(disposable)
        
        
        let defaultProxyVisibles: [String] = ["RU"]
        
        if defaultProxyVisibles.index(where: {$0 == Locale.current.regionCode}) != nil {
            forceHide = false
            updateProxyUI()
        }
        
//        let countryDisposable = (getCountryCode(network: account.network) |> deliverOnMainQueue).start(next: { [weak self] country in
//            self?.genericView.loginView.updateCountryCode(country)
//        })
//        proxyDisposable.add(countryDisposable)
        
        
        genericView.proxyButton.set(handler: {  _ in
            if let _ = settings {
                openProxySettings()
            }
        }, for: .Click)
        
        arguments = LoginAuthViewArguments(sendCode: { [weak self] phoneNumber in
            if let strongSelf = self {
                self?.actionDisposable.set((showModalProgress(signal: sendAuthorizationCode(account: strongSelf.account, phoneNumber: phoneNumber, apiId: API_ID, apiHash: API_HASH)
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
        },resendCode: { [weak self] in
            if let strongSelf = self {
                _ = resendAuthorizationCode(account: strongSelf.account).start()
            }
        }, editPhone: { [weak self] in
            if let strongSelf = self {
                _ = resetAuthorizationState(account: strongSelf.account, to: .empty).start()
            }
        }, checkCode: { [weak self] code in
            if let strongSelf = self {
                _ = (authorizeWithCode(account: strongSelf.account, code: code) |> deliverOnMainQueue ).start(error: { [weak self] error in
                    self?.genericView.loginView.updateCodeError(error)
                })
            }
            
        }, checkPassword: { [weak self] password in
            if let strongSelf = self {
                _ = (authorizeWithPassword(account: strongSelf.account, password: password)
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
        
        })
        
        //
        genericView.loginView.arguments = arguments
        genericView.arguments = arguments

        
        
        suggestedLanguageDisposable.set((currentlySuggestedLocalization(network: account.network, extractKeys: ["Login.ContinueOnLanguage"]) |> deliverOnMainQueue).start(next: { [weak self] info in
            if let strongSelf = self, let info = info, info.languageCode != appCurrentLanguage.languageCode {
                
                strongSelf.genericView.showLanguageButton(title: info.localizedKey("Login.ContinueOnLanguage"), callback: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        strongSelf.genericView.hideSwitchButton()
                        _ = showModalProgress(signal: downoadAndApplyLocalization(postbox: strongSelf.account.postbox, network: strongSelf.account.network, languageCode: info.languageCode), for: mainWindow).start()
                    }
                })
            }
        }))
        
        localizationDisposable.set(appearanceSignal.start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme()
        }))
        
    }
    
    
}
