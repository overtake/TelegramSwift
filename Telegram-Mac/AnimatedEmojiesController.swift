//
//  AnimatedEmojiesController.swift
//  Telegram
//
//  Created by Mike Renoir on 30.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore


private final class Arguments {
    let context: AccountContext
    let send:(StickerPackItem)->Void
    init(context: AccountContext, send:@escaping(StickerPackItem)->Void) {
        self.context = context
        self.send = send
    }
}

private struct State : Equatable {

    struct Section : Equatable {
        var items:[StickerPackItem]
    }
    var sections:[Section]
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    for section in state.sections {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("section"), equatable: InputDataEquatable(section), comparable: nil, item: { initialSize, stableId in
            return AnimatedEmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, items: section.items, callback: { item in
                arguments.send(item)
            })
        }))
        index += 1
    }
  
    // entries
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
}

final class AnimatedEmojiesView : View {
    private let tableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.tableView)
    }
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ transition: TableUpdateTransition) {
        self.tableView.merge(with: transition)
    }
}

final class AnimatedEmojiesController : TelegramGenericViewController<AnimatedEmojiesView> {
    private let disposable = MetaDisposable()
    
    private var interactions: EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    
    override init(_ context: AccountContext) {
        super.init(context)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let actionsDisposable = DisposableSet()
        
        let initialState = State(sections: [])
        
        let statePromise = ValuePromise<State>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }

        let arguments = Arguments(context: context, send: { [weak self] item in
            self?.interactions?.sendAnimatedEmoji(.animatedEmoji, item)
        })
        
        let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return InputDataSignalValue(entries: entries(state, arguments: arguments))
        }
        
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        let onMainQueue: Atomic<Bool> = Atomic(value: true)
        
        let inputArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: {
            
        })
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, signal) |> mapToQueue { appearance, state in
            let entries = state.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: state.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMainQueue.swap(false))
        } |> deliverOnMainQueue |> afterDisposed {
            previous.swap([])
        }
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.update(transition)
            self?.readyOnce()
        }))
        
        actionsDisposable.add(context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false).start(next: { pack in
            updateState { current in
                var current = current
                switch pack {
                case let .result(_, items, _):
                    current.sections = [.init(items: items)]
                default:
                    break
                }
                return current
            }
        }))
            
         self.onDeinit = {
             actionsDisposable.dispose()
         }
        
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction

    }
}
