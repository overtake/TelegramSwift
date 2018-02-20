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
private class InputFormatterView : View, NSTextFieldDelegate {
    let bold: TitleButton = TitleButton()
    let italic: TitleButton = TitleButton()
    let monospace: TitleButton = TitleButton()
    let link: TitleButton = TitleButton()
    
    let linkField: NSTextField = NSTextField()
    let dismissLink:ImageButton = ImageButton()
    
    fileprivate var state: InputFormatterViewState = .link
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(linkField)
//        addSubview(bold)
//        addSubview(italic)
//        addSubview(monospace)
        addSubview(link)
        addSubview(dismissLink)
 
        dismissLink.set(image: theme.icons.recentDismiss, for: .Normal)
        _ = dismissLink.sizeToFit()
        
        linkField.placeholderAttributedString = NSAttributedString.initialize(string: "Set a Link", color: theme.colors.grayText, font: .normal(.text))
        linkField.font = .normal(.text)
        linkField.wantsLayer = true
        linkField.maximumNumberOfLines = 1
        linkField.backgroundColor = .clear
        linkField.drawsBackground = true
        linkField.isBezeled = false
        linkField.isBordered = false
        linkField.focusRingType = .none
        linkField.isHidden = true
        
        linkField.delegate = self
        
        link.set(handler: { [weak self] _ in
            self?.change(state: .link, animated: true)
        }, for: .Click)
        
        bold.set(color: theme.colors.text, for: .Normal)
        italic.set(color: theme.colors.text, for: .Normal)
        monospace.set(color: theme.colors.text, for: .Normal)
        link.set(color: theme.colors.text, for: .Normal)

        
        bold.set(font: .bold(16.0), for: .Normal)
        italic.set(font: .italic(16.0), for: .Normal)
        monospace.set(font: .code(16.0), for: .Normal)
        link.set(font: .normal(16.0), for: .Normal)
        
        bold.set(text: "Bold", for: .Normal)
        italic.set(text: "Italic", for: .Normal)
        monospace.set(text: "Code", for: .Normal)
        link.set(text: "URL", for: .Normal)

        
        bold.setFrameSize(NSMakeSize(60, 40))
        italic.setFrameSize(NSMakeSize(60, 40))
        monospace.setFrameSize(NSMakeSize(60, 40))
        link.setFrameSize(NSMakeSize(60, 40))
        
        linkField.setFrameSize(frame.width - link.frame.width - 10, 18)
        linkField.centerY(x: 10)
        

        
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
            bold.change(pos: NSMakePoint(0, bold.frame.minY), animated: animated)
            italic.change(pos: NSMakePoint(bold.frame.maxX, italic.frame.minY), animated: animated)
            monospace.change(pos: NSMakePoint(italic.frame.maxX, monospace.frame.minY), animated: animated)
            link.change(pos: NSMakePoint(frame.width - link.frame.width, link.frame.minY), animated: animated)
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
            
            monospace.change(pos: NSMakePoint(-(monospace.frame.width), monospace.frame.minY), animated: animated)
            italic.change(pos: NSMakePoint(-(italic.frame.width + monospace.frame.width), italic.frame.minY), animated: animated)
            bold.change(pos: NSMakePoint(-(italic.frame.width + bold.frame.width + monospace.frame.width), bold.frame.minY), animated: animated)
            link.change(pos: NSMakePoint(frame.width - link.frame.width, link.frame.minY), animated: animated)
            
            window?.makeFirstResponder(linkField)
        }
    }
    
    override func layout() {
        super.layout()
        switch state {
        case .normal:
            bold.centerY(x: 0)
            italic.centerY(x: bold.frame.maxX)
            monospace.centerY(x: italic.frame.maxX)
            link.centerY(x: monospace.frame.maxX)
        case .link:
            link.centerY(x: frame.width - link.frame.width)
            monospace.centerY(x: 0)
            italic.centerY(x: -monospace.frame.maxX)
            bold.centerY(x: -italic.frame.maxX)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class InputFormatterArguments {
    let bold:() -> Void
    let italic:() -> Void
    let code:() -> Void
    let link:(String)->Void
    init(bold:@escaping()->Void, italic:@escaping()->Void, code:@escaping()->Void, link:@escaping(String)->Void) {
        self.bold = bold
        self.italic = italic
        self.code = code
        self.link = link
    }
}

class InputFormatterPopover: NSPopover {
    
    private let window: Window
    init(_ arguments: InputFormatterArguments, window: Window) {
        self.window = window
        super.init()
        let controller = NSViewController()
        let view = InputFormatterView(frame: NSMakeRect(0, 0, 240, 40))
        
        controller.view = view
        
        view.bold.set(handler: { _ in
            arguments.bold()
        }, for: .Click)
        
        view.italic.set(handler: { _ in
            arguments.italic()
        }, for: .Click)
        
        view.monospace.set(handler: { _ in
            arguments.code()
        }, for: .Click)
        
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
                    
                    attr.enumerateAttribute(NSAttributedStringKey.link, in: attr.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                        
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
        
        window.set(responder: { [weak view] () -> NSResponder? in
            if let view = view {
                if view.state == .link {
                    return view.linkField.textView
                }
            }
            return nil
            
        }, with: self, priority: .modal)
    }
    
    
    deinit {
        window.removeAllHandlers(for: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
