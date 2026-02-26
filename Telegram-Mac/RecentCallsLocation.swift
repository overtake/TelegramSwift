//
//  RecentCallsLocation.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit

enum CallListViewScrollPosition {
    case index(index: EngineMessage.Index, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

enum CallListLocation: Equatable {
    case initial(count: Int)
    case changeType(index: EngineMessage.Index)
    case navigation(index: EngineMessage.Index)
    case scroll(index: EngineMessage.Index, sourceIndex: EngineMessage.Index, scrollPosition: ListViewScrollPosition, animated: Bool)
    
    static func ==(lhs: CallListLocation, rhs: CallListLocation) -> Bool {
        switch lhs {
            case let .navigation(index):
                switch rhs {
                    case .navigation(index):
                        return true
                    default:
                        return false
                }
            default:
                return false
        }
    }
}

struct CallListLocationAndType: Equatable {
    let location: CallListLocation
    let scope: EngineCallList.Scope
}

enum CallListViewUpdateType {
    case Initial
    case Generic
    case Reload
    case ReloadAnimated
    case UpdateVisible
}

struct CallListViewUpdate {
    let view: EngineCallList
    let type: CallListViewUpdateType
    let scrollPosition: CallListViewScrollPosition?
}

func callListViewForLocationAndType(locationAndType: CallListLocationAndType, engine: TelegramEngine) -> Signal<(CallListViewUpdate, EngineCallList.Scope), NoError> {
    switch locationAndType.location {
    case let .initial(count):
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: EngineMessage.Index.absoluteUpperBound(),
            itemCount: count
        )
        |> map { view -> (CallListViewUpdate, EngineCallList.Scope) in
            return (CallListViewUpdate(view: view, type: .Generic, scrollPosition: nil), locationAndType.scope)
        }
    case let .changeType(index):
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (CallListViewUpdate, EngineCallList.Scope) in
            return (CallListViewUpdate(view: view, type: .ReloadAnimated, scrollPosition: nil), locationAndType.scope)
        }
    case let .navigation(index):
        var first = true
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (CallListViewUpdate, EngineCallList.Scope) in
            let genericType: CallListViewUpdateType
            if first {
                first = false
                genericType = .UpdateVisible
            } else {
                genericType = .Generic
            }
            return (CallListViewUpdate(view: view, type: genericType, scrollPosition: nil), locationAndType.scope)
        }
    case let .scroll(index, sourceIndex, scrollPosition, animated):
        let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
        let callScrollPosition: CallListViewScrollPosition = .index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
        var first = true
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (CallListViewUpdate, EngineCallList.Scope) in
            let genericType: CallListViewUpdateType
            let scrollPosition: CallListViewScrollPosition? = first ? callScrollPosition : nil
            if first {
                first = false
                genericType = .UpdateVisible
            } else {
                genericType = .Generic
            }
            return (CallListViewUpdate(view: view, type: genericType, scrollPosition: scrollPosition), locationAndType.scope)
        }
    }
}
