import TGUIKit
import Foundation


private final class ShimmerEffectForegroundView: View {
    private var currentBackgroundColor: NSColor?
    private var currentForegroundColor: NSColor?
    private let imageViewContainer: View
    private let imageView: ImageView
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageViewContainer = View()
        self.imageView = ImageView()
        super.init()
        self.imageViewContainer.addSubview(self.imageView)
        self.addSubview(self.imageViewContainer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        self.isCurrentlyInHierarchy = self.window != nil
        self.updateAnimation()
        
    }
    
    func update(backgroundColor: NSColor, foregroundColor: NSColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor) {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        let image = generateImage(CGSize(width: 320.0, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        })
        self.imageView.image = image
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageView.layer?.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            } else {
                self.updateAnimation()
            }
        }
        
        if frameUpdated {
            self.imageViewContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageView.layer?.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 320.0
        self.imageView.frame = CGRect(origin: CGPoint(x: -gradientHeight, y: 0.0), size: CGSize(width: gradientHeight, height: containerSize.height))
        let animation = self.imageView.layer!.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.width + gradientHeight) as NSNumber, keyPath: "position.x", timingFunction: .easeOut, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageView.layer?.add(animation, forKey: "shimmer")
    }
}

private let decodingMap: [String] = ["A", "A", "C", "A", "A", "A", "A", "H", "A", "A", "A", "L", "M", "A", "A", "A", "Q", "A", "S", "T", "A", "V", "A", "A", "A", "Z", "a", "a", "c", "a", "a", "a", "a", "h", "a", "a", "a", "l", "m", "a", "a", "a", "q", "a", "s", "t", "a", "v", "a", ".", "a", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", ","]
private func decodeStickerThumbnailData(_ data: Data) -> String {
    var string = "M"
    data.forEach { byte in
        if byte >= 128 + 64 {
            string.append(decodingMap[Int(byte) - 128 - 64])
        } else {
            if byte >= 128 {
                string.append(",")
            } else if byte >= 64 {
                string.append("-")
            }
            string.append("\(byte & 63)")
        }
    }
    string.append("z")
    return string
}

class StickerShimmerEffectView: View {
    private let backgroundView: View
    private let effectView: ShimmerEffectForegroundView
    private let foregroundView: ImageView
    
    private var maskView: ImageView?
    
    private var currentData: Data?
    private var currentBackgroundColor: NSColor?
    private var currentForegroundColor: NSColor?
    private var currentShimmeringColor: NSColor?
    private var currentSize = CGSize()
    
    override init() {
        self.backgroundView = View()
        self.effectView = ShimmerEffectForegroundView()
        self.foregroundView = ImageView()
        
        super.init()
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.effectView)
        self.addSubview(self.foregroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.effectView.updateAbsoluteRect(rect, within: containerSize)
    }
    
    public func update(backgroundColor: NSColor?, foregroundColor: NSColor, shimmeringColor: NSColor, data: Data?, size: CGSize) {
        if self.currentData == data, let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor), let currentShimmeringColor = self.currentShimmeringColor, currentShimmeringColor.isEqual(shimmeringColor), self.currentSize == size {
            return
        }
        
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.currentShimmeringColor = shimmeringColor
        self.currentData = data
        self.currentSize = size
        
        self.backgroundView.backgroundColor = foregroundColor
        
        self.effectView.update(backgroundColor: backgroundColor == nil ? .clear : foregroundColor, foregroundColor: shimmeringColor)
        
        let image = generateImage(size, rotatedContext: { size, context in
            if let backgroundColor = backgroundColor {
                context.setFillColor(backgroundColor.cgColor)
                context.setBlendMode(.copy)
                context.fill(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(NSColor.clear.cgColor)
            } else {
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(NSColor.black.cgColor)
            }
            
            if let data = data {
                var path = decodeStickerThumbnailData(data)
                if !path.hasPrefix("z") {
                    path = "\(path)z"
                }
                let reader = PathDataReader(input: path)
                let segments = reader.read()

                let scale = size.width / 512.0
                context.scaleBy(x: scale, y: scale)
                renderPath(segments, context: context)
            } else {
                let path = CGMutablePath()
                path.addRoundedRect(in: CGRect(origin: CGPoint(), size: size), cornerWidth: 10, cornerHeight: 10)
                context.addPath(path)
                context.fillPath()
            }
        })
                
        if backgroundColor == nil {
            self.foregroundView.image = nil
            
            let maskView: ImageView
            if let current = self.maskView {
                maskView = current
            } else {
                maskView = ImageView()
                maskView.frame = CGRect(origin: CGPoint(), size: size)
                self.maskView = maskView
                self.layer?.mask = maskView.layer
            }
            
        } else {
            self.foregroundView.image = image
            
            if let _ = self.maskView {
                self.layer?.mask = nil
                self.maskView = nil
            }
        }
        
        self.maskView?.image = image
        
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.foregroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.effectView.frame = CGRect(origin: CGPoint(), size: size)
    }
}

open class PathSegment: Equatable {
    public enum SegmentType {
        case M
        case L
        case C
        case Q
        case A
        case z
        case H
        case V
        case S
        case T
        case m
        case l
        case c
        case q
        case a
        case h
        case v
        case s
        case t
        case E
        case e
    }
    
    public let type: SegmentType
    public let data: [Double]

    public init(type: PathSegment.SegmentType = .M, data: [Double] = []) {
        self.type = type
        self.data = data
    }

    open func isAbsolute() -> Bool {
        switch type {
        case .M, .L, .H, .V, .C, .S, .Q, .T, .A, .E:
            return true
        default:
            return false
        }
    }

    public static func == (lhs: PathSegment, rhs: PathSegment) -> Bool {
        return lhs.type == rhs.type && lhs.data == rhs.data
    }
}

private func renderPath(_ segments: [PathSegment], context: CGContext) {
    var currentPoint: CGPoint?
    var cubicPoint: CGPoint?
    var quadrPoint: CGPoint?
    var initialPoint: CGPoint?
    
    func M(_ x: Double, y: Double) {
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        context.move(to: point)
        setInitPoint(point)
    }
    
    func m(_ x: Double, y: Double) {
        if let cur = currentPoint {
            let next = CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y)
            context.move(to: next)
            setInitPoint(next)
        } else {
            M(x, y: y)
        }
    }
    
    func L(_ x: Double, y: Double) {
        lineTo(CGPoint(x: CGFloat(x), y: CGFloat(y)))
    }
    
    func l(_ x: Double, y: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y))
        } else {
            L(x, y: y)
        }
    }
    
    func H(_ x: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(x), y: CGFloat(cur.y)))
        }
    }
    
    func h(_ x: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(cur.y)))
        }
    }
    
    func V(_ y: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(cur.x), y: CGFloat(y)))
        }
    }
    
    func v(_ y: Double) {
        if let cur = currentPoint {
            lineTo(CGPoint(x: CGFloat(cur.x), y: CGFloat(y) + cur.y))
        }
    }

    func lineTo(_ p: CGPoint) {
        context.addLine(to: p)
        setPoint(p)
    }
    
    func c(_ x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) {
        if let cur = currentPoint {
            let endPoint = CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y)
            let controlPoint1 = CGPoint(x: CGFloat(x1) + cur.x, y: CGFloat(y1) + cur.y)
            let controlPoint2 = CGPoint(x: CGFloat(x2) + cur.x, y: CGFloat(y2) + cur.y)
            context.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
            setCubicPoint(endPoint, cubic: controlPoint2)
        }
    }
    
    func C(_ x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) {
        let endPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let controlPoint1 = CGPoint(x: CGFloat(x1), y: CGFloat(y1))
        let controlPoint2 = CGPoint(x: CGFloat(x2), y: CGFloat(y2))
        context.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
        setCubicPoint(endPoint, cubic: controlPoint2)
    }
    
    func s(_ x2: Double, y2: Double, x: Double, y: Double) {
        if let cur = currentPoint {
            let nextCubic = CGPoint(x: CGFloat(x2) + cur.x, y: CGFloat(y2) + cur.y)
            let next = CGPoint(x: CGFloat(x) + cur.x, y: CGFloat(y) + cur.y)
            
            let xy1: CGPoint
            if let curCubicVal = cubicPoint {
                xy1 = CGPoint(x: CGFloat(2 * cur.x) - curCubicVal.x, y: CGFloat(2 * cur.y) - curCubicVal.y)
            } else {
                xy1 = cur
            }
            context.addCurve(to: next, control1: xy1, control2: nextCubic)
            setCubicPoint(next, cubic: nextCubic)
        }
    }
    
    func S(_ x2: Double, y2: Double, x: Double, y: Double) {
        if let cur = currentPoint {
            let nextCubic = CGPoint(x: CGFloat(x2), y: CGFloat(y2))
            let next = CGPoint(x: CGFloat(x), y: CGFloat(y))
            let xy1: CGPoint
            if let curCubicVal = cubicPoint {
                xy1 = CGPoint(x: CGFloat(2 * cur.x) - curCubicVal.x, y: CGFloat(2 * cur.y) - curCubicVal.y)
            } else {
                xy1 = cur
            }
            context.addCurve(to: next, control1: xy1, control2: nextCubic)
            setCubicPoint(next, cubic: nextCubic)
        }
    }
    
    func z() {
        context.fillPath()
    }
    
    func setQuadrPoint(_ p: CGPoint, quadr: CGPoint) {
        currentPoint = p
        quadrPoint = quadr
        cubicPoint = nil
    }

    func setCubicPoint(_ p: CGPoint, cubic: CGPoint) {
        currentPoint = p
        cubicPoint = cubic
        quadrPoint = nil
    }

    func setInitPoint(_ p: CGPoint) {
        setPoint(p)
        initialPoint = p
    }

    func setPoint(_ p: CGPoint) {
        currentPoint = p
        cubicPoint = nil
        quadrPoint = nil
    }
    
    for segment in segments {
        var data = segment.data
        switch segment.type {
            case .M:
                M(data[0], y: data[1])
                data.removeSubrange(Range(uncheckedBounds: (lower: 0, upper: 2)))
                while data.count >= 2 {
                    L(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .m:
                m(data[0], y: data[1])
                data.removeSubrange((0 ..< 2))
                while data.count >= 2 {
                    l(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .L:
                while data.count >= 2 {
                    L(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .l:
                while data.count >= 2 {
                    l(data[0], y: data[1])
                    data.removeSubrange((0 ..< 2))
                }
            case .H:
                H(data[0])
            case .h:
                h(data[0])
            case .V:
                V(data[0])
            case .v:
                v(data[0])
            case .C:
                while data.count >= 6 {
                    C(data[0], y1: data[1], x2: data[2], y2: data[3], x: data[4], y: data[5])
                    data.removeSubrange((0 ..< 6))
                }
            case .c:
                while data.count >= 6 {
                    c(data[0], y1: data[1], x2: data[2], y2: data[3], x: data[4], y: data[5])
                    data.removeSubrange((0 ..< 6))
                }
            case .S:
                while data.count >= 4 {
                    S(data[0], y2: data[1], x: data[2], y: data[3])
                    data.removeSubrange((0 ..< 4))
                }
            case .s:
                while data.count >= 4 {
                    s(data[0], y2: data[1], x: data[2], y: data[3])
                    data.removeSubrange((0 ..< 4))
                }
            case .z:
                z()
            default:
                print("unknown")
                break
        }
    }
}

private class PathDataReader {
    private let input: String
    private var current: UnicodeScalar?
    private var previous: UnicodeScalar?
    private var iterator: String.UnicodeScalarView.Iterator

    private static let spaces: Set<UnicodeScalar> = Set("\n\r\t ,".unicodeScalars)

    init(input: String) {
        self.input = input
        self.iterator = input.unicodeScalars.makeIterator()
    }

    public func read() -> [PathSegment] {
        readNext()
        var segments = [PathSegment]()
        while let array = readSegments() {
            segments.append(contentsOf: array)
        }
        return segments
    }

    private func readSegments() -> [PathSegment]? {
        if let type = readSegmentType() {
            let argCount = getArgCount(segment: type)
            if argCount == 0 {
                return [PathSegment(type: type)]
            }
            var result = [PathSegment]()
            let data: [Double]
            if type == .a || type == .A {
                data = readDataOfASegment()
            } else {
                data = readData()
            }
            var index = 0
            var isFirstSegment = true
            while index < data.count {
                let end = index + argCount
                if end > data.count {
                    break
                }
                var currentType = type
                if type == .M && !isFirstSegment {
                    currentType = .L
                }
                if type == .m && !isFirstSegment {
                    currentType = .l
                }
                result.append(PathSegment(type: currentType, data: Array(data[index..<end])))
                isFirstSegment = false
                index = end
            }
            return result
        }
        return nil
    }

    private func readData() -> [Double] {
        var data = [Double]()
        while true {
            skipSpaces()
            if let value = readNum() {
                data.append(value)
            } else {
                return data
            }
        }
    }

    private func readDataOfASegment() -> [Double] {
        let argCount = getArgCount(segment: .A)
        var data: [Double] = []
        var index = 0
        while true {
            skipSpaces()
            let value: Double?
            let indexMod = index % argCount
            if indexMod == 3 || indexMod == 4 {
                value = readFlag()
            } else {
                value = readNum()
            }
            guard let doubleValue = value else {
                return data
            }
            data.append(doubleValue)
            index += 1
        }
        return data
    }

    private func skipSpaces() {
        var currentCharacter = current
        while let character = currentCharacter, Self.spaces.contains(character) {
            currentCharacter = readNext()
        }
    }

    private func readFlag() -> Double? {
        guard let ch = current else {
            return .none
        }
        readNext()
        switch ch {
        case "0":
            return 0
        case "1":
            return 1
        default:
            return .none
        }
    }

    fileprivate func readNum() -> Double? {
        guard let ch = current else {
            return .none
        }

        guard ch >= "0" && ch <= "9" || ch == "." || ch == "-" else {
            return .none
        }

        var chars = [ch]
        var hasDot = ch == "."
        while let ch = readDigit(&hasDot) {
            chars.append(ch)
        }

        var buf = ""
        buf.unicodeScalars.append(contentsOf: chars)
        guard let value = Double(buf) else {
            return .none
        }
        return value
    }

    fileprivate func readDigit(_ hasDot: inout Bool) -> UnicodeScalar? {
        if let ch = readNext() {
            if (ch >= "0" && ch <= "9") || ch == "e" || (previous == "e" && ch == "-") {
                return ch
            } else if ch == "." && !hasDot {
                hasDot = true
                return ch
            }
        }
        return nil
    }

    fileprivate func isNum(ch: UnicodeScalar, hasDot: inout Bool) -> Bool {
        switch ch {
        case "0"..."9":
            return true
        case ".":
            if hasDot {
                return false
            }
            hasDot = true
        default:
            return true
        }
        return false
    }

    @discardableResult
    private func readNext() -> UnicodeScalar? {
        previous = current
        current = iterator.next()
        return current
    }

    private func isAcceptableSeparator(_ ch: UnicodeScalar?) -> Bool {
        if let ch = ch {
            return "\n\r\t ,".contains(String(ch))
        }
        return false
    }

    private func readSegmentType() -> PathSegment.SegmentType? {
        while true {
            if let type = getPathSegmentType() {
                readNext()
                return type
            }
            if readNext() == nil {
                return nil
            }
        }
    }

    fileprivate func getPathSegmentType() -> PathSegment.SegmentType? {
        if let ch = current {
            switch ch {
            case "M":
                return .M
            case "m":
                return .m
            case "L":
                return .L
            case "l":
                return .l
            case "C":
                return .C
            case "c":
                return .c
            case "Q":
                return .Q
            case "q":
                return .q
            case "A":
                return .A
            case "a":
                return .a
            case "z", "Z":
                return .z
            case "H":
                return .H
            case "h":
                return .h
            case "V":
                return .V
            case "v":
                return .v
            case "S":
                return .S
            case "s":
                return .s
            case "T":
                return .T
            case "t":
                return .t
            default:
                break
            }
        }
        return nil
    }

    fileprivate func getArgCount(segment: PathSegment.SegmentType) -> Int {
        switch segment {
        case .H, .h, .V, .v:
            return 1
        case .M, .m, .L, .l, .T, .t:
            return 2
        case .S, .s, .Q, .q:
            return 4
        case .C, .c:
            return 6
        case .A, .a:
            return 7
        default:
            return 0
        }
    }
}
