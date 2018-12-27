//
//  InstantPageSelectText.swift
//  Telegram
//
//  Created by keepcoder on 11/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

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
import AVFoundation

struct InstantPageSelectContainer {
    let attributedString: NSAttributedString
}

class InstantPageSelectManager : NSResponder {
    
    private var ranges:[(WeakReference<InstantPageTextLine>, InstantPageSelectContainer)] = []
    func add(line: InstantPageTextLine, attributedString: NSAttributedString) {
        ranges.append((WeakReference(value: line), InstantPageSelectContainer(attributedString: attributedString)))
    }
//
    func removeAll() {
        for selection in ranges {
            selection.0.value?.removeSelection()
        }
        ranges.removeAll()
    }
//
//    func remove(for id:Int64) {
//        
//    }
    var isEmpty:Bool {
        return ranges.isEmpty
    }
//
//    
    @objc func copy(_ sender:Any) {
        
        var string:String = ""
        
        for i in 0 ..< ranges.count {
            string += ranges[i].1.attributedString.string
            if i != ranges.count - 1 {
                string += "\n"
            }
        }
        
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: self)
        pb.setString(string, forType: .string)
        
    }
    
    var attributedString: NSAttributedString {
        let attr: NSMutableAttributedString = NSMutableAttributedString()
        for range in ranges {
            attr.append(range.1.attributedString)
            _ = attr.append(string: "\n")
        }
        return attr
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        removeAll()
        return true
    }
}

private let instantSelectManager:InstantPageSelectManager = {
    let manager = InstantPageSelectManager()
    return manager
}()

private class InstantViewContentInteractive : InteractionContentViewProtocol {
    
    
    private let callback:(AnyHashable)->NSView?
    init(_ callback:@escaping(AnyHashable)->NSView?) {
        self.callback = callback
    }
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        return callback(stableId)
    }
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        
    }
    
    public func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    public func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
}

class InstantPageSelectText : NSObject {
    
    private var beginInnerLocation:NSPoint = NSMakePoint(-1, -1)
    private var endInnerLocation:NSPoint = NSMakePoint(-1, -1)
    private let scroll:ScrollView
    private var deselect:Bool = false
    private var started:Bool = false
    private var startMessageId:MessageId? = nil
    private var interactive: InstantViewContentInteractive?
    
    init(_ scroll:ScrollView) {
        self.scroll = scroll
    }
    
    
    func initializeHandlers(for window:Window, instantLayout: InstantPageLayout, instantPage: InstantPage, account: Account, updateLayout: @escaping()->Void, openUrl:@escaping(InstantPageUrlItem) -> Void, itemsInRect:@escaping(NSRect) -> [InstantPageItem], effectiveRectForItem:@escaping(InstantPageItem)-> NSRect) {
        window.removeAllHandlers(for: self)
        
        
        window.set(mouseHandler: { [weak self, weak window] event -> KeyHandlerResult in
            
            
            let isInDocument = self?.scroll.documentView?.isInnerView(window?.contentView?.hitTest(event.locationInWindow)) ?? false
            
            self?.started = false
            _ = window?.makeFirstResponder(nil)
            if isInDocument {
                if let scroll = self?.scroll, let superview = scroll.superview, let documentView = scroll.documentView, let window = window {
                    let point = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                    let documentPoint = documentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                    if !NSPointInRect(point, scroll.frame) {
                        self?.beginInnerLocation = NSZeroPoint
                    } else {
                        self?.beginInnerLocation = documentPoint
                    }
                    self?.started = self?.beginInnerLocation != NSZeroPoint
                    updateLayout()
                }
            }
            return .invokeNext
            
        }, with: self, for: .leftMouseDown, priority: .modal)
        
        window.set(mouseHandler: { [weak self, weak window] event -> KeyHandlerResult in
            
            self?.started = false
            let isInDocument = self?.scroll.documentView?.isInnerView(window?.contentView?.hitTest(event.locationInWindow)) ?? false
            if isInDocument {
                if let documentView = self?.scroll.documentView {
                    if !instantSelectManager.isEmpty {
                        let textView = NSTextView()
                        textView.isSelectable = false
                        textView.isEditable = false
                        textView.isFieldEditor = false
                        textView.textStorage?.setAttributedString(instantSelectManager.attributedString)
                        if let menu = textView.menu {
                            NSMenu.popUpContextMenu(menu, with: event, for: documentView)
                        }
                        
                    }
                }
            }
            
            return .invoked
        }, with: self, for: .rightMouseDown, priority: .modal)
        
        window.set(mouseHandler: { [weak self, weak window] event -> KeyHandlerResult in
            
            let isInDocument = self?.scroll.documentView?.isInnerView(window?.contentView?.hitTest(event.locationInWindow)) ?? false
            
            guard isInDocument else {
                return .rejected
            }
            
            let result: KeyHandlerResult
            
            self?.beginInnerLocation = NSZeroPoint

            let point = self?.scroll.documentView?.convert(event.locationInWindow, from: nil) ?? NSZeroPoint
            
            
            let textItem = itemsInRect(NSMakeRect(point.x, point.y, 1, 1)).compactMap({$0 as? InstantPageTextItem}).first // instantLayout.items(in: NSMakeRect(point.x, point.y, 1, 1)).filter({$0 is InstantPageTextItem}).map({$0 as! InstantPageTextItem}).first
        
            let item = itemsInRect(NSMakeRect(point.x, point.y, 1, 1)).first

            _ = window?.makeFirstResponder(instantSelectManager)
            
            if event.clickCount == 2, let item = textItem {
                
                let itemsRect = NSMakeRect(max(point.x, 0), max(point.y, 0), 1, 1)

                
                instantSelectManager.removeAll()
                
                for line in item.lines {
                    
                    let itemFrame = effectiveRectForItem(item)
                    
                    var minX:CGFloat = item.frame.minX
                    switch item.alignment {
                    case .center:
                        minX += floorToScreenPixels(scaleFactor: System.backingScale, (item.frame.width - line.frame.width) / 2)
                    default:
                        break
                    }
                    
                    let rect = NSMakeRect(itemFrame.minX, itemsRect.minY < itemFrame.minY ? 0 : itemsRect.minY - itemFrame.minY, itemsRect.width ,itemsRect.minY < itemFrame.minY ? min(itemsRect.maxY - itemFrame.minY, itemFrame.height) : itemsRect.minY < itemFrame.minY ? min(itemFrame.maxY - itemsRect.minY, itemFrame.height) : itemsRect.height)
                    
  
                    let beginX = point.x - minX
                    
                    if rect.intersects(line.frame) {
                        instantSelectManager.add(line: line, attributedString: line.selectWord(in: NSMakePoint(beginX, 0), boundingWidth: itemFrame.width, alignment: item.alignment, rect: rect))
                    }
                    
                }
                result = .rejected
            } else if event.clickCount == 3, let textItem = textItem {
                instantSelectManager.removeAll()
                for line in textItem.lines {
                    instantSelectManager.add(line: line, attributedString: line.selectText(in: NSMakeRect(0, 0, line.frame.width, 1), boundingWidth: textItem.frame.width, alignment: textItem.alignment))
                }
                result = .rejected
            } else if event.clickCount == 1 {
                if let item = textItem, instantSelectManager.isEmpty {
                    let itemFrame = effectiveRectForItem(item)

                    let p = NSMakePoint(point.x - itemFrame.minX, point.y - itemFrame.minY)
                    if let link = item.linkAt(point: p) {
                        openUrl(link)
                    }
                    result = .rejected

                } else if let item = item, instantSelectManager.isEmpty {
                    let items = instantLayout.items
                    if item.isInteractive {
                        let medias = items.filter({$0.isInteractive}).reduce([], { current, item -> [InstantPageMedia] in
                            var current = current
                            current.append(contentsOf: item.medias)
                            return current
                        })
                        
                        self?.interactive = InstantViewContentInteractive({ stableId in
                            if let index = stableId.base as? Int {
                                for item in items {
                                    if let _ = item.medias.filter({$0.index == index}).first {
                                        if let subviews = self?.scroll.documentView?.subviews {
                                            for subview in subviews {
                                                if !NSIsEmptyRect(subview.visibleRect), let subview = subview as? InstantPageView, item.matchesView(subview) {
                                                    return subview as? NSView
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            return nil
                        })
                        
                        var index = medias.index(of: item.medias.first!)!
                        
                        let view = self?.interactive?.contentInteractionView(for: AnyHashable(index), animateIn: false)
                        
                        if let view = view as? InstantPageSlideshowView {
                            index += view.indexOfDisplayedSlide
                        }
                        
                        if let file = medias[index].media as? TelegramMediaFile, file.isMusic || file.isVoice {
                            
                            if view?.hitTest(point) is RadialProgressView, let view = view as? InstantPageAudioView {
                                if view.controller != nil {
                                    view.controller?.playOrPause()
                                } else {
                                    let audio = APSingleResourceController(account: account, wrapper: view.wrapper, streamable: true)
                                    view.controller = audio
                                    audio.start()
                                }
                            }
                            return .invokeNext
                        }
                        
                        if let v = view?.hitTest(point) as? RadialProgressView {
                            switch v.state {
                            case .Fetching:
                                return .invokeNext
                            case .Remote:
                                return .invokeNext
                            default:
                                break
                            }
                        }
                        
                       
                        showInstantViewGallery(account: account, medias: medias, firstIndex: index, self?.interactive)
               
                        
                        result = .rejected
                        
                    } else {
                        result = .invokeNext
                    }
                } else {
                    result = .invokeNext
                }
            } else {
                result = .invokeNext
            }
            
            if result == .invokeNext {
                Queue.mainQueue().justDispatch(updateLayout)
            } else {
                updateLayout()
            }
            
            
            return result
        }, with: self, for: .leftMouseUp, priority: .modal)
        
        window.set(mouseHandler: { [weak self, weak window] event -> KeyHandlerResult in
            
            let isInDocument = self?.scroll.documentView?.isInnerView(window?.contentView?.hitTest(event.locationInWindow)) ?? false
            
            guard isInDocument else {
                return .rejected
            }
            
            let point = self?.scroll.documentView?.convert(event.locationInWindow, from: nil) ?? NSZeroPoint
            
            
            let items = itemsInRect(NSMakeRect(point.x, point.y, 1, 1)).compactMap { $0 as? InstantPageTextItem }
            
            if items.isEmpty {
                NSCursor.arrow.set()
            } else {
                if let item = items.first {
                    let itemRect = effectiveRectForItem(item)
                    let p = NSMakePoint(point.x - itemRect.minX, point.y - itemRect.minY)
                    if let _ = item.linkAt(point: p) {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.iBeam.set()
                    }
                }
                
            }
            return .invokeNext
        }, with: self, for: .mouseMoved, priority:.modal)
        
        window.set(mouseHandler: { [weak self, weak window] event -> KeyHandlerResult in
            self?.endInnerLocation = self?.scroll.documentView?.convert(event.locationInWindow, from: nil) ?? NSZeroPoint
            
            
            if self?.started == true {
                
                self?.scroll.contentView.autoscroll(with: event)
                
                if window?.firstResponder != instantSelectManager {
                    _ = window?.makeFirstResponder(instantSelectManager)
                }
                self?.runSelector(instantLayout, updateLayout: updateLayout, itemsInRect: itemsInRect, effectiveRectForItem: effectiveRectForItem)
                return .invoked
            }
            return .invokeNext
        }, with: self, for: .leftMouseDragged, priority:.modal)
    }
    
    private func runSelector(_ instantPage: InstantPageLayout, updateLayout: @escaping()->Void, itemsInRect:@escaping(NSRect) -> [InstantPageItem], effectiveRectForItem:@escaping(InstantPageItem)-> NSRect) {
        
        
        instantSelectManager.removeAll()
        
        let itemsRect = NSMakeRect(max(min(endInnerLocation.x, beginInnerLocation.x), 0), max(min(endInnerLocation.y, beginInnerLocation.y), 0), abs(endInnerLocation.x - beginInnerLocation.x), abs(endInnerLocation.y - beginInnerLocation.y))
        
        guard itemsRect.size != NSZeroSize else {
            return
        }
        
        let items = itemsInRect(itemsRect).compactMap { $0 as? InstantPageTextItem }
        

        let reversed = endInnerLocation.y < beginInnerLocation.y
        
        

        let lines = items.reduce([]) { (current, item) -> [InstantPageTextLine] in
            let itemRect = effectiveRectForItem(item)
            
            let rect = NSMakeRect(itemRect.minX, itemsRect.minY < itemRect.minY ? 0 : itemsRect.minY - itemRect.minY, itemsRect.width ,itemsRect.minY < itemRect.minY ? min(itemsRect.maxY - itemRect.minY, itemRect.height) : itemsRect.minY < itemRect.minY ? min(itemRect.maxY - itemsRect.minY, itemRect.height) : itemsRect.height)
            
            let lines = item.lines.filter { line in
                return line.frame.intersects(rect)
            }
            
            return current + lines
        }
        
        for i in 0 ..< lines.count  {
            let line = lines[i]
            
            let item = items.first(where: {$0.lines.contains(where: {$0 === line})})!

            let itemRect = effectiveRectForItem(item)
            
            var minX:CGFloat = itemRect.minX
            switch item.alignment {
            case .center:
                minX += floorToScreenPixels(scaleFactor: System.backingScale, (itemRect.width - line.frame.width) / 2)
            default:
                break
            }
            
            let selectedText:NSAttributedString
            
            let beginX = beginInnerLocation.x - minX
            let endX = endInnerLocation.x - minX

            let firstLine: InstantPageTextLine = reversed ? lines.last! : lines.first!
            let endLine: InstantPageTextLine = !reversed ? lines.last! : lines.first!
            let multiple: Bool = lines.count > 1
            
            if firstLine === line {
                if !reversed {
                    if multiple {
                        selectedText = line.selectText(in: NSMakeRect(beginX, 0, line.frame.width - beginX, 0), boundingWidth: line.frame.width, alignment: .left)
                    } else {
                        selectedText = line.selectText(in: NSMakeRect(beginX, 0, endX - beginX, 0), boundingWidth: line.frame.width, alignment: .left)
                    }
                } else {
                    if multiple {
                        selectedText = line.selectText(in: NSMakeRect(0, 0, beginX, 0), boundingWidth: line.frame.width, alignment: .left)
                    } else {
                        selectedText = line.selectText(in: NSMakeRect(endX, 0, beginX - endX, 0), boundingWidth: line.frame.width, alignment: .left)
                    }
                }
                
            } else if endLine === line {
                if !reversed {
                    selectedText = line.selectText(in: NSMakeRect(0, 0, endX, 0), boundingWidth: line.frame.width, alignment: .left)
                } else {
                    selectedText = line.selectText(in: NSMakeRect(endX, 0, line.frame.maxX - endX, 0), boundingWidth: line.frame.width, alignment: .left)
                }
            } else {
                selectedText = line.selectText(in: NSMakeRect(0, 0, line.frame.width, 0), boundingWidth: line.frame.width, alignment: .left)
            }
            
            instantSelectManager.add(line: line, attributedString: selectedText)
        }

        updateLayout()
        
    }
    
    
    func removeHandlers(for window:Window) {
        window.removeAllHandlers(for: self)

    }
    
}
