//
//  File.swift
//  
//
//  Created by Mike Renoir on 20.12.2022.
//

import Foundation
import MergeLists
import AppKit
import ColorPalette


private struct Particle {
    var trackIndex: Int
    var position: CGPoint
    var scale: CGFloat
    var alpha: CGFloat
    var direction: CGPoint
    var velocity: CGFloat
    
    init(
        trackIndex: Int,
        position: CGPoint,
        scale: CGFloat,
        alpha: CGFloat,
        direction: CGPoint,
        velocity: CGFloat
    ) {
        self.trackIndex = trackIndex
        self.position = position
        self.scale = scale
        self.alpha = alpha
        self.direction = direction
        self.velocity = velocity
    }
    
    mutating func update(deltaTime: CGFloat) {
        var position = self.position
        position.x += self.direction.x * self.velocity * deltaTime
        position.y += self.direction.y * self.velocity * deltaTime
        self.position = position
    }
}

private final class ParticleSet {
    private(set) var particles: [Particle] = []
    
    init() {
        self.generateParticles(preAdvance: true)
    }
    
    private func generateParticles(preAdvance: Bool) {
        let maxDirections = 24
        
        if self.particles.count < maxDirections {
            var allTrackIndices: [Int] = Array(repeating: 0, count: maxDirections)
            for i in 0 ..< maxDirections {
                allTrackIndices[i] = i
            }
            var takenIndexCount = 0
            for particle in self.particles {
                allTrackIndices[particle.trackIndex] = -1
                takenIndexCount += 1
            }
            var availableTrackIndices: [Int] = []
            availableTrackIndices.reserveCapacity(maxDirections - takenIndexCount)
            for index in allTrackIndices {
                if index != -1 {
                    availableTrackIndices.append(index)
                }
            }
            
            if !availableTrackIndices.isEmpty {
                availableTrackIndices.shuffle()
                
                for takeIndex in availableTrackIndices {
                    let directionIndex = takeIndex
                    let angle = (CGFloat(directionIndex % maxDirections) / CGFloat(maxDirections)) * CGFloat.pi * 2.0
                    
                    let direction = CGPoint(x: cos(angle), y: sin(angle))
                    let velocity = CGFloat.random(in: 20.0 ..< 40.0)
                    let alpha = CGFloat.random(in: 0.1 ..< 0.4)
                    let scale = CGFloat.random(in: 0.5 ... 1.0) * 0.22
                    
                    var position = CGPoint(x: 100.0, y: 100.0)
                    var initialOffset: CGFloat = 0.4
                    if preAdvance {
                        initialOffset = CGFloat.random(in: initialOffset ... 1.0)
                    }
                    position.x += direction.x * initialOffset * 105.0
                    position.y += direction.y * initialOffset * 105.0
                    
                    let particle = Particle(
                        trackIndex: directionIndex,
                        position: position,
                        scale: scale,
                        alpha: alpha,
                        direction: direction,
                        velocity: velocity
                    )
                    self.particles.append(particle)
                }
            }
        }
    }
    
    func update(deltaTime: CGFloat) {
        let size = CGSize(width: 200.0, height: 200.0)
        let radius2 = pow(size.width * 0.5 + 10.0, 2.0)
        for i in (0 ..< self.particles.count).reversed() {
            self.particles[i].update(deltaTime: deltaTime)
            let position = self.particles[i].position
            
            if pow(position.x - size.width * 0.5, 2.0) + pow(position.y - size.height * 0.5, 2.0) > radius2 {
                self.particles.remove(at: i)
            }
        }
        
        self.generateParticles(preAdvance: false)
    }
}


public func optimizeArray(array: [Int], minPercent: Double) -> [Int] {
    let total = array.reduce(0, +)

    let minValue = Int(Double(total) * minPercent)

    var array = array
    var totalDiff = 0
    
    for i in 0 ..< array.count {
        if array[i] < minValue && array[i] > 0 {
            let diff = minValue - array[i]
            array[i] += diff
            totalDiff += diff
        }
    }

    let minus = totalDiff / array.count
    for i in 0 ..< array.count {
        if array[i] > 0 {
            array[i] -= minus
        }
    }
    
    return array
}





private class TooltipView : View {
    private let textView = TextView()
    private let visual = VisualEffect()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(visual)
        addSubview(textView)
        
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
                
        layer?.cornerRadius = 10
        
    }
    
    func update(attr: NSAttributedString, animated: Bool) -> NSSize {
        let layout = TextViewLayout(attr)
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
        visual.bgColor = presentation.colors.background.withMultipliedAlpha(0.8)
        return NSMakeSize(layout.layoutSize.width + 16, layout.layoutSize.height + 10)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) -> Void {
        transition.updateFrame(view: textView, frame: textView.centerFrame())
        transition.updateFrame(view: visual, frame: size.bounds.insetBy(dx: -10, dy: -5))
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class SectionLayer: SimpleLayer {
    private let maskLayer: SimpleShapeLayer
    private let gradientLayer: SimpleGradientLayer
        
    private var particleImage: CGImage?
    private var particleLayers: [SimpleLayer] = []
    
    private let item: PieChartView.Item
    init(_ item: PieChartView.Item) {
        self.item = item
        self.maskLayer = SimpleShapeLayer()
        self.maskLayer.fillColor = NSColor.white.cgColor
        
        self.gradientLayer = SimpleGradientLayer()
        self.gradientLayer.type = .radial
        self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
                
        super.init()
        
        self.mask = self.maskLayer
        self.addSublayer(self.gradientLayer)
        
        self.particleImage = item.particle
    }
    
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func isPointOnGraph(point: CGPoint) -> Bool {
        if let path = self.maskLayer.path {
            return path.contains(point)
        }
        return false
    }
    
    func update(size: CGSize, path: CGPath) {
        self.maskLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.gradientLayer.frame = CGRect(origin: CGPoint(), size: size)
        
        let normalColor = item.color.cgColor
        let darkerColor = item.color.withMultipliedBrightnessBy(0.96).cgColor
        let colors: [CGColor] = [
            darkerColor,
            normalColor,
            normalColor,
            normalColor,
            darkerColor
        ]
        self.gradientLayer.colors = colors
        
        let locations: [CGFloat] = [
            0.0,
            0.3,
            0.5,
            0.7,
            1.0
        ]
        self.gradientLayer.locations = locations.map { location in
            let location = location * 0.5 + 0.5
            return location as NSNumber
        }
        
        let path = CGMutablePath()
        self.maskLayer.path = path
        
    }
    
    func updateParticles(particleSet: ParticleSet) {
        guard let particleImage = self.particleImage else {
            return
        }
        for i in 0 ..< particleSet.particles.count {
            let particle = particleSet.particles[i]
            
            let particleLayer: SimpleLayer
            if i < self.particleLayers.count {
                particleLayer = self.particleLayers[i]
                particleLayer.isHidden = false
            } else {
                particleLayer = SimpleLayer()
                particleLayer.contents = particleImage
                particleLayer.bounds = CGRect(origin: CGPoint(), size: particleImage.size)
                self.particleLayers.append(particleLayer)
                self.insertSublayer(particleLayer, above: self.gradientLayer)
            }
            
            particleLayer.position = particle.position
            particleLayer.transform = CATransform3DMakeScale(particle.scale, particle.scale, 1.0)
            particleLayer.opacity = Float(particle.alpha)
        }
        if particleSet.particles.count < self.particleLayers.count {
            for i in particleSet.particles.count ..< self.particleLayers.count {
                self.particleLayers[i].isHidden = true
            }
        }
    }
}


public class PieChartView : Control {
    
    
    
    public struct Item : Comparable, Identifiable {
        public var id: AnyHashable
        public var index: Int
        public var count: Int
        public var color: NSColor
        public var badge: NSAttributedString?
        public var particle: CGImage?
        public init(id: AnyHashable, index: Int, count: Int, color: NSColor, badge: NSAttributedString?, particle: CGImage?) {
            self.id = id
            self.index = index
            self.count = count
            self.color = color
            self.badge = badge
            self.particle = particle
        }
        public var stableId: AnyHashable {
            return id
        }
        public static func <(lhs: Item, rhs: Item) -> Bool {
            return lhs.index < rhs.index
        }
    }
    
    public struct Presentation {
        public var strokeColor: NSColor
        public var strokeSize: CGFloat
        public var bgColor: NSColor
        public var totalTextColor: NSColor
        public var itemTextColor: NSColor
        public init(strokeColor: NSColor, strokeSize: CGFloat, bgColor: NSColor, totalTextColor: NSColor, itemTextColor: NSColor) {
            self.strokeColor = strokeColor
            self.strokeSize = strokeSize
            self.bgColor = bgColor
            self.totalTextColor = totalTextColor
            self.itemTextColor = itemTextColor
        }
    }
    
    public private(set) var items: [Item] = []
    public var presentation: Presentation {
        didSet {
            needsDisplay = true
        }
    }
    private let totalTextView = DynamicCounterTextView()
    private var tooltipView: TooltipView?
    
    
    public var toggleSelected:((Item)->Void)? = nil
    
    
    private var displayAnimator: ConstantDisplayLinkAnimator?
    
    private struct AnimationValues {
        struct Value {
            let value: Int
            let timestamp: CGFloat
        }
        var values:[AnyHashable : Value] = [:]
        var selection:[AnyHashable : CGFloat] = [:]
        var radius:[AnyHashable : CGFloat] = [:]
        var selected: AnyHashable? = nil
        
        var isEmpty: Bool {
            return radius.isEmpty && selection.isEmpty && values.isEmpty && selected == nil
        }
    }
    
    private var animationValues: AnimationValues = .init() {
        didSet {
            DispatchQueue.main.async {
                self.displayAnimator?.isPaused = self.animationValues.isEmpty
            }
            self.needsDisplay = true
        }
    }
    private var sectionLayers: [AnyHashable: SectionLayer] = [:]
    private let particleSet: ParticleSet = ParticleSet()

    
    public init(frame frameRect: NSRect, presentation: Presentation) {
        self.presentation = presentation
        super.init(frame: frameRect)
        addSubview(totalTextView)
        
        set(handler: { [weak self] control in
            self?.invokeToggle()
        }, for: .Click)
    }
    
    private func invokeToggle() {
        guard let window = self.window else {
            return
        }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let index = self.selectedItemIndex(at: point) {
            self.toggleSelected?(self.items[index])
        }
        if let view = tooltipView {
            performSubviewRemoval(view, animated: true)
            self.tooltipView = nil
        }
    }
        
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    public func update(items: [Item], dynamicText: String, animated: Bool) {
        
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)

        
        let prevItems = self.items
        
        for idx in deleteIndices.reversed() {
            self.items.remove(at: idx)
        }
        var updated = self.animationValues.values
        
        for indicesAndItem in indicesAndItems {
            let item = indicesAndItem.1
            self.items.insert(item, at: indicesAndItem.0)
            if animated {
                updated[item.stableId] = .init(value: 0, timestamp: 0)
            }
        }
        
    
        
        for updateIndex in updateIndices {
            let item = updateIndex.1
            let prev: Item = prevItems[updateIndex.2]
            self.items[updateIndex.0] = item
            if updated[item.stableId] == nil, animated {
                updated[item.stableId] = .init(value: prev.count, timestamp: 0)
            } else if let value = updated[item.stableId] {
                updated[item.stableId] = .init(value: value.value, timestamp: 0)
            }
        }
        
        if prevItems.isEmpty {
            for item in self.items {
                updated[item.stableId] = .init(value: items.reduce(0, { $0 + $1.count }) / items.count, timestamp: 0)
            }
        }
        
        self.animationValues.values = updated

        
        var dynamicFontSize: CGFloat = 15
        var value: DynamicCounterTextView.Value = DynamicCounterTextView.make(for: dynamicText, count: dynamicText, font: .avatar(dynamicFontSize), textColor: presentation.totalTextColor, width: .greatestFiniteMagnitude)
        
        let innerDiameter = min(bounds.width, bounds.height) / 2.5

        while value.size.width > innerDiameter && dynamicFontSize > 1 {
            dynamicFontSize -= 1
            value = DynamicCounterTextView.make(for: dynamicText, count: dynamicText, font: .avatar(dynamicFontSize), textColor: presentation.totalTextColor, width: dynamicFontSize < 6 ? innerDiameter - 4 : .greatestFiniteMagnitude)
        }
        
        totalTextView.update(value, animated: animated)
        totalTextView.change(size: value.size, animated: animated)
        totalTextView.change(pos: focus(value.size).origin, animated: animated)
        
        if displayAnimator == nil {
            displayAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                self?.runAnimatorUpdater()
            })
        }
        
        displayAnimator?.isPaused = self.animationValues.isEmpty
        
        self.runAnimatorUpdater()
        
        needsLayout = true
        self.needsDisplay = true
    }
    
    private func runAnimatorUpdater() {
        var updated = self.animationValues.values
        for (key, value) in self.animationValues.values {
            let item = self.items.first(where: { $0.id == key })
            if let item = item {
                let d = CGFloat(item.count - value.value)
                let timestamp = value.timestamp + 0.016 / 3
                let curve = listViewAnimationCurveEaseInOut(timestamp)
                let result = d * curve
                let current: Int
                if result < 0 {
                    current = Int(floor(result))
                } else {
                    current = Int(ceil(result))
                }
                let updatedValue = value.value + current
                updated[key] = .init(value: updatedValue, timestamp: timestamp)
                
                if abs(current) == 0 {
                    updated.removeValue(forKey: key)
                }
            }
        }
        
        var selection = self.animationValues.selection
        if let selected = self.animationValues.selected {
            let current = selection[selected] ?? 0
            selection[selected] = min(current + 0.016 * 8, 1)
        }
        for (key, value) in self.animationValues.selection {
            if key != self.animationValues.selected {
                let updatedValue = max(0, value - 0.016 * 8)
                if updatedValue > 0 {
                    selection[key] = updatedValue
                } else {
                    selection.removeValue(forKey: key)
                }
            }
        }
        
        var radius = self.animationValues.radius
        for item in items {
            let current = radius[item.id] ?? 0
            let value: CGFloat
            if !selection.isEmpty && selection[item.id] == nil {
                value = min(current + 0.016 * 8, 1)
            } else {
                value = max(current - 0.016 * 8, 0)
            }
            radius[item.id] = value
            if value == 0 {
                radius.removeValue(forKey: item.id)
            }
        }
        
        
        self.animationValues = .init(values: updated, selection: selection, radius: radius, selected: self.animationValues.selected)
        
        
    }
    
    public override func layout() {
        super.layout()
        totalTextView.center()
    }
    
    func selectedItemIndex(at point: CGPoint) -> Int? {
        
        
        
        let lastRenderedChartFrame = self.bounds
        let center = CGPoint(x: lastRenderedChartFrame.midX, y: lastRenderedChartFrame.midY)

        let radius = min(bounds.width, bounds.height) / 2 - presentation.strokeSize - 8

        let innerRadius = min(bounds.width, bounds.height) / 2.5 / 2
        
        if center.distance(p2: point) > radius || center.distance(p2: point) < innerRadius { return nil }
        let angle = (center - point).angle + .pi
        let total: CGFloat = items.map({ CGFloat($0.count) }).reduce(0, +)
        var startAngle: CGFloat = initialAngle
        for (index, piece) in items.enumerated() {
            let percent = CGFloat(piece.count) / total
            let segmentSize = 2 * .pi * percent
            let endAngle = startAngle + segmentSize
            if angle >= startAngle && angle <= endAngle ||
               angle + .pi * 2 >= startAngle && angle + .pi * 2 <= endAngle {
                return index
            }
            startAngle = endAngle
        }
        return nil
    }
    
    private let initialAngle: CGFloat = .pi / 3
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        guard let window = self.window else {
            return
        }
       
        var startAngle: CGFloat = self.initialAngle
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
                
        
        let items = self.items.filter { $0.count > 0 || animationValues.values[$0.stableId] != nil }
        
        var counts:[Int] = items.map { $0.count }
        
        for (i, item) in items.enumerated() {
            let count: CGFloat
            if let current = animationValues.values[item.stableId] {
                count = CGFloat(current.value)
            } else {
                count = CGFloat(item.count)
            }
            counts[i] = Int(count)
        }
        let total = counts.reduce(0, +)
        
        let selected = selectedItemIndex(at: self.convert(window.mouseLocationOutsideOfEventStream, from: nil))
        
        var validIds: [AnyHashable] = []

        
        for (i, item) in items.enumerated() {
            
            var selectionAnimationFraction: CGFloat = self.animationValues.selection[item.id] ?? 0
            if items.count == 1, selected == nil  {
                selectionAnimationFraction = 0
            }
            var radius = min(bounds.width, bounds.height) / 2 - presentation.strokeSize - 8

            if let add = self.animationValues.radius[item.id], items.count > 1 {
                radius -= 5 * add
            }
            
            
            let animationSelectionOffset: CGFloat = 5

            let maximumFontSize: CGFloat = radius / 7
            let minimumFontSize: CGFloat = 4
            let centerOffsetStartAngle = CGFloat.pi / 4
            let diagramRadius = radius - animationSelectionOffset

            
            let count = CGFloat(counts[i])
            let segmentSize = 2 * .pi * (count / CGFloat(total))
            let endAngle = startAngle + segmentSize
            let centerAngle = (startAngle + endAngle) / 2
            let labelVector = CGPoint(x: cos(centerAngle),
                                      y: sin(centerAngle))
            
            let updatedCenter = CGPoint(x: center.x ,
                                        y: center.y )
            
            ctx.saveGState()
            let path = CGMutablePath()
            path.move(to: updatedCenter)
            path.addArc(center: updatedCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()
            
            ctx.addPath(path)
            ctx.setFillColor(item.color.cgColor)
            ctx.fillPath()

            ctx.addPath(path)
            ctx.setLineWidth(presentation.strokeSize)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(presentation.strokeColor.cgColor)
            ctx.strokePath()
            
            ctx.restoreGState()
            
            
            ctx.saveGState()
            
            let percent = (count / CGFloat(total))
            
            if percent >= 0.04, percent != 1.0 {
                let text = "\(Int(percent * 100))%"
                let fraction = max(0, min(centerOffsetStartAngle, 1))
                
                let fontSize = (minimumFontSize + (maximumFontSize - minimumFontSize) * fraction).rounded(.down)
                let labelPotisionOffset = diagramRadius / 2 + diagramRadius / 2 * (1 - fraction) + 15
                let font = NSFont.avatar(fontSize)
                
                let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white,
                                                                 .font: font]
                
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                let textNode = TextLabelNode.layoutText(attributedString, bounds.size)
                
                let labelPoint = CGPoint(x: labelVector.x * labelPotisionOffset + updatedCenter.x - textNode.0.size.width / 2,
                                         y: labelVector.y * labelPotisionOffset + updatedCenter.y - textNode.0.size.height / 2)
                textNode.1.draw(CGRect(origin: labelPoint, size: textNode.0.size), in: ctx, backingScaleFactor: System.backingScale)

            }
            
            ctx.restoreGState()

            startAngle = endAngle
        }
        ctx.saveGState()
        ctx.move(to: center)
        ctx.setBlendMode(.clear)
        let clearRadius = min(bounds.width, bounds.height) / 2.5
        ctx.fillEllipse(in: focus(NSMakeSize(clearRadius, clearRadius)))
        ctx.restoreGState()
        
    }
    
    private func middleTextPoint(_ point: NSPoint, item: Item) -> NSPoint {
        
        let selectionAnimationFraction: CGFloat = 1.0

        let radius = min(bounds.width, bounds.height) / 2 - presentation.strokeSize - 8


        
        let centerOffsetStartAngle = CGFloat.pi / 4
        let fraction = max(0, min(centerOffsetStartAngle, 1))
        
        let animationSelectionOffset: CGFloat = 5

        let diagramRadius = radius - animationSelectionOffset

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let labelPotisionOffset = diagramRadius / 2 + diagramRadius / 2 * (1 - fraction) + 15
        let angle = (center - point).angle + .pi
        let total: CGFloat = items.map({ CGFloat($0.count) }).reduce(0, +)

        var startAngle: CGFloat = initialAngle
        for piece in items {
            let percent = CGFloat(piece.count) / total
            let segmentSize = 2 * .pi * percent
            let endAngle = startAngle + segmentSize
            if angle >= startAngle && angle <= endAngle ||
               angle + .pi * 2 >= startAngle && angle + .pi * 2 <= endAngle {
                
                let centerAngle = (startAngle + endAngle) / 2
                let vector = CGPoint(x: cos(centerAngle),
                                          y: sin(centerAngle))
                
                let updatedCenter = CGPoint(x: center.x + vector.x * selectionAnimationFraction * animationSelectionOffset,
                                            y: center.y + vector.y * selectionAnimationFraction * animationSelectionOffset)


                return CGPoint(x: floor(vector.x * labelPotisionOffset + updatedCenter.x),
                                         y: floor(vector.y * labelPotisionOffset + updatedCenter.y))

            }
            startAngle = endAngle
        }
        return .zero
    }
    
    private func updateTooltip(_ point: NSPoint) {
        if let index = self.selectedItemIndex(at: point) {
            let item = self.items[index]
            if let badge = item.badge {
                let current: TooltipView
                if let view = self.tooltipView {
                    current = view
                } else {
                    current = TooltipView(frame: .zero)
                    addSubview(current)
                    self.tooltipView = current
                    
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                let size = current.update(attr: badge, animated: true)
                let point = middleTextPoint(point, item: item)
                current.frame = CGRect(origin: point - NSMakePoint(size.width / 2, size.height / 2), size: size)
            }  else if let view = self.tooltipView {
                performSubviewRemoval(view, animated: true)
                self.tooltipView = nil
            }
        } else if let view = self.tooltipView {
            performSubviewRemoval(view, animated: true)
            self.tooltipView = nil
        }
    }
    
    private func updateGraph(_ point: NSPoint) {
        if let index = self.selectedItemIndex(at: point) {
            self.animationValues.selected = self.items[index].id
        } else {
            self.animationValues.selected = nil
        }
        self.updateTooltip(point)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateGraph(self.convert(event.locationInWindow, from: nil))
    }
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateGraph(self.convert(event.locationInWindow, from: nil))
    }
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateGraph(self.convert(event.locationInWindow, from: nil))
    }
}
