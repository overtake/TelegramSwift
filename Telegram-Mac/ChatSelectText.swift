//
//  ChatSelectText.swift
//  TelegramMac
//
//  Created by keepcoder on 17/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
struct SelectContainer {
    let text:String
    let range:NSRange
    let header:String?
}

class SelectManager : NSResponder {
    
    private var ranges:[(AnyHashable,WeakReference<TextView>, SelectContainer)] = []
    
    func add(range:NSRange, textView: TextView, text: String, header: String?, stableId: AnyHashable) {
        ranges.append((stableId, WeakReference(value: textView), SelectContainer(text: text, range: range, header: header)))
    }
    
    func removeAll() {
        for selection in ranges {
            if let value = selection.1.value {
                value.layout?.clearSelect()
                value.canBeResponder = true
                value.setNeedsDisplay()
            }
        }
        ranges.removeAll()
    }
    
    func remove(for id:Int64) {
        
    }
    var isEmpty:Bool {
        return ranges.isEmpty
    }
    
    
    @objc func copy(_ sender:Any) {
        
        var string:String = ""
        
        for i in stride(from: ranges.count - 1, to: -1, by: -1) {
            let container = ranges[i].2
            if let header = container.header, ranges.count > 1 {
                string += header + "\n"
            }
            
            if container.range.location != NSNotFound {
                if container.range.location != 0, ranges.count > 1 {
                    string += "..."
                }
                string += container.text.nsstring.substring(with: container.range)
                if container.range.location + container.range.length != container.text.length, ranges.count > 1 {
                    string += "..."
                }
            }
            
            if i != 0 {
                string += "\n\n"
            }
        }
        
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: self)
        pb.setString(string, forType: .string)
        
    }
    
    func selectNextChar() -> Bool {
        if let last = ranges.last, let textView = last.1.value {
            if last.2.range.max < last.2.text.length, let layout = textView.layout {
                
                var range = last.2.range
                
                switch layout.selectedRange.cursorAlignment {
                case let .min(cursorAlignment), let .max(cursorAlignment):
                    if range.min >= cursorAlignment {
                        range.length += 1
                    } else {
                        range.location += 1
                        if range.length > 1 {
                            range.length -= 1
                        }
                    }
                }
                let location = min(max(0, range.location), last.2.text.length)
                let length = max(min(range.length, last.2.text.length - location), 0)
                range = NSMakeRange(location, length)
                
                layout.selectedRange.range = range
                ranges[ranges.count - 1] = (last.0, last.1, SelectContainer(text: last.2.text, range: range, header: last.2.header))
                textView.needsDisplay = true
                return true
            }
        }
        return false
    }
    
    func selectPrevChar() -> Bool {
        if let first = ranges.first, let textView = first.1.value {
            if let layout = textView.layout {
                
                var range = first.2.range
                
                switch layout.selectedRange.cursorAlignment {
                case let .min(cursorAlignment), let .max(cursorAlignment):
                    if range.location >= cursorAlignment {
                        if range.length > 1 {
                            range.length -= 1
                        } else {
                            range.location -= 1
                        }
                    } else {
                        if range.location > 0 {
                            range.location -= 1
                            range.length += 1
                        }
                    }
                }
    
                let location = min(max(0, range.location), first.2.text.length)
                let length = max(min(range.length, first.2.text.length - location), 0)
                range = NSMakeRange(location, length)
                layout.selectedRange.range = range
                ranges[0] = (first.0, first.1, SelectContainer(text: first.2.text, range: range, header: first.2.header))
                textView.needsDisplay = true
                return true
            }
        }
        return false
    }
    
    func find(_ stableId:AnyHashable) -> NSRange? {
        for range in ranges {
            if range.0 == stableId {
                return range.2.range
            }
        }
        return nil
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        removeAll()
        return true
    }
}

let selectManager:SelectManager = {
    let manager = SelectManager()
    return manager
}()

protocol MultipleSelectable {
    var selectableTextViews:[TextView] { get }
    var header: String? { get }
}

class ChatSelectText : NSObject {
    
    private var beginInnerLocation:NSPoint = NSMakePoint(-1, -1)
    private var endInnerLocation:NSPoint = NSMakePoint(-1, -1)
    private let table:TableView
    private var deselect:Bool = false
    private var started:Bool = false
    private var startMessageId:MessageId? = nil
    private var lastPressureEventStage = 0
    private var inPressedState = false
    
    init(_ table:TableView) {
        self.table = table
    }
    
    
    
    func initializeHandlers(for window:Window, chatInteraction:ChatInteraction) {
        
        table.addScroll(listener: TableScrollListener ({ [weak table] _ in
            table?.enumerateVisibleViews(with: { view in
                view.updateMouse()
            })
        }))
        
        window.set(mouseHandler: { [weak table] event -> KeyHandlerResult in
            
            table?.enumerateVisibleViews(with: { view in
                view.updateMouse()
            })
            
            return .invokeNext
        }, with: self, for: .mouseMoved, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            
            self?.started = false
            self?.inPressedState = false
            
            if let table = self?.table, let superview = table.superview, let documentView = table.documentView {
                let point = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let documentPoint = documentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let row = table.row(at: documentPoint)
                if row < 0 || (!NSPointInRect(point, table.frame) || hasModals() || (!table.item(at: row).canMultiselectTextIn(window.mouseLocationOutsideOfEventStream) && chatInteraction.presentation.state != .selecting)) {
                    self?.beginInnerLocation = NSZeroPoint
                } else {
                    self?.beginInnerLocation = documentPoint
                }
                
                
                if row != -1, let item = table.item(at: row) as? ChatRowItem, let view = item.view as? ChatRowView {
                    if chatInteraction.presentation.state == .selecting || (theme.bubbled && !NSPointInRect(view.convert(window.mouseLocationOutsideOfEventStream, from: nil), view.bubbleFrame)) {
                        if self?.startMessageId == nil {
                            self?.startMessageId = item.message?.id
                        }
                        self?.deselect = !view.isSelectInGroup(window.mouseLocationOutsideOfEventStream)
                    }
                }
                
                self?.started = self?.beginInnerLocation != NSZeroPoint
            }
            
            return .invokeNext
        }, with: self, for: .leftMouseDown, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            
            self?.beginInnerLocation = NSZeroPoint
            
            Queue.mainQueue().justDispatch {
                guard let table = self?.table else {return}
                guard let documentView = table.documentView else {return}
                
                var cleanStartId: Bool = false
                let documentPoint = documentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let row = table.row(at: documentPoint)
                 if chatInteraction.presentation.state != .selecting {
                    if let view = table.viewNecessary(at: row) as? ChatRowView, !view.canStartTextSelecting(event) {
                        self?.beginInnerLocation = NSZeroPoint
                    }
                    cleanStartId = true
                }
                
                let point = self?.table.documentView?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? NSZeroPoint
                if let index = self?.table.row(at: point), index > 0, let item = self?.table.item(at: index), let view = item.view as? ChatRowView {
                    
                    if view.canDropSelection(in: window.mouseLocationOutsideOfEventStream) {
                        if let result = chatInteraction.presentation.selectionState?.selectedIds.isEmpty, result {
                            self?.startMessageId = nil
                            chatInteraction.update({$0.withoutSelectionState()})
                        }
                    }
                } else {
                    if let result = chatInteraction.presentation.selectionState?.selectedIds.isEmpty, result {
                        self?.startMessageId = nil
                        chatInteraction.update({$0.withoutSelectionState()})
                    }
                }
                if cleanStartId {
                    self?.startMessageId = nil
                }
            }
            return .invokeNext
        }, with: self, for: .leftMouseUp, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            self?.endInnerLocation = self?.table.documentView?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? NSZeroPoint
            
//            if let overView = window.contentView?.hitTest(window.mouseLocationOutsideOfEventStream) as? Control {
//                 self?.started = overView.userInteractionEnabled == true
//            }
            if self?.started == true {
                self?.started = !hasPopover(window)
            }
            
            if self?.started == true {
                self?.table.clipView.autoscroll(with: event)
                
                if chatInteraction.presentation.state != .selecting {
                    if window.firstResponder != selectManager {
                        window.makeFirstResponder(selectManager)
                    }
                    if self?.inPressedState == false {
                        self?.runSelector(window: window, chatInteraction: chatInteraction)
                    }
                    return .invoked
                    
                } else if chatInteraction.presentation.state == .selecting {
                    self?.runSelector(false, window: window, chatInteraction:chatInteraction)
                    return .invokeNext
                }
            }
            return .invokeNext
        }, with: self, for: .leftMouseDragged, priority:.medium)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            guard let `self` = self else { return .invokeNext }
            if event.stage == 2 && self.lastPressureEventStage < 2 {
                self.inPressedState = true
            }
            self.lastPressureEventStage = event.stage
            return .invokeNext
        }, with: self, for: .pressure, priority: .medium)
        
        window.set(handler: { () -> KeyHandlerResult in
            
            return .rejected
        }, with: self, for: .A, priority: .medium, modifierFlags: [.command])
    }
    
    private func runSelector(_ selectingText:Bool = true, window: Window, chatInteraction:ChatInteraction) {
        
        
        var startIndex = table.row(at: beginInnerLocation)
        var endIndex = table.row(at: endInnerLocation)
        
        
      
        
        let reversed = endIndex < startIndex;
        
        if(endIndex < startIndex) {
            startIndex = startIndex + endIndex;
            endIndex = startIndex - endIndex;
            startIndex = startIndex - endIndex;
        }
        
        if startIndex < 0 || endIndex < 0 {
            return
        }
        
        let beginRow = table.row(at: beginInnerLocation)
        if theme.bubbled, let view = table.item(at: beginRow).view as? ChatRowView, selectingText {
            if !NSPointInRect(view.convert(beginInnerLocation, from: table.documentView), view.bubbleFrame) {
                if startIndex != endIndex {
                    for i in max(0,startIndex) ... min(endIndex,table.count - 1)  {
                        let item = table.item(at: i) as? ChatRowItem
                        if let view = item?.view as? ChatRowView {
                            view.toggleSelected(deselect, in: window.mouseLocationOutsideOfEventStream)
                        }
                    }
                }
                
                return
            }
        }

        if selectingText {
            
            selectManager.removeAll()
            
            let isMultiple = abs(endIndex - startIndex) > 0;
            
            for i in startIndex ... endIndex  {
                let view = table.viewNecessary(at: i) as? MultipleSelectable
                if let views = view?.selectableTextViews {
                    for j in 0 ..< views.count {
                        let selectableView = views[j]
                        
                        if let layout = selectableView.layout {
                            let beginViewLocation = selectableView.convert(beginInnerLocation, from: table.documentView)
                            let endViewLocation = selectableView.convert(endInnerLocation, from: table.documentView)
                            
                            var startPoint:NSPoint = NSZeroPoint
                            var endPoint:NSPoint = NSZeroPoint
                            
                            if i == startIndex && i == endIndex {
                                
                            }
                            
                            if (i > startIndex && i < endIndex) {
                                startPoint = NSMakePoint(0, 0);
                                endPoint = NSMakePoint(layout.layoutSize.width, .greatestFiniteMagnitude);
                            } else if(i == startIndex) {
                                if(!isMultiple) {
                                    startPoint = beginViewLocation;
                                    endPoint = endViewLocation;
                                } else {
                                    if(!reversed) {
                                        startPoint = beginViewLocation
                                        endPoint = NSMakePoint(0, 0);
                                    } else {
                                        startPoint = NSMakePoint(0, 0);
                                        endPoint = endViewLocation;
                                    }
                                }
                                
                            } else if(i == endIndex) {
                                if(!reversed) {
                                    startPoint = NSMakePoint(layout.layoutSize.width, .greatestFiniteMagnitude);
                                    endPoint = endViewLocation;
                                } else {
                                    startPoint = beginViewLocation;
                                    endPoint = NSMakePoint(layout.layoutSize.width, .greatestFiniteMagnitude);
                                }
                            }
                            
                            selectableView.canBeResponder = false
                            layout.selectedRange.range = layout.selectedRange(startPoint:startPoint, currentPoint:endPoint)
                            layout.selectedRange.cursorAlignment = startPoint.x > endPoint.x ? .min(layout.selectedRange.range.max) : .max(layout.selectedRange.range.min)
                            selectManager.add(range: layout.selectedRange.range, textView: selectableView, text:layout.attributedString.string, header: view?.header, stableId: table.item(at: i).stableId)
                            selectableView.setNeedsDisplay()
                            
                            
                        }
                    }
                }
                
            }
        } else {
            if chatInteraction.presentation.state == .selecting {
                for i in max(0,startIndex) ... min(endIndex,table.count - 1)  {
                    let item = table.item(at: i) as? ChatRowItem
                    if let view = item?.view as? ChatRowView {
                        view.toggleSelected(deselect, in: window.mouseLocationOutsideOfEventStream)
                    }
                }
            }
            
        }
        
    }
    
    func removeHandlers(for window:Window) {
        window.removeAllHandlers(for: self)
    }
    
}
