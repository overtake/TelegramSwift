//
//  GroupCallRecorderRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore


final class GroupCallRecorderRowItem : GeneralRowItem {
    
    fileprivate let account: Account
    fileprivate let startedRecordedTime: Int32?
    fileprivate let start: ()->Void
    fileprivate let stop: ()->Void

    fileprivate let titleLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, account: Account, startedRecordedTime: Int32?, customTheme: GeneralRowItem.Theme? = nil, start:@escaping()->Void, stop:@escaping()->Void) {
        self.startedRecordedTime = startedRecordedTime
        self.start = start
        self.stop = stop
        self.account = account
        
        let text: String
        if let _ = startedRecordedTime {
            text = strings().voiceChatStopRecording
        } else {
            text = strings().voiceChatStartRecording
        }
        self.titleLayout = TextViewLayout(.initialize(string: text, color: customTheme?.textColor ?? theme.colors.text, font: .normal(.text)))
        
        super.init(initialSize, height: 42, stableId: stableId, viewType: viewType, customTheme: customTheme)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        titleLayout.measure(width: blockWidth - 80)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallRecorderRowView.self
    }
}

final class GroupCallRecorderRowView : GeneralContainableRowView {
    private let textView: TextView = TextView()
    private var indicator:View?
    private var statusTextView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Highlight)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Normal)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] control in
            if let item = self?.item as? GroupCallRecorderRowItem {
                if item.startedRecordedTime != nil {
                    item.stop()
                } else {
                    item.start()
                }
            }
        }, for: .Click)

        
    }
    
    override func updateColors() {
        super.updateColors()
        containerView.backgroundColor = containerView.controlState != .Highlight ? backdorColor : highlightColor
        textView.backgroundColor = containerView.backgroundColor
        statusTextView?.backgroundColor = containerView.backgroundColor
    }
    
    
    var highlightColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.highlightColor
        }
        return theme.colors.grayHighlight
    }
    override var backdorColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.backgroundColor
        }
        return super.backdorColor
    }
    
    var textColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.textColor
        }
        return theme.colors.text
    }
    var secondaryColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.grayTextColor
        }
        return theme.colors.grayText
    }
    
    override func layout() {
        super.layout()
        
        if let statusView = statusTextView {
            statusView.setFrameOrigin(statusPos)
        }
        if let indicator = indicator {
            indicator.setFrameOrigin(indicatorPos)
        }
        textView.setFrameOrigin(titlePos)
    }
    
    var titlePos: NSPoint {
        guard let item = item as? GroupCallRecorderRowItem else {
            return .zero
        }
        if let _ = statusTextView {
            return NSMakePoint(item.viewType.innerInset.left, 5)
        } else {
            return NSMakePoint(item.viewType.innerInset.left, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - textView.frame.height) / 2))
        }
    }
    
    var indicatorPos: NSPoint {
        guard let item = item as? GroupCallRecorderRowItem else {
            return .zero
        }
        if let indicator = indicator, let statusView = statusTextView {
            return NSMakePoint(item.viewType.innerInset.left, containerView.frame.height - statusView.frame.height - 5 + ((statusView.frame.height - indicator.frame.height) / 2))
        }
        return .zero
    }
    var statusPos: NSPoint {
        guard let item = item as? GroupCallRecorderRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        if let statusView = statusTextView {
            point = NSMakePoint(item.viewType.innerInset.left, containerView.frame.height - statusView.frame.height - 5)
        }
        if let indicator = indicator {
            point.x += indicator.frame.width + 4
        }
        return point
    }
    
    private var timer: SwiftSignalKit.Timer?
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallRecorderRowItem else {
            return
        }
        textView.update(item.titleLayout)
        
        if let recording = item.startedRecordedTime {
            let statusView: TextView
            if let current = self.statusTextView {
                statusView = current
            } else {
                statusView = TextView()
                statusView.userInteractionEnabled = false
                statusView.isSelectable = false
                statusView.backgroundColor = containerView.backgroundColor
                self.statusTextView = statusView
                addSubview(statusView)
                if animated {
                    statusView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            let indicator: View
            if let current = self.indicator {
                indicator = current
            } else {
                indicator = View()
                self.indicator = indicator
                indicator.setFrameSize(NSMakeSize(8, 8))
                indicator.layer?.cornerRadius = indicator.frame.height / 2
                addSubview(indicator)
                
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.timingFunction = .init(name: .easeInEaseOut)
                animation.fromValue = 0.5
                animation.toValue = 1.0
                animation.duration = 1.0
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.isRemovedOnCompletion = false
                animation.fillMode = CAMediaTimingFillMode.forwards
                
                indicator.layer?.add(animation, forKey: "opacity")
            }
            
           
            
            indicator.backgroundColor = item.customTheme?.redColor ?? theme.colors.redUI
            
            let duration:Int32 = item.account.network.getApproximateRemoteTimestamp() - recording
            let layout = TextViewLayout(.initialize(string: timerText(Int(duration)), color: secondaryColor, font: .normal(.short)))
            
            layout.measure(width: .greatestFiniteMagnitude)
            statusView.update(layout)
            textView.change(pos: titlePos, animated: animated)

            timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self, weak item] in
                if let item = item {
                    self?.set(item: item, animated: animated)
                }
            }, queue: .mainQueue())
            timer?.start()
            
        } else {
            
            timer?.invalidate()
            timer = nil
            
            if let statusView = statusTextView {
                self.statusTextView = nil
                if animated {
                    statusView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false,completion: { [weak statusView] _ in
                        statusView?.removeFromSuperview()
                    })
                } else {
                    statusView.removeFromSuperview()
                }
                textView.change(pos: titlePos, animated: animated)
            }
            if let indicator = indicator {
                self.indicator = nil
                if animated {
                    indicator.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false,completion: { [weak indicator] _ in
                        indicator?.removeFromSuperview()
                    })
                } else {
                    indicator.removeFromSuperview()
                }
            }
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
