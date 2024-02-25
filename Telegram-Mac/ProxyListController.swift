//
//  ProxyListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import SwiftSignalKit
import Postbox
import TGUIKit
import MtProtoKit

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

extension ProxyServerSettings {
    func withHexedStringData() -> ProxyServerSettings {
        switch self.connection {
        case let .mtp(secret):
            let data = MTProxySecret.parseData(secret)?.serializeToString().data(using: .utf8) ?? Data()
            return ProxyServerSettings(host: host, port: port, connection: .mtp(secret: data))
        default:
            return self
        }
    }
    
    func withDataHextString() -> ProxyServerSettings {
        switch self.connection {
        case let .mtp(secret):
            let data = MTProxySecret.parse(String(data: secret, encoding: .utf8) ?? "")?.serialize() ?? Data()
            return ProxyServerSettings(host: host, port: port, connection: .mtp(secret: data))
        default:
            return self
        }
    }
}



private func proxyListSettingsEntries(_ state: ProxyListState, status: ConnectionStatus, statuses: [ProxyServerSettings : ProxyServerStatus], arguments: ProxyListArguments, showUseCalls: Bool) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    struct UpdateEnableRow : Equatable {
        let enabled: Bool
        let hasActiveServer: Bool
        let hasServers: Bool
    }
    
    let updateEnableRow: UpdateEnableRow = UpdateEnableRow(enabled: state.settings.enabled, hasActiveServer: state.settings.effectiveActiveServer != nil, hasServers: !state.settings.servers.isEmpty)
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: _p_id_enable, equatable: InputDataEquatable(updateEnableRow), comparable: nil, item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().proxySettingsEnable, type: .switchable(state.settings.effectiveActiveServer != nil), viewType: showUseCalls ? .firstItem : .singleItem, action: {
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
        
        struct UseForCallEquatable : Equatable {
            let enabled: Bool
            let useForCalls: Bool
        }
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: _id_calls, equatable: InputDataEquatable(UseForCallEquatable(enabled: enabled, useForCalls: state.settings.useForCalls)), comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().proxySettingsUseForCalls, type: .switchable(state.settings.useForCalls && enabled), viewType: .lastItem, action: {
                arguments.enableForCalls(!state.settings.useForCalls)
            }, enabled: enabled)
        }))
    }

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var list: [ProxyServerSettings] = state.settings.servers.uniqueElements
    if let current = state.settings.effectiveActiveServer, list.first(where: {$0 == current}) == nil {
        list.insert(current, at: 0)
    }

    let addViewType: GeneralViewType = list.isEmpty ? .singleItem : .firstItem
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: _p_id_add, equatable: InputDataEquatable(addViewType), comparable: nil, item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().proxySettingsAddProxy, nameStyle: blueActionButton, type: .none, viewType: addViewType, action: { () in
            arguments.edit(nil)
        }, thumb: GeneralThumbAdditional(thumb: theme.icons.proxyAddProxy, textInset: 30, thumbInset: -5), inset:NSEdgeInsets(left: 20, right: 20))
    }))
    index += 1
    
    
    
    for proxy in list {
        struct ProxyEquatable : Equatable {
            let enabled: Bool
            let isActiveServer: Bool
            let connectionStatus: ConnectionStatus?
            let proxy: ProxyServerSettings
            let status: ProxyServerStatus?
            let viewType: GeneralViewType
        }
        
        let viewType = list.count == 1 ? .lastItem : (list.first == proxy ? .innerItem : bestGeneralViewType(list, for: proxy))

        let value = ProxyEquatable(enabled: state.settings.enabled, isActiveServer: state.settings.activeServer == proxy, connectionStatus: proxy == state.settings.effectiveActiveServer ? status : nil, proxy: proxy, status: statuses[proxy], viewType: viewType)
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(nil), identifier: InputDataIdentifier("_proxy_\(proxy.hashValue))"), equatable: InputDataEquatable(value), comparable: nil, item: { initialSize, stableId -> TableRowItem in
            return ProxyListRowItem(initialSize, stableId: stableId, proxy: proxy, waiting: !value.enabled && state.settings.activeServer == proxy, connectionStatus: value.connectionStatus, status: value.status, viewType: viewType, action: {
                arguments.connect(proxy)
            }, info: {
                arguments.edit(proxy)
            }, delete: {
                arguments.delete(proxy)
            })
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
 
    
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

func proxyListController(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, showUseCalls: Bool = true, share:@escaping([ProxyServerSettings])->Void = {_ in}, pushController:@escaping(ViewController) -> Void = { _ in }) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    let updateDisposable = MetaDisposable()
    actionsDisposable.add(updateDisposable)
    
    let statuses: ProxyServersStatuses = ProxyServersStatuses(network: network, servers: proxySettings(accountManager: accountManager) |> map { $0.servers })
    
    let stateValue:Atomic<ProxyListState> = Atomic(value: ProxyListState())
    let statePromise:ValuePromise<ProxyListState> = ValuePromise(ignoreRepeated: true)
    let updateState:(_ f:(ProxyListState)->ProxyListState)-> Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    actionsDisposable.add((proxySettings(accountManager: accountManager) |> deliverOnPrepareQueue).start(next: { settings in
        updateState { current in
            return current.withUpdatedSettings(settings)
        }
    }))
    
    let arguments = ProxyListArguments(edit: { proxy in
        if let proxy = proxy {
            pushController(addProxyController(accountManager: accountManager, network: network, settings: proxy, type: proxy.connection.type))
        } else {
            pushController(addProxyController(accountManager: accountManager, network: network, settings: nil, type: .socks5))
        }
    }, delete: { proxy in
        updateDisposable.set(updateProxySettingsInteractively(accountManager: accountManager, { current in
            return current.withRemovedServer(proxy)
        }).start())
    }, connect: { proxy in
        updateDisposable.set(updateProxySettingsInteractively(accountManager: accountManager, {$0.withUpdatedActiveServer(proxy).withUpdatedEnabled(true)}).start())
    }, disconnect: {
        updateDisposable.set(updateProxySettingsInteractively(accountManager: accountManager, {$0.withUpdatedEnabled(false)}).start())
    }, reconnectLatest: {
        updateDisposable.set(updateProxySettingsInteractively(accountManager: accountManager, { current in
            if !current.enabled, let _ = current.activeServer {
                return current.withUpdatedEnabled(true)
            } else if let first = current.servers.first {
                return current.withUpdatedActiveServer(first).withUpdatedEnabled(true)
            } else {
                return current
            }
        }).start())
    }, enableForCalls: { enable in
        updateDisposable.set(updateProxySettingsInteractively(accountManager: accountManager, {$0.withUpdatedUseForCalls(enable)}).start())
    })
    
    let controller = InputDataController(dataSignal: combineLatest(queue: prepareQueue, statePromise.get(), network.connectionStatus, statuses.statuses(), appearanceSignal) |> map {proxyListSettingsEntries($0.0, status: $0.1, statuses: $0.2, arguments: arguments, showUseCalls: showUseCalls)} |> map { InputDataSignalValue(entries: $0) }, title: strings().proxySettingsTitle, validateData: {
        data in
        
        if data[_p_id_add] != nil {
            arguments.edit(nil)
        }
        
        
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, removeAfterDisappear: false, hasDone: false, identifier: "proxy", afterTransaction: { controller in
        controller.rightBarView.isHidden = stateValue.with { $0.settings.servers.isEmpty }
    })
    
    return controller
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

private func addProxyController(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, settings: ProxyServerSettings?, type: ProxyType) -> (InputDataController) {
    
    let actionsDisposable = DisposableSet()

    let new = settings?.withHexedStringData() ?? ProxyServerSettings(host: "", port: 0, connection: type.defaultConnection)
    
    let stateValue:Atomic<ProxySettingsState> = Atomic(value: ProxySettingsState(server: new, type: settings == nil ? type : nil))
    let statePromise:ValuePromise<ProxySettingsState> = ValuePromise(ProxySettingsState(server: new, type: settings == nil ? type : nil), ignoreRepeated: false)
    let updateState:(_ f:(ProxySettingsState)->ProxySettingsState)-> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let title: String
    switch type {
    case .socks5:
        title = strings().proxySettingsSocks5
    case .mtp:
        title = strings().proxySettingsMTP
    }
    
    weak var _controller: ViewController?
    
    let controller = InputDataController(dataSignal: combineLatest(statePromise.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { state, _ in
        return addProxySettingsEntries(state: state, updateType: { type in
            updateState { current in
                switch type {
                case .socks5:
                    return .init(server: ProxyServerSettings(host: current.server.host, port: current.server.port, connection: type.defaultConnection), type: type)
                case .mtp:
                    return .init(server: ProxyServerSettings(host: current.server.host, port: current.server.port, connection: type.defaultConnection), type: type)
                }
            }
        })
    } |> map { InputDataSignalValue(entries: $0) }, title: title, validateData: { data -> InputDataValidation in
            if data[_id_export] != nil {
                updateState { current in
                    copyToClipboard(current.server.withDataHextString().link)
                    _controller?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
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
                    
                    let server = current.server.withDataHextString()

                    switch server.connection {
                    case let .mtp(secret):
                        if secret.count == 0 {
                            alert(for: mainWindow, info: strings().proxySettingsIncorrectSecret)
                           return current
                        }
                    default:
                        break
                    }
                    
                    actionsDisposable.add((updateProxySettingsInteractively(accountManager: accountManager, { proxySetting in
                        if let settings = settings {
                            return proxySetting
                                .withUpdatedServer(settings, with: server)
                        } else {
                            return proxySetting
                                .withAddedServer(server)
                                .withUpdatedActiveServer(server)
                                .withUpdatedEnabled(true)
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
                let secret = data[_id_secret]?.stringValue?.data(using: .utf8) ?? Data()
                return current.withUpdatedServer(ProxyServerSettings(host: data[_id_host]?.stringValue ?? "", port: port.isEmpty ? 0 : Int32(port)!, connection: .mtp(secret: secret)))
            case .socks5:
                return current.withUpdatedServer(ProxyServerSettings(host: data[_id_host]?.stringValue ?? "", port: port.isEmpty ? 0 : (Int32(port) ?? 0), connection: .socks5(username: data[_id_username]?.stringValue, password: data[_id_pass]?.stringValue)))
            }
        }
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, identifier: "proxy")
    
    _controller = controller
    
    return (controller)
}


private struct ProxySettingsState: Equatable {
    let server: ProxyServerSettings
    let type: ProxyType?
    init(server: ProxyServerSettings, type: ProxyType?) {
        self.server = server
        self.type = type
    }
   
    func withUpdatedServer(_ server: ProxyServerSettings) -> ProxySettingsState {
        return ProxySettingsState(server: server, type: self.type)
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
private let _id_qrcode = InputDataIdentifier("_id_qrcode")

private let _id_mode_socks5 = InputDataIdentifier("_id_mode_socks5")
private let _id_mode_mtproto = InputDataIdentifier("_id_mode_mtproto")


private func addProxySettingsEntries(state: ProxySettingsState, updateType:@escaping(ProxyType)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    if let type = state.type {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().proxySettingsType.uppercased()), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_mode_mtproto, data: InputDataGeneralData(name: strings().proxySettingsMTP, color: theme.colors.text, icon: nil, type: .selectable(type == .mtp), viewType: .firstItem, action: {
            updateType(.mtp)
        })))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_mode_socks5, data: InputDataGeneralData(name: strings().proxySettingsSocks5, color: theme.colors.text, icon: nil, type: .selectable(type == .socks5), viewType: .lastItem, action: {
            updateType(.socks5)
        })))
        index += 1

        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    
    let server = state.server
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().proxySettingsConnectionHeader.uppercased()), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(server.host), error: nil, identifier: _id_host, mode: .plain, data: InputDataRowData(viewType: .firstItem), placeholder: nil, inputPlaceholder: strings().proxySettingsServer, filter: {$0}, limit: 255))
    index += 1
    
    
    let portViewType: GeneralViewType
    switch server.connection {
    case .mtp:
        portViewType = .innerItem
    case .socks5:
        portViewType = .lastItem
    }
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string("\(server.port > 0 ? "\(server.port)" : "")"), error: nil, identifier: _id_port, mode: .plain, data: InputDataRowData(viewType: portViewType), placeholder: nil, inputPlaceholder: strings().proxySettingsPort, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: 10))
    index += 1

    switch server.connection {
    case let .mtp(secret):
        entries.append(.input(sectionId: sectionId, index: index, value: .string(String(data: secret, encoding: .utf8)), error: nil, identifier: _id_secret, mode: .plain, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: strings().proxySettingsSecret, filter: {$0}, limit: 255))
        index += 1
    case let .socks5(username, password):
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().proxySettingsCredentialsHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        entries.append(.input(sectionId: sectionId, index: index, value:  .string(username ?? ""), error: nil, identifier: _id_username, mode: .plain, data: InputDataRowData(viewType: .firstItem), placeholder: nil, inputPlaceholder: strings().proxySettingsUsername, filter: {$0}, limit: 255))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(password ?? ""), error: nil, identifier: _id_pass, mode: .secure, data: InputDataRowData(viewType: .lastItem), placeholder: nil, inputPlaceholder: strings().proxySettingsPassword, filter: {$0}, limit: 255))
        index += 1
    }
    
    if case .mtp = server.connection {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().proxySettingsMtpSponsor), data: InputDataGeneralTextData(viewType: .textBottomItem)))
        index += 1
    }
    
    if !server.isEmpty {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_export, data: InputDataGeneralData(name: strings().proxySettingsCopyLink, color: theme.colors.accent, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let link = server.withDataHextString().link
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_qrcode, equatable: InputDataEquatable(link), comparable: nil, item: { initialSize, stableId in
            return ProxyQRCodeRowItem(initialSize, stableId: stableId, link: link)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}



