//
//  EditImageSticker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

final class EditImageCanvasArguments {
    let makeNewActionAt:(NSPoint)->Void
    let addToLastAction:(NSPoint)->Void
    
    let switchAction:(EditImageCanvasAction)->Void
    let undo:()->Void
    let redo:()->Void
    let updateColorAndWidth:(NSColor, CGFloat)->Void
    
    let save:()->Void
    let cancel:()->Void
    init(makeNewActionAt:@escaping(NSPoint)->Void, addToLastAction:@escaping(NSPoint)->Void, switchAction:@escaping(EditImageCanvasAction)->Void, undo: @escaping()->Void, redo: @escaping()->Void, updateColorAndWidth: @escaping(NSColor, CGFloat)->Void, save: @escaping()->Void, cancel: @escaping()->Void) {
        self.makeNewActionAt = makeNewActionAt
        self.addToLastAction = addToLastAction
        self.switchAction = switchAction
        self.undo = undo
        self.redo = redo
        self.updateColorAndWidth = updateColorAndWidth
        self.save = save
        self.cancel = cancel
    }
}

func applyPaints(_ touches: [EditImageDrawTouch], for context: CGContext, imageSize: NSSize) {
    context.saveGState()
    for touch in touches {
        context.beginPath()
        
        let multiplier = NSMakePoint(imageSize.width / touch.canvasSize.width, imageSize.height / touch.canvasSize.height)
        
        for (i, point) in touch.lines.enumerated() {
            let point = NSMakePoint(point.x * multiplier.x, point.y * multiplier.y)
            if i == 0 {
                context.move(to: point)
            } else {
                context.addLine(to: point)
            }
        }
        
        context.setLineWidth(touch.width * ((multiplier.x + multiplier.y) / 2))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(touch.color.cgColor)
        
        switch touch.action {
        case .draw:
            context.setBlendMode(.normal)
        case .clear:
            context.setBlendMode(.clear)
        }
        context.strokePath()
    }
    context.restoreGState()
    context.setBlendMode(.normal)
}

final class EditImageDrawTouch : Equatable {
    
    static func == (lhs: EditImageDrawTouch, rhs: EditImageDrawTouch) -> Bool {
        return lhs.lines == rhs.lines &&
            lhs.color.argb == rhs.color.argb &&
            lhs.width == rhs.width &&
            lhs.action == rhs.action &&
            lhs.canvasSize == rhs.canvasSize
    }
    private(set) var lines:[NSPoint]
    let color: NSColor
    let width: CGFloat
    let action: EditImageCanvasAction
    let canvasSize: NSSize
    init(action: EditImageCanvasAction, point: NSPoint, canvasSize: NSSize, color: NSColor, width: CGFloat) {
        self.action = action
        self.lines = [point]
        self.color = color
        self.width = width
        self.canvasSize = canvasSize
    }
    func addPoint(_ point: NSPoint) {
        self.lines.append(point)
    }
}

class EditImageDrawView: Control {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    fileprivate var arguments: EditImageCanvasArguments? = nil
    private(set) fileprivate var state:EditImageCanvasState = EditImageCanvasState.default([])
    
    func update(with state: EditImageCanvasState) {
        self.state = state
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        needsDisplay = true
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        applyPaints(self.state.actionValues, for: context, imageSize: self.frame.size)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let point = self.convert(event.locationInWindow, from: nil)
        arguments?.makeNewActionAt(point)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        let point = self.convert(event.locationInWindow, from: nil)
        arguments?.addToLastAction(point)
        
    }
}


final class EditImageCanvasView : View {
    
    let imageContainer: View = View()
    
   // let magnifyView: MagnifyView
    
    let imageView: ImageView = ImageView()
    let drawView: EditImageDrawView = EditImageDrawView(frame: .zero)
    
    let colorPicker: EditImageColorPicker
    let shadowView: View = View()
    private let controls: EditImageCanvasControlsView = EditImageCanvasControlsView(frame: NSMakeRect(0, 0, 350, 40))
    required init(frame frameRect: NSRect, image: CGImage) {
        self.imageView.image = image
        colorPicker = EditImageColorPicker(frame: NSMakeRect(0, 0, 348, 200))
        super.init(frame: frameRect)
        
        shadowView.isEventLess = true
        
        
        addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        
        
        imageContainer.addSubview(drawView)
        addSubview(colorPicker)
        addSubview(controls)
        
    }
    
    fileprivate var arguments: EditImageCanvasArguments? = nil {
        didSet {
            controls.arguments = arguments
            drawView.arguments = arguments
            colorPicker.arguments = arguments
        }
    }

    
    func update(with state: EditImageCanvasState) {
        controls.update(with: state)
        drawView.update(with: state)
    }
    
    override func layout() {
        super.layout()
        imageContainer.setFrameSize(frame.width, frame.height - 120)
        
        let imageSize = self.imageView.image!.size.fitted(NSMakeSize(imageContainer.frame.width - 8, imageContainer.frame.height - 8))
        self.imageView.setFrameSize(imageSize)
        
        self.imageView.center()
        self.drawView.frame = imageView.frame
        
        
        controls.centerX(y: frame.height - controls.frame.height)
        colorPicker.centerX(y: controls.frame.minY - colorPicker.frame.height - 20)
    }

    func contentSize(maxSize: NSSize) -> NSSize {
        return NSMakeSize(maxSize.width, maxSize.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

enum EditImageCanvasAction : Hashable {
    case draw
    case clear
}

struct EditImageCanvasState : Equatable {
    let action: EditImageCanvasAction
    
    let color: NSColor
    let width: CGFloat
    
    let actionValues:[EditImageDrawTouch]
    let removedActions:[EditImageDrawTouch]
    
    init(action: EditImageCanvasAction, actionValues:[EditImageDrawTouch], removedActions:[EditImageDrawTouch], color: NSColor, width: CGFloat) {
        self.action = action
        self.actionValues = actionValues
        self.color = color
        self.width = width
        self.removedActions = removedActions
    }
    
    func withUpdatedAction(_ action: EditImageCanvasAction) -> EditImageCanvasState {
        return EditImageCanvasState(action: action, actionValues: self.actionValues, removedActions: self.removedActions, color: self.color, width: self.width)
    }
    
    func withUpdatedCurrentActionValues(_ f:([EditImageDrawTouch])->[EditImageDrawTouch]) -> EditImageCanvasState {
        return EditImageCanvasState(action: action, actionValues: f(self.actionValues), removedActions: self.removedActions, color: self.color, width: self.width)
    }
    
    func withAddedRemovedAction(_ action: EditImageDrawTouch) -> EditImageCanvasState {
        
        var removedActions = self.removedActions
        removedActions.append(action)
        
        return EditImageCanvasState(action: self.action, actionValues: self.actionValues, removedActions: removedActions, color: self.color, width: self.width)
    }
    
    func withReturnedRemovedAction() -> EditImageCanvasState {
        
        var removedActions = self.removedActions
        var actionValues = self.actionValues
        if !removedActions.isEmpty {
            let last = removedActions.removeLast()
            actionValues.append(last)
        } else {
            NSSound.beep()
        }
        return EditImageCanvasState(action: self.action, actionValues: actionValues, removedActions: removedActions, color: self.color, width: self.width)
    }
    
    func withClearedRemovedActions() -> EditImageCanvasState {
        return EditImageCanvasState(action: self.action, actionValues: self.actionValues, removedActions: [], color: self.color, width: self.width)
    }
    
    func withUpdateColorAndWidth(_ color: NSColor, _ width: CGFloat) -> EditImageCanvasState {
        return EditImageCanvasState(action: self.action, actionValues: self.actionValues, removedActions: self.removedActions, color: color, width: width)
    }
    
    static func `default`(_ actions: [EditImageDrawTouch]) -> EditImageCanvasState {
        return EditImageCanvasState(action: .draw, actionValues: actions, removedActions: [], color: .random, width: 6)
    }
}

final class EditImageCanvasController : ModalViewController {
    private let disposable = MetaDisposable()
    private let image: CGImage
    private let actions: [EditImageDrawTouch]
    private let updatedImage: ([EditImageDrawTouch])->Void
    private let closeHandler: ()->Void
    init(image: CGImage, actions: [EditImageDrawTouch], updatedImage: @escaping([EditImageDrawTouch])->Void, closeHandler: @escaping() -> Void) {
        self.stateValue = Atomic(value: EditImageCanvasState.default(actions))
        self.state = ValuePromise(EditImageCanvasState.default(actions), ignoreRepeated: false)
        self.image = image
        self.actions = actions
        self.updatedImage = updatedImage
        self.closeHandler = closeHandler
        super.init()
        bar = .init(height: 0)
    }
    
    private let stateValue: Atomic<EditImageCanvasState>
    private let state: ValuePromise<EditImageCanvasState>

    override var containerBackground: NSColor {
        return .clear
    }
    override var isVisualEffectBackground: Bool {
        return false
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        super.close(animationType: animationType)
        self.closeHandler()
    }
    
    
    override var background: NSColor {
        return .clear
    }
    

    
    override func returnKeyAction() -> KeyHandlerResult {
        self.updatedImage(stateValue.with { $0.actionValues} )
        close()
        return .invoked
    }
    
    override func measure(size: NSSize) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.contentSize(maxSize: NSMakeSize(contentSize.width - 80, contentSize.height - 80)), animated: false)
        }
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.contentSize(maxSize: NSMakeSize(contentSize.width - 80, contentSize.height - 80)), animated: animated)
        }
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return EditImageCanvasView.self
    }
    
    private var genericView: EditImageCanvasView {
        return self.view as! EditImageCanvasView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let updateState:((EditImageCanvasState)->EditImageCanvasState)->Void = { [weak self] f in
            guard let `self` = self else {
                return
            }
            self.state.set(self.stateValue.modify(f))
        }
        
        let arguments = EditImageCanvasArguments(makeNewActionAt: { [weak self] point in
            let canvasSize = self?.genericView.drawView.frame.size ?? .zero
            updateState { state in
                return state.withUpdatedCurrentActionValues { touches in
                    var touches = touches
                    touches.append(EditImageDrawTouch(action: state.action, point: point, canvasSize: canvasSize, color: state.color, width: state.width))
                    return touches
                }.withClearedRemovedActions()
            }
        }, addToLastAction: { point in
            updateState { state in
                return state.withUpdatedCurrentActionValues { touches in
                    touches.last?.addPoint(point)
                    return touches
                }
            }
        }, switchAction: { action in
            updateState { state in
                return state.withUpdatedAction(action)
            }
        }, undo: {
            updateState { state in
                var state = state
                var lastAction: EditImageDrawTouch?
                state = state.withUpdatedCurrentActionValues { touches in
                    var touches = touches
                    if !touches.isEmpty {
                        lastAction = touches.removeLast()
                    } else {
                        NSSound.beep()
                    }
                    return touches
                }
                if let lastAction = lastAction {
                    state = state.withAddedRemovedAction(lastAction)
                }
                return state
            }
        }, redo: {
            updateState {
                $0.withReturnedRemovedAction()
            }
        }, updateColorAndWidth: { color, width in
            updateState {
                $0.withUpdateColorAndWidth(color, width)
            }
        }, save: { [weak self] in
            _ = self?.returnKeyAction()
        }, cancel: { [weak self] in
            self?.close()
        })
        
        genericView.arguments = arguments
        
        disposable.set(state.get().start(next: { [weak self] state in
            self?.genericView.update(with: state)
        }))
        
        readyOnce()
    }
    override func initializer() -> NSView {
        let vz = viewClass() as! EditImageCanvasView.Type
        return vz.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), image: image);
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.arguments?.undo()
            
            return .invoked
        }, with: self, for: .Z, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.arguments?.redo()
            
            return .invoked
        }, with: self, for: .Z, priority: .modal, modifierFlags: [.command, .shift])
        
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.arguments?.switchAction(.clear)
            
            return .invoked
        }, with: self, for: .E, priority: .modal)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.arguments?.switchAction(.draw)
            
            return .invoked
        }, with: self, for: .L, priority: .modal)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    deinit {
        disposable.dispose()
    }
}
