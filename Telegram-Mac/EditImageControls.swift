//
//  EditImageControls.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

struct EditedImageData : Equatable {
    let originalUrl: URL
    let selectedRect: NSRect
    let orientation: ImageOrientation?
    let dimensions: SelectionRectDimensions
    let isHorizontalFlipped: Bool
    init(originalUrl: URL, selectedRect: NSRect = NSZeroRect, orientation: ImageOrientation? = nil, dimensions: SelectionRectDimensions = .none, isHorizontalFlipped: Bool = false) {
        self.originalUrl = originalUrl
        self.dimensions = dimensions
        self.selectedRect = selectedRect
        self.orientation = orientation
        self.isHorizontalFlipped = isHorizontalFlipped
    }
    var hasntData: Bool {
        return orientation == nil && dimensions == .none && !isHorizontalFlipped
    }
    
    
    func withUpdatedOrientation( _ orientation: ImageOrientation?) -> EditedImageData {
        return EditedImageData(originalUrl: self.originalUrl, selectedRect: selectedRect, orientation: orientation, dimensions: self.dimensions, isHorizontalFlipped: self.isHorizontalFlipped)
    }
    func withUpdatedFlip(_ isHorizontalFlipped: Bool) -> EditedImageData {
        return EditedImageData(originalUrl: self.originalUrl, selectedRect: self.selectedRect, orientation: self.orientation, dimensions: self.dimensions, isHorizontalFlipped: isHorizontalFlipped)
    }
    func withUpdatedDimensions(_ dimensions: SelectionRectDimensions) -> EditedImageData {
        return EditedImageData(originalUrl: self.originalUrl, selectedRect: self.selectedRect, orientation: self.orientation, dimensions: dimensions, isHorizontalFlipped: self.isHorizontalFlipped)
    }
    
    func withUpdatedSelectedRect(_ selectedRect: NSRect) -> EditedImageData {
        return EditedImageData(originalUrl: self.originalUrl, selectedRect: selectedRect, orientation: self.orientation, dimensions: self.dimensions, isHorizontalFlipped: self.isHorizontalFlipped)
    }
    
    func makeImage(_ image: CGImage) -> CGImage {
        return EditedImageData.makeImage(image, data: self)
    }
    
    func isNeedToRegenerate(_ data: EditedImageData?) -> Bool {
        return data?.orientation != self.orientation || (data != nil && data!.isHorizontalFlipped != self.isHorizontalFlipped)
    }
    
    fileprivate static func makeImage(_ image: CGImage, data: EditedImageData) -> CGImage {
        var image: CGImage = image
        var orientation = data.orientation
        
        if data.isHorizontalFlipped, let temp = orientation {
            switch temp {
            case .left:
                orientation = .leftMirrored
            case .right:
                orientation = .rightMirrored
            case .down:
                orientation = .downMirrored
            default:
                orientation = nil
            }
        }
        if let orientation = orientation {
            image = image.createMatchingBackingDataWithImage(orienation: orientation)!
        } else if data.isHorizontalFlipped {
            return generateImage(image.backingSize, contextGenerator: { size, ctx in
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: -1.0, y: 1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                ctx.draw(image, in: NSMakeRect(0, 0, size.width, size.height))
                
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: -1.0, y: 1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            })!
          //  image = NSImage(cgImage: image, size: image.backingSize).precomposed(flipHorizontal: true)
        }
       
        return image
    }
    
    static func generateNewUrl(data: EditedImageData, selectedRect: NSRect) -> Signal<URL, NoError> {
        return Signal { subscriber in
            
            if let image = NSImage(contentsOf: data.originalUrl)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                if selectedRect == NSMakeRect(0, 0, image.size.width, image.size.height) && data.hasntData {
                    subscriber.putNext(data.originalUrl)
                    subscriber.putCompletion()
                } else {
                    if let image = self.makeImage(image, data: data).cropping(to: selectedRect) {
                        return putToTemp(image: NSImage(cgImage: image, size: image.size), compress: true).start(next: { url in
                            subscriber.putNext(URL(fileURLWithPath: url))
                        }, error: { error in
                            subscriber.putError(error)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                    }
                }
                
                
            }
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(resourcesQueue)
    }
    
}

final class EditImageControlsArguments {
    let cancel:()->Void
    let success: () -> Void
    let flip: () -> Void
    let selectionDimensions: (SelectionRectDimensions) -> Void
    let rotate: () -> Void
    init(cancel:@escaping()->Void, success: @escaping()->Void, flip: @escaping()->Void, selectionDimensions: @escaping(SelectionRectDimensions)->Void, rotate: @escaping() -> Void) {
        self.cancel = cancel
        self.success = success
        self.flip = flip
        self.rotate = rotate
        self.selectionDimensions = selectionDimensions
    }
}

final class EditImageControlsView : View {
    let cancel = TitleButton()
    private let success = TitleButton()
    private let controlsContainer = View()
    private let flipper = ImageButton()
    private let rotate = ImageButton()
    private let dimensions = ImageButton()
    private var currentData: EditedImageData?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(cancel)
        addSubview(success)
        
        addSubview(controlsContainer)
        
        controlsContainer.addSubview(flipper)
        controlsContainer.addSubview(rotate)
        controlsContainer.addSubview(dimensions)
        
        controlsContainer.border = [.Left, .Right]
        controlsContainer.borderColor = NSColor.black.withAlphaComponent(0.2)
        backgroundColor = NSColor(0x303030)
        layer?.cornerRadius = 6
    }
    
    fileprivate func updateUserInterface(_ data: EditedImageData) {
        flipper.set(image: NSImage(named: "Icon_EditImageFlip")!.precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        rotate.set(image: NSImage(named: "Icon_EditImageRotate")!.precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        dimensions.set(image: NSImage(named: "Icon_EditImageSizes")!.precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)

        
        flipper.set(image: NSImage(named: "Icon_EditImageFlip")!.precomposed(.white), for: .Hover)
        rotate.set(image: NSImage(named: "Icon_EditImageRotate")!.precomposed(.white), for: .Hover)
        dimensions.set(image: NSImage(named: "Icon_EditImageSizes")!.precomposed(.white), for: .Hover)

        
        _ = flipper.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = rotate.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = dimensions.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        
        cancel.set(font: .medium(.title), for: .Normal)
        success.set(font: .medium(.title), for: .Normal)
        
        success.set(color: tintedNightPalette.accent, for: .Normal)
        cancel.set(color: .white, for: .Normal)
        
        cancel.set(text: L10n.modalCancel, for: .Normal)
        success.set(text: L10n.navigationDone, for: .Normal)
        
        _ = cancel.sizeToFit(NSZeroSize, NSMakeSize(75, frame.height), thatFit: true)
        _ = success.sizeToFit(NSZeroSize, NSMakeSize(75, frame.height), thatFit: true)
        
        flipper.isSelected = data.isHorizontalFlipped
        rotate.isSelected = data.orientation != nil
        dimensions.isSelected = data.dimensions != .none
    }
    
    override func layout() {
        super.layout()
        controlsContainer.setFrameSize(rotate.frame.width + flipper.frame.width + dimensions.frame.width, rotate.frame.height)
        rotate.setFrameOrigin(NSMakePoint(0, 0))
        flipper.setFrameOrigin(NSMakePoint(rotate.frame.maxX, 0))
        dimensions.setFrameOrigin(NSMakePoint(flipper.frame.maxX, 0))
        controlsContainer.center()
        
        cancel.centerY()
        success.centerY(x: frame.width - success.frame.width)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    fileprivate func set(settings: EditControllerSettings, handlers: EditImageControlsArguments) {
        
        success.set(handler: { _ in
            handlers.success()
        }, for: .Click)
        
        cancel.set(handler: { _ in
            handlers.cancel()
        }, for: .Click)
        
        flipper.set(handler: { control in
            handlers.flip()
        }, for: .Click)
        
        rotate.set(handler: { _ in
            handlers.rotate()
        }, for: .Click)
        
        dimensions.set(handler: { control in
            switch settings {
            case .disableSizes:
                break
            case .plain:
                if control.isSelected {
                    handlers.selectionDimensions(.none)
                } else {
                    let items: [SPopoverItem] = SelectionRectDimensions.all.map { value in
                        return SPopoverItem(value.description, {
                            handlers.selectionDimensions(value)
                        })
                    }
                    showPopover(for: control, with: SPopoverViewController(items: items, visibility: SelectionRectDimensions.all.count, handlerDelay: 0))
                }
            }
            
           
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EditImageControls: GenericViewController<EditImageControlsView> {
    let arguments: EditImageControlsArguments
    private let stateDisposable = MetaDisposable()
    private let stateValue: Signal<EditedImageData, NoError>
    private let settings: EditControllerSettings
    init(settings:EditControllerSettings, arguments: EditImageControlsArguments, stateValue: Signal<EditedImageData, NoError>) {
        self.arguments = arguments
        self.stateValue = stateValue
        self.settings = settings
        super.init(frame: NSMakeRect(0, 0, 300, 40))
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.set(settings: settings, handlers: arguments)
        stateDisposable.set(stateValue.start(next: { [weak self] current in
            self?.genericView.updateUserInterface(current)
        }))
    }
    
    deinit {
        stateDisposable.dispose()
    }
}
