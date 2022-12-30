//
//  PieChartTestController.swift
//  Telegram
//
//  Created by Mike Renoir on 20.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation

import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var items: [PieChartView.Item]
    var dynamicText: String
}

private class PieChartTestItem : GeneralRowItem {
    let items: [PieChartView.Item]
    let dynamicText: String
    init(_ initialSize: NSSize, stableId: AnyHashable, items: [PieChartView.Item], dynamicText: String) {
        self.items = items
        self.dynamicText = dynamicText
        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override var height: CGFloat {
        return 300
    }
    override func viewClass() -> AnyClass {
        return PieChartTestView.self
    }
}
private class PieChartTestView : GeneralContainableRowView {
    private let pieChart = PieChartView(frame: NSMakeRect(0, 0, 300, 300), presentation: .init(strokeColor: theme.colors.background, strokeSize: 2, bgColor: theme.colors.background, totalTextColor: theme.colors.text, itemTextColor: .white))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(pieChart)
    }
    
    override func layout() {
        super.layout()
        pieChart.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PieChartTestItem else {
            return
        }
        self.pieChart.update(items: item.items, dynamicText: item.dynamicText, animated: animated)
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("id"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PieChartTestItem.init(initialSize, stableId: stableId, items: state.items, dynamicText: state.dynamicText)
    }))
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PieChartTestController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let generateItems:()->([PieChartView.Item], String) = {
        let count = 6//Int.random(in: 3..<6)
        var items:[PieChartView.Item] = []
        
        for i in 0 ..< count {
            items.append(.init(id: i, index: i, count: Int.random(in: 100..<5000) * 1024 * 1024, color: theme.colors.peerColors(i).bottom, badge: nil))
        }
        
        let total = items.reduce(0, { $0 + $1.count })
        let sized = String.prettySized(with: total)

        
        let counts = optimizeArray(array: items.map { $0.count }, minPercent: 0.02)
        for i in 0 ..< items.count {
            items[i].count = counts[i]
        }
        
        return (items, sized)
    }
    
    let items = generateItems()
    
    let initialState = State(items: items.0, dynamicText: items.1)

    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "UPDATE", accept: {
        let items = generateItems()
        updateState { current in
            var current = current
            current.items = items.0
            current.dynamicText = items.1
            return current
        }
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    return modalController
    
}



