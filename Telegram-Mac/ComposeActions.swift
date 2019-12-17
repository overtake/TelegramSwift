//
//  ComposeAction.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit


func createGroup(with context: AccountContext) {
    
    let select = { SelectPeersController(titles: ComposeTitles(L10n.composeSelectUsers, L10n.composeNext), context: context, settings: [.contacts, .remote], isNewGroup: true) }
    let chooseName = { CreateGroupViewController(titles: ComposeTitles(L10n.groupNewGroup, L10n.composeCreate), context: context) }
    let signal = execute(context: context, select, chooseName) |> mapError { _ in return CreateGroupError.generic } |> mapToSignal { (_, result) -> Signal<(PeerId?, String?), CreateGroupError> in
        let signal = showModalProgress(signal: createGroup(account: context.account, title: result.title, peerIds: result.peerIds) |> map { return ($0, result.picture)}, for: mainWindow, disposeAfterComplete: false)
        return signal
    } |> mapToSignal{ peerId, picture -> Signal<(PeerId?, Bool), CreateGroupError> in
            if let peerId = peerId, let picture = picture {
                let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                let signal:Signal<(PeerId?, Bool), NoError> = updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                }) |> `catch` {_ in .complete()} |> map { value in
                    switch value {
                    case .complete:
                        return (Optional(peerId), false)
                    default:
                        return (nil, false)
                    }
                }
                
                return .single((peerId, true)) |> then(signal |> mapError { _ in return CreateGroupError.generic})
            }
            return .single((peerId, true))
        } |> deliverOnMainQueue |> filter {$0.1}
    
    
    _ = signal.start(next: { peerId, complete in
        if let peerId = peerId, complete {
            context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
        }
    }, error: { error in
        let text: String
        switch error {
        case .privacy:
            text = L10n.privacyGroupsAndChannelsInviteToChannelMultipleError
        case .generic:
            text = L10n.unknownError
        case .restricted:
            text = L10n.unknownError
        case .tooMuchLocationBasedGroups:
            text = L10n.unknownError
        case let .serverProvided(error):
            text = error
        case .tooMuchJoined:
            text = L10n.channelErrorAddTooMuch
        }
        alert(for: context.window, info: text)
    })
}


func createSupergroup(with context: AccountContext, defaultText: String = "") -> Signal<PeerId?, NoError> {
    let chooseName = CreateGroupViewController(titles: ComposeTitles(L10n.groupNewGroup, L10n.composeCreate), context: context, defaultText: defaultText)
    context.sharedContext.bindings.rootNavigation().push(chooseName)
    chooseName.restart(with: ComposeState([]))
    let signal = chooseName.onComplete.get() |> mapToSignal { result -> Signal<(PeerId?, Bool), NoError> in
        
        let createSignal: Signal<(PeerId?, String?), CreateChannelError> = showModalProgress(signal: createSupergroup(account: context.account, title: result.title, description: nil) |> map { return ($0, result.picture) }, for: mainWindow, disposeAfterComplete: false)
        
        return createSignal
         |> `catch` { _ in
            return .single((nil, nil))
         }
         |> mapToSignal { peerId, picture -> Signal<(PeerId?, Bool), NoError> in
            if let peerId = peerId {
                var additionalSignals:[Signal<Void, NoError>] = []
                
                if let picture = picture {
                    let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                    let signal:Signal<Void, NoError> = updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    }) |> `catch` { _ in .complete() } |> map { _ in }
                    additionalSignals.append(signal)
                }
                
                let combined:Signal<(PeerId?, Bool), NoError> = combineLatest(additionalSignals) |> map { _ in (nil, false) }
                
                
                
                return .single((peerId, true)) |> then(combined)
            }
            return .single((peerId, true))
        } |> deliverOnMainQueue
    }
    
    return signal |> filter { $0.1 } |> map { $0.0 }
}

func createChannel(with context: AccountContext) {
    
    let intro = ChannelIntroViewController(context)
    if FastSettings.needShowChannelIntro {
        context.sharedContext.bindings.rootNavigation().push(intro)
    }
    
    let introCompletion: Signal<Void, NoError> = FastSettings.needShowChannelIntro ? intro.onComplete.get() : Signal<Void, NoError>.single(Void())
    
    let create = introCompletion |> mapToSignal { () -> Signal<PeerId?, NoError> in
        let create = CreateChannelViewController(titles: ComposeTitles(L10n.channelNewChannel, L10n.composeNext), context: context)
        context.sharedContext.bindings.rootNavigation().push(create)
        return create.onComplete.get() |> deliverOnMainQueue |> filter {$0.1} |> mapToSignal { peerId, _ -> Signal<PeerId?, NoError> in
            if let peerId = peerId {
                FastSettings.markChannelIntroHasSeen()
                context.sharedContext.bindings.rootNavigation().removeAll()
                
                var chat: ChatController? = ChatController(context: context, chatLocation: .peer(peerId))
                var visibility: ChannelVisibilityController? = ChannelVisibilityController(context, peerId: peerId)

                chat!.navigationController = context.sharedContext.bindings.rootNavigation()
                visibility!.navigationController = context.sharedContext.bindings.rootNavigation()
                
                chat!.loadViewIfNeeded(context.sharedContext.bindings.rootNavigation().bounds)
                visibility!.loadViewIfNeeded(context.sharedContext.bindings.rootNavigation().bounds)
                
                
                
                let chatSignal = chat!.ready.get() |> filter { $0 } |> take(1) |> ignoreValues
                let visibilitySignal = visibility!.ready.get() |> filter { $0 } |> take(1) |> ignoreValues

                _ = combineLatest(queue: .mainQueue(), chatSignal, visibilitySignal).start(completed: {
                    context.sharedContext.bindings.rootNavigation().push(chat!)
                    context.sharedContext.bindings.rootNavigation().push(visibility!)

                    chat = nil
                    visibility = nil
                })
               
                return visibility!.onComplete.get() |> map {_ in return peerId}
            }
            return .single(nil)
        }
    }
    
    _ = create.start(next: { peerId in
        if let peerId = peerId {
            context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
        } else {
            context.sharedContext.bindings.rootNavigation().close()
        }
    })
}


private func execute<T1, I1, T2, V1, V2>(context: AccountContext, _ c1: @escaping() -> EmptyComposeController<I1,T1,V1>, _ c2: @escaping() -> EmptyComposeController<T1, T2, V2>) -> Signal<(T1,T2), NoError> {
    
    let c1Controller = c1()
    context.sharedContext.bindings.rootNavigation().push(c1Controller)
    return c1Controller.onComplete.get() |> mapToSignal {  (c1Next) -> Signal<(T1,T2), NoError> in
        let c2Controller = c2()
        context.sharedContext.bindings.rootNavigation().push(c2Controller)
        c2Controller.restart(with: ComposeState(c1Next))
        return c2Controller.onComplete.get() |> mapToSignal{ (c2Next) -> Signal<(T1,T2), NoError> in
            return .single((c1Next,c2Next))
        }
    }
}

private func push<I,O,V>(context: AccountContext, controller:EmptyComposeController<I,O,V>) -> Signal<O, NoError> {
    context.sharedContext.bindings.rootNavigation().push(controller)
    return controller.onComplete.get()
}

private func push<I,O,V>(context: AccountContext, controller:EmptyComposeController<I,O,V>, input:I) -> Signal<O, NoError> {
    context.sharedContext.bindings.rootNavigation().push(controller)
    controller.restart(with: ComposeState(input))
    return controller.onComplete.get()
}

private func execute<T1, I1, T2, T3, V1, V2, V3>(context: AccountContext, _ c1: @escaping () -> EmptyComposeController<I1,T1,V1>, _ c2: @escaping() -> EmptyComposeController<T1, T2, V2>, _ c3: @escaping() -> EmptyComposeController<T2, T3, V3>) -> Signal<T3, NoError> {
    
    return push(context: context, controller: c1()) |> mapToSignal { (c1Next) -> Signal<T3, NoError> in
        return push(context: context, controller: c2(), input:c1Next) |> mapToSignal{ (c2Next) -> Signal<T3, NoError> in
            return push(context: context, controller: c3(), input:c2Next) |> mapToSignal{ (c3Next) -> Signal<T3, NoError> in
                return .single(c3Next)
            }
        }
    }
}
