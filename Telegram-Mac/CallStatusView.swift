//
//  CallStatusView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

enum CallControllerStatusValue: Equatable {
    case text(String, Int32?)
    case timer(Double, Int32?)
}


class CallStatusView: View {
    
    
    private var statusTimer: SwiftSignalKit.Timer?
    
    var status: CallControllerStatusValue = .text("", nil) {
        didSet {
            if self.status != oldValue {
                self.statusTimer?.invalidate()
                if case .timer = self.status {
                    self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        self?.updateStatus()
                        }, queue: Queue.mainQueue())
                    self.statusTimer?.start()
                    self.updateStatus()
                } else {
                    self.updateStatus()
                }
            }
        }
    }
    
    private let statusTextView:NSTextField = NSTextField()
    private let receptionView = CallReceptionControl(frame: NSMakeRect(0, 0, 24, 10))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        statusTextView.font = .normal(18)
        statusTextView.drawsBackground = false
        statusTextView.backgroundColor = .random
        statusTextView.textColor = nightAccentPalette.text
        statusTextView.isSelectable = false
        statusTextView.isEditable = false
        statusTextView.isBordered = false
        statusTextView.focusRingType = .none
        
        addSubview(statusTextView)
        addSubview(receptionView)
    }
    
    override func layout() {
        super.layout()
        if receptionView.isHidden {
            statusTextView.center()
        } else {
            receptionView.centerY(x: 0)
            statusTextView.centerY(x: receptionView.frame.maxX)
        }
        
    }
    
    func sizeThatFits(_ size: NSSize) -> NSSize {
        let textSize = statusTextView.sizeThatFits(size)
        statusTextView.setFrameSize(textSize)
        return NSMakeSize(max(textSize.width, 60) + 28, size.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    deinit {
        statusTimer?.invalidate()
    }
    
    func updateStatus() {
        var statusText: String = ""
        switch self.status {
        case let .text(text, reception):
            statusText = text
            if let reception = reception {
                self.receptionView.reception = reception
            }
            self.receptionView.isHidden = reception == nil
        case let .timer(referenceTime, reception):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
            }
            statusText = durationString
            if let reception = reception {
                self.receptionView.reception = reception
            }
            self.receptionView.isHidden = reception == nil
        }
        statusTextView.stringValue = statusText
        statusTextView.sizeToFit()
        statusTextView.alignment = .center
        needsLayout = true
    }
   
}
