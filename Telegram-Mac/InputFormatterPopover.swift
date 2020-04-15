//
//  InputFormatterPopover.swift
//  Telegram
//
//  Created by keepcoder on 27/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


private enum InputFormatterViewState {
    case normal
    case link
}
private class InputFormatterView : NSView {
    let link: TitleButton = TitleButton()
    
    let linkField: NSTextField = NSTextField(frame: NSMakeRect(0, 0, 30, 18))
    let dismissLink:ImageButton = ImageButton()
    
    fileprivate var state: InputFormatterViewState = .link
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(linkField)
        addSubview(link)
        addSubview(dismissLink)
 
        dismissLink.set(image: theme.icons.recentDismiss, for: .Normal)
        _ = dismissLink.sizeToFit()
        
      //  linkField.placeholderAttributedString = NSAttributedString.initialize(string: L10n.inputFormatterSetLink, color: theme.colors.grayText, font: .normal(.text))
        linkField.font = .normal(.text)
        linkField.wantsLayer = true
        linkField.isEditable = true
        linkField.isSelectable = true
        linkField.maximumNumberOfLines = 1
        linkField.backgroundColor = .clear
        linkField.drawsBackground = false
        linkField.isBezeled = false
        linkField.isBordered = false
        linkField.focusRingType = .none
        
        
     //   linkField.delegate = self
        
        link.set(handler: { [weak self] _ in
            self?.change(state: .link, animated: true)
        }, for: .Click)
        


        
        dismissLink.centerY(x: frame.width - 10 - dismissLink.frame.width)
        dismissLink.isHidden = true
        
        change(state: .link, animated: false)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        
        if commandSelector == #selector(insertNewline(_:)) {
            
            return true
        }
        
        return false
    }
    
    func change(state: InputFormatterViewState, animated: Bool) {
        self.state = state
        switch state {
        case .normal:
            link.isHidden = false
            link._change(opacity: 1.0, animated: animated)
            dismissLink._change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.dismissLink.isHidden = true
                }
            })
            linkField._change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.linkField.isHidden = true
                }
            })
        case .link:
            linkField.isHidden = false
            dismissLink.isHidden = false
            linkField._change(opacity: 1.0, animated: animated)
            dismissLink._change(opacity: 1.0, animated: animated)
            
            link._change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.link.isHidden = true
                }
            })
            
        }
    }
    
    override func layout() {
        super.layout()
        
        linkField.setFrameSize(frame.width - link.frame.width - 10, 18)
        linkField.centerY(x: 10)
        linkField.textView?.frame = linkField.bounds
        switch state {
        case .normal:
            link.centerY(x: 0)
        case .link:
            link.centerY(x: frame.width - link.frame.width)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class InputFormatterArguments {
    let link:(String)->Void
    init(link:@escaping(String)->Void) {
        self.link = link
    }
}

private final class FormatterViewController : NSViewController {
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

class InputFormatterPopover: NSPopover {
    
    
    
    private let window: Window
    init(_ arguments: InputFormatterArguments, window: Window) {
        self.window = window
        super.init()
        let controller = FormatterViewController()
        let view = InputFormatterView(frame: NSMakeRect(0, 0, 240, 40))
        
        
        
        
        controller.view = view
        
        view.dismissLink.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        self.contentViewController = controller
        
        window.set(handler: { [weak view] () -> KeyHandlerResult in
            if let view = view {
                if view.state == .link {
                    let attr = view.linkField.attributedStringValue.mutableCopy() as! NSMutableAttributedString
                    
                    attr.detectLinks(type: [.Links])
                    
                    var url:String? = nil
                    
                    attr.enumerateAttribute(NSAttributedString.Key.link, in: attr.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                        
                        if let value = value as? inAppLink {
                            switch value {
                            case let .external(link, _):
                                url = link
                                break
                            default:
                                break
                            }
                        }
                        
                        let s: ObjCBool = (url != nil) ? true : false
                        stop.pointee = s
                        
                    })
                    
                    if let url = url {
                        arguments.link(url)
                    } else {
                        view.shake()
                    }
   
                }
                return  .invoked
            }
            return .rejected
        }, with: self, for: .Return, priority: .modal)
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, for: .Escape, priority: .modal)
        

    }
    
    deinit {
        window.removeAllHandlers(for: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
