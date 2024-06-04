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
import ColorPalette

private let dot: CGImage = generateImage(NSMakeSize(12, 12), contextGenerator: { size, ctx in
    ctx.clear(size.bounds)
    
    ctx.setFillColor(.white)
    ctx.fillEllipse(in: size.bounds)
    
    ctx.setFillColor(dayClassicPalette.accent.cgColor)
    ctx.fillEllipse(in: size.bounds.insetBy(dx: 1, dy: 1))
})!



private final class EditImageView : View {
    
    private final class Image : Control {
        
        private enum ResizeDirection {
            case topLeft
            case topRight
            case bottomLeft
            case bottomRight
            case middleTop
            case middleBottom
            case middleLeft
            case middleRight
        }
        
        private let topLeft = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        private let topRight = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        private let bottomRight = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        private let bottomLeft = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        
        private let bottomMiddle = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        private let topMiddle = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        
        private let leftMiddle = ImageButton(frame: NSMakeRect(0, 0, 12, 12))
        private let rightMiddle = ImageButton(frame: NSMakeRect(0, 0, 12, 12))

        private let controls = View()
        private let mover = Control()

        private let imageView = ImageView()
        
        private(set) var image: EditedImageData.Image
        
        private let update: (NSRect, Bool)->Void
        
        private var start: NSPoint?
        

        init(_ image: EditedImageData.Image, update: @escaping(NSRect, Bool)->Void, bringToFront: @escaping()->Void, select: @escaping()->Void) {
            self.image = image
            self.update = update
            super.init(frame: image.rect.insetBy(dx: -13, dy: -13))
            imageView.frame = image.rect.size.bounds
            addSubview(imageView)
            addSubview(controls)
            
            controls.addSubview(topLeft)
            controls.addSubview(topRight)
            controls.addSubview(bottomRight)
            controls.addSubview(bottomLeft)
            controls.addSubview(bottomMiddle)
            controls.addSubview(topMiddle)
            controls.addSubview(leftMiddle)
            controls.addSubview(rightMiddle)
            
            

            addSubview(mover)
            
            mover.set(handler: { control in
                if let event = NSApp.currentEvent {
                    if event.clickCount == 1 {
                        select()
                    } else if event.clickCount == 2 {
                        bringToFront()
                    }
                }
            }, for: .Click)
            
            mover.set(handler: { [weak self] _ in
                guard let strongSelf = self, let window = strongSelf.window else {
                    return
                }
                strongSelf.start = window.mouseLocationOutsideOfEventStream
                update(strongSelf.image.rect, true)
            }, for: .Down)
            
            mover.set(handler: { [weak self] _ in
                guard let strongSelf = self, let window = strongSelf.window, let start = strongSelf.start else {
                    return
                }
                let current = window.mouseLocationOutsideOfEventStream
                let result = NSMakePoint(current.x - start.x, start.y - current.y)
                update(strongSelf.image.rect.offsetBy(dx: result.x, dy: result.y), false)
                strongSelf.start = current
            }, for: .MouseDragging)
            
            mover.set(handler: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                update(strongSelf.image.rect, false)
                strongSelf.start = nil
            }, for: .Up)
            
            topLeft.scaleOnClick = true
            topRight.scaleOnClick = true
            bottomRight.scaleOnClick = true
            bottomLeft.scaleOnClick = true
            bottomMiddle.scaleOnClick = true
            topMiddle.scaleOnClick = true
            leftMiddle.scaleOnClick = true
            rightMiddle.scaleOnClick = true

            topLeft.autohighlight = false
            topRight.autohighlight = false
            bottomRight.autohighlight = false
            bottomLeft.autohighlight = false
            bottomMiddle.autohighlight = false
            topMiddle.autohighlight = false
            leftMiddle.autohighlight = false
            rightMiddle.autohighlight = false
            
            topRight.set(cursor: NSCursor.set_windowResizeNorthEastSouthWestCursor!, for: .Hover)
            topRight.set(cursor: NSCursor.set_windowResizeNorthEastSouthWestCursor!, for: .Highlight)
            bottomLeft.set(cursor: NSCursor.set_windowResizeNorthEastSouthWestCursor!, for: .Hover)
            bottomLeft.set(cursor: NSCursor.set_windowResizeNorthEastSouthWestCursor!, for: .Highlight)

            topLeft.set(cursor: NSCursor.set_windowResizeNorthWestSouthEastCursor!, for: .Hover)
            topLeft.set(cursor: NSCursor.set_windowResizeNorthWestSouthEastCursor!, for: .Highlight)
            bottomRight.set(cursor: NSCursor.set_windowResizeNorthWestSouthEastCursor!, for: .Hover)
            bottomRight.set(cursor: NSCursor.set_windowResizeNorthWestSouthEastCursor!, for: .Highlight)

            mover.set(cursor: NSCursor.pointingHand, for: .Hover)
            mover.set(cursor: NSCursor.pointingHand, for: .Highlight)
            
            
            topMiddle.set(cursor: NSCursor.resizeUpDown, for: .Hover)
            topMiddle.set(cursor: NSCursor.resizeUpDown, for: .Highlight)

            bottomMiddle.set(cursor: NSCursor.resizeUpDown, for: .Hover)
            bottomMiddle.set(cursor: NSCursor.resizeUpDown, for: .Highlight)

            leftMiddle.set(cursor: NSCursor.resizeLeftRight, for: .Hover)
            leftMiddle.set(cursor: NSCursor.resizeLeftRight, for: .Highlight)

            rightMiddle.set(cursor: NSCursor.resizeLeftRight, for: .Hover)
            rightMiddle.set(cursor: NSCursor.resizeLeftRight, for: .Highlight)


            topLeft.set(image: dot, for: .Normal)
            topRight.set(image: dot, for: .Normal)
            bottomRight.set(image: dot, for: .Normal)
            bottomLeft.set(image: dot, for: .Normal)
            bottomMiddle.set(image: dot, for: .Normal)
            topMiddle.set(image: dot, for: .Normal)
            leftMiddle.set(image: dot, for: .Normal)
            rightMiddle.set(image: dot, for: .Normal)
            
            topLeft.set(handler: { [weak self] _ in
                self?.initResizer(.topLeft)
            }, for: .Down)
            topRight.set(handler: { [weak self] _ in
                self?.initResizer(.topRight)
            }, for: .Down)
            bottomRight.set(handler: { [weak self] _ in
                self?.initResizer(.bottomRight)
            }, for: .Down)
            bottomLeft.set(handler: { [weak self] _ in
                self?.initResizer(.bottomLeft)
            }, for: .Down)
            bottomMiddle.set(handler: { [weak self] _ in
                self?.initResizer(.middleBottom)
            }, for: .Down)
            topMiddle.set(handler: { [weak self] _ in
                self?.initResizer(.middleTop)
            }, for: .Down)
            leftMiddle.set(handler: { [weak self] _ in
                self?.initResizer(.middleLeft)
            }, for: .Down)
            rightMiddle.set(handler: { [weak self] _ in
                self?.initResizer(.middleRight)
            }, for: .Down)
            
            topLeft.set(handler: { [weak self] _ in
                self?.resize(.topLeft)
            }, for: .MouseDragging)
            topRight.set(handler: { [weak self] _ in
                self?.resize(.topRight)
            }, for: .MouseDragging)
            bottomRight.set(handler: { [weak self] _ in
                self?.resize(.bottomRight)
            }, for: .MouseDragging)
            bottomLeft.set(handler: { [weak self] _ in
                self?.resize(.bottomLeft)
            }, for: .MouseDragging)
            bottomMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleBottom)
            }, for: .MouseDragging)
            topMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleTop)
            }, for: .MouseDragging)
            leftMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleLeft)
            }, for: .MouseDragging)
            rightMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleRight)
            }, for: .MouseDragging)
            
            topLeft.set(handler: { [weak self] _ in
                self?.resize(.topLeft, finish: true)
            }, for: .Up)
            topRight.set(handler: { [weak self] _ in
                self?.resize(.topRight, finish: true)
            }, for: .Up)
            bottomRight.set(handler: { [weak self] _ in
                self?.resize(.bottomRight, finish: true)
            }, for: .Up)
            bottomLeft.set(handler: { [weak self] _ in
                self?.resize(.bottomLeft, finish: true)
            }, for: .Up)
            bottomMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleBottom, finish: true)
            }, for: .Up)
            topMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleTop, finish: true)
            }, for: .Up)
            leftMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleLeft, finish: true)
            }, for: .Up)
            rightMiddle.set(handler: { [weak self] _ in
                self?.resize(.middleRight, finish: true)
            }, for: .Up)

            imageView.contentGravity = .resize
            imageView.image = image.img._cgImage
            
            needsLayout = true
        }
        
        private struct InitialResize {
            var startRect: NSRect
            var direction: ResizeDirection
            var startPoint: NSPoint
            
            func makeRect(_ point: NSPoint, aspect: Bool) -> NSRect {
                var rect = self.startRect
                
                let aspectRatio = rect.width / rect.height
                
                let current = startPoint - point
                
                switch direction {
                case .topLeft:
                    if aspect {
                        rect.size.width -= max(-current.x, current.y)
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.width += current.x
                        rect.size.height -= current.y
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX + size.width, rect.minY + size.height)
                case .topRight:
                    if aspect {
                        rect.size.width -= min(current.x, current.y)
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.width -= current.x
                        rect.size.height -= current.y
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX, rect.minY + size.height)
                case .bottomRight:
                    if aspect {
                        rect.size.width += min(-current.x, current.y)
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.width -= current.x
                        rect.size.height += current.y
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                case .bottomLeft:
                    if aspect {
                        rect.size.width += min(current.x, current.y)
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.width += current.x
                        rect.size.height += current.y
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX + size.width, rect.minY)
                case .middleBottom:
                    if aspect {
                        rect.size.width += current.y * aspectRatio
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.height += current.y
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX + size.width / 2, rect.minY)
                case .middleTop:
                    if aspect {
                        rect.size.width -= current.y * aspectRatio
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.height -= current.y
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX + size.width / 2, rect.minY + size.height)
                case .middleLeft:
                    rect.size.width += current.x
                    if aspect {
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.height -= current.x * aspectRatio
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX + size.width, rect.minY + size.height / 2)
                case .middleRight:
                    rect.size.width -= current.x
                    if aspect {
                        rect.size.height = rect.size.width / aspectRatio
                    } else {
                        rect.size.height += current.x * aspectRatio
                    }
                    rect.size.width = max(0, rect.size.width)
                    rect.size.height = max(0, rect.size.height)
                    let size = (self.startRect.size - rect.size)
                    rect.origin = NSMakePoint(rect.minX, rect.minY + size.height / 2)
                }
                return rect
            }
        }
        private var resizer: InitialResize?
        
        private func initResizer(_ direction: ResizeDirection) {
            guard let window = self.window else {
                return
            }
            self.resizer = .init(startRect: self.image.rect, direction: direction, startPoint: window.mouseLocationOutsideOfEventStream)
            
            self.update(self.image.rect, true)

        }
        private func resize(_ direction: ResizeDirection, finish: Bool = false) {
            guard let window = self.window, let resizer = self.resizer, let event = NSApp.currentEvent else {
                return
            }
            let rect = resizer.makeRect(window.mouseLocationOutsideOfEventStream, aspect: !event.modifierFlags.contains(.shift))
            self.update(rect, false)
            
            if finish {
                self.resizer = nil
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
        
        func update(with image: EditedImageData.Image, isSelected: Bool) {
            self.image = image
            controls.isHidden = !isSelected
            frame = image.rect.insetBy(dx: -13, dy: -13)
            self.imageView.frame = image.rect
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            imageView.frame = focus(image.rect.size)
            controls.frame = bounds
            
            mover.frame = imageView.frame
            
            topLeft.setFrameOrigin(NSMakePoint(0, 0))
            topRight.setFrameOrigin(NSMakePoint(controls.frame.width - topRight.frame.width, 0))
            bottomRight.setFrameOrigin(NSMakePoint(controls.frame.width - topRight.frame.width, controls.frame.height - topRight.frame.height))
            bottomLeft.setFrameOrigin(NSMakePoint(0, controls.frame.height - topRight.frame.height))
            topMiddle.centerX(y: 0)
            bottomMiddle.centerX(y: controls.frame.height - topRight.frame.height)
            
            leftMiddle.centerY(x: 0)
            rightMiddle.centerY(x: controls.frame.width - topRight.frame.width)

        }
    }

    
    private let imagesView: View = View()
    private var images: [AnyHashable : Image] = [:]

    fileprivate let imageView: ImageView = ImageView()
    private var image: CGImage
    fileprivate let selectionRectView: SelectionRectView = SelectionRectView(frame: NSMakeRect(0, 0, 100, 100))
    private let imageContainer: View = View()
    private let reset: TextButton = TextButton()
    private var currentData: EditedImageData?
    private let fakeCorners: (topLeft: ImageView, topRight: ImageView, bottomLeft: ImageView, bottomRight: ImageView)
    private var canReset: Bool = false
    
    var updateImage:((AnyHashable, NSRect, Bool)->Void)? = nil
    var bringImageToFront:((AnyHashable)->Void)? = nil
    var selectImage:((AnyHashable)->Void)? = nil

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
        
        imageView.background = .white
        
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
        reset.set(text: strings().editImageControlReset, for: .Normal)
        _ = reset.sizeToFit()
        
        reset.autohighlight = false
        reset.scaleOnClick = true
        
        imageContainer.addSubview(imagesView)
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
            self.imageView.image = value.makeImage(self.image, interface: true)
        }
        self.currentData = value
        
        setFrameSize(frame.size)

        
        if value.selectedRect != NSZeroRect {
            self.selectionRectView.applyRect(value.selectedRect, force: self.selectionRectView.dimensions != value.dimensions, dimensions: value.dimensions)
        } else {
            selectionRectView.applyRect(imageView.bounds, dimensions: value.dimensions)
        }
        self.canReset = canReset
        self.reset.isHidden = !canReset
        self.reset.removeAllHandlers()
        self.reset.set(handler: { _ in
            reset()
        }, for: .Click)
        
        self.updateImages(value.images, state: value)
        
        needsLayout = true
        
    }
    
    private func updateImages(_ images: [EditedImageData.Image], state: EditedImageData) {
        var validIds: Set<AnyHashable> = Set()

        for image in images {
            validIds.insert(image.stableId)
            
            let view: Image
            if let current = self.images[image.stableId] {
                view = current
            } else {
                view = Image(image, update: { [weak self] rect, start in
                    self?.updateImage?(image.stableId, rect, start)
                }, bringToFront: { [weak self] in
                    self?.bringImageToFront?(image.stableId)
                }, select: { [weak self] in
                    self?.selectImage?(image.stableId)
                })
                self.images[image.stableId] = view
                imagesView.addSubview(view)
            }
            view.update(with: image, isSelected: state.selectedImage == image.stableId)
        }
        
        var removeKeys: [AnyHashable] = []
        for (key, image) in self.images {
            if !validIds.contains(key) {
                removeKeys.append(key)
                image.removeFromSuperview()
            }
        }
        for key in removeKeys {
            self.images.removeValue(forKey: key)
        }
        
        imagesView.subviews = imagesView.subviews.sorted(by: { lhs, rhs in
            let lhs = lhs as! Image
            let rhs = rhs as! Image
            return images.firstIndex(of: lhs.image)! < images.firstIndex(of: rhs.image)!
        })

    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if !imageView._mouseInside() && !controls!.mouseInside() && !selectionRectView.inDragging {
            if let data = self.currentData, selectionRectView.isWholeSelected && data.hasntData  {
                (controls as? EditImageControlsView)?.cancel.send(event: .Click)
            } else {
                (self.controls as? EditImageControlsView)?.cancel.send(event: .Click)
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
        
        imagesView.frame = imageView.frame
        
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
        reset.isHidden = hide || !canReset
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

private func deg2rad(_ number: CGFloat) -> CGFloat {
    return number * .pi / 180
}

func transformPoints(points: [NSPoint], originalCanvasSize: NSSize, newCanvasSize: NSSize, angle: CGFloat, isHorizontalFlipped: Bool) -> [NSPoint] {
    let theta = deg2rad(angle)
    let originalCenterX = originalCanvasSize.width / 2
    let originalCenterY = originalCanvasSize.height / 2
    let newCenterX = newCanvasSize.width / 2
    let newCenterY = newCanvasSize.height / 2
    
    return points.map { point in
        var x = point.x
        var y = point.y
        
        // Flip horizontally if needed
        if (isHorizontalFlipped) {
            x = originalCanvasSize.width - x
        }
        
        // Translate point to original canvas center
        let tempX = x - originalCenterX
        let tempY = y - originalCenterY
        
        // Apply rotation
        let rotatedX = tempX * cos(theta) - tempY * sin(theta)
        let rotatedY = tempX * sin(theta) + tempY * cos(theta)
        
        // Translate to new canvas center
        x = rotatedX + newCenterX
        y = rotatedY + newCenterY
        
        return NSMakePoint(x, y)
    }
}

private func rotatedCanvasSize(canvasSize: NSSize, angle: CGFloat) -> NSSize {
    let theta = deg2rad(angle)
    let width = canvasSize.width
    let height = canvasSize.height
    
    let newWidth = abs(width * cos(theta)) + abs(height * sin(theta))
    let newHeight = abs(width * sin(theta)) + abs(height * cos(theta))
    
    return NSSize(width: newWidth, height: newHeight)
}


extension EditImageDrawTouch {
    func transform(_ data: EditedImageData, restore: Bool = false) -> EditImageDrawTouch {
        var lines = self.lines
        var canvasSize = self.canvasSize
        
        let originalCanvasSize = canvasSize
        var angle: CGFloat = 0
        if let orientation = data.orientation {
            switch orientation {
            case .up:
                angle = 0
            case .down:
                angle = restore ? -180 : 180
            case .left:
                if restore {
                    angle = data.isHorizontalFlipped ? 270 : 90
                } else {
                    angle = -90
                }
            case .right:
                if restore {
                    angle = data.isHorizontalFlipped ? -270 : -90
                } else {
                    angle = 90
                }
            default:
                break
            }
        }
        
        let flip = restore ? data.isHorizontalFlipped : data.isHorizontalFlipped
        
        canvasSize = rotatedCanvasSize(canvasSize: originalCanvasSize, angle: angle)
        lines = transformPoints(points: lines, originalCanvasSize: originalCanvasSize, newCanvasSize: canvasSize, angle: angle, isHorizontalFlipped: flip)

        
        return .init(action: action, lines: lines, canvasSize: canvasSize, color: color, width: width)
    }
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
    private let doneString: String?
    private let pasteDisposable = MetaDisposable()
    private let context: AccountContext
    
    var onClose: () -> Void = {}
    private let confirm: ((Signal<URL, NoError>, @escaping()->Void)->Void)?
    
    init(_ path: URL, context: AccountContext, defaultData: EditedImageData? = nil, settings: EditControllerSettings = .plain, doneString: String? = nil, confirm: ((Signal<URL, NoError>, @escaping()->Void)->Void)? = nil) {
        self.canReset = defaultData != nil
        self.context = context
        self.confirm = confirm
        self.doneString = doneString
        let initial = EditedImageData(originalUrl: path, selectedRect: .zero, dimensions: .none, isHorizontalFlipped: false, paintings: [], images: [])
        editState = Atomic(value: defaultData ?? initial)
        
        self.image = NSImage(contentsOf: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        self.path = path
        self.settings = settings
        super.init()
        bar = .init(height: 0)
        editValue.set(defaultData ?? initial)
    }
    
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        super.close(animationType: animationType)
        
        onClose()
    }
    
    
    var result:Signal<(URL, EditedImageData?), NoError> {
        return resultValue.get()
    }
    
    private var markAsClosed: Bool = false
    
    override func returnKeyAction() -> KeyHandlerResult {
        
        guard !markAsClosed else { return .invoked }
        
        let currentData = self.editState.modify {$0}
        let dataSignal = EditedImageData.generateNewUrl(data: currentData, selectedRect: self.genericView.selectedRect) |> map { ($0, $0 == currentData.originalUrl ? nil : currentData)}
        
        let promise: Promise<(URL, EditedImageData?)> = Promise()
        promise.set(dataSignal)
        
        let invoke = { [weak self] in
            guard let `self` = self else {
                return
            }
            self.resultValue.set(promise.get())
            
            let signal = self.resultValue.get() |> take(1) |> deliverOnMainQueue |> delay(0.1, queue: .mainQueue())
            self.markAsClosed = true
            _ = signal.start(next: { [weak self] _ in
                self?.close()
            })
        }
        
        if let confirm = self.confirm {
            confirm(promise.get() |> map { $0.0 }, invoke)
        } else {
            invoke()
        }
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
            updateValue { current in
                var current = current
                current.dimensions = dimensions
                current.selectedRect = rect
                return current
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
    
    private var previousCopyHandler: (()->Void)? = nil
    private var previousPasteHandler: (()->Void)? = nil

    private func loadCanvas() {
        guard let window = self.window else {
            return
        }
        genericView.hideElements(true)
        
        _ = (self.editValue.get() |> take(1)).startStandalone(next: { [weak self] data in
            guard let self else {
                return
            }
            let main = self.image
            let image = data.makeImage(main, interface: true, applyPainting: false)
            
            var paintings = editState.with { $0.paintings }
            
            paintings = paintings.map {
                $0.transform(data, restore: true)
            }
            
            showModal(with: EditImageCanvasController(image: image, actions: paintings, updatedImage: { [weak self] paintings in
                
                guard let self else {
                    return
                }
                
                let paintings = paintings.map {
                    $0.transform(data)
                }
                
                self.updateValue { current in
                    var current = current
                    current.paintings = paintings
                    return current
                }
            }, closeHandler: { [weak self] in
                self?.genericView.hideElements(false)
            }), for: window, animated: false, animationType: .alpha)
        })
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.controls.arguments.rotate()
            return .invoked
        }, with: self, for: .R, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.loadCanvas()
            return .invoked
        }, with: self, for: .D, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.updateValue { current in
                var current = current
                if let selected = current.selectedImage {
                    if let index = current.images.firstIndex(where: { $0.stableId == selected }) {
                        current.undo.append(.images(current.images, current.selectedImage))
                        current.images.remove(at: index)
                    }
                    current.selectedImage = current.images.last?.stableId
                }
                return current
            }
            return .invoked
        }, with: self, for: .Delete, priority: .modal)
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.undo()
            return .invoked
        }, with: self, for: .Z, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.redo()
            return .invoked
        }, with: self, for: .Z, priority: .modal, modifierFlags: [.command, .shift])
        
        self.previousCopyHandler = window?.copyhandler
        self.previousPasteHandler = window?.pastehandler

        
        window?.pastehandler = { [weak self] in
            self?.paste()
        }
        window?.copyhandler = { [weak self] in
            self?.copySomething()
        }
    }
    
    private func undo() {
        updateValue { current in
            var current = current
            if !current.undo.isEmpty {
                let action = current.undo.removeLast()
                switch action {
                case let .images(images, selected):
                    current.redo.append(.images(current.images, current.selectedImage))
                    current.images = images
                    current.selectedImage = selected
                }
            }
            return current
        }
    }
    private func redo() {
        updateValue { current in
            var current = current
            if !current.redo.isEmpty {
                let action = current.redo.removeLast()
                switch action {
                case let .images(images, selected):
                    current.undo.append(.images(current.images, current.selectedImage))
                    current.images = images
                    current.selectedImage = selected
                }
            }
            return current
        }
    }
    
    func copySomething() {
        let image: EditedImageData.Image? = self.editState.with { current in
            if let selected = current.selectedImage {
                if let index = current.images.firstIndex(where: { $0.stableId == selected }) {
                    return current.images[index]
                }
            }
            return nil
        }
        if let image = image {
            copyToClipboard(image.url, image.img)
        }
        
    }
    
    private func paste() {
        self.pasteDisposable.set(InputPasteboardParser.getPasteboardUrls(NSPasteboard.general, context: context).start(next: { [weak self] urls in
            self?.processPasteUrls(urls)
        }))
    }
    private func processPasteUrls(_ urls: [URL]) {
        var images:[EditedImageData.Image] = []
        for url in urls {
            if let image = NSImage(contentsOf: url) {
                let fitSize = NSMakeSize(max(min(genericView.imageView.frame.width / 2, image.size.width), 50), max(min(genericView.imageView.frame.height / 2, image.size.height), 50))
                let size = image.size.aspectFitted(fitSize)
                var rect = genericView.imageView.focus(size)
                rect.origin.y = CGFloat.random(in: max(0, rect.origin.y - floor(rect.origin.y * 0.1)) ..< rect.origin.y + floor(rect.origin.y * 0.1))
                rect.origin.x = CGFloat.random(in: max(0, rect.origin.x - floor(rect.origin.x * 0.1)) ..< rect.origin.x + floor(rect.origin.x * 0.1))

                let multiplierW = genericView.imageView.image!.size.width / genericView.imageView.frame.width
                let multiplierH = genericView.imageView.image!.size.height / genericView.imageView.frame.height
                
                images.append(.init(url: url, img: image, stableId: arc4random64(), rect: rect, multiplier: NSMakeSize(multiplierW, multiplierH), rotation: 0))
            }
        }
        updateValue { current in
            var current = current
            current.undo.append(.images(current.images, current.selectedImage))
            current.images.append(contentsOf: images)
            if !images.isEmpty {
                current.selectedImage = images.last?.stableId
            }
            return current
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
        
        window?.pastehandler = self.previousPasteHandler
        window?.copyhandler = self.previousCopyHandler
    }
    
    private func rotate() {
        var rect = NSZeroRect
        let imageSize = genericView.imageView.frame.size
        self.updateValue { current in
            var current = current
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
            current.orientation = orientation
            return current
        }

        let newSize = genericView.imageView.frame.size
        let multiplierWidth = newSize.height / imageSize.width
        let multiplierHeight = newSize.width / imageSize.height
        
        rect = rect.rotate90Degress(parentSize: imageSize)
        rect = rect.apply(multiplier: NSMakeSize(multiplierHeight, multiplierWidth))
        
        self.updateValue { current in
            var current = current
            current.selectedRect = rect
            return current
        }
    }
    
    private func flip() {
        let imageSize = genericView.imageView.frame.size
        updateValue { current in
            var current = current
            var rect = current.selectedRect
            rect.origin.x = imageSize.width - rect.maxX
            current.isHorizontalFlipped = !current.isHorizontalFlipped
            current.selectedRect = rect
            return current
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
            self?.updateValue { current in
                var current = current
                current.dimensions = dimension
                return current
            }
        }, rotate: { [weak self] in
            self?.rotate()
        }, draw: { [weak self] in
            self?.loadCanvas()
        }, getDoneString: { [weak self] in
            return self?.doneString
        }), stateValue: editValue.get())

        
        genericView.updateImage = { [weak self] stableId, rect, start in
            self?.updateValue { current in
                var current = current
                if let index = current.images.firstIndex(where: { $0.stableId == stableId }) {
                    if start {
                        current.undo.append(.images(current.images, current.selectedImage))
                    }
                    current.images[index].rect = rect
                    current.selectedImage = stableId
                }
                return current
            }
        }
        genericView.bringImageToFront = { [weak self] stableId in
            self?.updateValue { current in
                var current = current
                if let index = current.images.firstIndex(where: { $0.stableId == stableId }) {
                    if index != current.images.count - 1 {
                        current.undo.append(.images(current.images, current.selectedImage))
                        current.images.move(at: index, to: current.images.count - 1)
                        current.selectedImage = stableId
                    }
                }
                return current
            }
        }
        genericView.selectImage = { [weak self] stableId in
            self?.updateValue { current in
                var current = current
                current.selectedImage = stableId
                return current
            }
        }
        
        
        genericView.controls = self.controls.genericView
        updateDisposable.set((editValue.get() |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let `self` = self else {return}
            self.readyOnce()
            self.updateSize(false)
            self.genericView.applyEditedData(data, canReset: true, reset: { [weak self] in
                self?.updateValue { current in
                    var current = current
                    current.selectedRect = .zero
                    current.isHorizontalFlipped = false
                    current.dimensions = .none
                    current.orientation = nil
                    current.paintings = []
                    current.images = []
                    current.selectedImage = nil
                    return current
                }
            })
        }))
        
        updatedRectDisposable.set(genericView.selectionRectView.updatedRect.start(next: { [weak self] rect in
            self?.updateValue { current in
                var current = current
                current.selectedRect = rect
                return current
            }
            self?.genericView.updateVisibleCorners()
        }))
    }
    
    deinit {
        updateDisposable.dispose()
        updatedRectDisposable.dispose()
        pasteDisposable.dispose()
    }
    
}
