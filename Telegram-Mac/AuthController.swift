import Foundation
import Cocoa
import SwiftSignalKit
import TelegramCore
import Localization
import Postbox
import TGUIKit
import ApiCredentials
import InAppSettings

enum LoginAuthViewState {
    case phoneNumber
    case password
    case code
}


private let languageKey: String = "Login.ContinueOnLanguage"

extension AuthTransferExportedToken : Equatable {
    public static func == (lhs: AuthTransferExportedToken, rhs: AuthTransferExportedToken) -> Bool {
        return lhs.value == rhs.value && lhs.validUntil == rhs.validUntil
    }
}
extension AuthorizationCodeRequestError : Equatable {
    public static func == (lhs: AuthorizationCodeRequestError, rhs: AuthorizationCodeRequestError) -> Bool {
        switch lhs {
        case .invalidPhoneNumber:
            if case .invalidPhoneNumber = rhs {
                return true
            }
        case .limitExceeded:
            if case .limitExceeded = rhs {
                return true
            }
        case let .generic(lhsInfo):
            if case let .generic(rhsInfo) = rhs {
                return lhsInfo?.0 == rhsInfo?.0 && lhsInfo?.1 == rhsInfo?.1
            }
        case .phoneLimitExceeded:
            if case .phoneLimitExceeded = rhs {
                return true
            }
        case .phoneBanned:
            if case .phoneBanned = rhs {
                return true
            }
        case .timeout:
            if case .timeout = rhs {
                return true
            }
        }
        return false
    }
    
    
}

extension ExportAuthTransferTokenResult : Equatable {
    public static func == (lhs: ExportAuthTransferTokenResult, rhs: ExportAuthTransferTokenResult) -> Bool {
        switch lhs {
        case .changeAccountAndRetry:
            switch rhs {
            case .changeAccountAndRetry:
                return true
            default:
                return false
            }
        case let .displayToken(token):
            switch rhs {
            case .displayToken(token):
                return true
            default:
                return false
            }
        case .loggedIn:
            switch rhs {
            case .loggedIn:
                return true
            default:
                return false
            }
        case .passwordRequested:
            switch rhs {
            case .passwordRequested:
                return true
            default:
                return false
            }
        }
    }
}

final class AuthView : Control {
    private var continueOn: TitleButton?
    fileprivate let back = TitleButton()
    
    fileprivate let proxyButton:ImageButton = ImageButton()
    private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 12, 12))


    
    fileprivate var updateView: NSView? {
        didSet {
            if let updateView = updateView {
                addSubview(updateView)
            }
            needsLayout = true
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(back)
        addSubview(proxyButton)
        proxyButton.addSubview(proxyConnecting)

        proxyButton.scaleOnClick = true

        back.autohighlight = false
        back.scaleOnClick = true
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        back.set(image: theme.icons.chatNavigationBack, for: .Normal)
        back.set(font: .medium(.header), for: .Normal)
        back.set(color: theme.colors.accent, for: .Normal)
        back.set(text: strings().navigationBack, for: .Normal)
        back.sizeToFit(NSMakeSize(10, 10), NSMakeSize(0, 24), thatFit: true)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addView(_ view: NSView) {
        self.addSubview(view, positioned: .below, relativeTo: self.back)
    }
    
    func hideLanguage() {
        if let view = continueOn {
            performSubviewRemoval(view, animated: true)
            self.continueOn = nil
        }
    }
    
    func showLanguage(title: String, callback: @escaping()->Void) {
        let current: TitleButton
        if let view = self.continueOn {
            current = view
        } else {
            current = TitleButton()
            self.continueOn = current
            self.addSubview(current, positioned: .below, relativeTo: back)
            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }
        current.set(font: .normal(.text), for: .Normal)
        current.set(color: theme.colors.accent, for: .Normal)
        current.set(text: title, for: .Normal)
        current.sizeToFit()
        current.removeAllHandlers()
        current.set(handler: { [weak self] control in
            callback()
            performSubviewRemoval(control, animated: true)
            self?.continueOn = nil
        }, for: .Click)
        
        needsLayout = true
    }
    
    func updateBack(_ isHidden: Bool, animated: Bool) {
        self.back.change(opacity: isHidden ? 0 : 1, animated: animated)
    }
    
    fileprivate func updateProxy(_ pref: ProxySettings, _ connection: ConnectionStatus, _ isForceHidden: Bool = true) {
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


    
    override func layout() {
        super.layout()
        for subview in subviews {
            if subview != continueOn, subview != updateView, subview != back, subview != proxyButton {
                subview.setFrameSize(NSMakeSize(subview.frame.width, frame.height))
                subview.center()
            }
        }
        if let view = continueOn {
            view.centerX(y: frame.height - view.frame.height - 15)
        }
        if let updateView = updateView {
            updateView.frame = NSMakeRect(0, frame.height - 40, frame.width, 40)
        }
        back.setFrameOrigin(NSMakePoint(10, 10))
        proxyButton.setFrameOrigin(NSMakePoint(frame.width - proxyButton.frame.width - 10, 10))
    }
}


class AuthController : GenericViewController<AuthView> {
    
    private let disposable:MetaDisposable = MetaDisposable()
    private let tokenEventsDisposable = MetaDisposable()
    private let tokenDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let exportTokenDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    private let localizationDisposable = MetaDisposable()
    private let suggestedLanguageDisposable = MetaDisposable()
    private let proxyDisposable = MetaDisposable()
    private let delayDisposable = MetaDisposable()
    
    
    private let stateView: Promise<PostboxStateView> = Promise()
    private var account:UnauthorizedAccount {
        didSet {
            stateView.set(account.postbox.stateView())
        }
    }
    private var stateViewValue: Signal<PostboxStateView, NoError> {
        return stateView.get()
    }
    private let sharedContext: SharedAccountContext
    private var engine: TelegramEngineUnauthorized {
        return .init(account: self.account)
    }
   
    struct State : Equatable {
        var state: UnauthorizedAccountStateContents?
        var tokenResult: ExportAuthTransferTokenResult?
        var tokenAvailable: Bool
        var configuration: UnauthorizedConfiguration = .defaultValue
        var qrEnabled: Bool
        var error: AuthorizationCodeRequestError?
        var codeError: AuthorizationCodeVerificationError?
        var passwordError: AuthorizationPasswordVerificationError?
        var emailError: PasswordRecoveryError?
        var signError: SignUpError?
        var locked: Bool = false
        var countries:[Country] = []
    }
        
    
    #if !APP_STORE
    private let updateController: UpdateTabController
    #endif
    
    private var current: ViewController?
    
    private let loading_c: Auth_Loading
    private let token_c: Auth_TokenController
    private let phone_number_c: Auth_PhoneNumberController
    private let code_entry_c: Auth_CodeEntryController
    private let password_entry_c: Auth_PasswordEntryController
    private let email_recovery_c: Auth_EmailController
    private let awaiting_reset_c: Auth_AwaitingResetController
    private let signup_c: Auth_SignupController
    
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    
    init(_ account:UnauthorizedAccount, sharedContext: SharedAccountContext, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])) {
        self.account = account
        self.sharedContext = sharedContext
        self.stateView.set(account.postbox.stateView())

        self.token_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.loading_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.phone_number_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.code_entry_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.password_entry_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.email_recovery_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.awaiting_reset_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        self.signup_c = .init(frame: NSMakeRect(0, 0, 380, 300))
        
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        #if !APP_STORE
        updateController = UpdateTabController(sharedContext)
        #endif
        super.init()
        bar = .init(height: 0)
    }
    
    

    deinit {
        disposable.dispose()
        tokenEventsDisposable.dispose()
        tokenDisposable.dispose()
        stateDisposable.dispose()
        exportTokenDisposable.dispose()
        actionDisposable.dispose()
        localizationDisposable.dispose()
        suggestedLanguageDisposable.dispose()
        proxyDisposable.dispose()
        delayDisposable.dispose()
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
        return self.current?.firstResponder()
    }

    override var canBecomeResponder: Bool {
        return true
    }
    
    private func cancelOrBack(_ state: State, updateState:@escaping((State) -> State) -> Void) {
        guard let controller = self.current else {
            return
        }
        let index = self.index(of: controller)
        
        let discard:()->Void = { [weak self] in
            guard let window = self?.window, let account = self?.account else {
                return
            }
            confirm(for: window, header: appName, information: strings().loginNewCancelConfirm, okTitle: strings().alertYes, cancelTitle: strings().alertNO, successHandler: { _ in
                
                updateState { current in
                    var current = current
                    current.state = .empty
                    current.tokenAvailable = false
                    current.tokenResult = nil
                    current.qrEnabled = false
                    current.error = nil
                    current.signError = nil
                    current.emailError = nil
                    current.passwordError = nil
                    return current
                }
                
                _ = resetAuthorizationState(account: account, to: .empty).start()
            })
        }
        
        if self.otherAccountPhoneNumbers.1.isEmpty {
            discard()
        } else {
            if index <= 2 {
                _ = sharedContext.accountManager.transaction({ transaction in
                    transaction.removeAuth()
                }).start()
            } else {
                discard()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if !APP_STORE
        genericView.updateView = updateController.view
        #endif
        
        let sharedContext = self.sharedContext
                        
        let initialState = State(state: nil, tokenResult: nil, tokenAvailable: true, configuration: .defaultValue, qrEnabled: true)
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        self.genericView.back.set(handler: { [weak self] _ in
            self?.cancelOrBack(stateValue.with { $0 }, updateState: updateState)
        }, for: .Click)
        
        let refreshToken:()->Void = { [weak self] in
            guard let engine = self?.engine else {
                return
            }
            
            let available = stateValue.with { $0.tokenAvailable }
            if available {
                let tokenSignal: Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> = sharedContext.activeAccounts |> castError(ExportAuthTransferTokenError.self) |> take(1) |> mapToSignal { accounts in
                    return engine.auth.exportAuthTransferToken(accountManager: sharedContext.accountManager, otherAccountUserIds: accounts.accounts.map { $0.1.peerId.id }, syncContacts: false)
                }
                
                self?.tokenDisposable.set(tokenSignal.start(next: { result in
                    updateState { current in
                        var current = current
                        current.tokenResult = result
                        return current
                    }
                }, error: { error in
                    updateState { current in
                        var current = current
                        current.tokenResult = nil
                        return current
                    }
                }))
            }
            
        }
        
        self.tokenEventsDisposable.set((self.account.updateLoginTokenEvents |> deliverOnMainQueue).start(next: { _ in
            refreshToken()
        }))
        
        
        let engine = self.engine
        let getCountries = appearanceSignal |> mapToSignal { appearance in
            engine.localization.getCountriesList(accountManager: sharedContext.accountManager, langCode: appearance.language.baseLanguageCode)
        }
        
        let signal = combineLatest(queue: .mainQueue(), stateViewValue, unauthorizedConfiguration(accountManager: sharedContext.accountManager) |> take(1), getCountries)
        let account = self.account

        
        self.disposable.set(signal.start(next: { view, configuration, countries in
            let value = view.state as? UnauthorizedAccountState ?? UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)
            updateState { current in
                var current = current
                current.state = value.contents
                current.configuration = configuration
                current.qrEnabled = configuration.qr != .disabled
                current.countries = countries
                return current
            }
        }))
        
        self.stateDisposable.set((statePromise.get() |> filter { $0.state != nil } |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.updateState(state, refreshToken: refreshToken, updateState: updateState)
        }))
        
        if otherAccountPhoneNumbers.1.isEmpty {
            suggestedLanguageDisposable.set((engine.localization.currentlySuggestedLocalization(extractKeys: [languageKey]) |> deliverOnMainQueue).start(next: { [weak self] info in
                
                guard let window = self?.window, let engine = self?.engine else {
                    return
                }
                
                if let info = info, info.languageCode != appCurrentLanguage.baseLanguageCode {
                    self?.genericView.showLanguage(title: info.localizedKey(languageKey), callback: {
                        _ = showModalProgress(signal: engine.localization.downloadAndApplyLocalization(accountManager: sharedContext.accountManager, languageCode: info.languageCode), for: window).start()
                    })
                }
            }))
        }
        
       
        localizationDisposable.set(appearanceSignal.start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme(theme: theme)
        }))

        var forceHide = true
        var settings:(ProxySettings, ConnectionStatus)? = nil

        let updateProxy:()->Void = { [weak self] in
            if let settings = settings {
                self?.genericView.updateProxy(settings.0, settings.1, forceHide)
            }
        }
        
        let openProxySettings:()->Void = { [weak self] in
            self?.openProxy()
            forceHide = false
            updateProxy()
        }
        
        proxyDisposable.set(combineLatest(proxySettings(accountManager: sharedContext.accountManager) |> deliverOnMainQueue, account.network.connectionStatus |> deliverOnMainQueue).start(next: { pref, connection in
            settings = (pref, connection)
            updateProxy()
        }))
        
        let delaySignal = unauthorizedConfiguration(accountManager: self.sharedContext.accountManager) |> take(1) |> castError(Void.self) |> timeout(25.0, queue: .mainQueue(), alternate: .fail(Void())) |> deliverOnMainQueue
        
        delayDisposable.set(delaySignal.start(error: {
            forceHide = false
            updateProxy()
        }))

        genericView.proxyButton.set(handler: {  _ in
            if let _ = settings {
                openProxySettings()
            }
        }, for: .Click)
        
        readyOnce()

    }
    
    private func openProxy() {
        
        guard let window = self.window else {
            return
        }
        
        var pushController:((ViewController)->Void)? = nil
           
           let controller = proxyListController(accountManager: sharedContext.accountManager, network: account.network, showUseCalls: false, pushController: {  controller in
               pushController?(controller)
           })
           let navigation:NavigationViewController = NavigationViewController(controller, window)
           navigation._frameRect = NSMakeRect(0, 0, 350, 440)
           navigation.readyOnce()
           
           pushController = { [weak navigation] controller in
               navigation?.push(controller)
           }
           
           showModal(with: navigation, for: mainWindow)
           

    }
    
    
    private func updateState(_ state: State, refreshToken:@escaping()->Void, updateState:@escaping((State) -> State) -> Void) {
        
        let sharedContext = self.sharedContext
        var controller: ViewController?
        
        guard let currentState = state.state else {
            return
        }
                
        switch currentState {
        case .empty:
            if state.tokenAvailable {
                if let token = state.tokenResult {
                    switch token {
                    case let .displayToken(token):
                        controller = token_c
                        token_c.update(token, cancel: {
                            updateState { current in
                                var current = current
                                current.tokenAvailable = false
                                return current
                            }
                        })
                        
                        let timestamp = Int32(Date().timeIntervalSince1970)
                        let timeout = max(5, token.validUntil - timestamp)
                        self.exportTokenDisposable.set((Signal<Never, NoError>.complete()
                            |> delay(Double(timeout), queue: .mainQueue())).start(completed: refreshToken))
                    case let .changeAccountAndRetry(account):
                        controller = token_c
                        self.exportTokenDisposable.set(nil)
                        self.account = account
                        refreshToken()
                    case let .passwordRequested(account):
                        self.account = account
                        self.exportTokenDisposable.set(nil)
                        self.tokenEventsDisposable.set(nil)
                        controller = password_entry_c
                        updateState { current in
                            var current = current
                            current.tokenResult = nil
                            current.tokenAvailable = true
                            return current
                        }
                    case .loggedIn:
                        self.exportTokenDisposable.set(nil)
                        self.tokenEventsDisposable.set(nil)
                    }
                } else {
                    controller = token_c
                    token_c.update(nil, cancel: {
                        updateState { current in
                            var current = current
                            current.tokenAvailable = false
                            return current
                        }
                    })
                }
                
            } else {
                exportTokenDisposable.set(nil)
            }
            if state.tokenAvailable, state.qrEnabled {
                refreshToken()
            } else {
                controller = phone_number_c
                phone_number_c.update(currentState, countries: state.countries, error: state.error, qrEnabled: state.qrEnabled, takeToken: {
                    updateState { current in
                        var current = current
                        current.tokenAvailable = true
                        return current
                    }
                }, takeNext: { [weak self] value in
                    self?.sendCode(value, updateState: updateState)
                })
            }
        case let .phoneEntry(countryCode, number):
            controller = phone_number_c
            phone_number_c.update(currentState, countries: state.countries, error: state.error, qrEnabled: state.qrEnabled, takeToken: {
                updateState { current in
                    var current = current
                    current.tokenAvailable = true
                    return current
                }
            }, takeNext: { [weak self] value in
                self?.sendCode(value, updateState: updateState)
            })
            phone_number_c.set(number: "\(countryCode)" + number)
        case let .confirmationCodeEntry(number, type, _, timeout, nextType, _):
            controller = code_entry_c
            phone_number_c.set(number: number)
            code_entry_c.update(locked: state.locked, error: state.codeError, number: number, type: type, timeout: timeout, nextType: nextType, takeEdit: { [weak self] in
                updateState { current in
                    var current = current
                    current.locked = false
                    current.codeError = nil
                    return current
                }
                if let account = self?.account {
                    _ = resetAuthorizationState(account: account, to: .empty).start()
                }
            }, takeNext: { [weak self] code in
                guard let account = self?.account else {
                    return
                }
                updateState { current in
                    var current = current
                    current.locked = true
                    return current
                }
                
                let signal = authorizeWithCode(accountManager: sharedContext.accountManager, account: account, code: code, termsOfService: nil, forcedPasswordSetupNotice: { _ in
                    return nil
                })
                |> deliverOnMainQueue
                
                _ = signal.start(next: { value in
                    updateState { current in
                        var current = current
                        current.locked = false
                        current.codeError = nil
                        return current
                    }
                    switch value {
                    case let .signUp(data):
                        _ = beginSignUp(account: account, data: data).start()
                    default:
                        break
                    }
                }, error: { [weak self] error in
                    guard let account = self?.account else {
                        return
                    }
                    updateState { current in
                        var current = current
                        if case .codeExpired = error {
                            current.codeError = nil
                            current.error = .timeout
                        } else {
                            current.codeError = error
                            current.error = nil
                        }
                        current.locked = false
                        return current
                    }
                    switch error {
                    case .codeExpired:
                        _ = resetAuthorizationState(account: account, to: .empty).start()
                    default:
                        break
                    }
                })
            }, takeResend: { [weak self] in
                guard let window = self?.window else {
                    return
                }
                confirm(for: window, information: L10n.loginSmsAppErr, cancelTitle: L10n.loginSmsAppErrGotoSite, successHandler: { _ in
                                   
                }, cancelHandler:{
                    execute(inapp: .external(link: "https://telegram.org", false))
                })
            }, takeError: {
                updateState { current in
                    var current = current
                    current.codeError = nil
                    return current
                }
            })
        case let .passwordEntry(hint, number, _, suggestReset, _):
            controller = password_entry_c
            if let number = number {
                phone_number_c.set(number: number)
            }
            password_entry_c.update(locked: state.locked, error: state.passwordError, hint: hint, takeNext: { [weak self] password in
                guard let account = self?.account else {
                    return
                }
                updateState { current in
                    var current = current
                    current.locked = true
                    current.error = nil
                    return current
                }
                
                let signal = authorizeWithPassword(accountManager: sharedContext.accountManager, account: account, password: password, syncContacts: false)
                    |> map { () -> AuthorizationPasswordVerificationError? in
                         return nil
                    }
                    |> `catch` { error -> Signal<AuthorizationPasswordVerificationError?, AuthorizationPasswordVerificationError> in
                         return .single(error)
                    }
                    |> mapError {_ in }
                    |> deliverOnMainQueue
                
                
                _ = signal.start(next: { error in
                    updateState { current in
                        var current = current
                        current.locked = false
                        current.passwordError = error
                        return current
                    }
                })

                
            }, takeError: {
                updateState { current in
                    var current = current
                    current.locked = false
                    current.passwordError = nil
                    return current
                }
            }, takeForgot: { [weak self] reset, f in
                guard let window = self?.window, let engine = self?.engine else {
                    return
                }
                if reset {
                    let info = L10n.loginResetAccountDescription
                    let ok = L10n.loginResetAccount
                    confirm(for: window, information: info, okTitle: ok, successHandler: { [weak self] _ in
                        guard let account = self?.account else {
                            return
                        }
                        _ = showModalProgress(signal: performAccountReset(account: account), for: window).start(error: { error in
                            alert(for: window, info: L10n.unknownError)
                        })
                    })

                } else {
                    updateState { current in
                        var current = current
                        current.locked = true
                        return current
                    }
                    let signal = engine.auth.requestTwoStepVerificationPasswordRecoveryCode() |> deliverOnMainQueue
                    _ = signal.start(next: { pattern in
                        
                        updateState { current in
                            var current = current
                            current.locked = false
                            current.state = .passwordRecovery(hint: hint, number: number, code: nil, emailPattern: pattern, syncContacts: false)
                            return current
                        }
                        
                    }, error: { error in
                        alert(for: window, info: L10n.loginRecoveryMailFailed)
                        updateState { current in
                            var current = current
                            current.locked = false
                            return current
                        }
                        f()
                    })
                }
            })
        case let .awaitingAccountReset(protectedUntil, number, _):
            controller = awaiting_reset_c
            awaiting_reset_c.update(locked: state.locked, protectedUntil: protectedUntil, number: number, takeReset: { [weak self] in
                guard let window = self?.window, let account = self?.account else {
                    return
                }
                confirm(for: window, information: L10n.loginResetAccountDescription, okTitle: L10n.loginResetAccount, successHandler: { _ in
                    _ = showModalProgress(signal: performAccountReset(account: account) |> deliverOnMainQueue, for: window).start(error: { error in
                        alert(for: window, info: L10n.unknownError)
                    })
                })

            })
        case let .passwordRecovery(_, _, _, pattern, _):
            controller = email_recovery_c
            email_recovery_c.update(locked: state.locked, error: state.emailError, pattern: pattern, takeNext: { [weak self] value in
                guard let engine = self?.engine else {
                    return
                }
                updateState { current in
                    var current = current
                    current.locked = true
                    current.emailError = nil
                    return current
                }
                _ = engine.auth.performPasswordRecovery(code: value, updatedPassword: .none).start(next: { data in
                    let auth = loginWithRecoveredAccountData(accountManager: sharedContext.accountManager, account: engine.account, recoveredAccountData: data, syncContacts: false) |> deliverOnMainQueue
                    
                    _ = auth.start(completed: {
                        updateState { current in
                            var current = current
                            current.locked = false
                            return current
                        }
                    })
                    
                }, error: { error in
                    updateState { current in
                        var current = current
                        current.locked = false
                        current.emailError = error
                        return current
                    }
                })
            }, takeError: {
                updateState { current in
                    var current = current
                    current.emailError = nil
                    return current
                }
            }, takeReset: { [weak self] in
                guard let window = self?.window, let engine = self?.engine else {
                    return
                }
                
                let signal = performAccountReset(account: engine.account) |> deliverOnMainQueue

                confirm(for: window, header: appName, information: strings().loginNewEmailAlert, okTitle: strings().loginNewEmailAlertReset, cancelTitle: strings().alertCancel, successHandler: { _ in
                    
                    updateState { current in
                        var current = current
                        current.locked = true
                        return current
                    }
                    _ = signal.start(error: { error in
                        updateState { current in
                            var current = current
                            current.locked = false
                            return current
                        }
                        alert(for: window, info: strings().unknownError)
                    }, completed: {
                        updateState { current in
                            var current = current
                            current.locked = false
                            return current
                        }
                    })
                })
            })
        case .signUp:
            controller = signup_c
            signup_c.update(state.locked, error: state.signError, takeNext: { firstName, lastName, photo in
                
                let photoData: Data?
                if let photo = photo {
                    photoData = try? Data(contentsOf: URL(fileURLWithPath: photo))
                } else {
                    photoData = nil
                }
                updateState { current in
                    var current = current
                    current.locked = true
                    return current
                }
                
                let signal = signUpWithName(accountManager: sharedContext.accountManager, account: self.account, firstName: firstName, lastName: lastName, avatarData: photoData, avatarVideo: nil, videoStartTimestamp: nil, forcedPasswordSetupNotice: { _ in
                    return nil
                }) |> deliverOnMainQueue
                
                _ = signal.start(error: { error in
                    updateState { current in
                        var current = current
                        current.signError = error
                        current.locked = false
                        return current
                    }
                }, completed: {
                    updateState { current in
                        var current = current
                        current.signError = nil
                        current.locked = false
                        return current
                    }
                })

            }, takeTerms: {
                
            })
        }
        
        if let controller = controller {
            set(controller, animated: true)
        }
    }
    
    private func sendCode(_ phoneNumber: String, updateState:@escaping((State) -> State) -> Void) {
        guard let window = self.window else {
            return
        }
        let sharedContext = self.sharedContext
        let logInNumber = formatPhoneNumber(phoneNumber)
        for (number, accountId, isTestingEnvironment) in self.otherAccountPhoneNumbers.1 {
            if isTestingEnvironment == self.account.testingEnvironment && formatPhoneNumber(number) == logInNumber {
                confirm(for: window, information: strings().loginPhoneNumberAlreadyAuthorized, okTitle: strings().modalOK, cancelTitle: "", thridTitle: strings().loginPhoneNumberAlreadyAuthorizedSwitch, successHandler: { result in
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
        
        updateState { current in
            var current = current
            current.locked = true
            return current
        }

        let signal = sendAuthorizationCode(accountManager: sharedContext.accountManager, account: self.account, phoneNumber: phoneNumber, apiId: ApiEnvironment.apiId, apiHash: ApiEnvironment.apiHash, syncContacts: false)
                                       |> map(Optional.init)
                                       |> mapError(Optional.init)
                                       |> timeout(20, queue: Queue.mainQueue(), alternate: .fail(nil))
                                       |> filter { $0 != nil }
                                       |> map { $0! }
                                       |> deliverOnMainQueue
        

        self.actionDisposable.set(signal.start(next: { [weak self] account in
            updateState { current in
                var current = current
                current.error = nil
                current.locked = false
                return current
            }
            self?.account = account
        }, error: { [weak self] error in
            if let error = error {
                updateState { current in
                    var current = current
                    current.error = error
                    current.locked = false
                    return current
                }
            } else {
                confirm(for: window, header: strings().loginConnectionErrorHeader, information: strings().loginConnectionErrorInfo, okTitle: strings().loginConnectionErrorTryAgain, thridTitle: strings().loginConnectionErrorUseProxy, successHandler: { [weak self] result in
                    switch result {
                    case .basic:
                        self?.sendCode(phoneNumber, updateState: updateState)
                    case .thrid:
                        break
                    }
                })
            }
        }))
        _ = self.engine.localization.markSuggestedLocalizationAsSeenInteractively(languageCode: Locale.current.languageCode ?? "en").start()

    }
    
    func index(of controller: ViewController) -> Int {
        if controller == loading_c {
            return 0
        } else if controller == token_c {
            return 1
        } else if controller == phone_number_c {
            return 2
        } else if controller == code_entry_c {
            return 3
        } else if controller == password_entry_c {
            return 4
        } else if controller == email_recovery_c {
            return 5
        } else if controller == awaiting_reset_c {
            return 6
        } else if controller == signup_c {
            return 7
        }
        return 8
    }
    
    private func set(_ controller: ViewController, animated: Bool) {
        if self.current != controller {
            let previous = self.current

            let isNext: Bool
            if let previous = previous {
                let prevIndex = index(of: previous)
                let newIndex = index(of: controller)
                isNext = newIndex > prevIndex
            } else {
                isNext = true
            }
            
            self.genericView.updateBack(otherAccountPhoneNumbers.1.isEmpty ? index(of: controller) > 2 : false, animated: animated)
            
            self.genericView.hideLanguage()
            
            genericView.addView(controller.view)
            controller.viewWillAppear(animated)
            _ = window?.makeFirstResponder(controller.firstResponder())
            previous?.viewWillDisappear(animated)
            let window = self.window
           
            controller.frame = self.view.focus(NSMakeSize(controller.frame.width, self.frame.height))
            if animated {
                
                if previous == code_entry_c || previous == phone_number_c || controller == code_entry_c || controller == phone_number_c {
                    
                }
                
                controller.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, completion: { [weak controller] completed in
                    if completed {
                        controller?.viewDidAppear(animated)
                    }
                })
                
                controller.view.layer?.animateScaleSpring(from: 0.7, to: 1.0, duration: 0.3, bounce: false)
                controller.view.layer?.animatePosition(from: NSMakePoint(controller.frame.minX, controller.frame.minY + (isNext ? 20 : -20)), to: controller.frame.origin, duration: 0.3, timingFunction: .spring)

                
            } else {
                controller.viewDidAppear(animated)
                previous?.viewDidDisappear(animated)
            }
            if let previous = previous {
                performSubviewRemoval(previous.view, animated: animated, checkCompletion: true, completed: { [weak previous] completed in
                    if completed {
                        previous?.viewDidDisappear(animated)
                    }
                })
            }
            self.current = controller
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        loading_c.updateLocalizationAndTheme(theme: theme)
        token_c.updateLocalizationAndTheme(theme: theme)
        phone_number_c.updateLocalizationAndTheme(theme: theme)
        code_entry_c.updateLocalizationAndTheme(theme: theme)
        password_entry_c.updateLocalizationAndTheme(theme: theme)
        
        #if !APP_STORE
        updateController.updateLocalizationAndTheme(theme: theme)
        #endif
    }
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
}
