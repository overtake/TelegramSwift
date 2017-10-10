//
//  UsernameInputRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 12/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
class UsernameInputRowItem: GeneralInputRowItem {
    let status:AddressNameValidationStatus?
    let changeHandler:(String)->Void
    let disposable:MetaDisposable = MetaDisposable()
    init(_ initialSize: NSSize, stableId: AnyHashable, placeholder: String, limit: Int32, status:AddressNameValidationStatus?, text:String, changeHandler: @escaping (String) -> Void, holdText:Bool = false) {
        self.status = status
        self.changeHandler = changeHandler
        super.init(initialSize, stableId: stableId, placeholder: placeholder, text: text, limit: limit, holdText: holdText)
    }
    
    override func inputTextChanged(_ text:String) {
        self.changeHandler(text)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewClass() -> AnyClass {
        return UsernameInputRowView.self
    }
    
}



class UsernameInputRowView: GeneralInputRowView {
    let imageView = ImageView()
    let indicator:ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 15, 15))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        textView.isSingleLine = true
        textView.isWhitespaceDisabled = true
        addSubview(imageView)
        addSubview(indicator)
        imageView.isHidden = true
        indicator.isHidden = true
        
    }
    
    override func layout() {
        super.layout()
        if let item = item as? UsernameInputRowItem {
            imageView.setFrameOrigin(textView.frame.maxX - imageView.frame.width, textView.frame.maxY - imageView.frame.height - item.insets.bottom)
            indicator.setFrameOrigin(textView.frame.maxX - indicator.frame.width, textView.frame.maxY - indicator.frame.height - item.insets.bottom)
            if !imageView.isHidden || !indicator.isHidden {
                textView.setFrameSize(frame.width - item.insets.right - 30, textView.frame.height)
            } else {
                textView.setFrameSize(frame.width - item.insets.right, textView.frame.height)
            }
        }
    }
    
    override func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        super.textViewHeightChanged(height, animated: animated)
        imageView.change(pos: NSMakePoint(textView.frame.maxX - imageView.frame.width, textView.frame.maxY - imageView.frame.height), animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        if let item = item as? UsernameInputRowItem {
            imageView.image =  theme.icons.generalSelect
            imageView.sizeToFit()
            
           
            if let status = item.status {
                switch status {
                case .checking:
                    indicator.isHidden = false
                    indicator.animates = true
                    imageView.isHidden = true
                case .availability:
                    imageView.isHidden = false
                    imageView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    indicator.isHidden = true
                    indicator.animates = false
                default:
                    imageView.isHidden = true
                    indicator.isHidden = true
                    indicator.animates = false
                }
            } else {
                imageView.isHidden = true
                indicator.isHidden = true
                indicator.animates = false
            }
        }
        super.set(item: item, animated: animated)
    }
}
