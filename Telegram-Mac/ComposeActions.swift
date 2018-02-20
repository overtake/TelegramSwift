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


func createGroup(with account:Account, for navigation:NavigationViewController) {
    
    
    let select = SelectPeersController(titles: ComposeTitles(tr(L10n.composeSelectUsers), tr(L10n.composeNext)), account: account, settings: [.contacts, .remote], isNewGroup: true)
    let chooseName =  CreateGroupViewController(titles: ComposeTitles(tr(L10n.groupNewGroup), tr(L10n.composeCreate)), account: account)
    let signal = execute(navigation:navigation, select, chooseName) |> mapToSignal { (_, result) -> Signal<(PeerId?, String?), Void> in
        let signal = showModalProgress(signal: createGroup(account: account, title: result.title, peerIds: result.peerIds) |> map { return ($0, result.picture)}, for: mainWindow, disposeAfterComplete: false)
        return signal
    } |> mapToSignal{ peerId, picture -> Signal<(PeerId?, Bool), Void> in
            if let peerId = peerId, let picture = picture {
                let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                let signal:Signal<(PeerId?, Bool), Void> = updatePeerPhoto(account: account, peerId: peerId, resource: resource) |> mapError {_ in} |> map { value in
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
            navigation?.push(ChatController(account: account, chatLocation: .peer(peerId)))
        }
    })
}

func createChannel(with account:Account, for navigation:NavigationViewController) {
    
    let intro = ChannelIntroViewController(account)
    if FastSettings.needShowChannelIntro {
        navigation.push(intro)
    }
    
    let introCompletion: Signal<Void, Void> = FastSettings.needShowChannelIntro ? intro.onComplete.get() : Signal<Void, Void>.single(Void())
    
    let create = introCompletion |> mapToSignal { () -> Signal<PeerId?, Void> in
        let create = CreateChannelViewController(titles: ComposeTitles(tr(L10n.channelNewChannel), tr(L10n.composeNext)), account: account)
        navigation.push(create)
        return create.onComplete.get() |> deliverOnMainQueue |> filter {$0.1} |> mapToSignal { peerId, _ -> Signal<PeerId?, Void> in
            if let peerId = peerId {
                FastSettings.markChannelIntroHasSeen()
                navigation.push(ChatController(account: account, chatLocation: .peer(peerId)), style: .none)
                let visibility = ChannelVisibilityController(account: account, peerId: peerId)
                navigation.push(visibility)
                return visibility.onComplete.get() |> filter {$0} |> map {_ in return peerId}
            }
            return .single(nil)
        }
    }
    
    _ = create.start(next: { peerId in
        if let peerId = peerId {
            navigation.push(ChatController(account: account, chatLocation: .peer(peerId)))
        } else {
            navigation.close()
        }
    })
}


private func execute<T1, I1, T2, V1, V2>(navigation:NavigationViewController, _ c1:EmptyComposeController<I1,T1,V1>, _ c2: EmptyComposeController<T1, T2, V2>) -> Signal<(T1,T2), Void> {
    
    navigation.push(c1)
    return c1.onComplete.get() |> mapToSignal { (c1Next) -> Signal<(T1,T2), Void> in
        navigation.push(c2)
        c2.restart(with: ComposeState(c1Next))
        return c2.onComplete.get() |> mapToSignal{ (c2Next) -> Signal<(T1,T2), Void> in
            return .single((c1Next,c2Next))
        }
    }
}

private func push<I,O,V>(navigation:NavigationViewController, controller:EmptyComposeController<I,O,V>) -> Signal<O,Void> {
    navigation.push(controller)
    return controller.onComplete.get()
}

private func push<I,O,V>(navigation:NavigationViewController, controller:EmptyComposeController<I,O,V>, input:I) -> Signal<O,Void> {
    navigation.push(controller)
    controller.restart(with: ComposeState(input))
    return controller.onComplete.get()
}

private func execute<T1, I1, T2, T3, V1, V2, V3>(navigation:NavigationViewController, _ c1:EmptyComposeController<I1,T1,V1>, _ c2: EmptyComposeController<T1, T2, V2>, _ c3: EmptyComposeController<T2, T3, V3>) -> Signal<T3, Void> {
    
    return push(navigation: navigation, controller: c1) |> mapToSignal { (c1Next) -> Signal<T3, Void> in
        return push(navigation: navigation, controller: c2, input:c1Next) |> mapToSignal{ (c2Next) -> Signal<T3, Void> in
            return push(navigation: navigation, controller: c3, input:c2Next) |> mapToSignal{ (c3Next) -> Signal<T3, Void> in
                return .single(c3Next)
            }
        }
    }
}
