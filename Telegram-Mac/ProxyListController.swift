//
//  ProxyListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import TGUIKit

private let _p_id_enable: InputDataIdentifier = InputDataIdentifier("_p_id_enable")
private let _p_id_add: InputDataIdentifier = InputDataIdentifier("_p_id_add")
private let _id_calls: InputDataIdentifier = InputDataIdentifier("_id_calls")
private struct ProxyListState : Equatable {
    let settings: ProxySettings
    init(settings: ProxySettings = ProxySettings.defaultSettings) {
        self.settings = settings
    }
    
    func withUpdatedSettings(_ settings: ProxySettings) -> ProxyListState {
        return ProxyListState(settings: settings)
    }
}

//private func ==(lhs: ProxyListState, rhs: ProxyListState) -> Bool {
//    return lhs.pref == rhs.pref && lhs.current == rhs.current
//}


private func proxyListSettingsEntries(_ state: ProxyListState, status: ConnectionStatus, statuses: [ProxyServerSettings : ProxyServerStatus], arguments: ProxyListArguments, showUseCalls: Bool) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: _p_id_enable, equatable: InputDataEquatable(state.settings.effectiveActiveServer != nil), item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.proxySettingsEnable, type: .switchable(state.settings.effectiveActiveServer != nil), action: {
            if state.settings.enabled {
                arguments.disconnect()
            } else {
                arguments.reconnectLatest()
            }
        }, enabled: !state.settings.servers.isEmpty || state.settings.effectiveActiveServer != nil)
    }))
    index += 1
    
    if showUseCalls {
        var enabled = true
        if let server = state.settings.effectiveActiveServer {
            switch server.connection {
            case .mtp:
                enabled = false
            default:
                break
            }
        }
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: _id_calls, equatable: InputDataEquatable(state.settings.useForCalls && enabled), item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.proxySettingsUseForCalls, type: .switchable(state.settings.useForCalls && enabled), action: {
                arguments.enableForCalls(!state.settings.useForCalls)
            }, enabled: enabled)
        }))
    }

    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    

    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: _p_id_add, equatable: nil, item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.proxySettingsAddProxy, nameStyle: blueActionButton, type: .none, action: { () in
            arguments.edit(nil)
        }, thumb: GeneralThumbAdditional(thumb: theme.icons.proxyAddProxy, textInset: 30), inset:NSEdgeInsets(left: 30, right: 30))
    }))
    index += 1
    
    
    var list: [ProxyServerSettings] = state.settings.servers.uniqueElements
    
    if let current = state.settings.effectiveActiveServer, list.first(where: {$0 == current}) == nil {
        list.insert(current, at: 0)
    }
    
    for proxy in list {
        struct ProxyEquatable : Equatable {
            let waiting: Bool
            let connectionStatus: ConnectionStatus?
            let proxy: ProxyServerSettings
            let status: ProxyServerStatus?
        }
        let value = ProxyEquatable(waiting: !state.settings.enabled && state.settings.activeServer == proxy, connectionStatus: proxy == state.settings.effectiveActiveServer ? status : nil, proxy: proxy, status: statuses[proxy])
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: InputDataIdentifier("_proxy_\(proxy.hashValue))"), equatable: InputDataEquatable(value), item: { initialSize, stableId -> TableRowItem in
            return ProxyListRowItem(initialSize, stableId: stableId, proxy: proxy, waiting: value.waiting, connectionStatus: value.connectionStatus, status: value.status, action: {
                arguments.connect(proxy)
            }, info: {
                arguments.edit(proxy)
            }, delete: {
                arguments.delete(proxy)
            })
        }))
        index += 1
    }
    
   
    
    return entries
}


private final class ProxyListArguments {
    let edit:(ProxyServerSettings?)->Void
    let delete:(ProxyServerSettings)->Void
    let connect:(ProxyServerSettings)->Void
    let disconnect:()->Void
    let reconnectLatest:()->Void
    let enableForCalls:(Bool)->Void
    init(edit:@escaping(ProxyServerSettings?)->Void, delete: @escaping(ProxyServerSettings)->Void, connect: @escaping(ProxyServerSettings)->Void, disconnect: @escaping()->Void, reconnectLatest:@escaping()->Void, enableForCalls:@escaping(Bool)->Void) {
        self.edit = edit
        self.delete = delete
        self.connect = connect
        self.disconnect = disconnect
        self.reconnectLatest = reconnectLatest
        self.enableForCalls = enableForCalls
    }
}

private extension ProxyServerConnection {
    var type: ProxyType {
        switch self {
        case .socks5:
            return .socks5
        case .mtp:
            return .mtp
        }
    }
}

func proxyListController(postbox: Postbox, network: Network, showUseCalls: Bool = true) -> (@escaping((InputDataController)) -> Void) -> Void {
    return { f in
        
        let actionsDisposable = DisposableSet()
        
        let updateDisposable = MetaDisposable()
        actionsDisposable.add(updateDisposable)
        
        let statuses: ProxyServersStatuses = ProxyServersStatuses(network: network, servers: proxySettingsSignal(postbox) |> map { $0.servers})
        
        
        
        let stateValue:Atomic<ProxyListState> = Atomic(value: ProxyListState())
        let statePromise:ValuePromise<ProxyListState> = ValuePromise(ignoreRepeated: true)
        let updateState:(_ f:(ProxyListState)->ProxyListState)-> Void = { f in
            statePromise.set(stateValue.modify(f))
        }
        
        actionsDisposable.add((proxySettingsSignal(postbox) |> deliverOnPrepareQueue).start(next: { settings in
            updateState { current in
                return current.withUpdatedSettings(settings)
            }
        }))
        
        let arguments = ProxyListArguments(edit: { proxy in
            if let proxy = proxy {
                f(addProxyController(postbox: postbox, network: network, settings: proxy, type: proxy.connection.type))
            } else {
                let values: [ValuesSelectorValue<ProxyType>] = [ValuesSelectorValue(localized: L10n.proxySettingsSocks5, value: .socks5), ValuesSelectorValue(localized: L10n.proxySettingsMTP, value: .mtp)]
                showModal(with: ValuesSelectorModalController(values: values, selected: nil, title: L10n.proxySettingsType, onComplete: { selected in
                     f(addProxyController(postbox: postbox, network: network, settings: nil, type: selected.value))
                }), for: mainWindow)
            }
        }, delete: { proxy in
            updateDisposable.set(updateProxySettingsInteractively(postbox: postbox, network: network, { current in
                return current.withRemovedServer(proxy)
            }).start())
        }, connect: { proxy in
            updateDisposable.set(updateProxySettingsInteractively(postbox: postbox, network: network, {$0.withUpdatedActiveServer(proxy).withUpdatedEnabled(true)}).start())
        }, disconnect: {
            updateDisposable.set(updateProxySettingsInteractively(postbox: postbox, network: network, {$0.withUpdatedEnabled(false)}).start())
        }, reconnectLatest: {
           updateDisposable.set(updateProxySettingsInteractively(postbox: postbox, network: network, { current in
                if !current.enabled, let _ = current.activeServer {
                    return current.withUpdatedEnabled(true)
                } else if let first = current.servers.first {
                    return current.withUpdatedActiveServer(first).withUpdatedEnabled(true)
                } else {
                    return current
            }
            }).start())
        }, enableForCalls: { enable in
            updateDisposable.set(updateProxySettingsInteractively(postbox: postbox, network: network, {$0.withUpdatedUseForCalls(enable)}).start())
        })
        
        f((InputDataController(dataSignal: combineLatest(statePromise.get() |> deliverOnPrepareQueue, network.connectionStatus |> deliverOnPrepareQueue, statuses.statuses() |> deliverOnPrepareQueue) |> map {proxyListSettingsEntries($0.0, status: $0.1, statuses: $0.2, arguments: arguments, showUseCalls: showUseCalls)}, title: L10n.proxySettingsTitle, validateData: {
            data in
            
            if data[_p_id_add] != nil {
                arguments.edit(nil)
            }
            
            
            return .fail(.none)
        }, afterDisappear: {
            actionsDisposable.dispose()
        }, removeAfterDisappear: false, hasDone: false, identifier: "proxy")))
    }
}


private enum ProxyType {
    case socks5
    case mtp
    var defaultConnection: ProxyServerConnection {
        switch self {
        case .socks5:
            return .socks5(username: nil, password: nil)
        case .mtp:
            return .mtp(secret: Data())
        }
    }
}

private func addProxyController(postbox: Postbox, network: Network, settings: ProxyServerSettings?, type: ProxyType) -> (InputDataController) {
    
    let actionsDisposable = DisposableSet()

    let new = settings ?? ProxyServerSettings(host: "", port: 0, connection: type.defaultConnection)
    
    let stateValue:Atomic<ProxySettingsState> = Atomic(value: ProxySettingsState(server: new))
    let statePromise:ValuePromise<ProxySettingsState> = ValuePromise(ProxySettingsState(server: new), ignoreRepeated: false)
    let updateState:(_ f:(ProxySettingsState)->ProxySettingsState)-> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let title: String
    switch type {
    case .socks5:
        title = L10n.proxySettingsSocks5
    case .mtp:
        title = L10n.proxySettingsMTP
    }
    
    let controller = InputDataController(dataSignal: statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return addProxySettingsEntries(state: state)
    }, title: title, validateData: { data -> InputDataValidation in
            
            if data[_id_export] != nil {
                updateState { current in
                    let prefix: String
                    switch current.server.connection {
                    case .mtp:
                        prefix = "proxy"
                    case .socks5:
                        prefix = "socks"
                    }
                    var link = "https://t.me/\(prefix)?server=\(current.server.host)&port=\(current.server.port)"
                    switch current.server.connection {
                    case let .mtp(secret):
                        link += "&secret=\((secret as NSData).hexString)"
                    case let .socks5(username, password):
                        if let username = username {
                            link += "&user=\(username)"
                        }
                        if let password = password {
                            link += "&pass=\(password)"
                        }
                    }
                    
                    copyToClipboard(link)
                    alert(for: mainWindow, info: L10n.shareLinkCopied)
                    
                    return current
                }
                return .fail(.none)
            }
        
            return .fail(.doSomething { f in
                updateState { current in
                    var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                    if current.server.host.isEmpty {
                        fails[_id_host] = .shake
                    }
                    if current.server.port == 0 {
                        fails[_id_port] = .shake
                    }
                    switch current.server.connection {
                    case let .mtp(secret):
                        if secret.isEmpty {
                            fails[_id_secret] = .shake
                        }
                    default:
                        break
                    }
                    if !fails.isEmpty {
                        f(.fail(.fields(fails)))
                        return current
                    }
                    
                    actionsDisposable.add((updateProxySettingsInteractively(postbox: postbox, network: network, { proxySetting in
                        if let settings = settings {
                            return proxySetting.withUpdatedServer(settings, with: current.server)
                        } else {
                            return proxySetting.withAddedServer(current.server).withUpdatedActiveServer(current.server).withUpdatedEnabled(true)
                        }
                    }) |> deliverOnMainQueue).start(next: { _ in
                        f(.success(.navigationBack))
                    }))
                    return current
                }
                })
    }, updateDatas: { data in
        updateState { current in
            let port = data[_id_port]!.stringValue!
            switch current.server.connection {
            case .mtp:
                return current.withUpdatedServer(ProxyServerSettings(host: data[_id_host]?.stringValue ?? "", port: port.isEmpty ? 0 : Int32(port)!, connection: .mtp(secret: ObjcUtils.data(fromHexString: data[_id_secret]?.stringValue ?? ""))))
            case .socks5:
                return current.withUpdatedServer(ProxyServerSettings(host: data[_id_host]?.stringValue ?? "", port: port.isEmpty ? 0 : Int32(port)!, connection: .socks5(username: data[_id_username]?.stringValue, password: data[_id_pass]?.stringValue)))
            }
        }
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, identifier: "proxy")
    
    return (controller)
}


private struct ProxySettingsState: Equatable {
    let server: ProxyServerSettings
    init(server: ProxyServerSettings) {
        self.server = server
    }
   
    func withUpdatedServer(_ server: ProxyServerSettings) -> ProxySettingsState {
        return ProxySettingsState(server: server)
    }
}



private let _id_disable = InputDataIdentifier("disable")
private let _id_socks5 = InputDataIdentifier("socks5")
private let _id_export = InputDataIdentifier("export")

private let _id_host = InputDataIdentifier("host")
private let _id_port = InputDataIdentifier("port")
private let _id_username = InputDataIdentifier("username")
private let _id_secret = InputDataIdentifier("secret")
private let _id_pass = InputDataIdentifier("pass")

private func addProxySettingsEntries(state: ProxySettingsState) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    
    let server = state.server
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.proxySettingsConnectionHeader.uppercased(), color: theme.colors.grayText, detectBold: true))
    index += 1
    
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(server.host), error: nil, identifier: _id_host, mode: .plain, placeholder: L10n.proxySettingsServer, inputPlaceholder: L10n.proxySettingsServer, filter: {$0}, limit: 255))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string("\(server.port > 0 ? "\(server.port)" : "")"), error: nil, identifier: _id_port, mode: .plain, placeholder: L10n.proxySettingsPort, inputPlaceholder: L10n.proxySettingsPort, filter: {$0.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)}, limit: 10))
    index += 1
    

    
   
    
    switch server.connection {
    case let .mtp(secret):
        entries.append(.input(sectionId: sectionId, index: index, value: .string((secret as NSData).hexString), error: nil, identifier: _id_secret, mode: .plain, placeholder: L10n.proxySettingsSecret, inputPlaceholder: L10n.proxySettingsSecret, filter: {$0}, limit: 255))
        index += 1
    case let .socks5(username, password):
        entries.append(.sectionId(sectionId))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: L10n.proxySettingsCredentialsHeader, color: theme.colors.grayText, detectBold: true))
        index += 1
        entries.append(.input(sectionId: sectionId, index: index, value:  .string(username ?? ""), error: nil, identifier: _id_username, mode: .plain, placeholder: L10n.proxySettingsUsername, inputPlaceholder: L10n.proxySettingsUsername, filter: {$0}, limit: 255))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(password ?? ""), error: nil, identifier: _id_pass, mode: .secure, placeholder: L10n.proxySettingsPassword, inputPlaceholder: L10n.proxySettingsPassword, filter: {$0}, limit: 255))
        index += 1
    }
    
    if case .mtp = server.connection {
        entries.append(.desc(sectionId: sectionId, index: index, text: L10n.proxySettingsMtpSponsor, color: theme.colors.grayText, detectBold: true))
        index += 1
    }
    
    if !server.host.isEmpty && server.port > 0 {
        entries.append(.sectionId(sectionId))
        sectionId += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_export, name: L10n.proxySettingsCopyLink, color: theme.colors.blueUI, icon: nil, type: .none))
    }
    
    return entries
}



