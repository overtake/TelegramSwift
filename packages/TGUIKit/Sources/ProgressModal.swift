//
//  ProgressModal.swift
//  TGUIKit
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AppKit
import ColorPalette

private final class ProgressModalView : NSVisualEffectView {
    private let progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 32, 32))
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.cornerRadius = 10.0
        self.autoresizingMask = []
        self.autoresizesSubviews = false
        self.addSubview(self.progressView)
        self.material = presentation.colors.isDark ? .dark : .light
        self.blendingMode = .withinWindow
        self.state = .active
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSMakeSize(80, 80))
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.progressView.center()
        self.center()
    }
}

class ProgressModalController: ModalViewController {

    private var progressView:ProgressIndicator?
    override var background: NSColor {
        return .clear
    }
    
    override var contentBelowBackground: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return nil
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        super.close(animationType: animationType)
        disposable.dispose()
    }
    
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return ProgressModalView.self
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    deinit {
        disposable.dispose()
    }
    
    fileprivate let disposable: Disposable
    
    init(_ disposable: Disposable) {
        self.disposable = disposable
        super.init(frame:NSMakeRect(0,0,80,80))
        self.bar = .init(height: 0)
    }
    
    
}


private final class SuccessModalView : NSVisualEffectView {
    private let imageView:ImageView = ImageView()
    private let textView: TextView = TextView()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(imageView)
        self.wantsLayer = true
        self.layer?.cornerRadius = 10.0
        self.autoresizingMask = []
        self.autoresizesSubviews = false
        self.material = presentation.colors.isDark ? .dark : .light
        self.blendingMode = .withinWindow
    }
    

    
    override func layout() {
        super.layout()
        
        if !textView.isHidden {
            imageView.centerY(x: 20)
            textView.centerY(x: imageView.frame.maxX + 20)
        } else {
            imageView.center()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateIcon(icon: CGImage, text: TextViewLayout?) {
        imageView.image = icon
        imageView.sizeToFit()
        textView.isSelectable = false
        textView.isHidden = text == nil
        textView.update(text)
        needsLayout = true
    }
}

class SuccessModalController : ModalViewController {
    override var background: NSColor {
        return .clear
    }
    
    override var contentBelowBackground: Bool {
        return true
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return SuccessModalView.self
    }
    private var genericView: SuccessModalView {
        return self.view as! SuccessModalView
    }
    
    override var redirectMouseAfterClosing: Bool {
        return true
    }

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.updateIcon(icon: icon, text: text)
        readyOnce()
    }
    
//    override var handleEvents: Bool {
//        return false
//    }
//    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private let icon: CGImage
    private let text: TextViewLayout?
    private let _backgroundColor: NSColor
    init(_ icon: CGImage, text: TextViewLayout? = nil, background: NSColor) {
        self.icon = icon
        self.text = text
        self._backgroundColor = background
        super.init(frame:NSMakeRect(0, 0, text != nil ? 100 + text!.layoutSize.width : 80, text != nil ? max(icon.backingSize.height + 20, text!.layoutSize.height + 20) : 80))
        self.bar = .init(height: 0)
    }
}

public func showModalProgress<T, E>(signal:Signal<T,E>, for window:Window, disposeAfterComplete: Bool = true) -> Signal<T,E> {
    return Signal { subscriber in
        
        var signal = signal |> deliverOnMainQueue
        let beforeDisposable:DisposableSet = DisposableSet()

        let modal = ProgressModalController(beforeDisposable)
        let beforeModal:Signal<Void,Void> = .single(Void()) |> delay(0.25, queue: Queue.mainQueue())
        
        
        beforeDisposable.add(beforeModal.startStandalone(completed: {
            showModal(with: modal, for: window, animationType: .scaleCenter)
        }))
        
        signal = signal |> afterDisposed {
            modal.close()
        }
        
        beforeDisposable.add(signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
            if disposeAfterComplete {
                beforeDisposable.dispose()
            }
            modal.close()
        }, completed: {
            subscriber.putCompletion()
            if disposeAfterComplete {
                beforeDisposable.dispose()
            }
            modal.close()
        }))
        
        return beforeDisposable
    }
}

public func showModalSuccess(for window: Window, icon: CGImage, text: TextViewLayout? = nil, background: NSColor = presentation.colors.background, delay _delay: Double) -> Signal<Void, NoError> {
    
    let modal = SuccessModalController(icon, text: text, background: background)
    showModal(with: modal, for: window, animationType: .scaleCenter)

    return Signal<Void, NoError>({ [weak modal] _ -> Disposable in
        return ActionDisposable {
            modal?.close()
        }
    }) |> timeout(_delay, queue: Queue.mainQueue(), alternate: Signal<Void, NoError>({ [weak modal] _ -> Disposable in
        modal?.close()
        return EmptyDisposable
    }))
}


private final class TextAndLabelModalView : View {
    private let textView: TextView = TextView()
    private var titleView: TextView?
    private let visualEffectView = NSVisualEffectView(frame: NSZeroRect)
    private let overlay = Control()
    private var button: TextButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        self.visualEffectView.material = .ultraDark
        self.visualEffectView.blendingMode = .withinWindow
        self.visualEffectView.state = .active
        self.visualEffectView.wantsLayer = true
        addSubview(self.visualEffectView)

        //self.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        self.textView.disableBackgroundDrawing = true
        self.textView.isSelectable = false
        self.textView.userInteractionEnabled = true
        addSubview(self.textView)
        layer?.cornerRadius = 10
        
        addSubview(overlay)

        
        self.textView.set(handler: { [weak self] _ in
            self?.button?.send(event: .Down)
        }, for: .Down)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }

    func update(text: String, title: String?, button: String?, callback: ((String)->Void)?, maxSize: NSSize) -> NSSize {

        if let title = title {
            self.titleView = TextView()
            addSubview(self.titleView!)

            self.titleView?.disableBackgroundDrawing = true
            self.titleView?.isSelectable = false
            self.titleView?.userInteractionEnabled = false
            let titleLayout = TextViewLayout(.initialize(string: title, color: .white, font: .medium(.title)), maximumNumberOfLines: 1)
            titleLayout.measure(width: min(380, maxSize.width - 120))
            self.titleView?.update(titleLayout)
        }
        
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: .white), bold: MarkdownAttributeSet(font: .bold(.text), textColor: .white), link: MarkdownAttributeSet(font: .normal(.title), textColor: nightAccentPalette.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })).mutableCopy() as! NSMutableAttributedString
        
        attr.detectBoldColorInString(with: .medium(.title))
        
        let textLayout = TextViewLayout(attr)
        textLayout.interactions = .init(processURL: { contents in
            if let string = contents as? String {
                callback?(string)
            }
        })
        
        overlay.set(handler: { _ in
            callback?("")
        }, for: .Down)
        
        textLayout.measure(width: min(400, maxSize.width - 80))
        self.textView.update(textLayout)

        if let button = button {
            let current: TextButton
            if let view = self.button {
                current = view
            } else {
                current = TextButton()
                current.scaleOnClick = true
                self.button = current
                addSubview(current)
                current.set(handler: { _ in
                    callback?("action")
                }, for: .Down)
            }
            
            current.set(font: .medium(.header), for: .Normal)
            current.set(color: nightAccentPalette.link, for: .Normal)
            current.set(text: button, for: .Normal)
            current.sizeToFit(NSMakeSize(10, 0))
            
           
            addSubview(current)
        } else if let view = self.button {
            performSubviewRemoval(view, animated: false)
            self.button = nil
        }


        var size: NSSize = .zero

        if let titleView = self.titleView {
            size.width = max(textView.frame.width, titleView.frame.width) + 20
            size.height = textView.frame.height + titleView.frame.height + 5 + 20
        } else {
            size.width = textView.frame.width + 20
            size.height = textView.frame.height + 20
        }

        if let button = self.button {
            size.width += button.frame.width
        }
        
        return size
    }

    override func layout() {
        super.layout()
        overlay.frame = bounds
        visualEffectView.frame = bounds

        if let titleView = titleView {
            titleView.setFrameOrigin(NSMakePoint(10, 10))
            textView.setFrameOrigin(NSMakePoint(10, titleView.frame.maxY + 5))
        } else {
            textView.centerY(x: 10)
        }
        if let button = button {
            button.centerY(x: frame.width - button.frame.width - 10)
        }
    }
    
}

class TextAndLabelModalController: ModalViewController {

    override var background: NSColor {
        return .clear
    }

    override var redirectMouseAfterClosing: Bool {
        return true
    }
    

    override func becomeFirstResponder() -> Bool? {
        return nil
    }

    override var contentBelowBackground: Bool {
        return true
    }


    override var containerBackground: NSColor {
        return .clear
    }

    override func viewClass() -> AnyClass {
        return TextAndLabelModalView.self
    }

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }

    private var genericView: TextAndLabelModalView {
        return self.view as! TextAndLabelModalView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let size = self.genericView.update(text: text, title: title, button: button, callback: self.callback, maxSize: windowSize)
        self.modal?.resize(with: size, animated: false)

        readyOnce()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
    }
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override var redirectUserInterfaceCalls: Bool {
        return true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override var canBecomeResponder: Bool {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        return nil
    }

    deinit {
    }

    private let text: String
    private let title: String?
    private let button: String?
    private let windowSize: NSSize
    private let callback:((String)->Void)?
    init(text: String, title: String?, button: String?, callback:((String)->Void)?, windowSize: NSSize) {
        self.text = text
        self.windowSize = windowSize
        self.title = title
        self.callback = callback
        self.button = button
        super.init(frame:NSMakeRect(0, 0, 80, 80))
        self.bar = .init(height: 0)
    }


}

public func showModalText(for window: Window, text: String, title: String? = nil, button: String? = nil, callback:((String)->Void)? = nil) {
    let modal = TextAndLabelModalController(text: text, title: title, button: button, callback: callback, windowSize: window.frame.size)

    showModal(with: modal, for: window, animationType: .scaleCenter)

    let words = (text + " " + (title ?? "")).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

    let msPerChar: TimeInterval = 60 / 180 / 6

    let showTime = max(min(msPerChar * TimeInterval(words.length), 10), 5)


    let signal = Signal<Void, NoError>({ _ -> Disposable in
        return ActionDisposable {
           
        }
    }) |> timeout(showTime, queue: Queue.mainQueue(), alternate: Signal<Void, NoError>({ [weak modal] _ -> Disposable in
        modal?.close()
        return EmptyDisposable
    }))

    _ = signal.start()
}

