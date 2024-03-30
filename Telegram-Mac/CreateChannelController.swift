//
//  CreateChannelController.swift
//  Telegram
//
//  Created by Mike Renoir on 13.01.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

private final class Arguments {
    let context: AccountContext
    let updateName: (String)->Void
    let updatePicture: (Bool)->Void
    let revokePeerId:(PeerId)->Void
    init(context: AccountContext, updateName: @escaping(String)->Void, updatePicture:@escaping(Bool)->Void, revokePeerId:@escaping(PeerId)->Void) {
        self.context = context
        self.updateName = updateName
        self.updatePicture = updatePicture
        self.revokePeerId = revokePeerId
    }
}

struct CreateChannelRequires : OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    static let username = CreateChannelRequires(rawValue: 1 << 1)
}

private struct State : Equatable {
    var name: String = ""
    var picture: String?
    var about: String?
    var requires: CreateChannelRequires
    var editingPublicLinkText: String?
    var addressNameValidationStatus: AddressNameValidationStatus?
    var updatingAddressName: Bool = false
    var publicChannelsToRevoke: [PeerEquatable]?
    var revokingPeerId: PeerId?
}

private let _id_name = InputDataIdentifier("_id_name")
private let _id_about = InputDataIdentifier("_id_about")
private let _id_username = InputDataIdentifier("_id_username")

private func _id_peer(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(peerId.toInt64())")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: 0, text: .plain(strings().channelNameHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    
    entries.append(.custom(sectionId: sectionId, index: 100, value: .none, identifier: _id_name, equatable: .init(state.picture), comparable: nil, item: { initialSize, stableId in
        return GroupNameRowItem(initialSize, stableId: stableId, account: arguments.context.account, placeholder: strings().channelChannelNameHolder, photo: state.picture, viewType: .singleItem, limit: 140, textChangeHandler: arguments.updateName, pickPicture: arguments.updatePicture)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if !state.requires.isEmpty {
        
        if state.requires.contains(.username) {
            if let publicChannelsToRevoke = state.publicChannelsToRevoke {
                
                entries.append(.desc(sectionId: sectionId, index: 200, text: .plain(strings().createChannelTooManyErrorTitle), data: .init(color: theme.colors.redUI, viewType: .textTopItem)))

                let sorted = publicChannelsToRevoke.sorted(by: { lhs, rhs in
                    var lhsDate: Int32 = 0
                    var rhsDate: Int32 = 0
                    if let lhs = lhs.peer as? TelegramChannel {
                        lhsDate = lhs.creationDate
                    }
                    if let rhs = rhs.peer as? TelegramChannel {
                        rhsDate = rhs.creationDate
                    }
                    return lhsDate > rhsDate
                })
                
                struct TuplePeer: Equatable {
                    let peer: PeerEquatable
                    let viewType: GeneralViewType
                    let index: Int32
                    let enabled: Bool
                }
                var items: [TuplePeer] = []
                for (i, peer) in sorted.enumerated() {
                    items.append(.init(peer: peer, viewType: bestGeneralViewType(sorted, for: i), index: 201 + Int32(i), enabled: peer.peer.id != state.revokingPeerId))
                }
                for item in items {
                    entries.append(.custom(sectionId: sectionId, index: item.index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                        return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: item.enabled, height: 42, photoSize: NSMakeSize(32, 32), status: "t.me/\(item.peer.peer.addressName ?? "unknown")", inset: NSEdgeInsets(left: 20, right: 20), interactionType:.deletable(onRemove: { peerId in
                            arguments.revokePeerId(peerId)
                        }, deletable: true), viewType: item.viewType)
                    }))
                }
            } else {
                entries.append(.desc(sectionId: sectionId, index: 200, text: .plain(strings().createGroupRequiresUsernameHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))

                
                entries.append(.input(sectionId: sectionId, index: 300, value: .string(state.editingPublicLinkText), error: nil, identifier: _id_username, mode: .plain, data: .init(viewType: .singleItem, defaultText: "t.me/"), placeholder: nil, inputPlaceholder: strings().createGroupRequiresUsernamePlaceholder, filter: { value in
                    return value
                }, limit: 30))
                
                if let status = state.addressNameValidationStatus, let addressName = state.editingPublicLinkText {
                    
                    var text:String = ""
                    var color:NSColor = theme.colors.listGrayText
                    
                    switch status {
                    case let .invalidFormat(format):
                        text = format.description
                        color = theme.colors.redUI
                    case let .availability(availability):
                        text = availability.description(for: addressName, target: .channel)
                        switch availability {
                        case .available:
                            color = theme.colors.listGrayText
                        case .purchaseAvailable:
                            color = theme.colors.listGrayText
                        default:
                            color = theme.colors.redUI
                        }
                    case .checking:
                        text = strings().channelVisibilityChecking
                        color = theme.colors.listGrayText
                    }
                    
                    entries.append(.desc(sectionId: sectionId, index: 400, text: .markdown(text, linkHandler: { link in
                        if link == "fragment" {
                            let link: String = "fragment.com/username/\(addressName)"
                            execute(inapp: inApp(for: link.nsstring))
                        }
                    }), data: .init(color: color, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(5, 16, 0, 0)))))

                } else {
                    entries.append(.desc(sectionId: sectionId, index: 500, text: .plain(strings().createGroupRequiresUsernameInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
                }
            }
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    }

    

    entries.append(.desc(sectionId: sectionId, index: 600, text: .plain(strings().channelDescHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    
    entries.append(.input(sectionId: sectionId, index: 700, value: .string(state.about), error: nil, identifier: _id_about, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().channelDescriptionHolder, filter: { $0 }, limit: 255))
    
    entries.append(.desc(sectionId: sectionId, index: 800, text: .plain(strings().channelDescriptionHolderDescrpiton), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))

    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func CreateChannelController(context: AccountContext, requires: CreateChannelRequires = [], onComplete: @escaping(PeerId, Bool)->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(requires: requires)
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let revokeAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(revokeAddressNameDisposable)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, updateName: { name in
        updateState { current in
            var current = current
            current.name = name
            return current
        }
    }, updatePicture: { select in
        if select {
            filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
                if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                    _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                        let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square))
                        showModal(with: controller, for: context.window, animationType: .scaleCenter)
                        _ = (controller.result |> deliverOnMainQueue).start(next: { url, _ in
                            updateState { current in
                                var current = current
                                current.picture = url.path
                                return current
                            }
                        })
                        
                        controller.onClose = {
                            removeFile(at: path)
                        }
                    })
                }
            })
        } else {
            updateState { current in
                var current = current
                current.picture = nil
                return current
            }
        }
    }, revokePeerId: { peerId in
        revokeAddressNameDisposable.set((verifyAlertSignal(for: context.window, information: strings().channelVisibilityConfirmRevoke) |> mapToSignalPromotingError { result -> Signal<Bool, UpdateAddressNameError> in
            if result == nil {
                return .fail(.generic)
            } else {
                return .single(true)
            }
        } |> mapToSignal { _ -> Signal<Void, UpdateAddressNameError> in
            return context.engine.peers.updateAddressName(domain: .peer(peerId), name: nil)
        } |> deliverOnMainQueue).start(error: { _ in
            updateState { current in
                var current = current
                current.revokingPeerId = nil
                return current
            }
        }, completed: {
            updateState { current in
                var current = current
                current.revokingPeerId = nil
                current.publicChannelsToRevoke = nil
                return current
            }
        }))
    })
    
    let addressNameAssignment: Signal<[Peer]?, NoError> = .single(nil) |> then(context.engine.peers.channelAddressNameAssignmentAvailability(peerId: nil) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
        if case .addressNameLimitReached = result {
            return context.engine.peers.adminedPublicChannels()
            |> map { Optional($0.map { $0.peer._asPeer() }) }
        } else {
            return .single(nil)
        }
    })

    
    actionsDisposable.add(addressNameAssignment.start(next: { peers in
        updateState { current in
            var current = current
            if peers?.isEmpty == false {
                current.publicChannelsToRevoke = peers?.compactMap {
                    .init($0)
                }
            } else {
                current.publicChannelsToRevoke = nil
            }
            return current
        }
    }))
            
          
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    
    let create:(String, String?, String?, String?)->Void = { name, about, picture, username in
        let signal: Signal<(PeerId, Bool)?, CreateChannelError> = showModalProgress(signal: context.engine.peers.createChannel(title: name, description: about), for: context.window, disposeAfterComplete: false) |> mapToSignal { peerId -> Signal<PeerId, CreateChannelError> in
            if let username = username {
                return context.engine.peers.updateAddressName(domain: .peer(peerId), name: username)
                |> mapError { error in
                    return .generic
                }
                |> map { _ in
                    return peerId
                }
            } else {
                return .single(peerId)
            }
        } |> mapToSignal { peerId in
            if let picture = picture {
                let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                let signal:Signal<(PeerId, Bool)?, CreateChannelError> = context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: resource), mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                }) |> mapError { _ in CreateChannelError.generic } |> map { value in
                    switch value {
                    case .complete:
                        return (peerId, false)
                    default:
                        return nil
                    }
                }
                return .single((peerId, true)) |> then(signal)
            }
            return .single((peerId, true))
        } |> deliverOnMainQueue
        
        _ = signal.start(next: { value in
            if let value = value {
                onComplete(value.0, value.1)
            }
        }, error: { error in
            let text: String
            switch error {
            case .generic:
                text = strings().unknownError
            case .tooMuchJoined:
                showInactiveChannels(context: context, source: .create)
                return
            case let .serverProvided(t):
                text = t
            default:
                text = strings().unknownError
            }
            showModalText(for: context.window, text: text)
        })
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().channelNewChannel, hasDone: true, doneString: { strings().navigationNext })
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        if state.name.isEmpty {
            return .fail(.fields([_id_name : .shake]))
        }
        if state.requires.contains(.username), state.publicChannelsToRevoke != nil {
            showModalText(for: context.window, text: strings().createChannelUsernameError)
            return .fail(.none)
        }
        if state.requires.contains(.username), state.addressNameValidationStatus != .availability(.available) {
            return .fail(.fields([_id_username : .shake]))
        }
        return .fail(.doSomething(next: { f in
            create(state.name, state.about, state.picture, state.editingPublicLinkText)
            f(.none)
        }))
    }
    
    controller.updateDatas = { datas in
        
        let currentAddress = stateValue.with { $0.editingPublicLinkText }
        let text = datas[_id_username]?.stringValue ?? ""
        if text.length < 5 {
            checkAddressNameDisposable.set(nil)
            updateState { current in
                var current = current
                current.editingPublicLinkText = text
                current.addressNameValidationStatus = nil
                return current
            }
        } else if currentAddress != text {
            updateState { current in
                var current = current
                current.editingPublicLinkText = text
                return current
            }
            checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(.init(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(0))), name: text)
                |> deliverOnMainQueue).start(next: { result in
                updateState { current in
                    var current = current
                    current.addressNameValidationStatus = result
                    return current
                }
            }))
        }
        updateState { current in
            var current = current
            current.about = datas[_id_about]?.stringValue
            return current
        }
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
