//
//  ComposeAction.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit


func createGroup(with context: AccountContext, for navigation:NavigationViewController) {
    
    let select = { SelectPeersController(titles: ComposeTitles(L10n.composeSelectUsers, L10n.composeNext), context: context, settings: [.contacts, .remote], isNewGroup: true) }
    let chooseName = { CreateGroupViewController(titles: ComposeTitles(L10n.groupNewGroup, L10n.composeCreate), context: context) }
    let signal = execute(navigation:navigation, select, chooseName) |> mapToSignal { (_, result) -> Signal<(PeerId?, String?), NoError> in
        let signal = showModalProgress(signal: createGroup(account: context.account, title: result.title, peerIds: result.peerIds) |> map { return ($0, result.picture)}, for: mainWindow, disposeAfterComplete: false)
        return signal
    } |> mapToSignal{ peerId, picture -> Signal<(PeerId?, Bool), NoError> in
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
                
                return .single((peerId, true)) |> then(signal)
            }
            return .single((peerId, true))
        } |> deliverOnMainQueue |> filter {$0.1}
    
    
    _ = signal.start(next: { [weak navigation] peerId, complete in
        if let peerId = peerId, complete {
            navigation?.push(ChatController(context: context, chatLocation: .peer(peerId)))
        }
    })
}

func createChannel(with context: AccountContext, for navigation:NavigationViewController) {
    
    let intro = ChannelIntroViewController(context)
    if FastSettings.needShowChannelIntro {
        navigation.push(intro)
    }
    
    let introCompletion: Signal<Void, NoError> = FastSettings.needShowChannelIntro ? intro.onComplete.get() : Signal<Void, NoError>.single(Void())
    
    let create = introCompletion |> mapToSignal { [weak navigation] () -> Signal<PeerId?, NoError> in
        let create = CreateChannelViewController(titles: ComposeTitles(L10n.channelNewChannel, L10n.composeNext), context: context)
        navigation?.push(create)
        return create.onComplete.get() |> deliverOnMainQueue |> filter {$0.1} |> mapToSignal { [weak navigation] peerId, _ -> Signal<PeerId?, NoError> in
            if let peerId = peerId, let navigation = navigation {
                FastSettings.markChannelIntroHasSeen()
                navigation.removeAll()
                
                var chat: ChatController? = ChatController(context: context, chatLocation: .peer(peerId))
                var visibility: ChannelVisibilityController? = ChannelVisibilityController(context, peerId: peerId)

                chat!.navigationController = navigation
                visibility!.navigationController = navigation
                
                chat!.loadViewIfNeeded(navigation.bounds)
                visibility!.loadViewIfNeeded(navigation.bounds)
                
                
                
                let chatSignal = chat!.ready.get() |> filter { $0 } |> take(1) |> ignoreValues
                let visibilitySignal = visibility!.ready.get() |> filter { $0 } |> take(1) |> ignoreValues

                _ = combineLatest(queue: .mainQueue(), chatSignal, visibilitySignal).start(completed: { [weak navigation] in
                    if let navigation = navigation {
                        navigation.push(chat!)
                        navigation.push(visibility!)
                    }
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
            navigation.push(ChatController(context: context, chatLocation: .peer(peerId)))
        } else {
            navigation.close()
        }
    })
}


private func execute<T1, I1, T2, V1, V2>(navigation:NavigationViewController, _ c1: @escaping() -> EmptyComposeController<I1,T1,V1>, _ c2: @escaping() -> EmptyComposeController<T1, T2, V2>) -> Signal<(T1,T2), NoError> {
    
    let c1Controller = c1()
    navigation.push(c1Controller)
    return c1Controller.onComplete.get() |> mapToSignal { [weak navigation] (c1Next) -> Signal<(T1,T2), NoError> in
        let c2Controller = c2()
        navigation?.push(c2Controller)
        c2Controller.restart(with: ComposeState(c1Next))
        return c2Controller.onComplete.get() |> mapToSignal{ (c2Next) -> Signal<(T1,T2), NoError> in
            return .single((c1Next,c2Next))
        }
    }
}

private func push<I,O,V>(navigation:NavigationViewController, controller:EmptyComposeController<I,O,V>) -> Signal<O, NoError> {
    navigation.push(controller)
    return controller.onComplete.get()
}

private func push<I,O,V>(navigation:NavigationViewController, controller:EmptyComposeController<I,O,V>, input:I) -> Signal<O, NoError> {
    navigation.push(controller)
    controller.restart(with: ComposeState(input))
    return controller.onComplete.get()
}

private func execute<T1, I1, T2, T3, V1, V2, V3>(navigation:NavigationViewController, _ c1: @escaping () -> EmptyComposeController<I1,T1,V1>, _ c2: @escaping() -> EmptyComposeController<T1, T2, V2>, _ c3: @escaping() -> EmptyComposeController<T2, T3, V3>) -> Signal<T3, NoError> {
    
    return push(navigation: navigation, controller: c1()) |> mapToSignal { (c1Next) -> Signal<T3, NoError> in
        return push(navigation: navigation, controller: c2(), input:c1Next) |> mapToSignal{ (c2Next) -> Signal<T3, NoError> in
            return push(navigation: navigation, controller: c3(), input:c2Next) |> mapToSignal{ (c3Next) -> Signal<T3, NoError> in
                return .single(c3Next)
            }
        }
    }
}
