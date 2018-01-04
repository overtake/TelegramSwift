//
//  ProxySettingsViewController.swift
//  Telegram
//
//  Created by keepcoder on 19/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private final class ProxySettingsArguments {
    let account:Account
    let changeSettingsType:(ProxySettingsStateType)->Void
    let changeServerHandler:(String)->Void
    let changePortHandler:(String)->Void
    let changeUsernameHandler:(String)->Void
    let changePasswordHandler:(String)->Void
    let copyShareLink:()->Void
    let exportProxy:()->Void
    init(_ account:Account, changeSettingsType:@escaping(ProxySettingsStateType)->Void, changeServerHandler:@escaping(String)->Void, changePortHandler:@escaping(String)->Void, changeUsernameHandler:@escaping(String)->Void, changePasswordHandler:@escaping(String)->Void, copyShareLink:@escaping()->Void, exportProxy:@escaping()->Void) {
        self.account = account
        self.changeSettingsType = changeSettingsType
        self.changeServerHandler = changeServerHandler
        self.changePortHandler = changePortHandler
        self.changeUsernameHandler = changeUsernameHandler
        self.changePasswordHandler = changePasswordHandler
        self.copyShareLink = copyShareLink
        self.exportProxy = exportProxy
    }
}

private enum ProxySettingsEntryId : Hashable {
    case section(Int32)
    case index(Int32)
    case header(Int32)
    var hashValue: Int {
        switch self {
        case .index(let index):
            return Int(index)
        case .section(let section):
            return Int(section)
        case .header(let index):
            return Int(index)
        }
    }
    
    static func ==(lhs: ProxySettingsEntryId, rhs: ProxySettingsEntryId) -> Bool {
        switch lhs {
        case .section(let index):
            if case .section(index) = rhs {
                return true
            } else {
                return false
            }
        case .index(let index):
            if case .index(index) = rhs {
                return true
            } else {
                return false
            }
        case .header(let index):
            if case .header(index) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum ProxySettingsEntry : TableItemListNodeEntry {
    case disabled(Int32, Bool)
    case socks5(Int32, Bool)
    case server(Int32, String)
    case port(Int32, String)
    case username(Int32, String)
    case password(Int32, String)
    case section(Int32)
    case header(Int32, Int32, String)
    case share(Int32, Int32, String)
    case exportProxy(Int32)
    var stableId: ProxySettingsEntryId {
        switch self {
        case .disabled:
            return .index(0)
        case .socks5:
            return .index(1)
        case .server:
            return .index(2)
        case .port:
            return .index(3)
        case .username:
            return .index(4)
        case .password:
            return .index(5)
        case .share:
            return .index(6)
        case .exportProxy:
            return .index(7)
        case .header(_, let index, _):
            return .header(index)
        case .section(let id):
            return .section(id)
        }
    }
    
    var index:Int32 {
        switch self {
        case .exportProxy:
            return 0
        case .disabled:
            return 1
        case .socks5:
            return 2
        case .server:
            return 3
        case .port:
            return 4
        case .username:
            return 5
        case .password:
            return 6
        case .header(let section, let index, _):
            return (section + 1) * 1000 - index - 30
        case .share(let section, let index, _):
            return (section + 1) * 1000 - index + 30
        case .section(let index):
            return (index + 1) * 1000 - index
        }
    }
    
    static func <(lhs:ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func ==(lhs:ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        switch lhs {
        case let .disabled(index, value):
            if case .disabled(index, value) = rhs {
                return true
            } else {
                return false
            }
        case let .exportProxy(index):
            if case .exportProxy(index) = rhs {
                return true
            } else {
                return false
            }
        case let .socks5(index, value):
            if case .socks5(index, value) = rhs {
                return true
            } else {
                return false
            }
        case let .server(index, current):
            if case .server(index, current) = rhs {
                return true
            } else {
                return false
            }
        case let .port(index, current):
            if case .port(index, current) = rhs {
                return true
            } else {
                return false
            }
        case let .username(index, current):
            if case .username(index, current) = rhs {
                return true
            } else {
                return false
            }
        case let .password(index, current):
            if case .password(index, current) = rhs {
                return true
            } else {
                return false
            }
        case .header(let section, let index, let text):
            if case .header(section, index, text) = rhs {
                return true
            } else {
                return false
            }
        case .share(let section, let index, let text):
            if case .share(section, index, text) = rhs {
                return true
            } else {
                return false
            }
        case .section(let index):
            if case .section(index) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    func item(_ arguments: ProxySettingsArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .header(_, _, let text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: false, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .share(_, _, let text):
            let attributed = NSMutableAttributedString()
            _ = attributed.append(string: text, color: .link, font: .medium(.text))
            return GeneralTextRowItem(initialSize, stableId: stableId, text: attributed, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:10, bottom:2), action: {
                arguments.copyShareLink()
            })
        case .disabled(_, let value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.proxySettingsDisabled), type: .selectable(stateback: { () -> Bool in
                return value
            }), action: { 
                arguments.changeSettingsType(.disabled)
            })
        case .socks5(_, let value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.proxySettingsSocks5), type: .selectable(stateback: { () -> Bool in
                return value
            }), action: {
                arguments.changeSettingsType(.socks5)
            })
        case .server(_, let value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.proxySettingsServer), text: value, limit: 250, insets: NSEdgeInsets(left:25,right:25,top:10,bottom:3), textChangeHandler: { modified in
                arguments.changeServerHandler(modified)
            })
        case .port(_, let value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.proxySettingsPort), text: Int(value) == 0 ? "" : value, limit: 6, insets: NSEdgeInsets(left:25,right:25,top:10,bottom:3), textChangeHandler: { modified in
                arguments.changePortHandler(modified)
            }, textFilter: { value in
                if let _ = Int32(value) {
                    return value
                } else {
                    return ""
                }
            })
        case .username(_, let value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.proxySettingsUsername), text: value, limit: 250, insets: NSEdgeInsets(left:25,right:25,top:10,bottom:3), textChangeHandler: { modified in
                arguments.changeUsernameHandler(modified)
            })
        case .password(_, let value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.proxySettingsPassword), text: value, limit: 250, insets: NSEdgeInsets(left:25,right:25,top:10,bottom:3), textChangeHandler: { modified in
                arguments.changePasswordHandler(modified)
            })
        case .exportProxy:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.proxySettingsExportLink), nameStyle: blueActionButton, type: .next, action: {
                arguments.exportProxy()
            })
        }
    }
}

private enum ProxySettingsStateType {
    case disabled
    case socks5
}
private class ProxySettingsState: Equatable {
    let type:ProxySettingsStateType
    let settings: ProxySettings?
    init() {
        self.type = .disabled
        self.settings = nil
    }
    init(type:ProxySettingsStateType, settings: ProxySettings?) {
        self.type = type
        self.settings = settings
    }
    
    static func ==(lhs: ProxySettingsState, rhs: ProxySettingsState) -> Bool {
        if let lhsSettings = lhs.settings, let rhsSettings = rhs.settings {
            if !lhsSettings.isEqual(to: rhsSettings) {
                return false
            }
        } else if (lhs.settings != nil) != (rhs.settings != nil) {
            return false
        }
        return lhs.type == rhs.type
    }
    func withUpdatedSettings(_ settings: ProxySettings?) -> ProxySettingsState {
        return ProxySettingsState(type: self.type, settings: settings)
    }
    func withUpdatedType(_ type: ProxySettingsStateType) -> ProxySettingsState {
        return ProxySettingsState(type: type, settings: self.settings)
    }
    
}

private func proxySettingsEntries(_ state: ProxySettingsState) -> [ProxySettingsEntry] {
    var entries:[ProxySettingsEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var headerIndex:Int32 = 1
    
    entries.append(.exportProxy(sectionId))
    entries.append(.header(sectionId, headerIndex, tr(L10n.proxySettingsExportDescription)))
    headerIndex += 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.disabled(sectionId, state.type == .disabled))
    entries.append(.socks5(sectionId, state.type == .socks5))
    
    if state.type == .socks5 {
        let settings = state.settings
        
        entries.append(.section(sectionId))
        sectionId += 1
        entries.append(.header(sectionId, headerIndex, tr(L10n.proxySettingsConnectionHeader)))
        headerIndex += 1
        
        entries.append(.server(sectionId, settings?.host ?? ""))
        entries.append(.port(sectionId, settings?.port != nil ? "\(settings!.port)" : ""))
        
        entries.append(.section(sectionId))
        sectionId += 1
        entries.append(.header(sectionId, headerIndex, tr(L10n.proxySettingsCredentialsHeader)))
        headerIndex += 1
        
        entries.append(.username(sectionId, settings?.username ?? ""))
        entries.append(.password(sectionId, settings?.password ?? ""))
        
        if !(settings?.host ?? "").isEmpty && (settings?.port ?? 0) > 0 {
            entries.append(.share(sectionId, headerIndex, tr(L10n.proxySettingsShare)))
        }
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ProxySettingsEntry>], right: [AppearanceWrapperEntry<ProxySettingsEntry>], initialSize:NSSize, arguments:ProxySettingsArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ProxySettingsViewController: EditableViewController<TableView> {
    private let preferencesDisposable = MetaDisposable()
    private let stateValue:Atomic<ProxySettingsState> = Atomic(value: ProxySettingsState())

    private let statePromise:ValuePromise<ProxySettingsState> = ValuePromise(ProxySettingsState(), ignoreRepeated: true)
    
    override init(_ account: Account) {
        super.init(account)
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let stateValue = self.stateValue
        let account = self.account
        let statePromise:ValuePromise<ProxySettingsState> = self.statePromise
        let updateState:(_ f:(ProxySettingsState)->ProxySettingsState)-> Void = { f in
            statePromise.set(stateValue.modify(f))
        }
        
        let arguments = ProxySettingsArguments(account, changeSettingsType: { value in
            updateState({ current in
                return current.withUpdatedType(value)
            })
            
        }, changeServerHandler: { updated in
            updateState({$0.withUpdatedSettings(ProxySettings(host: updated, port: $0.settings?.port ?? 0, username: $0.settings?.username, password: $0.settings?.password, useForCalls: false))})
        }, changePortHandler: { updated in
            updateState({$0.withUpdatedSettings(ProxySettings(host: $0.settings?.host ?? "", port: Int32(updated) ?? 0, username: $0.settings?.username, password: $0.settings?.password, useForCalls: false))})
        }, changeUsernameHandler: { updated in
            updateState({$0.withUpdatedSettings(ProxySettings(host: $0.settings?.host ?? "", port: $0.settings?.port ?? 0, username: updated, password: $0.settings?.password, useForCalls: false))})

        }, changePasswordHandler: { updated in
            updateState({$0.withUpdatedSettings(ProxySettings(host: $0.settings?.host ?? "", port: $0.settings?.port ?? 0, username: $0.settings?.username, password: updated, useForCalls: false))})
        }, copyShareLink: { [weak self] in
            if let value = stateValue.modify({$0}).settings {
                var link = "https://t.me/socks?server=\(value.host)&port=\(value.port)"
                if let username = value.username {
                    link += "&username=\(username)"
                }
                if let password = value.password {
                    link += "&password=\(password)"
                }
                copyToClipboard(link)
                self?.show(toaster: ControllerToaster(text: tr(L10n.shareLinkCopied)))
            }
        }, exportProxy: {
            let link = NSPasteboard.general.string(forType: .string)
            var found: Bool = false
            if let link = link, !link.isEmpty {
                let attributed = NSMutableAttributedString()
                _ = attributed.append(string: link)
                attributed.detectLinks(type: [.Links], account: account, applyProxy: { settings in
                    applyExternalProxy(settings, postbox: account.postbox, network: account.network)
                })
                attributed.enumerateAttribute(NSAttributedStringKey.link, in: attributed.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                    if let value = value as? inAppLink {
                        switch value {
                        case .socks(let proxy, let applyProxy):
                            applyProxy(proxy)
                            found = true
                            stop.pointee = true
                        default:
                            break
                        }
                    }
                })
            }
            if !found {
                alert(for: mainWindow, info: tr(L10n.proxySettingsProxyNotFound))
            }
        })
        
        let initialState:Atomic<ProxySettingsState> = Atomic(value: ProxySettingsState())
        
        let previous:Atomic<[AppearanceWrapperEntry<ProxySettingsEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        preferencesDisposable.set((account.postbox.preferencesView(keys: [PreferencesKeys.proxySettings])).start(next: { view in
            let settings = view.values[PreferencesKeys.proxySettings] as? ProxySettings
            updateState({ current in
                let updated = current.withUpdatedSettings(settings).withUpdatedType(settings == nil ? .disabled : .socks5)
                return updated
            })
            _ = initialState.swap(stateValue.modify({$0}))
        }))
        
        genericView.merge(with: (combineLatest(statePromise.get() |> deliverOnMainQueue, appearanceSignal) ) |> map { values in
            return proxySettingsEntries(values.0).map({AppearanceWrapperEntry(entry: $0, appearance: values.1)})
        } |> map {
            return prepareTransition(left: previous.swap($0), right: $0, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> afterNext { [weak self] value -> TableUpdateTransition in
            let state = stateValue.modify{$0}
            let initial = initialState.modify{$0}
            if initial != state {
                if state.type == .disabled {
                    self?.set(editable: initial != state)
                } else {
                    if let settings = state.settings {
                        self?.set(editable: !settings.host.isEmpty && settings.port > 0)
                    } else {
                        self?.set(editable: false)
                    }
                }
            } else {
                self?.set(editable: false)
            }
            
            
            return value
        })
        readyOnce()
    }
    
    override var normalString: String {
        return tr(L10n.proxySettingsSave)
    }
    
    
    
    override func changeState() {
        let state = stateValue.modify({$0})
        set(editable: false)
        _ = applyProxySettings(postbox: account.postbox, network: account.network, settings: state.type == .disabled ? nil : state.settings).start()
        
    }
    
    deinit {
        preferencesDisposable.dispose()
    }
}
