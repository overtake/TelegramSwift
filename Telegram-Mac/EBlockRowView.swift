//
//  EBlockRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import InAppSettings

private let xAdd:CGFloat = 41
private let yAdd:CGFloat = 34


private final class LineLayer : SimpleLayer {
    
    struct Key: Hashable {
        let value: Int
        let index: Int
    }
    
    private let content = SimpleLayer()
    init(emoji: NSAttributedString) {
        self.emoji = emoji
        super.init()
        addSublayer(content)
        let signal = generateEmoji(emoji) |> deliverOnMainQueue
        
        let value = cachedEmoji(emoji: emoji.string, scale: System.backingScale)
        
        content.frame = NSMakeSize(xAdd, yAdd).bounds.focus(NSMakeSize(30, 33))
        content.contents = value
        if self.contents == nil {
            self.disposable = signal.start(next: { [weak self] image in
                self?.content.contents = image
                if let image = image {
                    cacheEmoji(image, emoji: emoji.string, scale: System.backingScale)
                }
            })
        }
    }
    
    deinit {
        disposable?.dispose()
    }
    
    private var disposable: Disposable?
    
    let emoji: NSAttributedString
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EBlockRowView: TableRowView {
    
    private var popover: NSPopover?
    
    var selectedEmoji:String = ""
    
    private let longHandle = MetaDisposable()
    private var useEmoji: Bool = true
    private let content = Control()
    
    
    private var lines:[LineLayer.Key : LineLayer] = [:]
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(content)

        
        content.set(handler: { [weak self] _ in
            self?.updateDown()
        }, for: .Down)
        
        content.set(handler: { [weak self] _ in
            self?.updateDragging()
        }, for: .MouseDragging)
        
        content.set(handler: { [weak self] _ in
            self?.updateUp()
        }, for: .Up)
    }
    
    private var currentDownItem: (LineLayer, NSAttributedString, Bool)?
    private func updateDown() {
        if let item = itemUnderMouse {
            self.currentDownItem = (item.0, item.1, true)
        }
        if let itemUnderMouse = self.currentDownItem {
            itemUnderMouse.0.animateScale(from: 1, to: 0.85, duration: 0.2, removeOnCompletion: false)
        }
    }
    private func updateDragging() {
        if let current = self.currentDownItem {
            if self.itemUnderMouse?.1 != current.1, current.2  {
                current.0.animateScale(from: 0.85, to: 1, duration: 0.2, removeOnCompletion: true)
                self.currentDownItem?.2 = false
            } else if !current.2, self.itemUnderMouse?.1 == current.1 {
                current.0.animateScale(from: 1, to: 0.85, duration: 0.2, removeOnCompletion: false)
                self.currentDownItem?.2 = true
            }
        }
    }
    private func updateUp() {
        if let itemUnderMouse = self.currentDownItem {
            itemUnderMouse.0.animateScale(from: 0.85, to: 1, duration: 0.2, removeOnCompletion: true)
            if itemUnderMouse.1 == self.itemUnderMouse?.1 {
                self.click()
            }
        }
        self.currentDownItem = nil
    }
    
    private var itemUnderMouse: (LineLayer, NSAttributedString)? {
        guard let window = self.window else {
            return nil
        }
        let point = self.content.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        

        let firstLayer = self.lines.first(where: { layer in
            return NSPointInRect(point, layer.1.frame)
        })?.value
        
        if let firstLayer = firstLayer {
            return (firstLayer, firstLayer.emoji)
        }
        
        return nil
    }
    
    private func click() {
        if let currentDownItem = currentDownItem, let item = item as? EBlockItem {
            let wrect = self.content.convert(currentDownItem.0.frame, to: nil)
            item.selectHandler(currentDownItem.1.string, wrect)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        content.frame = bounds
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EBlockItem else {
            return
        }
        
        updateLines(item: item, animated: animated)
    }
    
   
    
    func updateLines(item: EBlockItem, animated: Bool) {
        
        var validIds: [LineLayer.Key] = []
        var point: NSPoint = NSMakePoint(10, 0)
        var index: Int = 0
        for line in item.lineAttr {
            for symbol in line {
                let id = LineLayer.Key(value: symbol.string.hashValue, index: index)
                let view: LineLayer
                if let current = self.lines[id] {
                    view = current
                } else {
                    view = LineLayer(emoji: symbol)
                    self.lines[id] = view
                    self.content.layer?.addSublayer(view)
                    
                    if animated {
                        view.animateScale(from: 0.1, to: 1, duration: 0.3, timingFunction: .spring)
                        view.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                let size = NSMakeSize(xAdd, yAdd)
                view.frame = CGRect(origin: point, size: size)
                point.x += xAdd
                
                validIds.append(id)
                index += 1
            }
            point.y += yAdd
            point.x = 10
        }
        
        
        var removeKeys: [LineLayer.Key] = []
        for (key, itemLayer) in self.lines {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            self.lines.removeValue(forKey: key)
        }
    }
    
    
}
