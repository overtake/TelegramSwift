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
    let send:(StickerPackItem, StickerPackReference)->Void
    let focusPack:(StickerPackCollectionInfo)->Void
    init(context: AccountContext, send:@escaping(StickerPackItem, StickerPackReference)->Void, focusPack:@escaping(StickerPackCollectionInfo)->Void) {
        self.context = context
        self.send = send
        self.focusPack = focusPack
    }
}

private struct State : Equatable {

    struct Section : Equatable {
        var info: StickerPackCollectionInfo
        var items:[StickerPackItem]
    }
    var sections:[Section]
}

private func _id_section(_ info:StickerPackCollectionInfo) -> InputDataIdentifier {
    return .init("_id_section_\(info.id.id)")
}
private func _id_pack(_ info:StickerPackCollectionInfo) -> InputDataIdentifier {
    return .init("_id_pack_\(info.id.id)")
}

private func packEntries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    var sectionId:Int32 = 0

    for section in state.sections {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pack(section.info), equatable: InputDataEquatable(section), comparable: nil, item: { initialSize, stableId in
            return AnimatedEmojiesPackItem(initialSize, context: arguments.context, stableId: stableId, info: section.info, topItem: section.items.first, focusHandler: arguments.focusPack)
        }))
        index += 1
    }
    
    return entries
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    for section in state.sections {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_section(section.info), equatable: InputDataEquatable(section), comparable: nil, item: { initialSize, stableId in
            return AnimatedEmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, info: section.info, items: section.items, callback: { item in
                arguments.send(item, .name(section.info.shortName))
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
    private let packsView = HorizontalTableView(frame: NSZeroRect)
    private let borderView = View()
    private let tabs = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tabs.addSubview(self.packsView)
        addSubview(self.tableView)
        addSubview(self.borderView)
        addSubview(tabs)
    }
    
    override func layout() {
        super.layout()
        tabs.frame = NSMakeRect(0, 0, frame.width, 50)
        packsView.frame = NSMakeRect(0, 5, frame.width, 40)
        borderView.frame = NSMakeRect(0, tabs.frame.height, frame.width, .borderSize)
        tableView.frame = NSMakeRect(0, tabs.frame.maxY, frame.width, frame.height - tabs.frame.maxY)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        borderView.backgroundColor = theme.colors.border
        tabs.backgroundColor = theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(sections: TableUpdateTransition, packs: TableUpdateTransition) {
        self.tableView.merge(with: sections)
        self.packsView.merge(with: packs)
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

        let arguments = Arguments(context: context, send: { [weak self] item, reference in
            self?.interactions?.sendAnimatedEmoji(reference, item)
        }, focusPack: { info in
            var bp = 0
            bp += 1
        })
        
        let signal:Signal<(sections: InputDataSignalValue, packs: InputDataSignalValue), NoError> = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            let sections = InputDataSignalValue(entries: entries(state, arguments: arguments))
            let packs = InputDataSignalValue(entries: packEntries(state, arguments: arguments))
            return (sections: sections, packs: packs)
        }
        
        
        let previousSections: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let previousPacks: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])

        let initialSize = self.atomicSize
        
        let onMainQueue: Atomic<Bool> = Atomic(value: false)
        
        let inputArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: {
            
        })
        
        let transition: Signal<(sections: TableUpdateTransition, packs: TableUpdateTransition), NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, signal) |> mapToQueue { appearance, state in
            let sectionEntries = state.sections.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let packEntries = state.packs.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

            let onMain = onMainQueue.swap(false)
            
            
            
            let sectionsTransition = prepareInputDataTransition(left: previousSections.swap(sectionEntries), right: sectionEntries, animated: state.sections.animated, searchState: state.sections.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMain)
            
            
            
            
            let packsTransition = prepareInputDataTransition(left: previousPacks.swap(packEntries), right: packEntries, animated: state.packs.animated, searchState: state.packs.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMain)

            return combineLatest(sectionsTransition, packsTransition) |> map { values in
                return (sections: values.0, packs: values.1)
            }
            
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.update(sections: transition.sections, packs: transition.packs)
            self?.readyOnce()
        }))
        
        
        var references: [StickerPackReference] = []
        references.append(.animatedEmoji)
        references.append(.name("webemoji"))

        
        let signals = references.map {
            context.engine.stickers.loadedStickerPack(reference: $0, forceActualized: false)
        }
        
        actionsDisposable.add(combineLatest(signals).start(next: { packs in
            updateState { current in
                var current = current
                var sections: [State.Section] = []
                for pack in packs {
                    switch pack {
                    case let .result(info, items, _):
                        sections.append(.init(info: info, items: items))
                    default:
                        break
                    }
                }
                current.sections = sections
                return current
            }
        }))
            
         self.onDeinit = {
             actionsDisposable.dispose()
             _ = previousSections.swap([])
             _ = previousPacks.swap([])
         }
        
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction

    }
}
