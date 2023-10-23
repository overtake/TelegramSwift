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

    
    var textView:TextView = TextView()

    
    private(set) var containerView:View = View()
    private(set) var content:WPLayout?
    private var action: TitleButton? = nil

    
    var selectableTextViews: [TextView] {
        return []
    }
    
    func previewMediaIfPossible() -> Bool {
        return false
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let content = content else {return}
        
        ctx.setFillColor(PeerNameColorCache.value.get(content.presentation.activity, flipped: true).cgColor)
        let radius:CGFloat = 3.0
        
        ctx.fill(NSMakeRect(-radius, 0, radius * 2, layer.bounds.height))
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
        }
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
            current.borderColor = layout.presentation.activity.0.withAlphaComponent(0.1)
            current.set(color: layout.presentation.activity.0, for: .Normal)
            current.set(font: .medium(.title), for: .Normal)
            current.set(background: .clear, for: .Normal)
            current.set(text: text, for: .Normal)
            _ = current.sizeToFit(NSZeroSize, NSMakeSize(layout.contentRect.width, 36), thatFit: false)
            
            current.set(color: layout.presentation.activity.0, for: .Normal)
            if layout.hasInstantPage {
                current.set(image: NSImage.init(named: "Icon_ChatIV")!.precomposed(layout.presentation.activity.0), for: .Normal)
            } else {
                current.removeImage(for: .Normal)
            }
        } else if let view = self.action {
            performSubviewRemoval(view, animated: animated)
            self.action = nil
        }
        let color = self.backgroundColor
        self.backgroundColor = layout.presentation.activity.0.withAlphaComponent(0.1) //color
        self.needsLayout = true
    }
    
    func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self.containerView
    }
    
    var mediaContentView: NSView? {
        return containerView
    }

}
