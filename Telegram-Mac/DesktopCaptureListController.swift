//
//  DesktopCaptureListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TgVoipWebrtc
import SwiftSignalKit

private final class DesktopCaptureListArguments {
    let select:(DesktopCaptureSource, DesktopCaptureSourceManager)->Void
    init(select:@escaping(DesktopCaptureSource, DesktopCaptureSourceManager)->Void) {
        self.select = select
    }
}

private struct DesktopCaptureListState : Equatable {
    var screens: [DesktopCaptureSource]
    var windows: [DesktopCaptureSource]
    var selected: DesktopCaptureSource?
    init(screens: [DesktopCaptureSource], windows: [DesktopCaptureSource], selected: DesktopCaptureSource?) {
        self.screens = screens
        self.windows = windows
        self.selected = selected
    }
}

private func entries(_ state: DesktopCaptureListState, screens: DesktopCaptureSourceManager?, windows: DesktopCaptureSourceManager?, excludeWindowNumber: Int = 0, arguments: DesktopCaptureListArguments) -> [InputDataEntry] {
        
    var entries:[InputDataEntry] = []
    
    struct Tuple : Equatable {
        let source: DesktopCaptureSource
        let selected: DesktopCaptureSource?
    }
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(sectionId)"), equatable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 15, stableId: stableId, backgroundColor: .clear)
    }))
    sectionId += 1
    
    for source in state.screens {
        let id: String = source.uniqueKey()
        let selected = source == state.selected ? state.selected : nil
        let tuple = Tuple(source: source, selected: selected)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), item: { [weak screens] initialSize, stableId in
            return DesktopCapturePreviewItem(initialSize, stableId: stableId, source: tuple.source, selectedSource: tuple.selected, manager: screens, select: arguments.select)
        }))
        index += 1
    }
    
    for source in state.windows {
        let id: String = source.uniqueKey()
        if id != "\(excludeWindowNumber)" {
            let selected = source == state.selected ? state.selected : nil
            let tuple = Tuple(source: source, selected: selected)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), item: { [weak windows] initialSize, stableId in
                return DesktopCapturePreviewItem(initialSize, stableId: stableId, source: tuple.source, selectedSource: tuple.selected, manager: windows, select: arguments.select)
            }))
            index += 1
        }
    }

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(sectionId)"), equatable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 15, stableId: stableId, backgroundColor: .clear)
    }))
    sectionId += 1
    
    return entries
}

final class DesktopCapturerListController: GenericViewController<HorizontalTableView> {
    
    private let windows = DesktopCaptureSourceManager(_w: ())
    private let screens = DesktopCaptureSourceManager(_s: ())

    private var updateDisposable: Disposable?
    private let disposable: MetaDisposable = MetaDisposable()
    var updateSelected:((DesktopCaptureSource, DesktopCaptureSourceManager)->Void)? = nil
    init(size: NSSize) {
        super.init(frame: .init(origin: .zero, size: size))
        self.bar = .init(height: 0)
    }
    
    var excludeWindowNumber: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
                        
        let initialState = DesktopCaptureListState(screens: screens.list(), windows: windows.list(), selected: screens.list().first!)

        if let selected = initialState.selected {
            self.updateSelected?(selected, screens)
        }
        
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((DesktopCaptureListState) -> DesktopCaptureListState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let windows = self.windows
        let screens = self.screens
        
        let updateSignal = Signal<NoValue, NoError> { [weak windows, weak screens] subscriber in
            
            updateState { current in
                var current = current
                current.screens = screens?.list() ?? []
                current.windows = windows?.list() ?? []
                if let selected = current.selected, !current.windows.contains(selected) && !current.screens.contains(selected) {
                    current.selected = nil
                }
                return current
            }
            
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
        
        self.updateDisposable = ((updateSignal |> then(.complete() |> suspendAwareDelay(2, queue: .mainQueue()))) |> restart).start()
        
        let arguments = DesktopCaptureListArguments(select: { [weak self] source, manager in
            updateState { current in
                var current = current
                current.selected = source
                return current
            }
            self?.updateSelected?(source, manager)
        })
        
        let excludeWindowNumber = self.excludeWindowNumber

        
        let signal = statePromise.get() |> map { [weak windows, weak screens] state in
            return InputDataSignalValue(entries: entries(state, screens: screens, windows: windows, excludeWindowNumber: excludeWindowNumber, arguments: arguments))
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        
        let initialSize = self.atomicSize
        
        let transaction: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal) |> mapToQueue { state, appearance in
            
            let entries = state.entries.map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: nil, initialSize: initialSize.with { $0 }, arguments: InputDataArguments(select: {_, _ in }, dataUpdated: {}), onMainQueue: false)
        } |> deliverOnMainQueue
        
        genericView.needUpdateVisibleAfterScroll = true
        
        genericView.getBackgroundColor = {
            .clear
        }
        
        disposable.set(transaction.start(next: { [weak self] transaction in
            self?.genericView.merge(with: transaction)
        }))

    }
    
    override func initializer() -> HorizontalTableView {
        return HorizontalTableView(frame: bounds, isFlipped: true, bottomInset: 0, drawBorder: false)
    }
    
    deinit {
        disposable.dispose()
        updateDisposable?.dispose()
    }
    
}

