
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let toggleEnabled:()->Void
    let togglePrice:(StarsAmount)->Void
    init(context: AccountContext, toggleEnabled:@escaping()->Void, togglePrice:@escaping(StarsAmount)->Void) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.togglePrice = togglePrice
    }
}

private struct State : Equatable {
    var enabled: Bool = false
    var stars: StarsAmount = .init(value: 500, nanos: 0)
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_toggle = InputDataIdentifier("_id_toggle")
private let _id_price = InputDataIdentifier("_id_price")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
      
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.direct_messages, text: .initialize(string: strings().channelMessagesHeader, color: theme.colors.grayText, font: .normal(.title)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_toggle, data: .init(name: strings().channelMessagesText, color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelMessagesPaidHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        let maximumStars = arguments.context.appConfiguration.getGeneralValue("stars_paid_message_amount_max", orElse: 10000)
        let commission = arguments.context.appConfiguration.getGeneralValue("stars_paid_message_commission_permille", orElse: 850).decemial

        let stars = state.stars
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_price, equatable: .init(state.stars), comparable: nil, item: { initialSize, stableId in
            return PrecieSliderRowItem(initialSize, stableId: stableId, current: Double(stars.value) / (Double(maximumStars)), magnit: [], markers: ["0", "\(maximumStars)"], showValue: stars.value == 0 ? strings().channelMessagesPaidFree : strings().starListItemCountCountable(Int(stars.value)), update: { value in
                arguments.togglePrice(.init(value: Int64(value * (Double(maximumStars))), nanos: 0))
            }, viewType: .singleItem)
            
        }))
        
        let infoText: String
        if stars.value > 0 {
            
            let amount = "\(Double(stars.value) * 0.013 * (commission / 100))".prettyCurrencyNumberUsd

            
            infoText = strings().channelMessagesPaidInfo("\(commission.string)%", "\(amount)")
        } else {
            infoText = strings().channelMessagesPaidInfoZero("\(commission.string)%")
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(infoText), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
   

  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    
    return entries
}

func SuggestPostController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    actionsDisposable.add(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)).startStandalone(next: { peer in
        updateState { current in
            var current = current
            if let peer = peer?._asPeer() as? TelegramChannel {
                current.enabled = peer.linkedMonoforumId != nil
                current.stars = peer.sendPaidMessageStars ?? .init(value: 500, nanos: 0)
            }
            return current
        }
    }))
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, toggleEnabled: {
        updateState { current in
            var current = current
            current.enabled = !current.enabled
            return current
        }
    }, togglePrice: { value in
        updateState { current in
            var current = current
            current.stars = value
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().channelMessagesTitle, hasDone: true)
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        _ = context.engine.peers.updateChannelPaidMessagesStars(peerId: peerId, stars: state.stars.value == 0 ? nil :  state.stars, broadcastMessagesAllowed: state.enabled).start()
        return .success(.navigationBack)
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }
    

    return controller
    
}


