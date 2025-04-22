
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
    
    
    //TODOLANG
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.bulb, text: .initialize(string: "Allow users to suggest posts for your channel.", color: theme.colors.grayText, font: .normal(.title)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_toggle, data: .init(name: "Allow Post Suggestions", color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("PRICE FOR EACH SUGGESTION"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        let maximumStars = 10000
        
        let stars = state.stars
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_price, equatable: .init(state.stars), comparable: nil, item: { initialSize, stableId in
            return PrecieSliderRowItem(initialSize, stableId: stableId, current: Double(stars.value) / (Double(maximumStars) - 1), magnit: [], markers: ["1", "\(maximumStars)"], showValue: strings().starListItemCountCountable(Int(stars.value)), update: { value in
                arguments.togglePrice(.init(value: Int64(1 + value * (Double(maximumStars) - 1)), nanos: 0))
            }, viewType: .singleItem)
            
        }))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Charge users for the ability to suggest one post for your channel. You're not required to publish any suggestions by charging this. You'll receive 85% of the selected fee for each incoming suggestion."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
   

  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    
    return entries
}

func SuggestPostController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
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
    
    let controller = InputDataController(dataSignal: signal, title: "Post Suggestions", hasDone: false)
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}


