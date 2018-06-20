//
//  WPContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac


class WPContentView: View, MultipleSelectable {
    
    
    var header: String? {
        return nil
    }

    
    var textView:TextView = TextView()

    
    private(set) var containerView:View = View()
    
    private(set) var content:WPLayout?
    
    private var instantPageButton: TitleButton? = nil
    
    override var backgroundColor: NSColor {
        didSet {
            
            containerView.backgroundColor = backgroundColor
            for subview in containerView.subviews {
                subview.background = backgroundColor
            }
            if let content = content {
                instantPageButton?.layer?.borderColor = content.presentation.activity.cgColor
                instantPageButton?.set(color: content.presentation.activity, for: .Normal)
                
                if content.hasInstantPage {
                    instantPageButton?.set(image: content.presentation.ivIcon, for: .Normal)
                    instantPageButton?.set(image: content.presentation.ivIcon, for: .Highlight)
                } else {
                    instantPageButton?.removeImage(for: .Normal)
                    instantPageButton?.removeImage(for: .Highlight)
                }
            }
            
            setNeedsDisplay()
        }
    }
    
    var selectableTextViews: [TextView] {
        return [textView]
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let content = content else {return}
        
        ctx.setFillColor(content.presentation.activity.cgColor)
        let radius:CGFloat = 1.0
        ctx.fill(NSMakeRect(0, radius, 2, layer.bounds.height - radius * 2))
        ctx.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: layer.bounds.height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
        
        if let siteName = content.siteName {
            siteName.1.draw(NSMakeRect(content.insets.left, 0, siteName.0.size.width, siteName.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        }
    }
    
    override func layout() {
        super.layout()
        if let content = self.content {
            containerView.frame = content.contentRect
            if !textView.isEqual(to: content.textLayout) {
                textView.update(content.textLayout)
            }
            textView.isHidden = content.textLayout == nil
            _ = instantPageButton?.sizeToFit(NSZeroSize, NSMakeSize(content.contentRect.width, 30), thatFit: true)
            instantPageButton?.setFrameOrigin(0, content.contentRect.height - 30)
        }
        needsDisplay = true
    }
    
    func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return convert(point, from: nil)
    }
    
    required public override init() {
        super.init()
        super.addSubview(containerView)
        addSubview(textView)
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

    func update(with layout:WPLayout) -> Void {
        self.content = layout
        
        if layout.hasInstantPage || layout.isProxyConfig {
            if instantPageButton == nil {
                instantPageButton = TitleButton()
                
                instantPageButton?.layer?.cornerRadius = .cornerRadius
                instantPageButton?.layer?.borderWidth = 1
                instantPageButton?.disableActions()
                
             addSubview(instantPageButton!)
            }
            instantPageButton?.layer?.borderColor = theme.colors.blueIcon.cgColor

            instantPageButton?.set(color: theme.colors.blueIcon, for: .Normal)
         
            instantPageButton?.set(font: .medium(.title), for: .Normal)
            instantPageButton?.set(background: .clear, for: .Normal)
            instantPageButton?.set(text: layout.isProxyConfig ? L10n.chatApplyProxy : L10n.chatInstantView, for: .Normal)
            _ = instantPageButton?.sizeToFit(NSZeroSize, NSMakeSize(layout.contentRect.width, 30), thatFit: false)
            
            instantPageButton?.removeAllHandlers()
            instantPageButton?.set(handler : { [weak layout] _ in
                if let content = layout {
                    if content.hasInstantPage {
                        showInstantPage(InstantPageViewController(content.account, webPage: content.parent.media[0] as! TelegramMediaWebpage, message: content.parent.text))
                    } else if let proxyConfig = content.proxyConfig {
                        applyExternalProxy(proxyConfig, postbox: content.account.postbox, network: content.account.network)
                    }
                }
            }, for: .Click)
            
        } else {
            instantPageButton?.removeFromSuperview()
            instantPageButton = nil
        }
        
        self.needsLayout = true
    }
    
    func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self.containerView
    }
    

}
