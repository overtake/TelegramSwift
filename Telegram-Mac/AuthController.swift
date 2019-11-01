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


class AuthHeaderView : View {

    
    private let containerView = View(frame: NSMakeRect(0, 0, 300, 480))
    
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
    fileprivate let backButton = TitleButton()
    fileprivate let cancelButton = TitleButton()

    fileprivate var needShowSuggestedButton: Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        intro.setFrameSize(containerView.frame.size)
        
        let logoImage = #imageLiteral(resourceName: "Icon_LegacyIntro").precomposed()
        self.logo.image = logoImage
        self.logo.sizeToFit()
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

        
        updateState(state, animated: false)
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        switchLanguage.set(color: theme.colors.accent, for: .Normal)
        
        let headerLayout = TextViewLayout(.initialize(string: appName, color: theme.colors.text, font: NSFont.normal(30.0)), maximumNumberOfLines: 1)
        headerLayout.measure(width: .greatestFiniteMagnitude)
        header.update(headerLayout)
        
        header.backgroundColor = theme.colors.background
        desc.backgroundColor = theme.colors.background
        textHeaderView.backgroundColor = theme.colors.background
        
        let descLayout = TextViewLayout(.initialize(string: tr(L10n.loginWelcomeDescription), color: theme.colors.grayText, font: .normal(16.0)), maximumNumberOfLines: 2, alignment: .center)
        descLayout.measure(width: 300)
        desc.update(descLayout)
        
        nextButton.set(text: L10n.loginNext, for: .Normal)
        nextButton.style = ControlStyle(font: .medium(15.0), foregroundColor: .white, backgroundColor: theme.colors.accent)
        proxyConnecting.progressColor = theme.colors.accentIcon
//        proxyConnecting.lineWidth = 1.0
        
        
        backButton.set(font: .medium(.header), for: .Normal)
        backButton.set(color: theme.colors.accent, for: .Normal)
        backButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        backButton.set(text: L10n.navigationBack, for: .Normal)
        _ = backButton.sizeToFit()
        
        cancelButton.set(font: .medium(.header), for: .Normal)
        cancelButton.set(color: theme.colors.accent, for: .Normal)
        cancelButton.set(text: L10n.navigationCancel, for: .Normal)
        _ = cancelButton.sizeToFit()
        
        
        
        updateState(self.state, animated: false)
        needsLayout = true
        
    }
    
    fileprivate func updateState(_ state:UnauthorizedAccountStateContents, animated: Bool) {
        
        
        self.state = state
        
        self.loginView.updateState(self.state, animated: animated)
       
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
    private let sharedContext: SharedAccountContext
    #if !APP_STORE
    private let updateController: UpdateTabController
    #endif
    
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
            self.genericView.updateState(state.contents, animated: !isFirst)
        }
        isFirst = false
        readyOnce()
    }

    
    deinit {
        disposable.dispose()
        actionDisposable.dispose()
        suggestedLanguageDisposable.dispose()
        proxyDisposable.dispose()
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
        return genericView.loginView.firstResponder()
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
        navigation._frameRect = NSMakeRect(0, 0, 300, 440)
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
        
        if defaultProxyVisibles.index(where: {$0 == Locale.current.regionCode}) != nil {
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

                
                self?.actionDisposable.set((showModalProgress(signal: sendAuthorizationCode(accountManager: sharedContext.accountManager, account: strongSelf.account, phoneNumber: phoneNumber, apiId: API_ID, apiHash: API_HASH, syncContacts: false)
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
        
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        #if !APP_STORE
        updateController.updateLocalizationAndTheme(theme: theme)
        #endif
    }
    
}
