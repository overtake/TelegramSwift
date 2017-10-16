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
                if !NSPointInRect(point, table.frame) {
                    self?.beginInnerLocation = NSZeroPoint
                } else {
                    self?.beginInnerLocation = documentPoint
                }
                Queue.mainQueue().justDispatch { [weak self] in
                    if chatInteraction.presentation.state == .selecting {
                        if let beginInnerLocation = self?.beginInnerLocation, let selectionState = chatInteraction.presentation.selectionState {
                            let row = table.row(at: beginInnerLocation)
                            if row != -1, let item = table.item(at: row) as? ChatRowItem, let message = item.message {
                                if self?.startMessageId == nil {
                                    self?.startMessageId = message.id
                                }
                                self?.deselect = !selectionState.selectedIds.contains(message.id)
                            }
                        }
                    } else {
                        if let view = table.viewNecessary(at: row) as? ChatRowView, !view.canStartTextSelecting(event) {
                            self?.beginInnerLocation = NSZeroPoint
                        }
                        self?.startMessageId = nil
                    }
                    self?.started = self?.beginInnerLocation != NSZeroPoint
                    
                }
            }
            
            return .invokeNext
            }, with: self, for: .leftMouseDown, priority:.medium)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            self?.beginInnerLocation = NSZeroPoint
            
            let point = self?.table.documentView?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? NSZeroPoint
            if let index = self?.table.row(at: point), index > 0, let item = self?.table.item(at: index) as? ChatRowItem {
                
                if item.message?.id == self?.startMessageId {
                    if let result = item.chatInteraction.presentation.selectionState?.selectedIds.isEmpty, result {
                        self?.startMessageId = nil
                        item.chatInteraction.update({$0.withoutSelectionState()})
                    }
                }
                
            }
            
            
            return .invokeNext
            }, with: self, for: .leftMouseUp, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            self?.endInnerLocation = self?.table.documentView?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? NSZeroPoint
            
            if let overView = window.contentView?.hitTest(window.mouseLocationOutsideOfEventStream) as? Control {
                if overView.userInteractionEnabled == false {
                    self?.started = false
                }
            }
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
                    return .invoked
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
        
        if startIndex < 0 && endIndex < 0 {
            return
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
                            selectManager.add(range: layout.selectedRange.range, textView: selectableView, text:layout.attributedString.string, header: view?.header, stableId: table.item(at: i).stableId)
                            selectableView.setNeedsDisplay()
                            
                            
                        }
                    }
                }
                
            }
        } else {
            if let selectionState = chatInteraction.presentation.selectionState {
                
                var ids:Set<MessageId> = selectionState.selectedIds
                for i in max(0,startIndex) ... min(endIndex,table.count - 1)  {
                    if let item = table.item(at: i) as? ChatRowItem, let message = item.message {
                        
                        if deselect {
                            ids.remove(message.id)
                        } else {
                            ids.insert(message.id)
                        }
                    }
                    
                    
                }
                chatInteraction.update({$0.withUpdatedSelectedMessages(ids)})
                
            }
            
        }
        
    }
    
    func removeHandlers(for window:Window) {
        window.removeAllHandlers(for: self)
    }
    
}
