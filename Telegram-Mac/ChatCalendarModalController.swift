//
//  ChatCalendarModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import CalendarUtils

private final class ControllerArguments {
    let context: AccountContext
    let onlyFuture: Bool
    let limitedBy: Date?
    let selectDayAnyway: Bool
    let addFetch:(Signal<Void, NoError>)->Void
    let jumpTo:(Message)->Void
    init(context: AccountContext, onlyFuture: Bool, limitedBy: Date?, selectDayAnyway: Bool, addFetch:@escaping(Signal<Void, NoError>)->Void, jumpTo:@escaping(Message)->Void) {
        self.context = context
        self.onlyFuture = onlyFuture
        self.limitedBy = limitedBy
        self.selectDayAnyway = selectDayAnyway
        self.addFetch = addFetch
        self.jumpTo = jumpTo
    }
}

private struct State : Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        if let lhsState = lhs.calendarState, let rhsState = rhs.calendarState {
            if lhsState.minTimestamp != rhsState.minTimestamp {
                return false
            }
            if lhsState.hasMore != rhsState.hasMore {
                return false
            }
            if lhsState.messagesByDay.count != rhsState.messagesByDay.count {
                return false
            }
            for (key, lhsValue) in lhsState.messagesByDay {
                let rhsValue = rhsState.messagesByDay[key]
                if rhsValue?.message.id != lhsValue.message.id || rhsValue?.count != lhsValue.count {
                    return false
                }
            }
        } else if (lhs.calendarState != nil) != (rhs.calendarState != nil) {
            return false
        }
        return true
    }
    
    var calendarState: SparseMessageCalendar.State?
}

private func _id_month(_ timestamp: TimeInterval) -> InputDataIdentifier {
    return .init("id_month_\(timestamp)")
}
private func _id_header(_ timestamp: TimeInterval) -> InputDataIdentifier {
    return .init("_id_header_\(timestamp)")
}
private func entries(state: State, controllerArguments: ControllerArguments, calendarArguments: CalendarMonthInteractions) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    let sectionId:Int32 = 0
    var index: Int32 = 0
    
    var current = CalendarUtils.stepMonth(0, date: Date())!
    
    if let calendarState = state.calendarState {
        
        while true {
            
            let currentDate = current
                        
            let month = CalendarMonthStruct(month: current, mode: .media, selectDayAnyway: controllerArguments.selectDayAnyway, onlyFuture: controllerArguments.onlyFuture, limitedBy: controllerArguments.limitedBy, dayHandler: { day in
                
                let date = CalendarUtils.monthDay(day, date: currentDate)!
                
                let entry = calendarState.messagesByDay[Int32(date.startOfDayUTC.timeIntervalSince1970)]
                if let entry = entry {
                    controllerArguments.jumpTo(entry.message)
                }
            }, dayPreview: { day in
                let date = Date(timeIntervalSince1970: TimeInterval(day))
                let entry = calendarState.messagesByDay[Int32(date.startOfDayUTC.timeIntervalSince1970)]
                if let entry = entry {
                    let context = controllerArguments.context
                    let view = TransformImageView()
                    view.frame = NSMakeRect(0, 0, 35, 35)
                    view.layer?.cornerRadius = view.frame.height / 2
                    let fg = View(frame: view.bounds)
                    fg.backgroundColor = .blackTransparent
                    view.addSubview(fg)
                    fg.toolTip = strings().peerMediaCalendarMediaCountable(entry.count)
                    var updateSignal: Signal<ImageDataTransformation, NoError>?
                    var fetchSignal: Signal<Void, NoError>?
                    var dimensions: NSSize = view.frame.size
                    if let media = entry.message.media.first as? TelegramMediaImage {
                        updateSignal = chatMessagePhoto(account: context.account, imageReference: .message(message: MessageReference(entry.message), media: media), toRepresentationSize: dimensions, scale: System.backingScale, synchronousLoad: false)
                        fetchSignal = chatMessagePhotoInteractiveFetched(account: context.account, imageReference: .message(message: MessageReference(entry.message), media: media), toRepresentationSize: dimensions)
                        dimensions = media.representationForDisplayAtSize(PixelDimensions(dimensions))?.dimensions.size ?? dimensions
                    } else if let media = entry.message.media.first as? TelegramMediaFile {
                        updateSignal = chatMessageVideo(postbox: context.account.postbox, fileReference: .message(message: MessageReference(entry.message), media: media), scale: System.backingScale)
                        fetchSignal = messageMediaFileInteractiveFetched(context: context, messageId: entry.message.id, fileReference: FileMediaReference.message(message: MessageReference(entry.message), media: media))
                        dimensions = media.dimensions?.size ?? dimensions
                    }
                    
                    let arguments = TransformImageArguments(corners: .init(radius: view.frame.height / 2), imageSize: dimensions.aspectFilled(view.frame.size), boundingSize: view.frame.size, intrinsicInsets: NSEdgeInsets())
                    
                    if let updateSignal = updateSignal, let media = entry.message.media.first {
                        view.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil))
                        
                        if !view.isFullyLoaded {
                            view.setSignal(updateSignal, cacheImage: { result in
                                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
                            })
                        }
                        
                        view.set(arguments: arguments)
                    }
                    if let fetchSignal = fetchSignal {
                        controllerArguments.addFetch(fetchSignal)
                    }
                    return view
                }
                return nil
            })
            
            
            var ids:[MessageId] = []
            
            for i in 0 ..< 7 * 6 {
                if i + 1 < month.currentStartDay {
                    continue
                } else if (i + 2) - month.currentStartDay > month.lastDayOfMonth {
                    break
                } else {
                    let date = CalendarUtils.monthDay(i, date: currentDate)!
                    let entry = calendarState.messagesByDay[Int32(date.startOfDayUTC.timeIntervalSince1970)]
                    if let entry = entry {
                        ids.append(entry.message.id)
                    }
                }
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_month(current.timeIntervalSince1970), equatable: .init(ids), comparable: nil, item: { initialSize, stableId in
                return ChatCalendarMonthRowItem(initialSize, stableId: stableId, month: month)
            }))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header(current.timeIntervalSince1970), equatable: .init(current.timeIntervalSince1970), comparable: nil, item: { initialSize, stableId in
                return ChatCalendarHeaderRowItem(initialSize, stableId: stableId, month: month)
            }))
            index += 1

            current = CalendarUtils.stepMonth(-1, date: current)
            
            if let minTimestamp = calendarState.minTimestamp {
                if Int(current.timeIntervalSince1970) < minTimestamp {
                    break
                }
            } else {
                if month.components.year! < 2013 || (month.components.year == 2013 && month.components.month! <= 9) {
                    break
                }

            }
        }
    }
    
    
    return entries
}

func ChatCalendarModalController(context: AccountContext, sparseCalendar: SparseMessageCalendar, jumpTo:@escaping(Message)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(calendarState: nil)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
        
    var close:(()->Void)? = nil
    
    let controllerArguments = ControllerArguments(context: context, onlyFuture: false, limitedBy: nil, selectDayAnyway: false, addFetch: { signal in
        actionsDisposable.add(signal.start())
    }, jumpTo: { message in
        jumpTo(message)
        close?()
    })

    let calendarAguments = CalendarMonthInteractions(selectAction: { selected in
        
    }, backAction: { date in
       
    }, nextAction: { date in
        
    }, changeYear: { year, date in
        
    })
    
    

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state: state, controllerArguments: controllerArguments, calendarArguments: calendarAguments))
    }
    
    actionsDisposable.add((sparseCalendar.state |> deliverOnPrepareQueue).start(next: { state in
        updateState { current in
            var current = current
            current.calendarState = state
            return current
        }
    }))
    
    let controller = InputDataController(dataSignal: signal, title: strings().peerMediaCalendarTitle)
    
    controller.contextObject = sparseCalendar
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(300, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    actionsDisposable.add(combineLatest(queue: .mainQueue(), statePromise.get(), sparseCalendar.isLoadingMore).start(next: { [weak sparseCalendar] state, isLoading in
        let loadMore = stateValue.with { $0.calendarState?.hasMore == true && !isLoading }
        if loadMore {
            sparseCalendar?.loadMore()
        }
    }))
    
    
    
        
    controller.didLoaded = { controller, _ in
        controller.tableView.updateAfterInitialize(isFlipped: false, bottomInset: 0, drawBorder: false)
//        controller.tableView.set(stickClass: ChatCalendarHeaderRowItem.self, handler: { item in
//            
//        })
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
        
        
    }
    
    return modalController
}



