//
//  ChatSelectText.swift
//  TelegramMac
//
//  Created by keepcoder on 17/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit
struct SelectContainer {
    let text:NSAttributedString
    let range:NSRange
    let header:String?
}

class SelectManager : NSResponder {
    fileprivate weak var chatInteraction: ChatInteraction?
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var ranges:Atomic<[(AnyHashable,WeakReference<TextView>, SelectContainer)]> = Atomic(value: [])
    
    func add(range:NSRange, textView: TextView, text: NSAttributedString, header: String?, stableId: AnyHashable) {
        _ = ranges.modify { ranges in
            var ranges = ranges
            ranges.append((stableId, WeakReference(value: textView), SelectContainer(text: text, range: range, header: header)))
            return ranges
        }
    }
    
    func removeAll() {
        _ = ranges.modify { ranges in
            for selection in ranges {
                if let value = selection.1.value {
                    value.textLayout?.clearSelect()
                    value.canBeResponder = true
                    value.setNeedsDisplay()
                }
            }
            return []
        }
    }
    
    func remove(for id:Int64) {
        
    }
    var isEmpty:Bool {
        return ranges.with { $0.isEmpty }
    }
    
    
    var selectedText: NSAttributedString {
        let string:NSMutableAttributedString = NSMutableAttributedString()
        ranges.with { ranges in
            for i in stride(from: ranges.count - 1, to: -1, by: -1) {
                let container = ranges[i].2
                if let header = container.header, ranges.count > 1 {
                    _ = string.append(string: header + "\n", color: nil, font: .normal(.text))
                }
                
                if container.range.location != NSNotFound {
                    if container.range.location != 0, ranges.count > 1 {
                        _ = string.append(string: "...", color: nil, font: .normal(.text))
                    }
                    string.append(container.text.attributedSubstring(from: container.range))
                    if container.range.location + container.range.length != container.text.length, ranges.count > 1 {
                        _ = string.append(string: "...", color: nil, font: .normal(.text))
                    }
                }
                
                if i != 0 {
                    _ = string.append(string: "\n\n", color: nil, font: .normal(.text))
                }
            }
        }
        return string
    }
    
    @objc func copy(_ sender:Any) {
        
        if let window = self.chatInteraction?.context.window, let peer = self.chatInteraction?.peer, peer.isCopyProtected {
            showProtectedCopyAlert(peer, for: window)
            return
        }
        
        let selectedText = self.selectedText
        if !selectedText.string.isEmpty {
            if !globalLinkExecutor.copyAttributedString(selectedText) {
                NSPasteboard.general.declareTypes([.string], owner: self)
                NSPasteboard.general.setString(selectedText.string, forType: .string)
            }
        } else if let chatInteraction = self.chatInteraction {
            if let selectionState = chatInteraction.presentation.selectionState {
                _ = chatInteraction.context.account.postbox.messagesAtIds(Array(selectionState.selectedIds.sorted(by: <))).start(next: { messages in
                    var text: String = ""
                    for message in messages {
                        if !text.isEmpty {
                            text += "\n\n"
                        }
                        if let forwardInfo = message.forwardInfo {
                            text += "> " + forwardInfo.authorTitle + ":"
                        } else {
                            text += "> " + (message.effectiveAuthor?.displayTitle ?? "") + ":"
                        }
                        text += "\n"
                        text += pullText(from: message).string as String
                    }
                    copyToClipboard(text)
                })
            }
        }
        
    }
    
    func selectNextChar() -> Bool {
        var result: Bool = false
        _ = ranges.modify { ranges in
            var ranges = ranges
            if let last = ranges.last, let textView = last.1.value {
                if last.2.range.max < last.2.text.length, let layout = textView.textLayout {
                    
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
                    result = true
                    return ranges
                }
            }
            result = false
            return ranges
        }
        return result
    }
    
    func selectPrevChar() -> Bool {
        var result: Bool = false
        _ = ranges.modify { ranges in
            var ranges = ranges
            if let first = ranges.first, let textView = first.1.value {
                if let layout = textView.textLayout {
                    
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
                    result = true
                    return ranges
                }
            }
            result = false
            return ranges
        }
        return result
    }
    
    func find(_ stableId:AnyHashable) -> NSRange? {
        return ranges.with { ranges -> NSRange? in
            for range in ranges {
                if range.0 == stableId {
                    return range.2.range
                }
            }
            return nil
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        removeAll()
        return true
    }
}

let selectManager:SelectManager = SelectManager()

func initializeSelectManager() {
    _ = selectManager.isEmpty
}

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
    private var locationInWindow: NSPoint? = nil
    private var reversible: Bool = false
    
    private var lastSelectdMessageId: MessageId?
    
    init(_ table:TableView) {
        self.table = table
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    func initializeHandlers(for window:Window, chatInteraction:ChatInteraction) {
        
        self.reversible = chatInteraction.mode.isSavedMode
        
        selectManager.chatInteraction = chatInteraction
        
        table.addScroll(listener: TableScrollListener (dispatchWhenVisibleRangeUpdated: false, { [weak table] _ in
            table?.enumerateVisibleViews(with: { view in
                view.updateMouse()
            })
        }))
        
        window.set(mouseHandler: { [weak table] event -> KeyHandlerResult in
            
            table?.enumerateVisibleViews(with: { view in
                view.updateMouse()
            })
            
            return .rejected
        }, with: self, for: .mouseMoved, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            
            self?.started = false
            self?.inPressedState = false
            self?.locationInWindow = event.locationInWindow
            
            if let table = self?.table, let superview = table.superview, let documentView = table.documentView {
                let point = superview.convert(event.locationInWindow, from: nil)
                let documentPoint = documentView.convert(event.locationInWindow, from: nil)
                let row = table.row(at: documentPoint)
                
                var isCurrentTableView: (NSView?)->Bool = { _ in return false}
                
                isCurrentTableView = { [weak table] view in
                    if view === table {
                        return true
                    } else if let superview = view?.superview {
                        if superview is TableView, view is TableRowView || view is NSClipView {
                            return isCurrentTableView(superview)
                        } else if superview is TableView {
                            return false
                        } else {
                            return isCurrentTableView(superview)
                        }
                    } else {
                        return false
                    }
                }
                
                if row < 0 || (!NSPointInRect(point, table.frame) || hasModals(window) || (!table.item(at: row).canMultiselectTextIn(event.locationInWindow) && chatInteraction.presentation.state != .selecting)) || !isCurrentTableView(window.contentView?.hitTest(event.locationInWindow)) {
                    self?.beginInnerLocation = NSZeroPoint
                } else {
                    self?.beginInnerLocation = documentPoint
                }
                
                
                if row != -1, let item = table.item(at: row) as? ChatRowItem, let view = item.view as? ChatRowView {
                    if chatInteraction.presentation.state == .selecting || (theme.bubbled && !NSPointInRect(view.convert(event.locationInWindow, from: nil), view.bubbleFrame(item))) {
                        if self?.startMessageId == nil {
                            self?.startMessageId = item.message?.id
                        }
                        self?.deselect = !view.isSelectInGroup(event.locationInWindow)
                    }
                }
                
                self?.started = self?.beginInnerLocation != NSZeroPoint
                if self?.started == true, row != -1 {
                    if chatInteraction.presentation.state == .selecting, let deselect = self?.deselect {
                        let item = table.item(at: row) as? ChatRowItem
                        if let view = item?.view as? ChatRowView {
                            view.toggleSelected(deselect, in: window.mouseLocationOutsideOfEventStream)
                        }
                    }
                }
            }
            
            return .invokeNext
        }, with: self, for: .leftMouseDown, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            
            self?.beginInnerLocation = NSZeroPoint
            self?.locationInWindow = nil
            
            Queue.mainQueue().justDispatch {
                guard let table = self?.table else {return}
                guard let documentView = table.documentView else {return}
                
                var cleanStartId: Bool = false
                let documentPoint = documentView.convert(event.locationInWindow, from: nil)
                let row = table.row(at: documentPoint)
                 if chatInteraction.presentation.state != .selecting {
                    if let view = table.viewNecessary(at: row) as? ChatRowView, !view.canStartTextSelecting(event) {
                        self?.beginInnerLocation = NSZeroPoint
                    }
                    cleanStartId = true
                }
               
                
                let point = self?.table.documentView?.convert(event.locationInWindow, from: nil) ?? NSZeroPoint
                if let index = self?.table.row(at: point), index > 0, let item = self?.table.item(at: index), let view = item.view as? ChatRowView {
                    
                    if event.clickCount > 1, selectManager.isEmpty {
                        if !view.isAllowedToDoubleAction(view.convert(event.locationInWindow, from: nil)) {
                            var set: Bool = false
                            inner: for view in view.selectableTextViews {
                                if view == window.firstResponder {
                                    _ = window.makeFirstResponder(view)
                                    set = true
                                    break inner
                                }
                            }
                            if !set {
                                _ = window.makeFirstResponder(view.selectableTextViews.first)
                            }
                        }
                    }

                    if chatInteraction.presentation.reportMode == nil {
                        if view.canDropSelection(in: event.locationInWindow) {
                            if let result = chatInteraction.presentation.selectionState?.selectedIds.isEmpty, result {
                                self?.startMessageId = nil
                                chatInteraction.update({$0.withoutSelectionState()})
                            }
                        }
                    }
                } else {
                    if chatInteraction.presentation.reportMode == nil {
                        if let result = chatInteraction.presentation.selectionState?.selectedIds.isEmpty, result {
                            self?.startMessageId = nil
                            chatInteraction.update({$0.withoutSelectionState()})
                        }
                    }
                }
                if cleanStartId {
                    self?.startMessageId = nil
                }
            }
            return .invokeNext
        }, with: self, for: .leftMouseUp, priority:.medium)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            
            guard let `self` = self else {return .rejected}
            
            self.endInnerLocation = self.table.documentView?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? NSZeroPoint
            
            if self.started {
                self.started = !hasPopover(window) && self.beginInnerLocation != NSZeroPoint
            }
            if event.clickCount > 1 {
                self.started = false
            }
            
           // NSLog("\(!NSPointInRect(event.locationInWindow, window.bounds))")
            
            if self.started {
                self.table.clipView.autoscroll(with: event)
                if chatInteraction.presentation.state != .selecting {
                    if !self.inPressedState {
                        self.runSelector(window: window, chatInteraction: chatInteraction)
                        if window.firstResponder != selectManager {
                            _ = window.makeFirstResponder(selectManager)
                        }
                    }
                    return .invoked
                    
                } else if chatInteraction.presentation.state == .selecting {
                    self.runSelector(false, window: window, chatInteraction: chatInteraction)
                    return .invokeNext
                }
            }
            return .invokeNext
        }, with: self, for: .leftMouseDragged, priority:.medium)
        
        window.set(mouseHandler: { [weak self] (event) -> KeyHandlerResult in
            guard let `self` = self else { return .rejected }
            if event.stage == 2 && self.lastPressureEventStage < 2 {
                self.inPressedState = true
            }
            self.lastPressureEventStage = event.stage
            return .rejected
        }, with: self, for: .pressure, priority: .medium)
        
        window.set(handler: { _ -> KeyHandlerResult in
            
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
        if  let view = table.item(at: beginRow).view as? ChatRowView, let item = view.item as? ChatRowItem, selectingText, table._mouseInside() {
            let rowPoint = view.convert(beginInnerLocation, from: table.documentView)
            if (!NSPointInRect(rowPoint, view.bubbleFrame(item)) && theme.bubbled) {
                if startIndex != endIndex || abs(beginInnerLocation.y - endInnerLocation.y) > 10 {
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
                    
                    var start_j:Int? = nil
                    var end_j:Int? = nil
                    
                    inner: for j in 0 ..< views.count {
                        let selectableView = views[j]
                        let viewRect = selectableView.convert(CGRect(origin: .zero, size: selectableView.frame.size), to: table.documentView)
                        let rect = NSRect(x: viewRect.midX, y: min(beginInnerLocation.y, endInnerLocation.y), width: abs(endInnerLocation.x - beginInnerLocation.x), height: abs(endInnerLocation.y - beginInnerLocation.y))
                        
                        if rect.intersects(viewRect) {
                            if start_j == nil {
                                start_j = j
                            } else {
                                start_j = min(start_j!, j)
                            }
                            if end_j == nil {
                                end_j = j
                            } else {
                                end_j = max(end_j!, j)
                            }
                        }
                    }
                    
                    for j in 0 ..< views.count {
                        let selectableView = views[j]
                        
                        if let layout = selectableView.textLayout {
                            let beginViewLocation = selectableView.convert(beginInnerLocation, from: table.documentView)
                            let endViewLocation = selectableView.convert(endInnerLocation, from: table.documentView)
                            
                            var startPoint:NSPoint = NSZeroPoint
                            var endPoint:NSPoint = NSZeroPoint
                            
                            if i == startIndex && i == endIndex {
                                
                            }
                            
                           
                            let fillEnd = NSMakePoint(layout.layoutSize.width, .greatestFiniteMagnitude)
                            
                            if (i > startIndex && i < endIndex) {
                                startPoint = NSMakePoint(0, 0);
                                endPoint = fillEnd;
                            } else if(i == startIndex) {
                                if(!isMultiple) {
                                    startPoint = beginViewLocation;
                                    endPoint = endViewLocation;
                                } else {
                                    if(!reversed) {
                                        if reversible {
                                            startPoint = beginViewLocation
                                            endPoint = fillEnd;
                                        } else {
                                            startPoint = beginViewLocation
                                            endPoint = NSMakePoint(0, 0);
                                        }
                                    } else {
                                        if reversible {
                                            startPoint = fillEnd;
                                            endPoint = endViewLocation;
                                        } else {
                                            startPoint = NSMakePoint(0, 0);
                                            endPoint = endViewLocation;
                                        }
                                    }
                                }
                                
                            } else if(i == endIndex) {
                                if(!reversed) {
                                    if reversible {
                                        startPoint = .zero;
                                        endPoint = endViewLocation;
                                    } else {
                                        startPoint = fillEnd;
                                        endPoint = endViewLocation;
                                    }
                                } else {
                                    startPoint = beginViewLocation;
                                    if reversible {
                                        endPoint = .zero
                                    } else {
                                        endPoint = fillEnd;
                                    }
                                }
                            }
                            
                            if let start_j = start_j, let end_j = end_j, i == endIndex || i == startIndex {
                                if j < start_j || j > end_j {
                                    continue
                                } else {
                                    if end_j - start_j > 0 {
                                        if beginInnerLocation.y > endInnerLocation.y {
                                            if j <= start_j {
                                                endPoint = NSMakePoint(layout.layoutSize.width, .greatestFiniteMagnitude);
                                            } else {
                                                startPoint = .zero
                                            }
                                        } else if beginInnerLocation.y < endInnerLocation.y {
                                            if j > start_j {
                                                endPoint = .zero
                                            } else {
                                                startPoint = NSMakePoint(layout.layoutSize.width, .greatestFiniteMagnitude);
                                            }
                                        }
                                    }
                                    
                                }
                            }
                            
                            selectableView.canBeResponder = false
                            layout.selectedRange.range = layout.selectedRange(startPoint:startPoint, currentPoint:endPoint)
                            layout.selectedRange.cursorAlignment = startPoint.x > endPoint.x ? .min(layout.selectedRange.range.max) : .max(layout.selectedRange.range.min)
                            selectManager.add(range: layout.selectedRange.range, textView: selectableView, text:layout.attributedString, header: view?.header, stableId: table.item(at: i).stableId)
                            selectableView.setNeedsDisplayLayer()
                            
                            
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
