import AppKit

public protocol Interpolatable {
    static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> (Interpolatable)
}


private final class PropertyAnimation<T: Interpolatable> {
    let from: T
    let to: T
    let animation: ContainedViewLayoutTransition
    let startTimestamp: Double
    private let interpolator: (Interpolatable, Interpolatable, CGFloat) -> Interpolatable
    
    init(fromValue: T, toValue: T, animation: ContainedViewLayoutTransition, startTimestamp: Double) {
        self.from = fromValue
        self.to = toValue
        self.animation = animation
        self.startTimestamp = startTimestamp
        self.interpolator = T.interpolator()
    }
    
    func valueAt(_ t: CGFloat) -> Interpolatable {
        if t <= 0.0 {
            return self.from
        } else if t >= 1.0 {
            return self.to
        } else {
            return self.interpolator(self.from, self.to, t)
        }
    }
}

public final class AnimatableProperty<T: Interpolatable> {
    public private(set) var presentationValue: T
    public private(set) var value: T
    private var animation: PropertyAnimation<T>?
    
    public init(value: T) {
        self.value = value
        self.presentationValue = value
    }
    
    public func update(value: T, transition: ContainedViewLayoutTransition = .immediate) {
        let currentTimestamp = CACurrentMediaTime()
        if case .immediate = transition {
            if let animation = self.animation, case let .animated(duration, curve) = animation.animation {
                self.value = value
                let elapsed = duration - (currentTimestamp - animation.startTimestamp)
                if let presentationValue = self.presentationValue as? CGFloat, let newValue = value as? CGFloat, abs(presentationValue - newValue) > 0.56 {
                    self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: .animated(duration: elapsed * 0.8, curve: curve), startTimestamp: currentTimestamp)
                } else {
                    self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: .animated(duration: elapsed, curve: curve), startTimestamp: currentTimestamp)
                }
            } else {
                self.value = value
                self.presentationValue = value
                self.animation = nil
            }
        } else {
            self.value = value
            self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: transition, startTimestamp: currentTimestamp)
        }
    }
    
    public func tick(timestamp: Double) -> Bool {
        guard let animation = self.animation, case let .animated(duration, curve) = animation.animation else {
            return false
        }
        
        let timeFromStart = timestamp - animation.startTimestamp
        var t = max(0.0, timeFromStart / duration)
        switch curve {
        case .linear:
            break
        case .easeInOut:
            t = listViewAnimationCurveEaseInOut(t)
        case .spring:
            t = lookupSpringValue(t)
        case .easeOut:
            t = listViewAnimationCurveEaseInOut(t)
        case .legacy:
            t = listViewAnimationCurveEaseInOut(t)
        }
        self.presentationValue = animation.valueAt(t) as! T

        if timeFromStart <= duration {
            return true
        }
        self.animation = nil
        return false
    }
}

private func lookupSpringValue(_ t: CGFloat) -> CGFloat {
    let table: [(CGFloat, CGFloat)] = [
        (0.0, 0.0),
        (0.0625, 0.1123005598783493),
        (0.125, 0.31598418951034546),
        (0.1875, 0.5103585720062256),
        (0.25, 0.6650152802467346),
        (0.3125, 0.777747631072998),
        (0.375, 0.8557760119438171),
        (0.4375, 0.9079672694206238),
        (0.5, 0.942038357257843),
        (0.5625, 0.9638798832893372),
        (0.625, 0.9776856303215027),
        (0.6875, 0.9863143563270569),
        (0.75, 0.991658091545105),
        (0.8125, 0.9949421286582947),
        (0.875, 0.9969474077224731),
        (0.9375, 0.9981651306152344),
        (1.0, 1.0)
    ]
    
    for i in 0 ..< table.count - 2 {
        let lhs = table[i]
        let rhs = table[i + 1]
        
        if t >= lhs.0 && t <= rhs.0 {
            let fraction = (t - lhs.0) / (rhs.0 - lhs.0)
            let value = lhs.1 + fraction * (rhs.1 - lhs.1)
            return value
        }
    }
    return 1.0
}



extension CGFloat: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            let fromValue: CGFloat = from as! CGFloat
            let toValue: CGFloat = to as! CGFloat
            let invT: CGFloat = 1.0 - t
            let term: CGFloat = toValue * t + fromValue * invT
            return term
        }
    }
    
    static func interpolate(from fromValue: CGFloat, to toValue: CGFloat, at t: CGFloat) -> CGFloat {
        let invT: CGFloat = 1.0 - t
        let term: CGFloat = toValue * t + fromValue * invT
        return term
    }
}
