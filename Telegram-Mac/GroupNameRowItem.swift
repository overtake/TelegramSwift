//
//  GroupNameRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class GroupNameRowItem: GeneralInputRowItem {

    init(_ initialSize: NSSize, stableId: AnyHashable, placeholder: String, text:String = "", limit: Int32 = 140, textChangeHandler:@escaping(String)->Void = {_ in}) {
        super.init(initialSize, stableId: stableId, placeholder: placeholder, limit: limit, textChangeHandler:textChangeHandler)
    }
    
    override func viewClass() -> AnyClass {
        return GroupNameRowView.self
    }
    
    override var height: CGFloat {
        return 80
    }
    
}




class GroupNameRowView : GeneralInputRowView {
    private let imageView:ImageView = ImageView()
    private let sepator:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.isSingleLine = true
        addSubview(sepator)
        addSubview(imageView)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        sepator.backgroundColor = theme.colors.border
        imageView.image = theme.icons.newChatCamera
        imageView.sizeToFit()
    }
    
    override func layout() {
        super.layout()
        textView.frame = NSMakeRect(100, 0, frame.width - 140 ,textView.frame.height)
        textView.centerY()
        imageView.setFrameOrigin(30 + floorToScreenPixels((50 - imageView.frame.width)/2.0), 17 + floorToScreenPixels((50 - imageView.frame.height)/2.0))
        sepator.frame = NSMakeRect(105, textView.frame.maxY - .borderSize, frame.width - 140, .borderSize)
    }
    
    override func textViewTextDidChange(_ string: String) {
        super.textViewTextDidChange(string)
    }
    
    override func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        textView._change(pos: NSMakePoint(100, floorToScreenPixels((frame.height - height)/2.0)), animated: animated)
        super.textViewHeightChanged(height, animated: animated)
        sepator._change(pos: NSMakePoint(105, textView.frame.maxY - .borderSize), animated: animated)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.background.cgColor)
        ctx.fill(bounds)
        ctx.setStrokeColor(theme.colors.grayIcon.cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: NSMakeRect(30, 17, 50, 50))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
