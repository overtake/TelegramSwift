//
//  EditImagModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit





private final class EditImageView : View {
    fileprivate let imageView: ImageView = ImageView()
    private var image: CGImage
    fileprivate let selectionRectView: SelectionRectView = SelectionRectView(frame: NSMakeRect(0, 0, 100, 100))
    private let imageContainer: View = View()
    private let reset: TitleButton = TitleButton()
    private var currentData: EditedImageData?
    private let fakeCorners: (topLeft: ImageView, topRight: ImageView, bottomLeft: ImageView, bottomRight: ImageView)
    
    
    required init(frame frameRect: NSRect, image: CGImage) {
        self.image = image
        fakeCorners = (topLeft: ImageView(), topRight: ImageView(), bottomLeft: ImageView(), bottomRight: ImageView())
        let corners = generateSelectionAreaCorners(.white)
        fakeCorners.topLeft.image = corners.topLeft
        fakeCorners.topRight.image = corners.topRight
        fakeCorners.bottomLeft.image = corners.bottomLeft
        fakeCorners.bottomRight.image = corners.bottomRight
        
        fakeCorners.topLeft.sizeToFit()
        fakeCorners.topRight.sizeToFit()
        fakeCorners.bottomLeft.sizeToFit()
        fakeCorners.bottomRight.sizeToFit()
        
        super.init(frame: frameRect)
        
        
        imageContainer.addSubview(fakeCorners.topLeft)
        imageContainer.addSubview(fakeCorners.topRight)
        imageContainer.addSubview(fakeCorners.bottomLeft)
        imageContainer.addSubview(fakeCorners.bottomRight)
        
        
        imageView.wantsLayer = true
        imageView.image = image
        addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        imageView.addSubview(selectionRectView)
        addSubview(reset)
       // reset.isHidden = true
        autoresizesSubviews = false
        

        
        reset.set(font: .medium(.title), for: .Normal)
        reset.set(color: .white, for: .Normal)
        reset.set(text: L10n.editImageControlReset, for: .Normal)
        _ = reset.sizeToFit()
        
    }
    
    var controls: View? {
        didSet {
            oldValue?.removeFromSuperview()
            if let controls = controls {
                addSubview(controls)
            }
        }
    }
    
    var selectedRect: NSRect {
        let multiplierX = self.imageView.image!.size.width / selectionRectView.frame.width
        let multiplierY = self.imageView.image!.size.height / selectionRectView.frame.height
        let rect = NSMakeRect(selectionRectView.selectedRect.minX, selectionRectView.selectedRect.minY, selectionRectView.selectedRect.width, selectionRectView.selectedRect.height)
        return rect.apply(multiplier: NSMakeSize(multiplierX, multiplierY))
    }
    
    fileprivate func updateVisibleCorners() {
        
    }
    
    func applyEditedData(_ value: EditedImageData, canReset: Bool, reset: @escaping()->Void) {
        if value.isNeedToRegenerate(currentData) {
            self.imageView.image = value.makeImage(self.image)
        }
        self.currentData = value
        
        setFrameSize(frame.size)

        
        if value.selectedRect != NSZeroRect {
            self.selectionRectView.applyRect(value.selectedRect, force: self.selectionRectView.dimensions != value.dimensions, dimensions: value.dimensions)
        } else {
            selectionRectView.applyRect(imageView.bounds, dimensions: value.dimensions)
        }
        
        self.reset.isHidden = !canReset
        self.reset.removeAllHandlers()
        self.reset.set(handler: { _ in
            reset()
        }, for: .Click)
        
        needsLayout = true
        
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if !imageView._mouseInside() && !controls!.mouseInside() && !selectionRectView.inDragging {
            if let data = self.currentData, selectionRectView.isWholeSelected && data.hasntData  {
                (controls as? EditImageControlsView)?.cancel.send(event: .Click)
            } else {
                confirm(for: mainWindow, information: L10n.editImageControlConfirmDiscard, successHandler: { [weak self] _ in
                     (self?.controls as? EditImageControlsView)?.cancel.send(event: .Click)
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = self.frame.size
        super.setFrameSize(newSize)
       
        imageContainer.setFrameSize(frame.width, frame.height - 120)
        
        let imageSize = imageView.image!.size.fitted(NSMakeSize(imageContainer.frame.width - 8, imageContainer.frame.height - 8))
        let oldImageSize = imageView.frame.size
        imageView.setFrameSize(imageSize)
        selectionRectView.frame = imageView.bounds
        
        imageView.center()
        
        if oldSize != newSize, oldSize != NSZeroSize, inLiveResize {
            let multiplier = NSMakeSize(imageSize.width / oldImageSize.width, imageSize.height / oldImageSize.height)
            selectionRectView.applyRect(selectionRectView.selectedRect.apply(multiplier: multiplier))
        }
        

        if let controls = controls {
            controls.centerX(y: frame.height - controls.frame.height)
            reset.centerX(y: controls.frame.minY - (80 - reset.frame.height) / 2)
        }
        
    }
    
    func hideElements(_ hide: Bool) {
        imageContainer.isHidden = hide
        reset.isHidden = hide
    }
    
    func contentSize(maxSize: NSSize) -> NSSize {
        return NSMakeSize(maxSize.width, maxSize.height)
    }
    
    override func layout() {
        super.layout()
        fakeCorners.topLeft.setFrameOrigin(selectionRectView.convert(selectionRectView.topLeftPosition, to: fakeCorners.topLeft.superview))
        fakeCorners.topRight.setFrameOrigin(selectionRectView.convert(selectionRectView.topRightPosition, to: fakeCorners.topRight.superview))
        
        fakeCorners.bottomLeft.setFrameOrigin(selectionRectView.convert(selectionRectView.bottomLeftPosition, to: fakeCorners.bottomLeft.superview))
        fakeCorners.bottomRight.setFrameOrigin(selectionRectView.convert(selectionRectView.bottomRightPosition, to: fakeCorners.bottomRight.superview))
    }
        
}

enum EditControllerSettings {
    case disableSizes(dimensions: SelectionRectDimensions)
    case plain
}

class EditImageModalController: ModalViewController {
    private let path: URL
    private let editValue: ValuePromise<EditedImageData> = ValuePromise(ignoreRepeated: true)
    private let editState: Atomic<EditedImageData>
    private let updateDisposable = MetaDisposable()
    private let updatedRectDisposable = MetaDisposable()
    private var controls: EditImageControls!
    private let image: CGImage
    private let settings: EditControllerSettings
    private let resultValue: Promise<(URL, EditedImageData?)> = Promise()
    private var canReset: Bool
    
    var onClose: () -> Void = {}
    
    init(_ path: URL, defaultData: EditedImageData? = nil, settings: EditControllerSettings = .plain) {
        self.canReset = defaultData != nil
        editState = Atomic(value: defaultData ?? EditedImageData(originalUrl: path))
        
        self.image = NSImage(contentsOf: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        self.path = path
        self.settings = settings
        super.init()
        bar = .init(height: 0)
        editValue.set(defaultData ?? EditedImageData(originalUrl: path))
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        super.close(animationType: animationType)
        
        onClose()
    }
    
    
    var result:Signal<(URL, EditedImageData?), NoError> {
        return resultValue.get()
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        let currentData = editState.modify {$0}
        resultValue.set(EditedImageData.generateNewUrl(data: currentData, selectedRect: genericView.selectedRect) |> map { ($0, $0 == currentData.originalUrl ? nil : currentData)})
        close()
        return .invoked
    }
    
    override open func measure(size: NSSize) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:genericView.contentSize(maxSize: NSMakeSize(contentSize.width - 80, contentSize.height - 80)), animated: false)
        }
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:genericView.contentSize(maxSize: NSMakeSize(contentSize.width - 80, contentSize.height - 80)), animated: animated)
        }
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func initializer() -> NSView {
        return EditImageView.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), image: image)
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return EditImageView.self
    }
    
    private var genericView: EditImageView {
        return self.view as! EditImageView
    }
    
    override var background: NSColor {
        return .clear
    }
    override var isVisualEffectBackground: Bool {
        return true
    }
    
    
    private func updateValue(_ f:@escaping(EditedImageData) -> EditedImageData) {
        self.editValue.set(editState.modify(f))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch settings {
        case let .disableSizes(dimensions):
            let imageSize = self.genericView.imageView.frame.size
            let size = NSMakeSize(200, 200).aspectFitted(imageSize)
            let rect = NSMakeRect((imageSize.width - size.width) / 2, (imageSize.height - size.height) / 2, size.width, size.height)
            genericView.selectionRectView.isCircleCap = true
            updateValue { data in
                return data.withUpdatedDimensions(dimensions).withUpdatedSelectedRect(rect)
            }
        default:
            genericView.selectionRectView.isCircleCap = false
        }
    }
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    private func loadCanvas() {
        guard let window = self.window else {
            return
        }
        genericView.hideElements(true)
        showModal(with: EditImageCanvasController(image: self.image, actions: editState.with { $0.paintings }, updatedImage: { [weak self] paintings in
            self?.updateValue {
                $0.withUpdatedPaintings(paintings)
            }
        }, closeHandler: { [weak self] in
            self?.genericView.hideElements(false)
        }), for: window, animated: false, animationType: .alpha)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.controls.arguments.rotate()
            return .invoked
        }, with: self, for: .R, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.loadCanvas()
            return .invoked
        }, with: self, for: .Y, priority: .modal, modifierFlags: [.command])
        
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    private func rotate() {
        var rect = NSZeroRect
        let imageSize = genericView.imageView.frame.size
        var isFlipped: Bool = false
        var newRotation: ImageOrientation?
        self.updateValue { current in
            rect = current.selectedRect
            let orientation: ImageOrientation?
            if let value = current.orientation {
                switch value {
                case .right:
                    orientation = .down
                case .down:
                    orientation = .left
                default:
                    orientation = nil
                }
            } else {
                orientation = .right
            }
            newRotation = orientation
            isFlipped = current.isHorizontalFlipped
            return current.withUpdatedOrientation(orientation)
        }
        
//        if isFlipped, let newRotation = newRotation, newRotation == .right {
//            rect.origin.x = imageSize.width - rect.maxX
//        } else if isFlipped, newRotation == nil {
//            rect.origin.x = imageSize.width - rect.maxX
//        }
        
        let newSize = genericView.imageView.frame.size
        let multiplierWidth = newSize.height / imageSize.width
        let multiplierHeight = newSize.width / imageSize.height
        
        rect = rect.rotate90Degress(parentSize: imageSize)
        rect = rect.apply(multiplier: NSMakeSize(multiplierHeight, multiplierWidth))
        
        self.updateValue { current in
            return current.withUpdatedSelectedRect(rect)
        }
    }
    
    private func flip() {
        let imageSize = genericView.imageView.frame.size
        updateValue { value in
            var rect = value.selectedRect
            rect.origin.x = imageSize.width - rect.maxX
            return value.withUpdatedFlip(!value.isHorizontalFlipped).withUpdatedSelectedRect(rect)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.controls = EditImageControls(settings: settings, arguments: EditImageControlsArguments(cancel: { [weak self] in
            self?.close()
        }, success: { [weak self] in
            _ = self?.returnKeyAction()
        }, flip: { [weak self] in
            self?.flip()
        }, selectionDimensions: { [weak self] dimension in
            self?.updateValue { value in
                return value.withUpdatedDimensions(dimension)
            }
        }, rotate: { [weak self] in
            self?.rotate()
        }, draw: { [weak self] in
                self?.loadCanvas()
        }), stateValue: editValue.get())

        
      
        
        
        genericView.controls = self.controls.genericView
        updateDisposable.set((editValue.get() |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let `self` = self else {return}
            self.readyOnce()
            self.updateSize(false)
            self.genericView.applyEditedData(data, canReset: self.canReset, reset: { [weak self] in
                self?.canReset = false
                self?.updateValue {$0.withUpdatedSelectedRect(NSZeroRect).withUpdatedFlip(false).withUpdatedDimensions(.none).withUpdatedOrientation(nil).withUpdatedPaintings([])}
            })
        }))
        
        updatedRectDisposable.set(genericView.selectionRectView.updatedRect.start(next: { [weak self] rect in
            self?.updateValue { $0.withUpdatedSelectedRect(rect) }
            self?.genericView.updateVisibleCorners()
        }))
    }
    
    deinit {
        updateDisposable.dispose()
        updatedRectDisposable.dispose()
    }
    
}
