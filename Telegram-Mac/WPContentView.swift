//
//  WPContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore



class WPContentView: Control, MultipleSelectable, ModalPreviewRowViewProtocol {
    
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        return nil
    }
    
    var header: String? {
        return nil
    }

    private let dashLayer = DashLayer()
    
    var textView:TextView = TextView()

    
    private(set) var containerView:View = View()
    private(set) var content:WPLayout?
    private var action: TitleButton? = nil
    
    private var closeAdView: ImageButton?

    
    var selectableTextViews: [TextView] {
        return []
    }
    
    func previewMediaIfPossible() -> Bool {
        return false
    }
    

    override func layout() {
        super.layout()
        if let content = self.content {
            containerView.frame = content.contentRect
            textView.update(content.textLayout)
            textView.isHidden = content.textLayout == nil
            if let action = action {
                _ = action.sizeToFit(NSZeroSize, NSMakeSize(content.contentRect.width, 36), thatFit: true)
                action.setFrameOrigin(0, content.contentRect.height - action.frame.height + content.imageInsets.top * 2)
            }
            if let closeAdView = closeAdView {
                closeAdView.setFrameOrigin(NSMakePoint(self.frame.width - closeAdView.frame.width - 0, 0))
            }
        }
        dashLayer.frame = NSMakeRect(0, 0, 3, frame.height)
        needsDisplay = true
    }
    
    func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return convert(point, from: nil)
    }
    
    required public override init() {
        super.init()
        
        self.isDynamicColorUpdateLocked = true
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        super.addSubview(containerView)
        self.layer?.addSublayer(dashLayer)
        addSubview(textView)
        
        
        self.scaleOnClick = true
        
        layer?.cornerRadius = .cornerRadius
        
        set(handler: { [weak self] _ in
            self?.content?.invokeAction()
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func addSubview(_ view: NSView) {
        containerView.addSubview(view)
    }
    
    deinit {
        containerView.removeAllSubviews()
    }
    
    func updateMouse() {
        
    }

    func update(with layout:WPLayout, animated: Bool) -> Void {
        self.content = layout
        
        if let text = layout.action_text {
            let current: TitleButton
            if let view = self.action {
                current = view
            } else {
                current = TitleButton()
                self.action = current
                current.disableActions()
                addSubview(current)
                current.userInteractionEnabled = false
                
            }

            current.border = [.Top]
            current.borderColor = layout.presentation.activity.main.withAlphaComponent(0.1)
            current.set(color: layout.presentation.activity.main, for: .Normal)
            current.set(font: .medium(.title), for: .Normal)
            current.set(background: .clear, for: .Normal)
            current.set(text: text, for: .Normal)
            _ = current.sizeToFit(NSZeroSize, NSMakeSize(layout.contentRect.width, 36), thatFit: false)
            
            current.set(color: layout.presentation.activity.main, for: .Normal)
            if layout.hasInstantPage {
                current.set(image: NSImage.init(named: "Icon_ChatIV")!.precomposed(layout.presentation.activity.main), for: .Normal)
            } else {
                current.removeImage(for: .Normal)
            }
        } else if let view = self.action {
            performSubviewRemoval(view, animated: animated)
            self.action = nil
        }
        
        if let _ = layout.parent.adAttribute {
            //
            let current: ImageButton
            if let view = self.closeAdView {
                current = view
            } else {
                current = ImageButton()
                current.autohighlight = false
                current.scaleOnClick = true
                self.closeAdView = current
                super.addSubview(current)
            }
            current.removeAllHandlers()
            current.set(handler: { [weak layout] _ in
                layout?.premiumBoarding()
            }, for: .Click)
            current.set(image: NSImage(named: "Icon_GradientClose")!.precomposed(layout.presentation.activity.main), for: .Normal)
            current.sizeToFit()
            
        } else if let view = self.closeAdView {
            performSubviewRemoval(view, animated: animated)
            self.closeAdView = nil
        }
        
        self.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.1) //color
        self.needsLayout = true
        
        self.dashLayer.colors = layout.presentation.activity
    }
    
    func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self.containerView
    }
    
    var mediaContentView: NSView? {
        return containerView
    }

}
